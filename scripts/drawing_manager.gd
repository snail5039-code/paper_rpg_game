extends Node2D
## 연필 모드 (Tab).
## 좌드래그: 연필 / 우드래그 또는 X 키: 지우개 / Enter: 완성 판정 / Backspace: 전체 지우기 / Esc: 닫기
## 연필 모드 동안 게임은 일시정지된다. 선은 월드 좌표로 저장된다.

signal submitted(strokes: Array)
signal closed   ## 연필 모드를 닫았다
signal erased_at(world_pos: Vector2)  ## 지우개가 지나간 자리 (문 자국 닦기 등에 쓴다)

const Art := preload("res://scripts/art.gd")

const POINT_SPACING := 3.0
const ERASER_RADIUS := 7.0
const PENCIL_COLOR := Color(0.22, 0.22, 0.28)
const GUIDE_COLOR := Color(0.9, 0.35, 0.35)

var active := false
var guides: Array = []          # Array[PackedVector2Array] — 설계도 안내선
var show_guides := true
var strokes: Array = []         # Array[PackedVector2Array]
var eraser_tool := false
var persist := false            # true 면 닫아도 선이 남고, 평소에도 보인다 (내 마을 자유 낙서)

var _current := PackedVector2Array()
var _pen_down := false
var _erasing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100


func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	_pen_down = false
	_erasing = false
	_current = PackedVector2Array()
	if not on:
		if not persist:
			strokes.clear()
		eraser_tool = false
	GameState.set_draw_mode(on)
	queue_redraw()
	if not on:
		closed.emit()


func clear_strokes() -> void:
	strokes.clear()
	_current = PackedVector2Array()
	queue_redraw()


func _process(_delta: float) -> void:
	if active:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_draw"):
		if not GameState.dialogue_open and not GameState.cutscene:
			set_active(not active)
		get_viewport().set_input_as_handled()
		return
	if not active:
		return

	if event.is_action_pressed("ui_cancel"):
		set_active(false)
	elif event.is_action_pressed("draw_confirm"):
		_finish_stroke()
		submitted.emit(strokes.duplicate())
	elif event.is_action_pressed("draw_clear"):
		clear_strokes()
	elif event.is_action_pressed("draw_eraser"):
		eraser_tool = not eraser_tool
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if eraser_tool:
				_erasing = mb.pressed
				if mb.pressed:
					_erase_at(get_global_mouse_position())
			elif mb.pressed:
				_pen_down = true
				_current = PackedVector2Array([get_global_mouse_position()])
			else:
				_finish_stroke()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_erasing = mb.pressed
			if mb.pressed:
				_erase_at(get_global_mouse_position())
	elif event is InputEventMouseMotion:
		var pos := get_global_mouse_position()
		if _pen_down:
			_add_point(pos)
		elif _erasing:
			_erase_at(pos)
	else:
		return
	get_viewport().set_input_as_handled()


func _add_point(pos: Vector2) -> void:
	if _current.is_empty():
		_current.append(pos)
		return
	var last := _current[_current.size() - 1]
	var d := last.distance_to(pos)
	if d < POINT_SPACING:
		return
	# 빠르게 그어도 점 간격이 일정하도록 보간 (지우개/판정 정확도)
	var n := ceili(d / POINT_SPACING)
	for k in range(1, n + 1):
		_current.append(last.lerp(pos, float(k) / n))


func _finish_stroke() -> void:
	if _pen_down and _current.size() >= 1:
		strokes.append(_current)
	_current = PackedVector2Array()
	_pen_down = false


func _erase_at(p: Vector2) -> void:
	erased_at.emit(p)
	var out: Array = []
	for s in strokes:
		var seg := PackedVector2Array()
		for q in (s as PackedVector2Array):
			if q.distance_to(p) <= ERASER_RADIUS:
				if seg.size() >= 2:
					out.append(seg)
				seg = PackedVector2Array()
			else:
				seg.append(q)
		if seg.size() >= 2:
			out.append(seg)
	strokes = out


func _visible_world_rect() -> Rect2:
	var inv := get_viewport().get_canvas_transform().affine_inverse()
	var r := get_viewport_rect()
	var a := inv * r.position
	var b := inv * r.end
	return Rect2(a, b - a)


func _draw() -> void:
	if not active:
		if persist:
			for s in strokes:
				_draw_stroke(s as PackedVector2Array)
		return
	var view := _visible_world_rect()

	# 공책 종이 + 모눈
	draw_rect(view, Color(0.99, 0.98, 0.93, 0.45))
	var grid := 8.0
	var x := floorf(view.position.x / grid) * grid
	while x < view.end.x:
		draw_line(Vector2(x, view.position.y), Vector2(x, view.end.y), Color(0.55, 0.7, 0.9, 0.25), 1.0)
		x += grid
	var y := floorf(view.position.y / grid) * grid
	while y < view.end.y:
		draw_line(Vector2(view.position.x, y), Vector2(view.end.x, y), Color(0.55, 0.7, 0.9, 0.25), 1.0)
		y += grid

	# 설계도 안내선 (점선)
	if show_guides:
		for g in guides:
			_draw_dashed(g as PackedVector2Array, GUIDE_COLOR)

	# 그린 선
	for s in strokes:
		_draw_stroke(s as PackedVector2Array)
	_draw_stroke(_current)

	# 커서: 지금 쥔 도구
	var m := get_global_mouse_position()
	var erasing := eraser_tool or _erasing
	var icon := Art.tex("tool_eraser" if erasing else "tool_pencil")
	if erasing:
		draw_arc(m, ERASER_RADIUS, 0, TAU, 20, Color(0.9, 0.5, 0.6, 0.8), 1.0)
	if icon:
		var size := Vector2(icon.get_width(), icon.get_height()) * (16.0 / icon.get_height())
		# 연필은 심 끝(왼쪽 아래)이, 지우개는 가운데가 마우스 위치에 오게
		var pos := m + Vector2(-size.x * 0.5, -size.y * 0.5) if erasing else m + Vector2(0, -size.y)
		draw_texture_rect(icon, Rect2(pos, size), false)
	elif not erasing:
		draw_circle(m, 1.5, PENCIL_COLOR)


func _draw_stroke(s: PackedVector2Array) -> void:
	if s.size() >= 2:
		draw_polyline(s, PENCIL_COLOR, 1.5, true)
	elif s.size() == 1:
		draw_circle(s[0], 0.9, PENCIL_COLOR)


func _draw_dashed(line: PackedVector2Array, color: Color) -> void:
	for i in range(line.size() - 1):
		var a := line[i]
		var b := line[i + 1]
		var seg_len := a.distance_to(b)
		if seg_len <= 0.0:
			continue
		var dir := (b - a) / seg_len
		var t := 0.0
		while t < seg_len:
			var e := minf(t + 4.0, seg_len)
			draw_line(a + dir * t, a + dir * e, color, 1.5)
			t += 7.0
