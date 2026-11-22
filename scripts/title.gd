extends Node
## 시작 화면. 게임을 켜면 가장 먼저 나온다.
##   이어하기     : 마지막에 하던 캐릭터로 바로 시작
##   캐릭터 고르기: 캐릭터 칸 8개 (새로 만들기, 시작, 지우기). 마을과 창고는 모든 캐릭터가 같이 쓴다.
##   설정         : 소리 크기, 전체 화면
##   끝내기

const Art := preload("res://scripts/art.gd")
const UI := preload("res://scripts/ui_kit.gd")
const MenusScript := preload("res://scripts/menus.gd")

var _root: Control
var _menus: Dictionary = {}
var _buttons: Array = []
var _continue: Button


func _ready() -> void:
	get_tree().paused = false
	var layer := CanvasLayer.new()
	add_child(layer)
	_root = Control.new()
	_root.size = Vector2(640, 360)
	layer.add_child(_root)
	var bg := UI.icon(_root, "bg_title", Vector2.ZERO, Vector2(640, 360), Color.WHITE, false)
	if bg.texture == null:
		var back := ColorRect.new()
		back.color = Color(0.96, 0.92, 0.82)
		back.size = Vector2(640, 360)
		_root.add_child(back)
	UI.icon(_root, "ui_note", Vector2(424, 14), Vector2(190, 240), Color.WHITE, false)
	var title := UI.label(_root, "공책 RPG", Vector2(424, 50), Vector2(190, 26), 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := UI.label(_root, "(가제)", Vector2(424, 74), Vector2(190, 14), 9)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", UI.INK_SOFT)
	_continue = UI.button(_root, "이어하기", Vector2(454, 98), Vector2(130, 26), _on_continue)
	_buttons = [
		_continue,
		UI.button(_root, "캐릭터 고르기", Vector2(454, 128), Vector2(130, 26), _open.bind("slots")),
		UI.button(_root, "설정", Vector2(454, 158), Vector2(130, 26), _open.bind("settings")),
		UI.button(_root, "끝내기", Vector2(454, 188), Vector2(130, 26), get_tree().quit),
	]
	for b in _buttons:
		(b as Button).add_theme_font_size_override("font_size", 11)
	for k in ["slots", "settings"]:
		var m: Control = MenusScript.new()
		m.set("kind", k)
		_root.add_child(m)
		m.connect("close_requested", _close.bind(k))
		_menus[k] = m
	_refresh()
	Sound.music(true)


func _refresh() -> void:
	var last := int(GameState.settings.get("last_slot", 0))
	var info := GameState.slot_info(last)
	_continue.disabled = info.is_empty()
	_continue.text = "이어하기" if info.is_empty() else "이어하기 (%d번 · 필력 %d)" % [last, int(info["level"])]


func _on_continue() -> void:
	GameState.start_slot(int(GameState.settings.get("last_slot", 0)))


func _open(k: String) -> void:
	for other in _menus:
		(_menus[other] as Control).visible = false
	(_menus[k] as Control).visible = true
	(_menus[k] as Control).call("open")


func _close(k: String) -> void:
	(_menus[k] as Control).visible = false
	_refresh()


func menu(k: String) -> Control:
	return _menus[k]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		for k in _menus:
			if (_menus[k] as Control).visible:
				_close(k)
