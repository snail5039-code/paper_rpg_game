extends CanvasLayer
## 그림책 장면: 공책 종이 위에 그림 한 장과 글 몇 줄. 클릭·F·Space·Enter 로 글을 넘기고, 마지막 글 뒤에 닫힌다.
## 이야기의 큰 장면(1장 뒷이야기의 시작·기억·편지·끝)에 쓴다. 게임은 그동안 멈춘다.
##   await StoryBook.play(부모, [[그림 이름, [글, 글, ...]], ...], 제목)

const Art := preload("res://scripts/core/art.gd")
const PAPER := Color(0.99, 0.96, 0.88)
const INK := Color(0.28, 0.22, 0.18)
const PIC := Rect2(70, 34, 500, 240)        # 그림 자리 (화면 640×360)

signal finished
signal _next

var _pages: Array = []
var _title := ""
var _pic: TextureRect
var _text: Label
var _head: Label
var _hint: Label
var _root: Control
var _waiting := false
var _tex_hold: Array = []    # 그리는 텍스처는 붙잡아 둔다


static func play(parent: Node, pages: Array, title: String = "") -> void:
	var b: CanvasLayer = load("res://scripts/ui/story_book.gd").new()
	b.set("_pages", pages)
	b.set("_title", title)
	parent.add_child(b)
	await b.finished


func _ready() -> void:
	layer = 40
	add_to_group("story_book")
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.set_cutscene(true)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.modulate.a = 0.0
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.09, 0.07, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var page := Control.new()          # 공책 종이 (줄, 왼쪽 빨간 여백선, 구멍)
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.draw.connect(_draw_page.bind(page))
	_root.add_child(page)
	_pic = TextureRect.new()
	_pic.position = PIC.position
	_pic.size = PIC.size
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_pic.clip_contents = true
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_pic)
	_head = _label(Vector2(70, 14), Vector2(500, 16), 10, Color(0.55, 0.3, 0.25))
	_head.text = _title
	_text = _label(Vector2(80, 284), Vector2(480, 44), 12, INK)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint = _label(Vector2(480, 330), Vector2(90, 12), 8, Color(INK, 0.6))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.text = "클릭 · F ▶"
	_run.call_deferred()


func _label(pos: Vector2, sz: Vector2, font: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l


func _run() -> void:
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.35)
	await tw.finished
	for pg in _pages:
		var tex := Art.tex(str(pg[0]))
		_tex_hold.append(tex)
		if tex != _pic.texture:
			_pic.modulate.a = 0.0
			_pic.texture = tex
			var t2 := create_tween()
			t2.tween_property(_pic, "modulate:a", 1.0, 0.4)
		for line in pg[1]:
			_text.text = str(line)
			_text.visible_ratio = 0.0
			var tt := create_tween()
			tt.tween_property(_text, "visible_ratio", 1.0, clampf(str(line).length() * 0.035, 0.2, 1.4))
			_waiting = true
			await _next
			if tt.is_running():
				tt.kill()
	var out := create_tween()
	out.tween_property(_root, "modulate:a", 0.0, 0.3)
	await out.finished
	GameState.set_cutscene(false)
	finished.emit()
	queue_free()


## 글이 다 나오기 전에 누르면 글을 한 번에 보여 주고, 다 나왔으면 다음 글로
func advance() -> void:
	if not _waiting:
		return
	if _text.visible_ratio < 1.0:
		_text.visible_ratio = 1.0
		return
	_waiting = false
	_next.emit()


func _input(event: InputEvent) -> void:
	var go := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		go = true
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		go = true
	if go:
		get_viewport().set_input_as_handled()
		advance()


func _draw_page(c: Control) -> void:
	var r := Rect2(50, 8, 540, 344)
	c.draw_rect(Rect2(r.position + Vector2(4, 5), r.size), Color(0, 0, 0, 0.35))
	c.draw_rect(r, PAPER)
	var y := r.position.y + 22.0
	while y < r.end.y - 6:
		c.draw_line(Vector2(r.position.x + 4, y), Vector2(r.end.x - 4, y), Color(0.6, 0.72, 0.9, 0.35), 1.0)
		y += 16.0
	c.draw_line(Vector2(r.position.x + 14, r.position.y), Vector2(r.position.x + 14, r.end.y), Color(0.9, 0.45, 0.45, 0.6), 1.0)
	for i in 6:
		c.draw_circle(Vector2(r.position.x + 7, r.position.y + 30 + i * 56), 3.0, Color(0.12, 0.09, 0.07, 0.82))
	# 그림 테두리 (크레용 선)
	c.draw_rect(PIC.grow(3), Color(0.35, 0.25, 0.2), false, 2.0)
	c.draw_rect(r, Color(0.45, 0.33, 0.25), false, 1.5)
