extends StaticBody2D
## 이야기 자리: 귀퉁이, 모자 잃은 도토리, 끊어진 덩굴처럼 F 로 말을 걸면 이야기가 이어지는 것.
## 그림 한 장(또는 6칸 띠의 첫 칸)을 보여 주고, 말을 걸면 story.on_spot(self) 을 부른다 (scripts/maps/ch2_story.gd).

const Art := preload("res://scripts/core/art.gd")
const TALK_RANGE := 36.0

var what := ""
var sprite_name := ""
var tint := Color.WHITE
var frames := 1
var story: Node
var done := false            # 이야기가 끝났다: 말이 끝나면 사라진다

var _emote: Sprite2D
var _busy := false


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
		var s := Art.make_sprite(self, t, Vector2(0, 6), frames, 1)
		s.frame = 0
		s.modulate = tint
		s.show_behind_parent = true
	_emote = Sprite2D.new()
	_emote.texture = Art.tex("key_f")
	_emote.scale = Art.SCALE
	_emote.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_emote.position = Vector2(0, -46)
	_emote.visible = false
	add_child(_emote)


func _process(_delta: float) -> void:
	var p := GameState.player_ref
	_emote.visible = not _busy and is_instance_valid(p) and p.global_position.distance_to(global_position) < TALK_RANGE
	if _emote.visible:
		_emote.position.y = -46.0 - absf(sin(Time.get_ticks_msec() / 260.0)) * 2.0


func interact() -> void:
	if _busy or story == null:
		return
	_busy = true
	await story.call("on_spot", self)
	_busy = false
	if done:
		remove_from_group("interactable")
		queue_free()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2(0, 5.0 / 0.4), 8, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO)
