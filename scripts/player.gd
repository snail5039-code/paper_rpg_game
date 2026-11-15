extends CharacterBody2D
## 플레이어: WASD 이동 + Space 회피 (MVP 초안)

@export var move_speed: float = 80.0
@export var dodge_speed: float = 200.0
@export var dodge_time: float = 0.15

var _dodge_timer: float = 0.0
var _facing: Vector2 = Vector2.DOWN


func _physics_process(delta: float) -> void:
	var dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).normalized()

	if dir != Vector2.ZERO:
		_facing = dir

	if _dodge_timer > 0.0:
		_dodge_timer -= delta
		velocity = _facing * dodge_speed
	else:
		velocity = dir * move_speed
		if Input.is_action_just_pressed("dodge"):
			_dodge_timer = dodge_time

	move_and_slide()
