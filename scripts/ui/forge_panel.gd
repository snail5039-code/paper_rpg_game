extends Control
## 강화소 화면. 내 마을의 강화소(bld_forge)에 F 로 연다.
##  왼쪽: 입은 장비와 가방의 장비 (눌러서 고른다). 오른쪽: 고른 장비, 지금 → 다음 능력, 성공률, 값, 실패하면 어떻게 되는지,
##  코팅지를 쓸지 고르는 칸, "두드리기" 단추.
##  두드리면 화면 가운데에 모루와 장비가 나오고 망치가 세 번 탕탕 내려친다. 그다음 결과를 크게 보여 준다
##  (성공: 금빛 별과 오라, 실패: 먼지, 하락: 회색으로 흔들림, 파괴: 종이 조각, 코팅지: 방패). 누르거나 잠시 뒤에 닫힌다.
##  강화소의 단계가 높을수록 성공률이 오른다 (GameState.forge_bonus).

signal closed

const Art := preload("res://scripts/core/art.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const Items := preload("res://scripts/data/items.gd")

const GRID := Rect2(62, 44, 150, 158)    # 장비 칸 (창 안)
const CELL := 30.0
const HIT_GAP := 0.32                    # 망치질 사이 시간
const CENTER := Vector2(320, 190)        # 연출의 가운데 (화면)
const RESULT_TEXT := {"ok": "강화 성공!", "fail": "실패…", "down": "실패… 한 단계 내려감", "broken": "장비가 지워졌어요", "saved": "코팅지가 막았어요!"}
const RESULT_COLOR := {"ok": Color(1.0, 0.85, 0.3), "fail": Color(0.85, 0.85, 0.85), "down": Color(0.75, 0.75, 0.9),
	"broken": Color(1.0, 0.45, 0.4), "saved": Color(0.6, 0.85, 1.0)}
const RESULT_FX := {"ok": "forge_ok", "fail": "forge_fail", "down": "forge_fail", "broken": "forge_broken", "saved": "forge_saved"}

var selected: Dictionary = {}
var use_coating := true
var busy := false
var last_result := ""
var result_hold := 2.4                   # 결과를 보여 주는 시간 (누르면 바로 닫힌다)

var _win: Control
var _grid_box: Control
var _big: TextureRect
var _name: Label
var _stat: Label
var _rate: Label
var _cost: Label
var _risk: Label
var _coat: Button
var _hit_btn: Button
var _info: Label
var _items: Array = []
var _stage: Control                      # 가운데 연출
var _skip := false


func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.08, 0.45)
	dim.size = size
	add_child(dim)
	_win = UI.icon(self, "ui_window", Vector2(110, 46), Vector2(420, 268), Color.WHITE, false)
	UI.icon(_win, "ui_plaque", Vector2(150, 5), Vector2(120, 27), Color.WHITE, false)
	var tl := UI.label(_win, "강화소", Vector2(166, 10), Vector2(100, 20), 12)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.icon_button(_win, "ui_close", Vector2(396, 0), Vector2(20, 20), close)
	var scroll := ScrollContainer.new()
	scroll.position = GRID.position
	scroll.size = GRID.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_win.add_child(scroll)
	_grid_box = Control.new()
	scroll.add_child(_grid_box)
	# 오른쪽: 고른 장비
	var x := 222.0
	UI.icon(_win, "ui_board", Vector2(x, 44), Vector2(56, 56), Color.WHITE, false)
	_big = TextureRect.new()
	_big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_big.position = Vector2(x + 9, 53)
	_big.size = Vector2(38, 38)
	_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win.add_child(_big)
	_name = UI.label(_win, "", Vector2(x + 62, 46), Vector2(116, 30), 10)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stat = UI.label(_win, "", Vector2(x + 62, 80), Vector2(116, 14), 9)
	_rate = UI.label(_win, "", Vector2(x, 104), Vector2(178, 14), 10)
	_cost = UI.label(_win, "", Vector2(x, 119), Vector2(178, 14), 9)
	_risk = UI.label(_win, "", Vector2(x, 133), Vector2(178, 24), 9)
	_risk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_risk.add_theme_color_override("font_color", Color(0.65, 0.3, 0.28))
	_coat = UI.button(_win, "", Vector2(x, 158), Vector2(178, 18), _toggle_coat)
	_hit_btn = UI.button(_win, "두드리기", Vector2(x, 180), Vector2(178, 22), hit)
	_info = UI.label(_win, "", Vector2(62, 208), Vector2(338, 26), 9)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_color_override("font_color", UI.INK_SOFT)
	refresh()


## 고를 수 있는 장비: 입은 것 먼저, 그다음 가방
func gear_list() -> Array:
	var out: Array = []
	for slot in Items.SLOTS:
		if GameState.equipped.has(slot):
			out.append(GameState.equipped[slot])
	out.append_array(GameState.inventory)
	return out


func select(item: Dictionary) -> void:
	if busy:
		return
	selected = item
	last_result = ""
	refresh()


func _toggle_coat() -> void:
	use_coating = not use_coating
	refresh()


func refresh() -> void:
	for c in _grid_box.get_children():
		c.queue_free()
	_items = gear_list()
	if not selected.is_empty() and not _items.any(func(it: Dictionary) -> bool: return is_same(it, selected)):
		selected = {}
	if selected.is_empty() and not _items.is_empty():
		selected = _items[0]
	var cols := int(GRID.size.x / CELL)
	_grid_box.custom_minimum_size = Vector2(GRID.size.x - 10, ceilf(_items.size() / float(cols)) * CELL)
	var worn := 0
	for slot in Items.SLOTS:
		if GameState.equipped.has(slot):
			worn += 1
	for i in _items.size():
		var it: Dictionary = _items[i]
		var pos := Vector2((i % cols) * CELL, (i / cols) * CELL)
		UI.icon(_grid_box, "ui_btn_sq_on" if is_same(it, selected) else "ui_slot", pos, Vector2(CELL - 2, CELL - 2), Color.WHITE, false)
		UI.icon(_grid_box, Items.icon(it), pos + Vector2(4, 4), Vector2(CELL - 10, CELL - 10), Items.tier_color(it))
		var plus := int(it.get("plus", 0))
		if plus > 0:
			var pl := UI.label(_grid_box, "+%d" % plus, pos + Vector2(8, 16), Vector2(19, 10), 8)
			pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			pl.add_theme_color_override("font_color", Items.aura_color(plus) if plus >= Items.AURA_MIN else UI.INK)
		if i < worn:
			UI.label(_grid_box, "E", pos + Vector2(3, 0), Vector2(10, 10), 8)
		var b := Button.new()
		b.flat = true
		b.position = pos
		b.size = Vector2(CELL - 2, CELL - 2)
		b.pressed.connect(select.bind(it))
		_grid_box.add_child(b)
	_show_selected()


func _show_selected() -> void:
	var coats := GameState.consumable_count("coating")
	_coat.text = "코팅지 쓰기: %s  (%d장)" % ["예" if use_coating else "아니요", coats]
	if selected.is_empty():
		_big.texture = null
		_name.text = "강화할 장비가 없어요."
		for l in [_stat, _rate, _cost, _risk]:
			(l as Label).text = ""
		_hit_btn.disabled = true
		_info.text = _footer()
		return
	_big.texture = Art.tex(Items.icon(selected))
	_big.modulate = Items.tier_color(selected)
	_name.text = Items.item_name(selected)
	var plus := int(selected.get("plus", 0))
	var key := str(Items.MAIN_STAT[str(selected["slot"])])
	var now := Items.main_value(selected)
	var maxed := plus >= Items.MAX_PLUS
	if maxed:
		_stat.text = "%s %d" % [Items.STAT_LABEL[key], now]
		_rate.text = "최고 단계 (+%d)" % plus
		_cost.text = ""
		_risk.text = ""
	else:
		var next := selected.duplicate(true)
		next["plus"] = plus + 1
		_stat.text = "%s %d → %d" % [Items.STAT_LABEL[key], now, Items.main_value(next)]
		var base := Items.enhance_rate(selected)
		var chance := GameState.enhance_chance(selected, GameState.forge_bonus())
		_rate.text = "+%d → +%d   성공 %d%%%s" % [plus, plus + 1, roundi(chance * 100.0), " (+%d)" % roundi((chance - base) * 100.0) if chance > base else ""]
		var cost: Array = Items.enhance_cost(selected)
		_cost.text = "연필심 %d/%d   가루 %d/%d" % [int(cost[0]), GameState.pencil_lead, int(cost[1]), GameState.dust]
		_cost.add_theme_color_override("font_color", UI.INK if GameState.pencil_lead >= int(cost[0]) and GameState.dust >= int(cost[1]) else Color(0.75, 0.3, 0.3))
		var guard := use_coating and coats > 0
		if plus < 6:
			_risk.text = "실패해도 그대로예요."
		elif plus < 9:
			_risk.text = "실패하면 한 단계 내려가요." + (" 코팅지가 막아 줘요." if guard else "")
		else:
			_risk.text = "실패하면 장비가 지워져요!" + (" 코팅지가 막아 줘요." if guard else "")
	_hit_btn.disabled = busy or maxed
	_info.text = _footer()


func _footer() -> String:
	if last_result != "":
		return str(RESULT_TEXT.get(last_result, last_result))
	var lv := GameState.build_level("bld_forge")
	return "강화소 %d단계: 성공률 +%d%%. +%d부터 발밑에 오라가 생겨요.   Esc 닫기" % [lv, roundi(GameState.forge_bonus() * 100.0), Items.AURA_MIN]


## 두드리기: 가운데에서 망치 세 번 → 결과를 크게
func hit() -> void:
	if busy or selected.is_empty():
		return
	var cost: Array = Items.enhance_cost(selected)
	if GameState.pencil_lead < int(cost[0]) or GameState.dust < int(cost[1]):
		last_result = "재료가 부족해요. (연필심 %d, 지우개 가루 %d)" % [int(cost[0]), int(cost[1])]
		Sound.play("fail")
		_show_selected()
		return
	busy = true
	_hit_btn.disabled = true
	var item := selected
	var before := int(item.get("plus", 0))
	var icon := Items.icon(item)
	var tint := Items.tier_color(item)
	# 결과는 먼저 정해 두고, 연출이 끝난 뒤에 보여 준다
	last_result = GameState.enhance(item, use_coating, GameState.forge_bonus())
	await _play_stage(icon, tint, before, last_result)
	if last_result == "broken":
		selected = {}
	busy = false
	GameState.save_game()
	refresh()


## 가운데 연출. 멈춤 중에도 흐르는 타이머를 쓴다 (창이 열리면 게임이 멈춘다).
func _play_stage(icon: String, tint: Color, before: int, result: String) -> void:
	_skip = false
	_stage = Control.new()
	_stage.size = size
	_stage.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_skip = true)
	add_child(_stage)
	_win.visible = false        # 연출 동안 창은 숨긴다
	var dark := ColorRect.new()
	dark.color = Color(0.06, 0.05, 0.05, 0.78)
	dark.size = size
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(dark)
	var anvil := _sprite("forge_anvil", CENTER + Vector2(0, 50), 128.0)
	var glow := _sprite("fx_aura", CENTER + Vector2(0, 8), 150.0, 4)
	glow.visible = false
	var item := _sprite(icon, CENTER + Vector2(0, -6), 58.0)
	item.modulate = tint
	var hammer := _sprite("forge_hammer_up", CENTER + Vector2(56, -54), 96.0)
	var spark := _sprite("forge_spark", CENTER + Vector2(0, -6), 96.0)
	spark.visible = false
	var plus_label := _label("+%d" % before, CENTER + Vector2(-150, -20), Vector2(100, 28), 24, Color(1, 1, 1))
	# 탕! 탕! 탕!
	for i in 3:
		hammer.texture = Art.tex("forge_hammer_up")
		hammer.position = CENTER + Vector2(58, -58)
		hammer.rotation = 0.0
		await _wait(HIT_GAP * 0.55)
		hammer.texture = Art.tex("forge_hammer_hit")
		hammer.position = CENTER + Vector2(30, -26)
		Sound.play("forge_hit")
		spark.visible = true
		spark.rotation = randf() * TAU
		spark.scale = Vector2.ONE * spark.get_meta("k") * (0.8 + 0.15 * i)
		_shake_stage(5.0 + i * 2.0)
		await _wait(HIT_GAP * 0.45)
		spark.visible = false
	hammer.visible = false
	# 결과
	var fx := _sprite(str(RESULT_FX.get(result, "forge_fail")), CENTER + Vector2(0, -6), 70.0)
	if result == "ok":
		_stage.move_child(fx, 1)   # 금빛 별은 장비 뒤에서 퍼진다 (어두운 바탕 바로 위)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	var k: float = fx.get_meta("k")
	fx.scale = Vector2.ONE * k * 0.3
	tw.tween_property(fx, "scale", Vector2.ONE * k * (2.6 if result == "ok" else 1.8), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	match result:
		"ok":
			Sound.play("forge_ok")
			plus_label.text = "+%d" % (before + 1)
			tw.tween_property(fx, "rotation", 0.6, 1.8)
			tw.tween_property(item, "scale", item.scale * 1.25, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_flash()
			# 오라: 이 단계부터 캐릭터에 생기는 빛을 미리 보여 준다
			if before + 1 >= Items.AURA_MIN:
				glow.visible = true
				glow.modulate = Items.aura_color(before + 1)
			_shake_stage(10.0)
		"broken":
			Sound.play("forge_break")
			tw.tween_property(item, "modulate:a", 0.0, 0.35)
			tw.tween_property(item, "scale", item.scale * 0.3, 0.35)
			plus_label.text = ""
			_shake_stage(14.0)
		"down":
			Sound.play("forge_down")
			plus_label.text = "+%d" % (before - 1)
			item.modulate = tint.darkened(0.35)
			_shake_stage(8.0)
		"saved":
			Sound.play("forge_saved")
		_:
			Sound.play("fail")
	var big := _label(str(RESULT_TEXT.get(result, result)), Vector2(0, 46), Vector2(640, 60), 40, RESULT_COLOR.get(result, Color.WHITE))
	big.pivot_offset = Vector2(320, 30)
	big.scale = Vector2(0.4, 0.4)
	var tw2 := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw2.tween_property(big, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.tween_property(big, "scale", Vector2.ONE, 0.12)
	var sub := {"ok": "+%d → +%d" % [before, before + 1], "down": "+%d → +%d" % [before, before - 1], "fail": "그대로 +%d" % before,
		"saved": "그대로 +%d (코팅지 1장 씀)" % before, "broken": "+%d 장비가 사라졌어요" % before}
	_label(str(sub.get(result, "")), Vector2(0, 104), Vector2(640, 24), 16, Color(1, 1, 1, 0.9))
	_label("누르면 계속", Vector2(0, 318), Vector2(640, 16), 10, Color(1, 1, 1, 0.55))
	# 보여 주기: 누르거나 시간이 지나면 닫는다
	var t := 0.0
	while t < result_hold and not _skip:
		if glow.visible:
			glow.frame = [0, 1, 2, 3, 2, 1][int(t * 8.0) % 6]
		await _wait(0.05)
		t += 0.05
	_stage.queue_free()
	_stage = null
	_win.visible = true


func _sprite(tex_name: String, at: Vector2, width: float, hframes: int = 1) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Art.tex(tex_name)
	s.hframes = hframes
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var k := width / (s.texture.get_width() / float(hframes)) if s.texture else 1.0
	s.set_meta("k", k)
	s.scale = Vector2.ONE * k
	s.position = at
	_stage.add_child(s)
	return s


func _label(text: String, pos: Vector2, sz: Vector2, font: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.1))
	l.add_theme_constant_override("outline_size", maxi(4, font / 6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(l)
	return l


func _flash() -> void:
	var f := ColorRect.new()
	f.color = Color(1, 0.97, 0.85, 0.85)
	f.size = size
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(f)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(f, "color:a", 0.0, 0.35)
	tw.tween_callback(f.queue_free)


func _shake_stage(power: float) -> void:
	if _stage == null:
		return
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for i in 4:
		tw.tween_property(_stage, "position", Vector2(randf_range(-power, power), randf_range(-power, power)), 0.03)
	tw.tween_property(_stage, "position", Vector2.ZERO, 0.04)


func _wait(sec: float) -> void:
	if is_inside_tree():
		await get_tree().create_timer(sec, true).timeout


func close() -> void:
	if busy:
		return
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if busy:
		_skip = true          # 결과 화면에서 아무 키나 누르면 넘어간다
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
