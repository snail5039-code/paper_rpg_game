extends Control
## 따라 그리기 화면 (공용). 점선을 제한 시간 안에 마우스로 따라 그리고 점수(0~1)를 돌려준다.
## 쓰는 곳: 쓰러진 몬스터 다시 그리기(포획), 내 마을 건물 짓기.
##   왼쪽 드래그: 그리기 / Enter: 완성 / Esc: 그만두기 (점수 -1)
## HUD 가 만들어서 쥐고 있다. 열려 있는 동안 게임은 멈춘다.

signal finished(score: float)   ## 그만두면 -1

const UI := preload("res://scripts/ui_kit.gd")
const Validator := preload("res://scripts/blueprint_validator.gd")
const SCREEN := Vector2(640, 360)
const TOLERANCE := 10.0

var active := false
var strokes: Array = []
var guides: Array = []          # 화면 좌표의 점선들 (PackedVector2Array)
var time_limit := 6.0
var _t := 0.0
var _current := PackedVector2Array()
var _dim: ColorRect
var _picture: TextureRect
var _paint: Control
var _title: Label
var _foot: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = SCREEN
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim = ColorRect.new()
	_dim.color = Color(0.12, 0.1, 0.12, 0.62)
	_dim.size = SCREEN
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_picture = TextureRect.new()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_picture)
	_paint = Control.new()
	_paint.size = SCREEN
	_paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paint.draw.connect(_draw_paint)
	add_child(_paint)
	_title = _text(26, 16)
	_foot = _text(322, 10)
	_foot.text = "마우스로 점선을 따라 그리세요.   Enter 완성   Esc 그만두기"


func _text(y: float, font_size: int) -> Label:
	var l := Label.new()
	l.position = Vector2(0, y)
	l.size = Vector2(640, 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	l.add_theme_color_override("font_outline_color", Color(0.2, 0.15, 0.15))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


## picture: 가운데에 흐리게 보여 줄 그림 (없어도 된다). rect: 그 그림이 놓일 자리.
func start(title: String, guide_lines: Array, seconds: float, picture: Texture2D = null,
		rect: Rect2 = Rect2(), tint: Color = Color(1, 1, 1, 0.45)) -> void:
	guides = guide_lines
	time_limit = seconds
	strokes.clear()
	_current = PackedVector2Array()
	_t = 0.0
	_title.text = title
	_picture.texture = picture
	_picture.position = rect.position
	_picture.size = rect.size
	_picture.modulate = tint
	active = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	GameState.set_menu_open(true)


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	if _t >= time_limit:
		finish()
	_paint.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_current = PackedVector2Array([event.position])
		elif _current.size() > 0:
			strokes.append(_current)
			_current = PackedVector2Array()
			if measure() >= 0.93:
				finish()
	elif event is InputEventMouseMotion and _current.size() > 0:
		if event.position.distance_to(_current[_current.size() - 1]) > 3.0:
			_current.append(event.position)


func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER:
			finish()
		elif event.physical_keycode == KEY_ESCAPE:
			finish(-1.0)
		get_viewport().set_input_as_handled()


## 마지막으로 잰, 그린 선 가운데 점선 위에 있는 비율 (0~1). 화면을 마구 칠하면 낮아진다.
var accuracy := 1.0


## 지금까지 그린 선의 점수: 점선을 덮은 비율 × (선 위에 그린 정도)
func measure() -> float:
	var all: Array = strokes.duplicate()
	if _current.size() > 1:
		all.append(_current)
	if all.is_empty() or guides.is_empty():
		return 0.0
	var r: Dictionary = Validator.evaluate(guides, all, TOLERANCE, 0.0, 0.0)
	accuracy = float(r["accuracy"])
	return clampf(float(r["coverage"]) * (0.5 + 0.5 * float(r["accuracy"])), 0.0, 1.0)


## forced 를 주면 그 점수로 끝낸다 (테스트, 그만두기)
func finish(forced: float = -2.0) -> void:
	if not active:
		return
	var score := forced if forced > -2.0 else measure()
	active = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.set_menu_open(false)
	finished.emit(score)


func _draw_paint() -> void:
	if not active:
		return
	var c := _paint
	var left := clampf(1.0 - _t / time_limit, 0.0, 1.0)
	c.draw_rect(Rect2(220, 54, 200, 6), Color(0.2, 0.17, 0.18, 0.8))
	c.draw_rect(Rect2(221, 55, 198 * left, 4), Color(1.0, 0.85, 0.4))
	for g in guides:
		var line: PackedVector2Array = g
		for i in line.size() - 1:
			var a := line[i]
			var b := line[i + 1]
			var n := maxi(1, int(a.distance_to(b) / 7.0))
			for k in n:
				if k % 2 == 0:
					c.draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), Color(1, 1, 1, 0.9), 2.0)
	for s in strokes + [_current]:
		if (s as PackedVector2Array).size() > 1:
			c.draw_polyline(s, Color(0.35, 0.3, 0.32), 4.5, true)
			c.draw_polyline(s, Color(1.0, 0.92, 0.6), 2.5, true)


# ---------- 점선 모양 ----------

## 가운데 center, 반지름 rx·ry 의 울퉁불퉁한 동그라미 (몬스터의 빠진 테두리)
static func blob(center: Vector2, rx: float, ry: float, wobble: float = 0.08) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 37:
		var a := TAU * i / 36.0
		var k := 1.0 + wobble * sin(a * 3.0)
		out.append(center + Vector2(cos(a) * rx * k, sin(a) * ry * k))
	return out


## 집 모양 (네모 벽 + 세모 지붕). rect 는 벽의 자리.
static func house(rect: Rect2) -> Array:
	var p := rect.position
	var s := rect.size
	return [
		PackedVector2Array([p, p + Vector2(s.x, 0), p + s, p + Vector2(0, s.y), p]),
		PackedVector2Array([p + Vector2(-s.x * 0.1, 0), p + Vector2(s.x * 0.5, -s.y * 0.6), p + Vector2(s.x * 1.1, 0)]),
	]
