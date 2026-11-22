extends CharacterBody2D
## 플레이어: WASD 이동, Space 회피, 마우스 왼쪽 클릭 공격, F 상호작용.
## 그래픽은 _draw() 임시 도형. 도트가 준비되면 AnimatedSprite2D 자식을 추가하고
## use_placeholder_art 를 끄면 된다.

signal hp_changed(hp: int, max_hp: int)

@export var use_placeholder_art := true
@export var move_speed := 95.0
@export var dodge_speed := 250.0
@export var dodge_time := 0.18
@export var dodge_cooldown := 0.45
@export var max_hp := 5
@export var invuln_time := 0.8
@export var attack_range := 34.0
@export var attack_arc_deg := 120.0
@export var attack_cooldown := 0.34
@export var attack_damage := 1
@export var interact_range := 40.0

var hp: int
var mp: float = 0.0
var max_mp: int = 0
var spawn_point := Vector2.ZERO
var facing := Vector2.DOWN

var _dodge_timer := 0.0
var _dodge_cd := 0.0
var _attack_cd := 0.0
var _swing_timer := 0.0
var _swing_dir := Vector2.DOWN
var _invuln := 0.0
var _knock := Vector2.ZERO
var _anim_t := 0.0


const Art := preload("res://scripts/art.gd")
const FOOT := Vector2(0, 6)
const WALK_FPS := 8.0
const IDLE_FRAME := 1
const SWING_TIME := 0.24
const MP_REGEN := 1.0       # 초당
const MP_PER_HIT := 2.0    # 기본 공격이 맞을 때마다

var _sprite: Sprite2D
var _attack_sprite: Sprite2D


func _ready() -> void:
	var sheet := Art.tex("player_walk")
	if sheet:
		use_placeholder_art = false
		_sprite = Art.make_sprite(self, sheet, FOOT, 4, 4)
		_sprite.show_behind_parent = true
	var attack_sheet := Art.tex("player_attack")
	if attack_sheet:
		_attack_sprite = Art.make_sprite(self, attack_sheet, FOOT, 3, 4)
		_attack_sprite.show_behind_parent = true
		_attack_sprite.visible = false
	max_hp = GameState.max_hp()
	hp = max_hp
	max_mp = GameState.max_mp()
	mp = max_mp
	GameState.leveled_up.connect(_on_level_up)
	GameState.changed.connect(_on_state_changed)
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	GameState.player_ref = self


func _physics_process(delta: float) -> void:
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_swing_timer = maxf(0.0, _swing_timer - delta)
	_invuln = maxf(0.0, _invuln - delta)
	mp = minf(float(max_mp), mp + MP_REGEN * delta)

	var dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).normalized()

	if dir != Vector2.ZERO and _dodge_timer <= 0.0:
		facing = dir
		_anim_t += delta

	if _dodge_timer > 0.0:
		_dodge_timer -= delta
		velocity = facing * dodge_speed
	else:
		velocity = dir * move_speed
		if Input.is_action_just_pressed("dodge") and _dodge_cd <= 0.0:
			_dodge_timer = dodge_time
			_dodge_cd = dodge_cooldown

	velocity += _knock
	_knock = _knock.move_toward(Vector2.ZERO, 600.0 * delta)
	move_and_slide()
	_update_sprite(dir != Vector2.ZERO)
	queue_redraw()


func _update_sprite(moving: bool) -> void:
	if _sprite == null:
		return
	var col := (int(_anim_t * WALK_FPS) % 4) if moving else IDLE_FRAME
	_sprite.frame_coords = Vector2i(col, Art.dir_row(facing))
	var blink := _invuln > 0.0 and int(_invuln * 20.0) % 2 == 0
	var swinging := _attack_sprite != null and _swing_timer > 0.0
	_sprite.visible = not blink and not swinging
	_sprite.modulate.a = 0.5 if is_dodging() else 1.0
	if _attack_sprite:
		_attack_sprite.visible = swinging and not blink
		if swinging:
			# 들기 → 휘두르기 → 마무리 3프레임
			var f := clampi(int((SWING_TIME - _swing_timer) / SWING_TIME * 3.0), 0, 2)
			_attack_sprite.frame_coords = Vector2i(f, Art.dir_row(_swing_dir))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		attack()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		if try_interact():
			get_viewport().set_input_as_handled()


## aim_override 를 주면 마우스 대신 그 방향으로 공격 (테스트·패드 대응용)
func attack(aim_override := Vector2.ZERO) -> void:
	if _attack_cd > 0.0:
		return
	_attack_cd = attack_cooldown
	_swing_timer = SWING_TIME
	var aim := aim_override if aim_override != Vector2.ZERO else get_global_mouse_position() - global_position
	_swing_dir = aim.normalized() if aim.length() > 1.0 else facing
	facing = _swing_dir

	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Node2D
		var to := enemy.global_position - global_position
		var reach := attack_range + float(enemy.get("radius"))
		if to.length() <= reach and absf(rad_to_deg(_swing_dir.angle_to(to))) <= attack_arc_deg * 0.5:
			var roll: Array = GameState.roll_damage(1.0, int(enemy.get("defense")))
			enemy.call("take_damage", int(roll[0]), _swing_dir, bool(roll[1]))
			mp = minf(float(max_mp), mp + MP_PER_HIT)


## 레벨이 오르면 최대 HP 가 늘고 전부 회복한다
func _on_level_up(_level: int) -> void:
	max_hp = GameState.max_hp()
	hp = max_hp
	max_mp = GameState.max_mp()
	mp = max_mp
	hp_changed.emit(hp, max_hp)


## 능력치를 올리면 최대 HP·MP 가 바뀐다. 늘어난 만큼 지금 값도 채워 준다.
func _on_state_changed() -> void:
	var new_hp := GameState.max_hp()
	var new_mp := GameState.max_mp()
	if new_hp != max_hp:
		hp = clampi(hp + maxi(0, new_hp - max_hp), 1, new_hp)
		max_hp = new_hp
		hp_changed.emit(hp, max_hp)
	if new_mp != max_mp:
		mp = clampf(mp + maxf(0.0, new_mp - max_mp), 0.0, new_mp)
		max_mp = new_mp


func try_interact() -> bool:
	var best: Node2D = null
	var best_d := interact_range
	for n in get_tree().get_nodes_in_group("interactable"):
		var node := n as Node2D
		var d := node.global_position.distance_to(global_position)
		if d <= best_d:
			best = node
			best_d = d
	if best:
		best.call("interact")
		return true
	return false


func is_dodging() -> bool:
	return _dodge_timer > 0.0


func take_damage(amount: int, from_dir: Vector2) -> void:
	if _invuln > 0.0 or is_dodging():
		return
	hp -= maxi(1, amount - GameState.defense())
	_invuln = invuln_time
	_knock = from_dir.normalized() * 160.0
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		_die()


func _die() -> void:
	GameState.notify("쓰러졌다... 마을 입구에서 다시 시작!")
	hp = max_hp
	mp = max_mp
	_knock = Vector2.ZERO
	global_position = spawn_point
	_invuln = 1.5
	hp_changed.emit(hp, max_hp)


func _draw() -> void:
	# 그림자 (스프라이트 뒤)
	if _sprite:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2(0, (FOOT.y - 1.0) / 0.4), 9, Color(0, 0, 0, 0.18))
		draw_set_transform(Vector2.ZERO)
	if _attack_sprite == null:
		_draw_swing()
	if not use_placeholder_art:
		return
	# 무적 시간 깜빡임
	if _invuln > 0.0 and int(_invuln * 20.0) % 2 == 0:
		return
	var bob := sin(_anim_t * 14.0) * 0.8
	var a := 0.5 if is_dodging() else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2(0, 16), 6, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO)
	# 몸 (남색 핫피)
	draw_rect(Rect2(-4, -1 + bob, 8, 8), Color(0.25, 0.3, 0.55, a))
	draw_rect(Rect2(-4, -1 + bob, 8, 8), Color(0.15, 0.15, 0.2, a), false, 1.0)
	# 머리
	draw_circle(Vector2(0, -6 + bob), 6, Color(1.0, 0.88, 0.78, a))
	draw_arc(Vector2(0, -6 + bob), 6, PI, TAU, 12, Color(0.2, 0.15, 0.15, a), 3.0)
	# 눈 (바라보는 방향)
	var eye := Vector2(facing.x * 2.0, 0)
	if facing.y >= -0.3:
		draw_rect(Rect2(Vector2(-3, -6 + bob) + eye, Vector2(1, 2)), Color(0.1, 0.1, 0.15, a))
		draw_rect(Rect2(Vector2(2, -6 + bob) + eye, Vector2(1, 2)), Color(0.1, 0.1, 0.15, a))


func _draw_swing() -> void:
	# 공격 궤적
	if _swing_timer > 0.0:
		var ang := _swing_dir.angle()
		var half := deg_to_rad(attack_arc_deg * 0.5)
		draw_arc(Vector2(0, -12), attack_range * 0.8, ang - half, ang + half, 12, Color(1, 1, 1, 0.9), 3.0)
		draw_arc(Vector2(0, -12), attack_range * 0.8, ang - half, ang + half, 12, Color(0.2, 0.2, 0.25, 0.8), 1.0)
