extends CanvasLayer
## HUD: HP, 연필심, 퀘스트, 조작 안내(키 아이콘), 알림 메시지, 대화창(초상화).

const Art := preload("res://scripts/art.gd")

var _hp_label: Label
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

	_hp_label = _label(root, Vector2(10, 8), 16)
	_lead_label = _label(root, Vector2(10, 30), 14)
	_quest_label = _label(root, Vector2(10, 50), 13)
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
	l.add_theme_constant_override("outline_size", 5)


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
		_hp_label.text = "HP  " + "■".repeat(maxi(hp, 0)) + "□".repeat(maxi(mx - hp, 0))
	_hint_box.visible = not GameState.dialogue_open and not GameState.cutscene


func _refresh() -> void:
	var Q := GameState.Quest
	var need := GameState.BRIDGE_COST
	_lead_label.text = "연필심  %d" % GameState.pencil_lead
	var q := GameState.quest
	if q == Q.NOT_STARTED:
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
		_quest_label.text = "1페이지 끝! 2페이지는 준비 중"


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
