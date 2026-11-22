extends Control
## 필살기 "밑그림" 화면 (V 키, 게이지가 가득 찼을 때).
##   1. 컷인: 일러스트가 화면을 가로질러 들어온다 (게임은 멈춘다)
##   2. 따라 그리기: 점선 별을 마우스로 따라 그린다 (4초). 다 그리면 바로 끝난다. Enter 로 일찍 끝낼 수 있다.
##   3. 터짐: 따라 그린 만큼 강해진 한 방이 화면의 모든 적에게 들어간다
## HUD 가 만들어서 쥐고 있고, 플레이어가 start() 를 부른다.

const Art := preload("res://scripts/art.gd")
const UI := preload("res://scripts/ui_kit.gd")
const Validator := preload("res://scripts/blueprint_validator.gd")

const CUTIN_TIME := 1.1
const TRACE_TIME := 4.0
const BURST_TIME := 0.7
const CENTER := Vector2(320, 176)
const RADIUS := 92.0
const TOLERANCE := 11.0
const SCREEN := Vector2(640, 360)

var phase := ""                 # "", "cutin", "trace", "burst"
var score := 0.0
var strokes: Array = []
var _t := 0.0
var _player: Node
var _current := PackedVector2Array()
var _guide := PackedVector2Array()
var _banner: TextureRect
var _star: TextureRect
var _label: Label
var _dim: ColorRect
var _paint: Control             # 별과 내 선을 그리는 판 (어두운 막 위에 그려야 보인다)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = SCREEN   # 화면 전체 (마우스를 받으려면 크기가 있어야 한다)
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.12, 0.1, 0.12, 0.6)
	_dim.size = SCREEN
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_banner = UI.icon(self, "ult_cutin", Vector2(-640, 77), Vector2(640, 213), Color.WHITE, false)
	_star = UI.icon(self, "fx_star", CENTER - Vector2(60, 60), Vector2(120, 120))
	_star.pivot_offset = Vector2(60, 60)
	_label = Label.new()
	_label.position = Vector2(0, 300)
	_label.size = Vector2(640, 30)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.6))
	_label.add_theme_color_override("font_outline_color", Color(0.2, 0.15, 0.15))
	_label.add_theme_constant_override("outline_size", 5)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_paint = Control.new()
	_paint.size = SCREEN
	_paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paint.draw.connect(_draw_trace)
	add_child(_paint)
	# 별 안내선 (꼭짓점 5개를 한 번에 잇는 닫힌 선)
	for i in 11:
		var r := RADIUS if i % 2 == 0 else RADIUS * 0.42
		_guide.append(CENTER + Vector2(0, -r).rotated(TAU * i / 10.0))


func is_active() -> bool:
	return phase != ""


func start(player: Node) -> void:
	if is_active():
		return
	_player = player
	strokes.clear()
	_current = PackedVector2Array()
	score = 0.0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	GameState.set_menu_open(true)
	_set_phase("cutin")


func _set_phase(p: String) -> void:
	phase = p
	_t = 0.0
	_banner.visible = p == "cutin"
	_star.visible = p == "burst"
	_dim.color.a = 0.6 if p != "burst" else 0.25
	match p:
		"cutin":
			_label.text = "필살기 — 밑그림!"
			_label.position.y = 258
		"trace":
			_label.text = "점선 별을 따라 그리세요!"
			_label.position.y = 30
		"burst":
			_label.text = "따라 그리기 %d%%!" % roundi(score * 100.0)
			_label.position.y = 250
	_paint.queue_redraw()


func _process(delta: float) -> void:
	if phase == "":
		return
	_t += delta
	match phase:
		"cutin":
			# 왼쪽에서 휙 들어와 잠깐 멈췄다가 오른쪽으로 빠진다
			var x := -640.0 + 640.0 * minf(1.0, _t / 0.22)
			if _t > CUTIN_TIME - 0.2:
				x = 640.0 * (_t - (CUTIN_TIME - 0.2)) / 0.2
			_banner.position.x = x
			if _t >= CUTIN_TIME:
				_set_phase("trace")
		"trace":
			if _t >= TRACE_TIME:
				finish_trace()
		"burst":
			var k := _t / BURST_TIME
			_star.scale = Vector2.ONE * (0.4 + 2.2 * k)
			_star.modulate.a = 1.0 - k * k
			if _t >= BURST_TIME:
				_close()
	_paint.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if phase != "trace":
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_current = PackedVector2Array([event.position])
		elif _current.size() > 0:
			strokes.append(_current)
			_current = PackedVector2Array()
			if measure() >= 0.92:
				finish_trace()
	elif event is InputEventMouseMotion and _current.size() > 0:
		if event.position.distance_to(_current[_current.size() - 1]) > 3.0:
			_current.append(event.position)


func _input(event: InputEvent) -> void:
	if phase == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if phase == "trace" and (event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER):
			finish_trace()
		get_viewport().set_input_as_handled()   # 필살기 중에는 다른 키가 먹지 않는다


## 지금까지 그린 선의 점수 (0~1): 별을 얼마나 덮었는지 × 얼마나 선 위에 그렸는지
func measure() -> float:
	var all: Array = strokes.duplicate()
	if _current.size() > 1:
		all.append(_current)
	if all.is_empty():
		return 0.0
	var r: Dictionary = Validator.evaluate([_guide], all, TOLERANCE, 0.0, 0.0)
	return clampf(float(r["coverage"]) * (0.5 + 0.5 * float(r["accuracy"])), 0.0, 1.0)


func finish_trace(forced_score: float = -1.0) -> void:
	if phase == "" or phase == "burst":
		return
	score = forced_score if forced_score >= 0.0 else measure()
	_set_phase("burst")


func _close() -> void:
	phase = ""
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.set_menu_open(false)
	if is_instance_valid(_player):
		_player.call("finish_ultimate", score)


func _draw_trace() -> void:
	if phase != "trace":
		return
	var c := _paint
	# 남은 시간 막대
	var left := clampf(1.0 - _t / TRACE_TIME, 0.0, 1.0)
	c.draw_rect(Rect2(220, 62, 200, 6), Color(0.2, 0.17, 0.18, 0.8))
	c.draw_rect(Rect2(221, 63, 198 * left, 4), Color(1.0, 0.85, 0.4))
	# 점선 별
	for i in _guide.size() - 1:
		var a := _guide[i]
		var b := _guide[i + 1]
		var n := int(a.distance_to(b) / 9.0)
		for k in n:
			if k % 2 == 0:
				c.draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), Color(1, 1, 1, 0.85), 2.0)
	for s in strokes + [_current]:
		if (s as PackedVector2Array).size() > 1:
			c.draw_polyline(s, Color(1.0, 0.86, 0.35), 3.5, true)
