extends Control
## 낚시 (내 마을의 낚시터에서 F).
##   1. 찌를 던지고 기다린다 (1.2 ~ 3초). 이때 F 를 누르면 너무 일러서 놓친다.
##   2. "!" 가 뜨면 0.7초 안에 F 를 누른다 (정성 낚시터는 1초). 늦으면 놓친다.
##   3. 잡은 물고기는 가방의 소모품에 들어간다. 밤에는 큰 물고기가 더 잘 잡힌다.
## Esc 로 그만둔다. 낚시하는 동안 게임은 멈춘다.

const UI := preload("res://scripts/ui_kit.gd")
const Items := preload("res://scripts/items.gd")

var phase := ""              # "", "wait", "bite", "result"
var window := 0.7
var _t := 0.0
var _wait := 2.0
var _label: Label
var _mark: Label
var _icon: TextureRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(640, 360)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.icon(self, "ui_note", Vector2(220, 120), Vector2(200, 110), Color.WHITE, false)
	_label = UI.label(self, "", Vector2(232, 190), Vector2(176, 30), 10)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mark = UI.label(self, "", Vector2(220, 138), Vector2(200, 44), 36)
	_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mark.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	_icon = UI.icon(self, "", Vector2(300, 140), Vector2(40, 40))


func is_active() -> bool:
	return phase != ""


func start(fine: bool = false) -> void:
	if is_active():
		return
	window = 1.0 if fine else 0.7
	visible = true
	GameState.set_menu_open(true)
	_cast()


func _cast() -> void:
	phase = "wait"
	_t = 0.0
	_wait = randf_range(1.2, 3.0)
	_mark.text = ""
	_icon.texture = null
	_label.text = "찌를 던졌어요…\n(! 가 뜨면 F,  Esc 그만두기)"


func _process(delta: float) -> void:
	if phase == "":
		return
	_t += delta
	if phase == "wait":
		_mark.text = ".".repeat(1 + int(_t * 2.0) % 3)
		if _t >= _wait:
			phase = "bite"
			_t = 0.0
			_mark.text = "!"
			_label.text = "지금이에요! F"
	elif phase == "bite" and _t >= window:
		_result("")
	elif phase == "result" and _t >= 1.3:
		_cast()


## 입질에 맞춰 챈다. 돌려주는 것: 잡은 물고기 id ("" 은 놓침)
func pull() -> String:
	if phase == "bite":
		var id := GameState.catch_fish()
		_result(id)
		return id
	if phase == "wait":
		_result("")
	return ""


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
		elif event.physical_keycode == KEY_F:
			pull()
		get_viewport().set_input_as_handled()
