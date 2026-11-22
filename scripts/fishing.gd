extends Control
## 낚시 (내 마을의 낚시터, 1장 마을의 강가에서 F).
##   1. 찌를 던지고 기다린다 (1.2 ~ 3초). 이때 F 를 누르면 너무 일러서 놓친다.
##   2. "!" 가 뜨면 0.7초 안에 F 를 누른다 (정성 낚시터는 1초).
##   3. 끌어올리기: F 를 누르고 있으면 찌가 올라가고 떼면 내려간다. 찌를 초록 칸 안에 두면 게이지가 찬다.
##      게이지가 다 차면 낚는다. 7초 안에 못 채우면 놓친다.
##   잡은 것은 가방의 소모품에 들어간다. 낮과 밤, 낚시터마다 낚이는 것이 다르다.
## Esc 로 그만둔다. 낚시하는 동안 게임은 멈춘다.

const UI := preload("res://scripts/ui_kit.gd")
const Items := preload("res://scripts/items.gd")

const REEL_TIME := 7.0
const FILL_TIME := 2.0       # 초록 칸 안에 이만큼 머물면 낚는다
const BAR := Rect2(428, 122, 14, 106)

var phase := ""              # "", "wait", "bite", "reel", "result"
var window := 0.7
var place := "home"
var progress := 0.0          # 끌어올리기 게이지 (0 ~ 1)
var _zone_half := 0.17
var _pos := 0.3              # 찌의 높이 (0 아래 ~ 1 위)
var _vel := 0.0
var _zone := 0.5
var _t := 0.0
var _wait := 2.0
var _label: Label
var _mark: Label
var _icon: TextureRect
var _gauge: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(640, 360)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.08, 0.45)
	dim.size = Vector2(640, 360)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	UI.icon(self, "ui_note", Vector2(200, 112), Vector2(260, 128), Color.WHITE, false)
	_label = UI.label(self, "", Vector2(222, 192), Vector2(196, 32), 10)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mark = UI.label(self, "", Vector2(220, 130), Vector2(200, 56), 48)
	_mark.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	_mark.add_theme_constant_override("outline_size", 6)
	_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mark.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	_mark.pivot_offset = Vector2(100, 28)
	_icon = UI.icon(self, "", Vector2(300, 140), Vector2(40, 40))
	_gauge = Control.new()
	_gauge.size = size
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.draw.connect(_draw_gauge)
	add_child(_gauge)


func is_active() -> bool:
	return phase != ""


func start(fine: bool = false, where: String = "home") -> void:
	if is_active():
		return
	window = 1.0 if fine else 0.7
	_zone_half = 0.21 if fine else 0.17
	place = where
	visible = true
	GameState.set_menu_open(true)
	_cast()


func _cast() -> void:
	phase = "wait"
	_t = 0.0
	_wait = randf_range(1.2, 3.0)
	_mark.text = ""
	_mark.scale = Vector2.ONE
	_icon.texture = null
	_label.text = "찌를 던졌어요…\n(! 가 뜨면 F,  Esc 그만두기)"


func _process(delta: float) -> void:
	if phase == "":
		return
	_t += delta
	match phase:
		"wait":
			_mark.text = ".".repeat(1 + int(_t * 2.0) % 3)
			if _t >= _wait:
				phase = "bite"
				_t = 0.0
				_mark.text = "!"
				_label.text = "지금이에요! F"
		"bite":
			_mark.scale = Vector2.ONE * (1.0 + 0.15 * sin(_t * 30.0))
			if _t >= window:
				_result("")
		"reel":
			var held := Input.is_physical_key_pressed(KEY_F) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			step_reel(delta, held)
		"result":
			if _t >= 1.3:
				_cast()
	_gauge.queue_redraw()


## 끌어올리기 한 프레임. held: F 를 누르고 있는지. (테스트에서 직접 부를 수 있다)
func step_reel(delta: float, held: bool) -> void:
	if phase != "reel":
		return
	_vel += (2.4 if held else -1.8) * delta
	_vel = clampf(_vel, -0.9, 0.9)
	_pos += _vel * delta
	if _pos <= 0.0 or _pos >= 1.0:
		_pos = clampf(_pos, 0.0, 1.0)
		_vel = 0.0
	_zone = 0.5 + 0.26 * sin(_t * 1.2)
	if absf(_pos - _zone) <= _zone_half:
		progress += delta / FILL_TIME
	else:
		progress = maxf(0.0, progress - delta / (FILL_TIME * 2.0))
	if progress >= 1.0:
		_result(GameState.catch_fish(place))
	elif _t >= REEL_TIME:
		_result("")


## 입질에 맞춰 챈다. 맞으면 끌어올리기로 넘어간다 (true). 너무 이르면 놓친다.
func pull() -> bool:
	if phase == "bite":
		phase = "reel"
		_t = 0.0
		progress = 0.0
		_pos = 0.3
		_vel = 0.0
		_mark.text = ""
		_label.text = "F 를 눌렀다 뗐다 하며 찌를 초록 칸에 두세요!"
		return true
	if phase == "wait":
		_result("")
	return false


func _result(id: String) -> void:
	phase = "result"
	_t = 0.0
	_mark.text = ""
	if id == "":
		_label.text = "놓쳤어요…"
	else:
		_icon.texture = UI.tex(str(Items.CONSUMABLES[id][1]))
		_label.text = "%s 을(를) 낚았어요!" % Items.CONSUMABLES[id][0]


func stop() -> void:
	if phase == "":
		return
	phase = ""
	visible = false
	GameState.set_menu_open(false)


func _input(event: InputEvent) -> void:
	if phase == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			stop()
		elif event.physical_keycode == KEY_F and phase != "reel":
			pull()
		get_viewport().set_input_as_handled()


func _draw_gauge() -> void:
	if phase != "reel":
		return
	var g := _gauge
	g.draw_rect(BAR.grow(2), Color(0.35, 0.27, 0.24))
	g.draw_rect(BAR, Color(0.8, 0.9, 1.0))
	var zy := BAR.end.y - (_zone + _zone_half) * BAR.size.y
	var zr := Rect2(BAR.position.x, zy, BAR.size.x, _zone_half * 2.0 * BAR.size.y).intersection(BAR)
	g.draw_rect(zr, Color(0.5, 0.85, 0.5))
	var by := BAR.end.y - _pos * BAR.size.y
	g.draw_rect(Rect2(BAR.position.x - 3, by - 3, BAR.size.x + 6, 6), Color(0.9, 0.35, 0.3))
	# 게이지
	g.draw_rect(Rect2(220, 176, 190, 8), Color(0.35, 0.27, 0.24))
	g.draw_rect(Rect2(221, 177, 188 * clampf(progress, 0.0, 1.0), 6), Color(1.0, 0.8, 0.35))
	g.draw_rect(Rect2(220, 166, 190 * clampf(1.0 - _t / REEL_TIME, 0.0, 1.0), 3), Color(0.6, 0.6, 0.65))
