extends Node2D
## 이야기 동안 주인공 뒤를 따라다니는 하루 (말을 걸 수는 없다). 그림은 마을의 하루와 같은 npc_walk (4×4: 가로 걷기 프레임, 세로 방향).
## ch1_story.gd 가 1장 뒷이야기 동안 사냥터에 붙인다.

const Art := preload("res://scripts/core/art.gd")
const FOLLOW_DIST := 22.0
const SPEED := 105.0

var player: Node2D
var _sprite: Sprite2D
var _row := 0
var _t := 0.0


static func attach(actors: Node, player_node: Node2D) -> Node2D:
	var h: Node2D = load("res://scripts/actors/haru_follower.gd").new()
	h.set("player", player_node)
	h.position = player_node.position + Vector2(18, -6)
	actors.add_child(h)
	return h


func _ready() -> void:
	add_to_group("haru_follower")
	var t := Art.tex("npc_walk")
	if t:
		_sprite = Art.make_sprite(self, t, Vector2(0, 6), 4, 4)
		_sprite.frame_coords = Vector2i(1, 0)


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var to := player.global_position - global_position
	var moving := to.length() > FOLLOW_DIST
	if moving:
		var step := minf(to.length() - FOLLOW_DIST, SPEED * delta * (2.0 if to.length() > 90.0 else 1.0))
		global_position += to.normalized() * step
		_row = Art.dir_row(to)
		_t += delta
	else:
		_t = 0.0
		if to.length() > 1.0:
			_row = Art.dir_row(to)
	if _sprite:
		_sprite.frame_coords = Vector2i(int(_t * 8.0) % 4 if moving else 1, _row)
	# 아주 멀어지면(문을 지나 순간 이동 등) 곁으로 바로 온다
	if to.length() > 260.0:
		global_position = player.global_position + Vector2(18, -6)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2(0, 5.0 / 0.4), 7, Color(0, 0, 0, 0.16))
	draw_set_transform(Vector2.ZERO)
