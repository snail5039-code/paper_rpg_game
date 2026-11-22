extends CanvasLayer
## HUD: HP, 연필심, 퀘스트, 조작 안내(키 아이콘), 알림 메시지, 대화창(초상화).

const Art := preload("res://scripts/art.gd")
const Data := preload("res://scripts/game_data.gd")
const MapViewScript := preload("res://scripts/map_view.gd")
const MenusScript := preload("res://scripts/menus.gd")
const UltimateScript := preload("res://scripts/ultimate.gd")
const TracePanelScript := preload("res://scripts/trace_panel.gd")
const FishingScript := preload("res://scripts/fishing.gd")
const Items := preload("res://scripts/items.gd")
const HP_FILL_W := 106.0
const EXP_FILL_W := 110.0

var quest_text_override := ""   # 비어 있지 않으면 "할 일" 대신 이 글을 보여 준다 (내 마을)
var _hp_label: Label
var _hp_clip: Control
var _exp_clip: Control
var _level_label: Label
var _bag: Control
var _stats: Control
var _stats_points: Label
var _stats_derived: Label
var _stat_rows: Array = []
var _mp_bar: ColorRect
var _map: Control
var _map_view: Control
var _points_badge: Label
var _menus: Dictionary = {}
var _quick: Array = []
var _ult: Control              # 필살기 화면
var _trace: Control            # 따라 그리기 화면 (포획, 건물 짓기)
var _fishing: Control          # 낚시 화면
var _night: ColorRect          # 밤에 화면을 어둡게 덮는 막
var _clock_label: Label
var _day_label: Label
var _ult_slot: Array = []      # [틀, 아이콘, 가림막, 글]
var _coin_label: Label
var _lead_label: Label
var _quest_label: Label
var _hint_box: HBoxContainer
var _hints: Array = []
var _toast: Label
var _toast_tween: Tween

var _dlg: PanelContainer
var _dlg_portrait: TextureRect
var _dlg_name: Label
var _dlg_text: Label
var _lines: Array = []
var _line_idx := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_night = ColorRect.new()
	_night.color = Color(0.08, 0.1, 0.32, 0.0)
	_night.size = Vector2(640, 360)
	_night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_night)
	_clock_label = _label(root, Vector2(548, 6), 11)
	_day_label = _label(root, Vector2(548, 20), 9)

	_build_bars(root)
	_quest_label = _label(root, Vector2(10, 68), 13)
	_quest_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))

	_hint_box = HBoxContainer.new()
	_hint_box.position = Vector2(10, 326)
	_hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_box.add_theme_constant_override("separation", 5)
	root.add_child(_hint_box)

	_toast = _label(root, Vector2(0, 80), 15)
	_toast.size = Vector2(640, 24)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0

	_build_quickbar(root)
	_build_menus(root)
	_ult = UltimateScript.new()
	root.add_child(_ult)
	_trace = TracePanelScript.new()
	root.add_child(_trace)
	_fishing = FishingScript.new()
	root.add_child(_fishing)
	add_to_group("hud")
	_build_stats(root)
	_build_map(root)
	_build_dialogue(root)

	GameState.changed.connect(_refresh)
	GameState.message.connect(show_toast)
	GameState.dialogue_requested.connect(_on_dialogue)
	GameState.dialogue_finished.connect(func() -> void: _dlg.visible = false)
	_refresh()


func _label(parent: Control, pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(l, font_size)
	parent.add_child(l)
	return l


func _style_label(l: Label, font_size: int) -> void:
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.15, 0.2))
	l.add_theme_constant_override("outline_size", 3)


func _tex_rect(parent: Control, tex_name: String, pos: Vector2, size: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = Art.tex(tex_name)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # 크기를 정하기 전에 먼저
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.position = pos
	tr.size = size
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr


## 왼쪽 위: HP 막대, 경험치 눈금, 레벨, 연필과 연필심 수
func _build_bars(root: Control) -> void:
	# HP: 틀 안쪽에 채움 그림을 잘라서 보여 준다
	_tex_rect(root, "hud_hp_frame", Vector2(6, 4), Vector2(141, 24))
	_hp_clip = Control.new()
	_hp_clip.position = Vector2(24, 12)
	_hp_clip.size = Vector2(HP_FILL_W, 9)
	_hp_clip.clip_contents = true
	_hp_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hp_clip)
	_tex_rect(_hp_clip, "hud_hp_fill", Vector2.ZERO, Vector2(HP_FILL_W, 9))
	_hp_label = _label(root, Vector2(150, 7), 12)

	# MP: HP 막대 바로 아래 파란 줄
	var mp_back := ColorRect.new()
	mp_back.color = Color(0.25, 0.22, 0.25, 0.8)
	mp_back.position = Vector2(23, 28)
	mp_back.size = Vector2(HP_FILL_W + 2, 5)
	mp_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mp_back)
	_mp_bar = ColorRect.new()
	_mp_bar.color = Color(0.4, 0.62, 0.95)
	_mp_bar.position = Vector2(24, 29)
	_mp_bar.size = Vector2(HP_FILL_W, 3)
	_mp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_mp_bar)

	# 경험치: 자 눈금 위에 노란 줄
	_tex_rect(root, "hud_exp_frame", Vector2(10, 37), Vector2(120, 12))
	_exp_clip = Control.new()
	_exp_clip.position = Vector2(15, 40)
	_exp_clip.size = Vector2(0, 4)
	_exp_clip.clip_contents = true
	_exp_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_exp_clip)
	_tex_rect(_exp_clip, "hud_exp_fill", Vector2.ZERO, Vector2(EXP_FILL_W, 4))
	_level_label = _label(root, Vector2(134, 34), 12)
	_points_badge = _label(root, Vector2(186, 34), 12)
	_points_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))

	# 연필 + 연필심
	_tex_rect(root, "hud_pencil_0", Vector2(10, 53), Vector2(100, 8.4))
	_lead_label = _label(root, Vector2(114, 48), 12)
	_coin_label = _label(root, Vector2(176, 48), 12)
	_coin_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))


## 가방(I), 스킬(K), 문방구 창은 scripts/menus.gd 가 그린다
func _build_menus(root: Control) -> void:
	for k in ["bag", "skills", "shop", "friends", "build", "storage", "board"]:
		var m: Control = MenusScript.new()
		m.set("kind", k)
		root.add_child(m)
		m.connect("close_requested", toggle_menu.bind(k))
		_menus[k] = m
	_bag = _menus["bag"]


## 오른쪽 아래: 소모품 2칸(1, 2)과 스킬 3칸(Q, E, R)
func _build_quickbar(root: Control) -> void:
	var upos := Vector2(420, 292)
	var frame := _tex_rect(root, "hud_slot_skill", upos, Vector2(34, 34))
	var uicon := _tex_rect(root, "skill_ult", upos + Vector2(5, 5), Vector2(24, 24))
	var ushade := ColorRect.new()
	ushade.color = Color(0.15, 0.12, 0.15, 0.6)
	ushade.position = upos + Vector2(4, 4)
	ushade.size = Vector2(26, 26)
	ushade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ushade)
	var ukey := _label(root, upos + Vector2(1, -5), 9)
	ukey.text = "V"
	_ult_slot = [frame, uicon, ushade, ukey]
	var keys := ["1", "2", "Q", "E", "R"]
	for i in 5:
		var pos := Vector2(462 + i * 34 + (8 if i >= 2 else 0), 296)
		_tex_rect(root, "hud_slot_item" if i < 2 else "hud_slot_skill", pos, Vector2(30, 30))
		var icon := _tex_rect(root, "", pos + Vector2(5, 5), Vector2(20, 20))
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var shade := ColorRect.new()
		shade.color = Color(0.15, 0.12, 0.15, 0.6)
		shade.position = pos + Vector2(4, 4)
		shade.size = Vector2(22, 0)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(shade)
		var key_l := _label(root, pos + Vector2(1, -5), 9)
		key_l.text = keys[i]
		var num_l := _label(root, pos + Vector2(14, 17), 9)
		num_l.size = Vector2(16, 12)
		num_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_quick.append([icon, shade, num_l])


## 필살기를 시작한다 (플레이어가 부른다)
func start_ultimate(player: Node) -> void:
	if _any_window_open() or GameState.dialogue_open or GameState.cutscene or GameState.draw_mode:
		return
	_ult.call("start", player)


func ultimate() -> Control:
	return _ult


func _refresh_quickbar() -> void:
	var p := GameState.player_ref
	# 필살기 칸: 배운 뒤에만 보인다. 게이지가 차오르고, 가득 차면 반짝인다.
	var has_ult := GameState.skill_rank("ult") > 0
	for n in _ult_slot:
		(n as Control).visible = has_ult
	if has_ult and is_instance_valid(p):
		var g := clampf(float(p.get("ult")) / 100.0, 0.0, 1.0)
		(_ult_slot[2] as ColorRect).size.y = 26.0 * (1.0 - g)
		var glow := 1.0 + 0.25 * sin(Time.get_ticks_msec() / 120.0) if g >= 1.0 else 1.0
		(_ult_slot[1] as Control).modulate = Color(glow, glow, glow * 0.8, 1.0 if g >= 1.0 else 0.6)
	for i in _quick.size():
		var q: Array = _quick[i]
		var icon: TextureRect = q[0]
		var shade: ColorRect = q[1]
		var num: Label = q[2]
		shade.size.y = 0
		if i < 2:
			var id := str(Items.QUICK_SLOTS[i])
			var n := GameState.consumable_count(id)
			_set_icon(icon, GameState.consumable_icon(id))
			icon.modulate = Color(1, 1, 1, 1.0 if n > 0 else 0.3)
			num.text = str(n) if n > 0 else ""
		else:
			var sid := str(GameState.skill_slots[i - 2])
			num.text = ""
			if sid == "":
				icon.texture = null
				continue
			_set_icon(icon, str(Items.SKILLS[sid]["icon"]))
			var cd := 0.0
			if is_instance_valid(p):
				cd = float((p.get("skill_cd") as Dictionary).get(sid, 0.0))
				icon.modulate = Color(1, 1, 1, 1.0 if float(p.get("mp")) >= float(Items.SKILLS[sid]["mp"]) else 0.4)
			if cd > 0.0:
				shade.size.y = 22.0 * clampf(cd / float(Items.SKILLS[sid]["cd"]), 0.0, 1.0)
				num.text = str(ceili(cd))


## 아이콘 텍스처는 이름이 바뀔 때만 다시 불러온다
func _set_icon(icon: TextureRect, tex_name: String) -> void:
	if icon.get_meta("tex_name", "") != tex_name:
		icon.set_meta("tex_name", tex_name)
		icon.texture = Art.tex(tex_name)


## 창 하나를 열거나 닫는다. 다른 창이 열려 있거나 대화·컷신 중에는 열지 않는다.
func toggle_menu(k: String) -> void:
	var m: Control = _menus[k]
	if not m.visible and (GameState.dialogue_open or GameState.cutscene or GameState.draw_mode or _any_window_open()):
		return
	m.visible = not m.visible
	GameState.set_menu_open(m.visible)
	if m.visible:
		m.call("open")


func is_menu_open(k: String) -> bool:
	return (_menus[k] as Control).visible


func _any_window_open() -> bool:
	for k in _menus:
		if (_menus[k] as Control).visible:
			return true
	return _stats.visible or _map.visible or bool(_trace.get("active")) or bool(_ult.call("is_active")) or bool(_fishing.call("is_active"))


## tab: 열 때 고를 탭 (0 사기, 1 팔기, 2 만들기, 3 강화)
func open_shop(tab: int = -1) -> void:
	if not is_menu_open("shop"):
		toggle_menu("shop")
	if tab >= 0 and is_menu_open("shop"):
		(_menus["shop"] as Control).call("_set_tab", tab)


func menu(k: String) -> Control:
	return _menus[k]


func trace_panel() -> Control:
	return _trace


func fishing() -> Control:
	return _fishing


func start_fishing(fine: bool) -> void:
	if not _any_window_open():
		_fishing.call("start", fine)


## 능력치 화면 (C 키): 레벨마다 받은 포인트를 필압·끈기·손끝·눈썰미에 넣는다
func _build_stats(root: Control) -> void:
	_stats = Control.new()
	_stats.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats.visible = false
	root.add_child(_stats)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.08, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats.add_child(dim)
	var win := _tex_rect(_stats, "ui_window", Vector2(110, 46), Vector2(420, 268))

	var title := Label.new()
	title.text = "능력치"
	title.position = Vector2(0, 14)
	title.size = Vector2(420, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.35, 0.25, 0.2))
	win.add_child(title)

	_stats_points = _dark_label(win, Vector2(72, 44), Vector2(280, 18), 12)

	for i in GameState.STAT_KEYS.size():
		var y := 68.0 + i * 30.0
		_tex_rect(win, "stat_%d" % i, Vector2(72, y), Vector2(24, 24))
		var name_l := _dark_label(win, Vector2(102, y + 3), Vector2(60, 18), 13)
		name_l.text = str(GameState.STAT_NAMES[i])
		var value_l := _dark_label(win, Vector2(160, y + 3), Vector2(30, 18), 13)
		value_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var desc_l := _dark_label(win, Vector2(236, y + 5), Vector2(140, 16), 10)
		desc_l.text = str(GameState.STAT_DESCS[i])
		desc_l.add_theme_color_override("font_color", Color(0.5, 0.42, 0.38))
		var btn := Button.new()
		btn.text = "+"
		btn.position = Vector2(200, y + 1)
		btn.size = Vector2(26, 22)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_add_stat.bind(i))
		win.add_child(btn)
		_stat_rows.append([value_l, btn])

	_stats_derived = _dark_label(win, Vector2(72, 192), Vector2(290, 34), 11)
	var foot := _dark_label(win, Vector2(0, 240), Vector2(420, 16), 11)
	foot.text = "1~4 또는 + 로 올리기   ·   C 닫기"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_color_override("font_color", Color(0.5, 0.42, 0.38))


func _dark_label(parent: Control, pos: Vector2, size: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(0.3, 0.25, 0.22))
	parent.add_child(l)
	return l


func _add_stat(index: int) -> void:
	GameState.add_stat(str(GameState.STAT_KEYS[index]))


func toggle_stats() -> void:
	if not _stats.visible and (GameState.dialogue_open or GameState.cutscene or GameState.draw_mode or _any_window_open()):
		return
	_stats.visible = not _stats.visible
	GameState.set_menu_open(_stats.visible)
	_refresh()


func is_stats_open() -> bool:
	return _stats.visible


func _refresh_stats() -> void:
	_stats_points.text = "필력 %d      남은 포인트  %d" % [GameState.level, GameState.stat_points]
	for i in _stat_rows.size():
		var row: Array = _stat_rows[i]
		(row[0] as Label).text = str(GameState.stat(str(GameState.STAT_KEYS[i])))
		(row[1] as Button).disabled = GameState.stat_points <= 0
	_stats_derived.text = "공격력 %d    방어 %d    최대 HP %d    최대 MP %d\n치명타 확률 %d%%    경험치 %d / %d" % [
		GameState.attack_power(), GameState.defense(), GameState.max_hp(), GameState.max_mp(),
		roundi(GameState.crit_chance() * 100.0), GameState.exp, GameState.exp_needed()]


## 지도 (M 키): 1장의 화면 배치와 지금 있는 곳
func _build_map(root: Control) -> void:
	_map = Control.new()
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.visible = false
	root.add_child(_map)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.08, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.add_child(dim)
	var win := _tex_rect(_map, "ui_window", Vector2(110, 46), Vector2(420, 268))
	var title := _dark_label(win, Vector2(0, 14), Vector2(420, 24), 17)
	title.text = "지도 · 1장"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.35, 0.25, 0.2))

	# 손으로 그린 듯한 지도 그림 (scripts/map_view.gd)
	_map_view = MapViewScript.new()
	_map_view.position = Vector2(55, 44)
	_map_view.size = Vector2(310, 190)
	win.add_child(_map_view)
	var foot := _dark_label(win, Vector2(0, 240), Vector2(420, 16), 11)
	foot.text = "M  닫기"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_color_override("font_color", Color(0.5, 0.42, 0.38))


func toggle_map() -> void:
	if not _map.visible and (GameState.dialogue_open or GameState.cutscene or GameState.draw_mode or _any_window_open()):
		return
	_map.visible = not _map.visible
	GameState.set_menu_open(_map.visible)
	if _map.visible:
		_map_view.call("refresh")


func is_map_open() -> bool:
	return _map.visible


func toggle_bag() -> void:
	toggle_menu("bag")


func is_bag_open() -> bool:
	return is_menu_open("bag")


func _build_dialogue(root: Control) -> void:
	_dlg = PanelContainer.new()
	_dlg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg.position = Vector2(40, 232)
	_dlg.size = Vector2(560, 86)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.99, 0.97, 0.9)
	sb.border_color = Color(0.25, 0.25, 0.3)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(8)
	_dlg.add_theme_stylebox_override("panel", sb)
	root.add_child(_dlg)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	_dlg.add_child(row)

	_dlg_portrait = TextureRect.new()
	_dlg_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg_portrait.custom_minimum_size = Vector2(60, 70)
	_dlg_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dlg_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_dlg_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	row.add_child(_dlg_portrait)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	_dlg_name = Label.new()
	_dlg_name.add_theme_font_size_override("font_size", 13)
	_dlg_name.add_theme_color_override("font_color", Color(0.75, 0.3, 0.35))
	box.add_child(_dlg_name)
	_dlg_text = Label.new()
	_dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dlg_text.custom_minimum_size = Vector2(420, 0)
	_dlg_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dlg_text.add_theme_font_size_override("font_size", 15)
	_dlg_text.add_theme_color_override("font_color", Color(0.2, 0.2, 0.25))
	box.add_child(_dlg_text)
	_dlg.visible = false


func _process(_delta: float) -> void:
	var p := GameState.player_ref
	if is_instance_valid(p):
		var hp: int = p.get("hp")
		var mx: int = p.get("max_hp")
		_hp_label.text = "%d / %d" % [maxi(hp, 0), mx]
		_hp_clip.size.x = HP_FILL_W * clampf(float(hp) / float(maxi(mx, 1)), 0.0, 1.0)
		var mmx: int = p.get("max_mp")
		_mp_bar.size.x = HP_FILL_W * clampf(float(p.get("mp")) / float(maxi(mmx, 1)), 0.0, 1.0)
	_hint_box.visible = not GameState.dialogue_open and not GameState.cutscene
	_night.color.a = 0.42 * GameState.night_amount()
	_clock_label.text = GameState.clock_text()
	_day_label.text = "%d일째  피로 %d" % [GameState.day, GameState.fatigue]
	_refresh_quickbar()


func _refresh() -> void:
	var Q := GameState.Quest
	var need := GameState.BRIDGE_COST
	_lead_label.text = "× %d" % GameState.pencil_lead
	_coin_label.text = "동전 %d" % GameState.coins
	_level_label.text = "필력 %d" % GameState.level
	var full := GameState.level >= GameState.MAX_LEVEL
	_exp_clip.size.x = EXP_FILL_W * (1.0 if full else clampf(float(GameState.exp) / float(GameState.exp_needed()), 0.0, 1.0))
	_points_badge.text = "C  +%d" % GameState.stat_points if GameState.stat_points > 0 else ""
	if _stats.visible:
		_refresh_stats()
	var q := GameState.quest
	if quest_text_override != "":
		_quest_label.text = quest_text_override
	elif q == Q.NOT_STARTED:
		_quest_label.text = "할 일: 마을 사람과 이야기하기"
	elif q == Q.FIND_LEAD:
		if GameState.pencil_lead < need:
			_quest_label.text = "할 일: 슬라임을 물리치고 연필심 모으기 (%d/%d)" % [GameState.pencil_lead, need]
		else:
			_quest_label.text = "할 일: 강가에서 점선을 따라 다리 그리기"
	elif q == Q.BRIDGE_BUILT:
		_quest_label.text = "할 일: 다리를 건너 빨간 문으로 가기"
	elif q == Q.CLEAN_DOOR:
		_quest_label.text = "할 일: 지우개로 문의 자국 닦기"
	elif q == Q.DOOR_OPEN:
		_quest_label.text = "할 일: 열린 문으로 들어가기"
	else:
		_quest_label.text = "빨간 문으로 들어가면 내 마을로 갈 수 있다"


## 조작 안내 줄. items = [[아이콘 이름 또는 "", 설명], ...]  예: [["key_wasd", "이동"]]
func set_hints(items: Array) -> void:
	if items == _hints:
		return
	_hints = items.duplicate(true)
	for c in _hint_box.get_children():
		c.queue_free()
	for it in items:
		var icon := Art.tex(str(it[0])) if str(it[0]) != "" else null
		if icon:
			var tr := TextureRect.new()
			tr.texture = icon
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			var h := 26.0
			tr.custom_minimum_size = Vector2(h * icon.get_width() / icon.get_height(), h)
			_hint_box.add_child(tr)
		var l := Label.new()
		l.text = str(it[1]) + "   "
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_style_label(l, 13)
		_hint_box.add_child(l)


func show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


# ---------- 대화 ----------

func _on_dialogue(speaker: String, lines: Array, portrait: String) -> void:
	_lines = lines
	_line_idx = 0
	_dlg_name.text = speaker
	var tex := Art.tex("portrait_" + portrait) if portrait != "" else null
	_dlg_portrait.texture = tex
	_dlg_portrait.visible = tex != null
	_dlg.visible = true
	_show_line()


func _show_line() -> void:
	_dlg_text.text = str(_lines[_line_idx]) + "   ▼"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.physical_keycode == KEY_I or (_bag.visible and event.physical_keycode == KEY_ESCAPE)):
		toggle_bag()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.physical_keycode
		if kc == KEY_K or (is_menu_open("skills") and kc == KEY_ESCAPE):
			toggle_menu("skills")
			get_viewport().set_input_as_handled()
			return
		if is_menu_open("shop") and kc == KEY_ESCAPE:
			toggle_menu("shop")
			get_viewport().set_input_as_handled()
			return
		if kc == KEY_P or (is_menu_open("friends") and kc == KEY_ESCAPE):
			toggle_menu("friends")
			get_viewport().set_input_as_handled()
			return
		for mk in ["build", "storage", "board"]:
			if is_menu_open(mk) and kc == KEY_ESCAPE:
				toggle_menu(mk)
				get_viewport().set_input_as_handled()
				return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode
		if code == KEY_M or (_map.visible and code == KEY_ESCAPE):
			toggle_map()
			get_viewport().set_input_as_handled()
			return
		if code == KEY_C or (_stats.visible and code == KEY_ESCAPE):
			toggle_stats()
			get_viewport().set_input_as_handled()
			return
		if _stats.visible and code >= KEY_1 and code <= KEY_4:
			_add_stat(code - KEY_1)
			get_viewport().set_input_as_handled()
			return
	if not _dlg.visible:
		return
	var advance: bool = event.is_action_pressed("interact") or event.is_action_pressed("dodge") \
		or event.is_action_pressed("draw_confirm") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not advance:
		return
	get_viewport().set_input_as_handled()
	_line_idx += 1
	if _line_idx >= _lines.size():
		_dlg.visible = false
		GameState.end_dialogue()
	else:
		_show_line()
