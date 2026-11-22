extends Control
## 공책 종이 창 하나. kind 에 따라 내용이 달라진다:
##   "bag"    가방 (I): 입은 장비, 가방 속 장비, 재료
##   "skills" 스킬 (K): 스킬 포인트로 배우고, Q·E·R 칸에 넣기
##   "shop"   문방구: 사기, 팔기, 만들기, 강화
## 내용은 GameState 가 바뀔 때마다 통째로 다시 만든다 (목록이 짧아서 충분하다).

const Art := preload("res://scripts/art.gd")
const Data := preload("res://scripts/game_data.gd")
const Items := preload("res://scripts/items.gd")

const INK := Color(0.3, 0.25, 0.22)
const INK_SOFT := Color(0.5, 0.42, 0.38)
const TITLES := {"bag": "가방", "skills": "스킬", "shop": "문방구"}
const TABS := {"bag": ["장비", "재료", "소모품"], "skills": [], "shop": ["사기", "팔기", "만들기", "강화"]}
const CLOSE_HINT := {"bag": "I  닫기", "skills": "K  닫기", "shop": "Esc  닫기"}

var kind := "bag"
var tab := 0
var selected := -1            # 가방에서 고른 장비 (-1 없음). 입은 장비는 -2 - 부위 번호
var _win: Control
var _body: Control
var _info: Label
var _tab_buttons: Array = []
var _message := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.08, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_win = TextureRect.new()
	(_win as TextureRect).texture = Art.tex("ui_window")
	(_win as TextureRect).expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	(_win as TextureRect).stretch_mode = TextureRect.STRETCH_SCALE
	_win.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_win.position = Vector2(110, 46)
	_win.size = Vector2(420, 268)
	_win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_win)
	var title := _label(_win, str(TITLES[kind]), Vector2(0, 12), Vector2(420, 22), 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var x := 66.0
	for i in (TABS[kind] as Array).size():
		var b := _button(_win, str(TABS[kind][i]), Vector2(x, 34), Vector2(50, 20), _set_tab.bind(i))
		_tab_buttons.append(b)
		x += 54.0
	_body = Control.new()
	_body.position = Vector2(62, 62 if not (TABS[kind] as Array).is_empty() else 44)
	_body.size = Vector2(300, 130 if not (TABS[kind] as Array).is_empty() else 148)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win.add_child(_body)
	_info = _label(_win, "", Vector2(64, 194), Vector2(296, 46), 9)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var foot := _label(_win, str(CLOSE_HINT[kind]), Vector2(0, 243), Vector2(420, 14), 10)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_color_override("font_color", INK_SOFT)
	GameState.changed.connect(func() -> void:
		if visible:
			refresh())


func open() -> void:
	selected = -1
	_message = ""
	refresh()


func _set_tab(i: int) -> void:
	tab = i
	selected = -1
	_message = ""
	refresh()


# ---------- 부품 ----------

func _label(parent: Control, text: String, pos: Vector2, size: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", INK)
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, pos: Vector2, size: Vector2, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 9)
	# 공책에 어울리는 종이색 단추 (기본 어두운 단추를 쓰지 않는다)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color(0.99, 0.95, 0.84), "hover": Color(1.0, 0.9, 0.7),
			"pressed": Color(0.95, 0.82, 0.6), "disabled": Color(0.9, 0.86, 0.78, 0.6)}[state]
		sb.border_color = Color(0.5, 0.38, 0.3) if state != "disabled" else Color(0.65, 0.58, 0.52, 0.6)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(3)
		sb.set_content_margin_all(1)
		b.add_theme_stylebox_override(state, sb)
	for col in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(col, INK)
	b.add_theme_color_override("font_disabled_color", INK_SOFT)
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


func _icon(parent: Control, tex_name: String, pos: Vector2, size: float, tint: Color = Color.WHITE) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = Art.tex(tex_name)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.position = pos
	tr.size = Vector2(size, size)
	tr.modulate = tint
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr


func _clear_style(b: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())


## 세로로 긴 목록을 담는 스크롤 상자. 돌려주는 것은 줄을 넣을 상자다.
func _list() -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.position = Vector2.ZERO
	sc.size = _body.size
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(sc)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	sc.add_child(box)
	return box


## 목록의 한 줄: 아이콘, 글, 오른쪽 단추들 [[글, 눌렀을 때, 누를 수 있는지], ...]
func _row(box: VBoxContainer, icon_name: String, text: String, buttons: Array, tint: Color = Color.WHITE) -> void:
	var row := Control.new()
	row.custom_minimum_size = Vector2(286, 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	if icon_name != "":
		_icon(row, icon_name, Vector2(0, 2), 18, tint)
	var x := 286.0
	for i in range(buttons.size() - 1, -1, -1):
		var spec: Array = buttons[i]
		var w := maxf(20.0, 8.0 + str(spec[0]).length() * 8.0)
		x -= w + 2.0
		var b := _button(row, str(spec[0]), Vector2(x, 0), Vector2(w, 21), spec[1])
		b.disabled = not bool(spec[2])
	_label(row, text, Vector2(22, 4), Vector2(x - 24, 16), 9)


func refresh() -> void:
	_clear_action_buttons()
	for c in _body.get_children():
		c.queue_free()
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).disabled = i == tab
	_info.text = _message
	match kind:
		"bag": _refresh_bag()
		"skills": _refresh_skills()
		"shop": _refresh_shop()


# ---------- 가방 ----------

func _refresh_bag() -> void:
	if tab == 1:
		_materials_grid()
		return
	if tab == 2:
		var box := _list()
		for id in Items.CONSUMABLES:
			var n := GameState.consumable_count(str(id))
			if n > 0:
				var info: Array = Items.CONSUMABLES[id]
				_row(box, str(info[1]), "%s ×%d   %s" % [info[0], n, info[3]], [])
		_info.text = "1 번 키: 반창고    2 번 키: 우유"
		return
	# 입은 장비 6칸 (2 × 3)
	for i in Items.SLOTS.size():
		var slot := str(Items.SLOTS[i])
		var pos := Vector2((i % 2) * 40, (i / 2) * 44)
		_icon(_body, "ui_slot_on" if selected == -2 - i else "ui_slot", pos, 36)
		if GameState.equipped.has(slot):
			var item: Dictionary = GameState.equipped[slot]
			_icon(_body, Items.icon(item), pos + Vector2(5, 5), 26, Items.tier_color(item))
		_clear_style(_button(_body, "", pos, Vector2(36, 36), _select.bind(-2 - i)))
		var name_l := _label(_body, str(Items.SLOT_NAMES[slot]), pos + Vector2(-2, 35), Vector2(40, 10), 7)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.add_theme_color_override("font_color", INK_SOFT)
	# 가방 속 장비 (6 × 4)
	for i in GameState.INVENTORY_SIZE:
		var pos2 := Vector2(96 + (i % 6) * 34, (i / 6) * 33)
		_icon(_body, "ui_slot_on" if selected == i else "ui_slot", pos2, 31)
		if i < GameState.inventory.size():
			var item2: Dictionary = GameState.inventory[i]
			_icon(_body, Items.icon(item2), pos2 + Vector2(4, 4), 23, Items.tier_color(item2))
			_clear_style(_button(_body, "", pos2, Vector2(31, 31), _select.bind(i)))
	# 고른 장비의 설명과 단추
	var item3 := _selected_item()
	if item3.is_empty():
		_info.text = _message if _message != "" else "장비를 누르면 설명이 나와요.   동전 %d   지우개 가루 %d" % [GameState.coins, GameState.dust]
		return
	_info.text = Items.describe(item3).replace("\n", "   ")
	if selected >= 0:
		_button(_win, "입기", Vector2(226, 218), Vector2(40, 20), _equip_selected)
		_button(_win, "분해", Vector2(270, 218), Vector2(40, 20), _disassemble_selected)
	else:
		_button(_win, "벗기", Vector2(270, 218), Vector2(40, 20), _unequip_selected)


func _materials_grid() -> void:
	for i in Data.MATERIALS.size():
		var pos := Vector2(4 + (i % 6) * 49, (i / 6) * 62)
		var n := GameState.material_count(i)
		_icon(_body, "ui_slot", pos + Vector2(3, 0), 38)
		_icon(_body, "mat_%d" % i, pos + Vector2(9, 6), 26, Color(1, 1, 1, 1) if n > 0 else Color(0.2, 0.2, 0.2, 0.25))
		var count := _label(_body, str(n) if n > 0 else "", pos + Vector2(20, 24), Vector2(22, 12), 9)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var name_l := _label(_body, str(Data.MATERIALS[i]) if n > 0 else "?", pos + Vector2(-4, 39), Vector2(52, 12), 8)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.text = "필력 %d   경험치 %d / %d   연필심 %d   동전 %d   지우개 가루 %d" % [
		GameState.level, GameState.exp, GameState.exp_needed(), GameState.pencil_lead, GameState.coins, GameState.dust]


func _select(i: int) -> void:
	selected = i
	_message = ""
	_clear_action_buttons()
	refresh()


func _selected_item() -> Dictionary:
	if selected >= 0 and selected < GameState.inventory.size():
		return GameState.inventory[selected]
	if selected <= -2:
		var slot := str(Items.SLOTS[-2 - selected])
		if GameState.equipped.has(slot):
			return GameState.equipped[slot]
	return {}


## 입기·분해·벗기 단추는 창에 직접 붙이므로 따로 지운다
func _clear_action_buttons() -> void:
	for c in _win.get_children():
		if c is Button and not _tab_buttons.has(c):
			c.queue_free()


func _equip_selected() -> void:
	var i := selected
	selected = -1
	_clear_action_buttons()
	if not GameState.equip(i):
		_message = "필력이 모자라서 쓸 수 없어요."
		refresh()


func _disassemble_selected() -> void:
	var i := selected
	selected = -1
	_clear_action_buttons()
	_message = "지우개 가루 %d개를 얻었어요." % GameState.disassemble(i)
	refresh()


func _unequip_selected() -> void:
	var slot := str(Items.SLOTS[-2 - selected])
	selected = -1
	_clear_action_buttons()
	if not GameState.unequip(slot):
		_message = "가방이 가득 차서 벗을 수 없어요."
		refresh()


# ---------- 스킬 ----------

func _refresh_skills() -> void:
	var box := _list()
	for id in Items.SKILL_ORDER:
		var info: Dictionary = Items.SKILLS[id]
		var rank := GameState.skill_rank(str(id))
		var locked := GameState.level < int(info["level"])
		var text := "%s  %d/%d" % [info["name"], rank, int(info["max"])]
		if locked:
			text += "  (필력 %d 부터)" % int(info["level"])
		elif str(info["kind"]) == "active":
			text += "  MP %d · %d초" % [int(info["mp"]), int(info["cd"])]
		var buttons: Array = []
		if str(info["kind"]) == "active" and rank > 0:
			for s in Items.SKILL_KEYS.size():
				var here: bool = str(GameState.skill_slots[s]) == str(id)
				buttons.append([str(Items.SKILL_KEYS[s]), GameState.set_skill_slot.bind(s, str(id)), not here])
		buttons.append(["+", _learn.bind(str(id)), GameState.skill_points > 0 and not locked and rank < int(info["max"])])
		_row(box, str(info["icon"]), text, buttons, Color(1, 1, 1, 0.35) if locked else Color.WHITE)
	if _message == "":
		_info.text = "스킬 포인트 %d   (레벨마다 1점)   + 로 배우고, Q·E·R 을 눌러 칸에 넣어요." % GameState.skill_points


func _learn(id: String) -> void:
	if GameState.learn_skill(id):
		_message = "%s: %s" % [Items.SKILLS[id]["name"], Items.SKILLS[id]["desc"]]
	refresh()


# ---------- 문방구 ----------

func _refresh_shop() -> void:
	var box := _list()
	var wallet := "동전 %d   연필심 %d   지우개 가루 %d" % [GameState.coins, GameState.pencil_lead, GameState.dust]
	if tab == 0:
		for entry in Items.SHOP:
			if typeof(entry) == TYPE_STRING:
				var info: Array = Items.CONSUMABLES[entry]
				_row(box, str(info[1]), "%s  (%d개 있음)  %s" % [info[0], GameState.consumable_count(str(entry)), info[3]],
					[["%d" % int(info[2]), _buy.bind(entry), GameState.coins >= int(info[2])]])
			else:
				var arr: Array = entry
				var sample := {"slot": arr[0], "shape": arr[1], "tier": arr[2], "level": 1, "plus": 0, "opts": []}
				_row(box, Items.icon(sample), Items.item_name(sample) + "  " + Items.stat_text(str(Items.MAIN_STAT[str(arr[0])]), Items.main_value(sample)),
					[["%d" % int(arr[3]), _buy.bind(entry), GameState.coins >= int(arr[3])]], Items.tier_color(sample))
	elif tab == 1:
		for i in GameState.inventory.size():
			var item: Dictionary = GameState.inventory[i]
			_row(box, Items.icon(item), Items.item_name(item),
				[["팔기 %d" % Items.sell_price(item), _sell.bind(i), true]], Items.tier_color(item))
		if GameState.inventory.is_empty():
			_row(box, "", "팔 장비가 없어요.", [])
	elif tab == 2:
		for recipe in Items.RECIPES:
			var parts: Array = []
			var mats: Dictionary = recipe[2]
			for id in mats:
				parts.append("%s %d/%d" % [Data.MATERIALS[int(id)], GameState.material_count(int(id)), int(mats[id])])
			if int(recipe[3]) > 0:
				parts.append("연필심 %d" % int(recipe[3]))
			var icon_name := ""
			var tint := Color.WHITE
			if typeof(recipe[1]) == TYPE_STRING:
				icon_name = str(Items.CONSUMABLES[recipe[1]][1])
			else:
				var r: Array = recipe[1]
				icon_name = "equip_%s_%d" % [r[0], int(r[1])]
				tint = Items.TIER_COLORS[int(r[2])]
			_row(box, icon_name, "%s  ←  %s" % [recipe[0], ", ".join(parts)], [["만들기", _craft.bind(recipe), GameState.can_craft(recipe)]], tint)
	else:
		var all: Array = []
		for slot in Items.SLOTS:
			if GameState.equipped.has(slot):
				all.append(GameState.equipped[slot])
		all.append_array(GameState.inventory)
		for item2 in all:
			var cost: Array = Items.enhance_cost(item2)
			var maxed := int(item2.get("plus", 0)) >= Items.MAX_PLUS
			var text := "%s   연필심 %d · 가루 %d · 성공 %d%%" % [Items.item_name(item2), int(cost[0]), int(cost[1]), roundi(Items.enhance_rate(item2) * 100.0)]
			_row(box, Items.icon(item2), Items.item_name(item2) + "  (최고 단계)" if maxed else text,
				[["강화", _enhance.bind(item2), not maxed]], Items.tier_color(item2))
		wallet += "   +7부터 실패하면 하락, +10부터 파괴"
	_info.text = (_message + "\n" if _message != "" else "") + wallet


func _buy(entry: Variant) -> void:
	_message = "샀어요." if GameState.buy(entry) else "동전이 모자라거나 가방이 가득 찼어요."
	refresh()


func _sell(i: int) -> void:
	_message = "동전 %d개를 받았어요." % GameState.sell_item(i)
	refresh()


func _craft(recipe: Array) -> void:
	_message = "%s 을(를) 만들었어요." % recipe[0] if GameState.craft(recipe) else "재료가 모자라요."
	refresh()


func _enhance(item: Dictionary) -> void:
	var result := GameState.enhance(item)
	var texts := {"ok": "강화 성공!", "fail": "실패… 다행히 그대로예요.", "down": "실패… 한 단계 내려갔어요.",
		"broken": "실패… 장비가 지워졌어요.", "saved": "실패했지만 코팅지가 막아 줬어요."}
	_message = str(texts.get(result, result))
	refresh()
