extends Control
## 자유롭게 그리는 작은 그림판. 액자에 걸 낙서, 직접 만드는 주민의 덧그리기에 쓴다.
## 크레용 색을 골라 선을 긋는다. 완성하면 32 × 32 도트 그림이 되어 저장되고 그 이름을 돌려준다.
##   왼쪽 드래그: 그리기 / 오른쪽 클릭: 마지막 획 지우기 / Enter: 완성 / Esc: 그만두기
## setup 으로 밑그림(under)을 주면 그 위에 덧그린다 (밑그림도 결과에 같이 들어간다).

signal done(art: String)   ## 저장한 그림 이름 ("drawn_…"). 그만두면 빈 글

const Art := preload("res://scripts/core/art.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const Pixel := preload("res://scripts/drawing/doodle_pixel.gd")

const N := 32
const BOARD := Rect2(70, 46, 156, 156)
const PAPER := Color(0.97, 0.94, 0.86)
## 크레용 색: 연필(진한 회색) + 만들기와 같은 파스텔 + 갈색·검은 하늘색
const COLORS := [
	Color(0.24, 0.2, 0.22), Color(0.98, 0.83, 0.42), Color(0.95, 0.56, 0.5), Color(0.6, 0.8, 0.95),
	Color(0.62, 0.85, 0.6), Color(0.8, 0.68, 0.95), Color(0.66, 0.48, 0.36), Color(0.4, 0.55, 0.85),
]

var title := "그림 그리기"
var hint := ""
var under: Texture2D = null      # 밑그림 (덧그리기)
var paper := true                # 바탕을 종이색으로 채울지 (액자). false 면 투명 (주민)
var strokes: Array = []          # {"pts": PackedVector2Array(0~1), "c": 색 번호}
var color := 0

var _win: Control
var _board: Control
var _preview: TextureRect
var _info: Label
var _current := PackedVector2Array()
var _swatches: Array = []
var _under_img: Image


func setup(t: String, h: String, base: Texture2D = null, fill_paper: bool = true) -> void:
	title = t
	hint = h
	under = base
	paper = fill_paper


func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if under:
		_under_img = under.get_image()
		if _under_img and _under_img.is_compressed():
			_under_img.decompress()
		if _under_img:
			_under_img = _under_img.duplicate()
			_under_img.convert(Image.FORMAT_RGBA8)
			_under_img.resize(N, N, Image.INTERPOLATE_NEAREST)
	_win = UI.icon(self, "ui_window", Vector2(110, 46), Vector2(420, 268), Color.WHITE, false)
	var tl := UI.label(_win, title, Vector2(0, 14), Vector2(420, 20), 14)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.icon(_win, "ui_board", BOARD.position - Vector2(8, 8), BOARD.size + Vector2(16, 16), Color.WHITE, false)
	_board = Control.new()
	_board.position = BOARD.position
	_board.size = BOARD.size
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_board.mouse_default_cursor_shape = Control.CURSOR_CROSS
	_board.draw.connect(_draw_board)
	_board.gui_input.connect(_board_input)
	_win.add_child(_board)

	var x := 246.0
	UI.label(_win, "도트로 보면", Vector2(x, 44), Vector2(80, 12), 9)
	UI.icon(_win, "ui_slot", Vector2(x, 56), Vector2(52, 52))
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.position = Vector2(x + 4, 60)
	_preview.size = Vector2(44, 44)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win.add_child(_preview)
	UI.label(_win, "크레용", Vector2(x, 114), Vector2(60, 12), 9)
	for i in COLORS.size():
		var sw := ColorRect.new()
		sw.color = COLORS[i]
		sw.position = Vector2(x + (i % 4) * 22, 128 + (i / 4) * 20)
		sw.size = Vector2(16, 16)
		sw.pivot_offset = Vector2(8, 8)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_win.add_child(sw)
		_swatches.append(sw)
		UI.button(_win, "", sw.position - Vector2(1, 1), Vector2(18, 18), set_color.bind(i), "plain")
	UI.button(_win, "완성", Vector2(x, 172), Vector2(52, 20), finish)
	UI.button(_win, "다시", Vector2(x + 56, 172), Vector2(52, 20), clear)
	UI.button(_win, "그만두기", Vector2(x + 112, 172), Vector2(52, 20), cancel)
	_info = UI.label(_win, "", Vector2(112, 212), Vector2(250, 30), 9)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_color_override("font_color", UI.INK_SOFT)
	_info.text = (hint + "\n" if hint != "" else "") + "오른쪽 클릭: 마지막 획 지우기   Enter: 완성"
	set_color(0)


func set_color(i: int) -> void:
	color = i
	for k in _swatches.size():
		(_swatches[k] as ColorRect).scale = Vector2(1.15, 1.15) if k == i else Vector2(0.8, 0.8)
	_update()


func clear() -> void:
	strokes.clear()
	_current = PackedVector2Array()
	_update()


func cancel() -> void:
	done.emit("")
	queue_free()


func _board_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_current = PackedVector2Array([_norm(mb.position)])
			elif _current.size() > 0:
				strokes.append({"pts": _current, "c": color})
				_current = PackedVector2Array()
				_update()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and not strokes.is_empty():
			strokes.pop_back()
			_update()
	elif event is InputEventMouseMotion and _current.size() > 0:
		var p := _norm((event as InputEventMouseMotion).position)
		if p.distance_to(_current[_current.size() - 1]) > 0.01:
			_current.append(p)
			_board.queue_redraw()


func _norm(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x / BOARD.size.x, 0.0, 0.999), clampf(p.y / BOARD.size.y, 0.0, 0.999))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			cancel()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER:
			finish()
			get_viewport().set_input_as_handled()


## 지금까지 그린 것을 N × N 도트 그림으로 (선마다 그 색으로 찍는다)
func render() -> Image:
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(PAPER if paper else Color(0, 0, 0, 0))
	if _under_img:
		img.blend_rect(_under_img, Rect2i(0, 0, N, N), Vector2i.ZERO)
	for s in strokes:
		var grid := Pixel.rasterize([s["pts"]])
		var c: Color = COLORS[int(s["c"])]
		# 크레용 선은 두 칸 굵기 (작게 걸어도 보이게)
		for y in N:
			for x in N:
				if grid[y][x]:
					img.set_pixel(x, y, c)
					if x + 1 < N:
						img.set_pixel(x + 1, y, c)
					if y + 1 < N:
						img.set_pixel(x, y + 1, c)
	return img


func _update() -> void:
	if _preview:
		_preview.texture = ImageTexture.create_from_image(render())
		_board.queue_redraw()


func _draw_board() -> void:
	_board.draw_rect(Rect2(Vector2.ZERO, BOARD.size), PAPER if paper else Color(1, 1, 1, 0.5))
	if under:
		_board.draw_texture_rect(under, Rect2(Vector2.ZERO, BOARD.size), false)
	for s in strokes + [{"pts": _current, "c": color}]:
		var pts: PackedVector2Array = s["pts"]
		var c: Color = COLORS[int(s["c"])]
		if pts.size() == 1:
			_board.draw_circle(pts[0] * BOARD.size, 2.5, c)
		elif pts.size() > 1:
			var scaled := PackedVector2Array()
			for p in pts:
				scaled.append(p * BOARD.size)
			_board.draw_polyline(scaled, c, 4.0, true)


## 완성: 도트 그림을 저장하고 그 이름을 알린다
func finish() -> void:
	if strokes.is_empty():
		_info.text = "아직 아무것도 그리지 않았어요."
		return
	var img := render()
	img.resize(N * Pixel.OUT_SCALE, N * Pixel.OUT_SCALE, Image.INTERPOLATE_NEAREST)
	var art := Art.save_drawn(img)
	Sound.play("craft")
	done.emit(art)
	queue_free()
