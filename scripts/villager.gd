extends StaticBody2D
## 마을 주민. 이름이 먼저 지워져서 이름표가 비어 있다. F 로 말을 걸면 대사를 한다.

const Art := preload("res://scripts/art.gd")
const TALK_RANGE := 34.0

var sprite_name := "villager_0"
var lines: Array = []
var speaker := "□□이"

var _emote: Sprite2D
var _talking := false


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)
	var t := Art.tex(sprite_name)
	if t:
		Art.make_sprite(self, t, Vector2(0, 6)).show_behind_parent = true
	_emote = Sprite2D.new()
	_emote.texture = Art.tex("key_f")
	_emote.scale = Art.SCALE
	_emote.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_emote.position = Vector2(0, -44)
	_emote.visible = false
	add_child(_emote)


func _process(_delta: float) -> void:
	var p := GameState.player_ref
	_emote.visible = is_instance_valid(p) and p.global_position.distance_to(global_position) < TALK_RANGE


func interact() -> void:
	if _talking or lines.is_empty():
		return
	_talking = true
	await GameState.say(speaker, lines)
	_talking = false


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2(0, 5.0 / 0.4), 8, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO)
