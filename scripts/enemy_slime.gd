extends CharacterBody2D
## 몬스터 1종: 낙서 슬라임.
## 평소에는 제자리 근처를 어슬렁거린다. 플레이어가 aggro_range 안으로 들어오면 쫓아오고,
## attack_range 까지 붙으면 움츠렸다가(예고) 몸통 박치기를 한다. 박치기 중에만 피해를 준다.
## 박치기 뒤에는 잠깐 쉬고, 플레이어가 멀어지거나 자기 자리에서 너무 벗어나면 포기한다.

signal died(home: Vector2)

const PickupScript := preload("res://scripts/pickup.gd")

@export var use_placeholder_art := true
@export var max_hp := 3
@export var speed := 40.0
@export var aggro_range := 62.0      ## 이 안으로 들어오면 쫓아오기 시작
@export var lose_range := 100.0      ## 이만큼 멀어지면 포기
@export var leash_range := 150.0     ## 자기 자리에서 이만큼 벗어나면 포기하고 돌아감
@export var attack_range := 30.0     ## 이 거리에서 박치기 준비
@export var windup_time := 0.5       ## 움츠리는 시간 (공격 예고)
@export var lunge_time := 0.22
@export var lunge_speed := 190.0
@export var rest_time := 1.1         ## 박치기 후 쉬는 시간
@export var contact_range := 15.0
@export var damage := 1

enum State { WANDER, CHASE, WINDUP, LUNGE, REST }

var state: int = State.WANDER
var _state_t := 0.0
var _lunge_dir := Vector2.ZERO
var _lunge_hit := false

var radius := 10.0
var hp: int
var home := Vector2.ZERO

var _knock := Vector2.ZERO
var _flash := 0.0
var _t := 0.0
var _wander := Vector2.ZERO
var _wander_timer := 0.0


const Art := preload("res://scripts/art.gd")
const FOOT := Vector2(0, 7)

var _sprite: Sprite2D
var _frames := {}


func _ready() -> void:
	for f in ["idle", "squash", "jump", "hurt"]:
		var t := Art.tex("slime_" + f)
		if t:
			_frames[f] = t
	if _frames.size() == 4:
		use_placeholder_art = false
		_sprite = Art.make_sprite(self, _frames["idle"], FOOT)
		_sprite.show_behind_parent = true
	hp = max_hp
	home = global_position
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	_t = randf() * 10.0


func _set_state(next: int) -> void:
	state = next
	_state_t = 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	_state_t += delta
	_flash = maxf(0.0, _flash - delta)

	var p := GameState.player_ref
	var has_player := is_instance_valid(p)
	var to := (p.global_position - global_position) if has_player else Vector2.ZERO
	var dist := to.length() if has_player else INF
	var from_home := global_position.distance_to(home)

	var move := Vector2.ZERO   # 이번 프레임 이동 속도
	var hop := maxf(0.0, sin(_t * 8.0))

	match state:
		State.WANDER:
			if dist < aggro_range and from_home < leash_range:
				_set_state(State.CHASE)
			else:
				_wander_timer -= delta
				if _wander_timer <= 0.0:
					_wander_timer = randf_range(1.0, 2.5)
					var back := home - global_position
					_wander = back.normalized() if back.length() > 40.0 						else Vector2.from_angle(randf() * TAU) * randf_range(0.0, 0.6)
				move = _wander * speed * (0.4 + hop)
		State.CHASE:
			if dist > lose_range or from_home > leash_range:
				_set_state(State.WANDER)
				_wander_timer = 0.0
			elif dist <= attack_range:
				_lunge_dir = to.normalized()
				_set_state(State.WINDUP)
			else:
				move = to.normalized() * speed * (0.4 + hop)
		State.WINDUP:
			hop = 0.0
			if _state_t >= windup_time:
				_lunge_hit = false
				_set_state(State.LUNGE)
		State.LUNGE:
			hop = 1.0
			move = _lunge_dir * lunge_speed
			if not _lunge_hit and dist < contact_range:
				_lunge_hit = true
				p.call("take_damage", damage, _lunge_dir)
			if _state_t >= lunge_time:
				_set_state(State.REST)
		State.REST:
			hop = 0.0
			if _state_t >= rest_time:
				_set_state(State.CHASE)

	velocity = move + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 500.0 * delta)
	move_and_slide()

	if _sprite:
		var frame := "idle"
		if _flash > 0.0:
			frame = "hurt"
		elif state == State.WINDUP or state == State.REST:
			frame = "squash"
		elif state == State.LUNGE or hop > 0.55:
			frame = "jump"
		elif hop <= 0.0:
			frame = "squash"
		Art.set_texture(_sprite, _frames[frame])
		var shake := Vector2.ZERO
		if state == State.WINDUP:
			shake = Vector2(sin(_t * 70.0) * 1.2, 0)  # 부르르 떨며 예고
		_sprite.position = FOOT + shake + Vector2(0, -hop * 5.0)
	queue_redraw()


func take_damage(amount: int, dir: Vector2) -> void:
	hp -= amount
	_flash = 0.25
	_knock = dir.normalized() * 190.0
	# 맞으면 준비 동작이 끊기고 잠깐 움찔한 뒤 쫓아온다
	if state != State.LUNGE:
		_set_state(State.REST)
		_state_t = rest_time - 0.35
	if hp <= 0:
		_die()


func _die() -> void:
	var drop: Node2D = PickupScript.new()
	drop.global_position = global_position
	get_parent().add_child(drop)
	died.emit(home)
	queue_free()


func _draw() -> void:
	if _sprite:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2(0, (FOOT.y - 1.0) / 0.4), 10, Color(0, 0, 0, 0.18))
		draw_set_transform(Vector2.ZERO)
		_draw_hp()
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
	_draw_hp()


func _draw_hp() -> void:
	# 체력 표시 (맞았을 때만)
	if hp < max_hp:
		for i in max_hp:
			var c := Color(0.9, 0.3, 0.35) if i < hp else Color(0.4, 0.4, 0.45)
			draw_rect(Rect2(-max_hp * 2.5 + i * 5.0, -24, 4, 3), c)


## 공격 예고: 움츠리는 동안 머리 위에 빨간 느낌표
func _draw_alert() -> void:
	if state != State.WINDUP:
		return
	var red := Color(0.9, 0.25, 0.25)
	draw_rect(Rect2(-1.5, -34, 3, 8), red)
	draw_rect(Rect2(-1.5, -24, 3, 3), red)
