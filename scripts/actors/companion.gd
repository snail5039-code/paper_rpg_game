extends Node2D
## 같이 다니는 친구 (다시 그려 준 몬스터). 플레이어를 따라다니며 가까운 적을 때린다.
##  - 1.4초마다 60 안의 적 하나를 공격한다.
##  - G 키: 친구 스킬. 주변(70)의 모든 적에게 공격력의 3배. 재사용 10초.
## 맵(village, field, home)이 Companion.attach(actors, player) 로 붙인다. 동행이 바뀌면 스스로 바뀐다.

const Art := preload("res://scripts/core/art.gd")
const Data := preload("res://scripts/data/game_data.gd")

const FOLLOW_DIST := 26.0
const SPEED := 110.0
const ATTACK_RANGE := 60.0
const ATTACK_EVERY := 1.4
const SKILL_RANGE := 70.0
const SKILL_CD := 10.0
const SKILL_MULT := 3.0

var player: Node2D
var friend: Dictionary = {}
var skill_cd := 0.0
var _attack_t := 0.0
var _sprite: Sprite2D
var _hframes := 1
var _t := 0.0
var _bump := 0.0            # 공격할 때 앞으로 살짝 튀는 정도
var _bump_dir := Vector2.ZERO
var _skill_fx := 0.0
var _star_tex: Texture2D


## 맵에 친구 노드를 하나 붙인다 (동행이 없으면 보이지 않는다)
static func attach(actors: Node, player_node: Node2D) -> Node2D:
	var c: Node2D = load("res://scripts/actors/companion.gd").new()
	c.set("player", player_node)
	c.position = player_node.position + Vector2(-20, 6)
	actors.add_child(c)
	return c


## 친구 종의 모습: [그림, 가로 프레임 수, 색]
static func look(sp: String) -> Array:
	var info: Dictionary = Data.FRIENDS.get(sp, {})
	var cfg: Dictionary = Data.MONSTERS.get(str(info.get("kind", "slime")), Data.MONSTERS["slime"])
	var tint: Color = info.get("tint", Color.WHITE)
	if str(cfg["art"]) == "strip":
		return [Art.tex("mon_" + str(cfg["sprite"])), 6, tint]
	if str(cfg["art"]) == "single":
		return [Art.tex(str(cfg["sprite"])), 1, tint]
	return [Art.tex(str(cfg["sprite"]) + "_idle"), 1, tint]


func _ready() -> void:
	add_to_group("companion")
	_star_tex = Art.tex("fx_hit")
	GameState.changed.connect(_sync)
	_sync()


func _sync() -> void:
	var f := GameState.companion_friend()
	if is_same(f, friend) and (_sprite != null or f.is_empty()):
		return
	friend = f
	if _sprite:
		_sprite.queue_free()
		_sprite = null
	visible = not friend.is_empty()
	if friend.is_empty():
		return
	var l := look(str(friend["sp"]))
	if l[0] != null:
		_hframes = int(l[1])
		_sprite = Art.make_sprite(self, l[0], Vector2(0, 6), _hframes, 1)
		_sprite.scale = Art.SCALE * 0.8
		_sprite.modulate = l[2]
		_sprite.show_behind_parent = true


func _physics_process(delta: float) -> void:
	if friend.is_empty() or not is_instance_valid(player):
		return
	_t += delta
	skill_cd = maxf(0.0, skill_cd - delta)
	_bump = maxf(0.0, _bump - delta * 5.0)
	_skill_fx = maxf(0.0, _skill_fx - delta)
	var to := player.global_position - global_position
	if to.length() > 220.0:
		global_position = player.global_position + Vector2(-20, 6)   # 너무 멀어지면 옆으로 온다
	elif to.length() > FOLLOW_DIST:
		global_position += to.normalized() * minf(SPEED * delta, to.length() - FOLLOW_DIST)
	_attack_t -= delta
	if _attack_t <= 0.0:
		var target := _nearest_enemy(ATTACK_RANGE)
		if target:
			_attack_t = ATTACK_EVERY
			_bump = 1.0
			_bump_dir = (target.global_position - global_position).normalized()
			target.call("take_damage", GameState.friend_attack(friend), _bump_dir, false)
	if _sprite:
		_sprite.position = Vector2(0, 6) + _bump_dir * _bump * 8.0 + Vector2(0, -absf(sin(_t * 7.0)) * 2.5)
		if _hframes > 1:
			_sprite.frame = int(_t * 6.0) % 2
		if absf(to.x) > 2.0:
			_sprite.flip_h = to.x < 0.0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_G:
		if use_skill():
			get_viewport().set_input_as_handled()


## 친구 스킬: 주변의 모든 적을 강하게 때린다
func use_skill() -> bool:
	if friend.is_empty():
		return false
	if skill_cd > 0.0:
		GameState.notify("%s 은(는) 아직 숨을 고르는 중이에요." % GameState.friend_name(friend))
		return false
	skill_cd = SKILL_CD
	_skill_fx = 0.4
	var dmg := roundi(GameState.friend_attack(friend) * SKILL_MULT)
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Node2D
		if enemy.global_position.distance_to(global_position) <= SKILL_RANGE + float(enemy.get("radius")):
			enemy.call("take_damage", dmg, (enemy.global_position - global_position).normalized(), false)
	GameState.notify("%s!" % str(Data.FRIENDS[str(friend["sp"])]["skill"]))
	return true


func _nearest_enemy(reach: float) -> Node2D:
	var best: Node2D = null
	var best_d := reach
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Node2D
		var d := enemy.global_position.distance_to(global_position) - float(enemy.get("radius"))
		if d <= best_d and int(enemy.get("hp")) > 0:
			best = enemy
			best_d = d
	return best


func _draw() -> void:
	if friend.is_empty():
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2(0, 5.0 / 0.4), 7, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO)
	if _sprite == null:
		draw_circle(Vector2(0, -2), 6, Color(0.7, 0.75, 1.0))
	if _skill_fx > 0.0:
		var p := 1.0 - _skill_fx / 0.4
		draw_arc(Vector2(0, -4), SKILL_RANGE * p, 0, TAU, 32, Color(1.0, 0.9, 0.5, 1.0 - p), 3.0)
