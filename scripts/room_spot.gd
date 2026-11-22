extends Node2D
## 내 집 안에서 F 로 쓰는 자리: 침대(mode "bed")와 문(mode "door"). 일은 방(scripts/room.gd)이 한다.

const Art := preload("res://scripts/art.gd")
const RANGE := 34.0

var mode := "bed"
var _key: Texture2D


func _ready() -> void:
	add_to_group("interactable")
	_key = Art.tex("key_f")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _room() -> Node:
	var n: Node = self
	while n != null and not n.has_method("use_bed"):
		n = n.get_parent()
	return n


func interact() -> void:
	var room := _room()
	if room:
		room.call("use_bed" if mode == "bed" else "leave")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var p := GameState.player_ref
	if _key and is_instance_valid(p) and p.global_position.distance_to(global_position) < RANGE:
		var h := 10.0
		var w := h * _key.get_width() / float(_key.get_height())
		draw_texture_rect(_key, Rect2(Vector2(-w * 0.5, -40), Vector2(w, h)), false)
	if mode == "door":
		draw_rect(Rect2(-16, 2, 32, 5), Color(0.55, 0.4, 0.3))
