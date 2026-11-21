extends CharacterBody2D
## 몬스터 1종: 낙서 슬라임.
## 가까이 오면 플레이어를 쫓아오고, 닿으면 피해. 처치 시 연필심을 떨어뜨린다.

signal died(home: Vector2)

const PickupScript := preload("res://scripts/pickup.gd")

@export var use_placeholder_art := true
@export var max_hp := 3
@export var speed := 34.0
@export var chase_range := 90.0
@export var contact_range := 11.0
@export var damage := 1

var radius := 6.0
var hp: int
var home := Vector2.ZERO

var _knock := Vector2.ZERO
var _flash := 0.0
var _t := 0.0
var _wander := Vector2.ZERO
var _wander_timer := 0.0


func _ready() -> void:
	hp = max_hp
	home = global_position
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	_t = randf() * 10.0


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)

	var dir := Vector2.ZERO
	var p := GameState.player_ref
	if is_instance_valid(p):
		var to := p.global_position - global_position
		if to.length() < chase_range:
			dir = to.normalized()
		if to.length() < contact_range:
			p.call("take_damage", damage, to.normalized())

	if dir == Vector2.ZERO:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_wander_timer = randf_range(1.0, 2.5)
			var back := (home - global_position)
			_wander = back.normalized() if back.length() > 40.0 else Vector2.from_angle(randf() * TAU) * randf_range(0.0, 0.6)
		dir = _wander

	# 통통 튀는 이동: 뛰는 순간에만 전진
	var hop := maxf(0.0, sin(_t * 8.0))
	velocity = dir * speed * (0.4 + hop) + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 500.0 * delta)
	move_and_slide()
	queue_redraw()


func take_damage(amount: int, dir: Vector2) -> void:
	hp -= amount
	_flash = 0.12
	_knock = dir.normalized() * 190.0
	if hp <= 0:
		_die()


func _die() -> void:
	var drop: Node2D = PickupScript.new()
	drop.global_position = global_position
	get_parent().add_child(drop)
	died.emit(home)
	queue_free()


func _draw() -> void:
	if not use_placeholder_art:
		return
	var hop := maxf(0.0, sin(_t * 8.0))
	var squash := Vector2(1.0 + (1.0 - hop) * 0.15, 0.85 + hop * 0.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2(0, 8), 6, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2(0, -hop * 4.0), 0.0, squash)
	var body := Color(1, 1, 1) if _flash > 0.0 else Color(0.66, 0.64, 0.92)
	draw_circle(Vector2(0, 0), 7, body)
	draw_arc(Vector2(0, 0), 7, 0, TAU, 18, Color(0.25, 0.25, 0.35), 1.0)
	draw_rect(Rect2(-3, -2, 1, 2), Color(0.15, 0.15, 0.25))
	draw_rect(Rect2(2, -2, 1, 2), Color(0.15, 0.15, 0.25))
	draw_set_transform(Vector2.ZERO)
	# 체력 표시 (맞았을 때만)
	if hp < max_hp:
		for i in max_hp:
			var c := Color(0.9, 0.3, 0.35) if i < hp else Color(0.4, 0.4, 0.45)
			draw_rect(Rect2(-max_hp * 2.0 + i * 4.0, -15, 3, 2), c)
