extends CanvasLayer
## HUD: HP, 연필심, 퀘스트, 조작 안내, 알림 메시지, 대화창.

var _hp_label: Label
var _lead_label: Label
var _quest_label: Label
var _help_label: Label
var _toast: Label
var _toast_tween: Tween

var _dlg: PanelContainer
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

	_help_label = _label(root, Vector2(10, 336), 12)
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
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.15, 0.2))
	l.add_theme_constant_override("outline_size", 5)
	parent.add_child(l)
	return l


func _build_dialogue(root: Control) -> void:
	_dlg = PanelContainer.new()
	_dlg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg.position = Vector2(40, 244)
	_dlg.size = Vector2(560, 82)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.99, 0.97, 0.9)
	sb.border_color = Color(0.25, 0.25, 0.3)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(10)
	_dlg.add_theme_stylebox_override("panel", sb)
	root.add_child(_dlg)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg.add_child(box)
	_dlg_name = Label.new()
	_dlg_name.add_theme_font_size_override("font_size", 13)
	_dlg_name.add_theme_color_override("font_color", Color(0.75, 0.3, 0.35))
	box.add_child(_dlg_name)
	_dlg_text = Label.new()
	_dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dlg_text.custom_minimum_size = Vector2(536, 0)
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
	if GameState.draw_mode:
		_help_label.text = "[연필 모드]  좌드래그 그리기 · 우드래그/X 지우개 · Enter 완성 · Backspace 전체 지우기 · Esc/Tab 닫기"
	else:
		_help_label.text = "WASD 이동 · 좌클릭 공격 · Space 회피 · F 대화 · Tab 연필 모드 · F5 저장 · F9 처음부터"


func _refresh() -> void:
	var Q := GameState.Quest
	var need := GameState.BRIDGE_COST
	_lead_label.text = "연필심  %d" % GameState.pencil_lead
	var q := GameState.quest
	if q == Q.NOT_STARTED:
		_quest_label.text = "퀘스트: 마을 사람과 이야기하기 [F]"
	elif q == Q.FIND_LEAD:
		if GameState.pencil_lead < need:
			_quest_label.text = "퀘스트: 슬라임을 물리치고 연필심 모으기 (%d/%d)" % [GameState.pencil_lead, need]
		else:
			_quest_label.text = "퀘스트: 강가에서 [Tab] → 점선을 따라 다리 그리기"
	elif q == Q.BRIDGE_BUILT:
		_quest_label.text = "퀘스트: 다리를 건너 도리이로 가기"
	else:
		_quest_label.text = "MVP 클리어! 다음 페이지는 개발 중"


func show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


# ---------- 대화 ----------

func _on_dialogue(speaker: String, lines: Array) -> void:
	_lines = lines
	_line_idx = 0
	_dlg_name.text = speaker
	_dlg.visible = true
	_show_line()


func _show_line() -> void:
	_dlg_text.text = str(_lines[_line_idx]) + "   ▼"


func _unhandled_input(event: InputEvent) -> void:
	if not _dlg.visible:
		return
	var advance: bool = event.is_action_pressed("interact") or event.is_action_pressed("dodge") \
		or event.is_action_pressed("draw_confirm") or event.is_action_pressed("ui_cancel") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not advance:
		return
	get_viewport().set_input_as_handled()
	_line_idx += 1
	if _line_idx >= _lines.size() or event.is_action_pressed("ui_cancel"):
		_dlg.visible = false
		GameState.end_dialogue()
	else:
		_show_line()
