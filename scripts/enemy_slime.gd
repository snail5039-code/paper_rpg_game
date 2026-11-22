extends CharacterBody2D
## 몬스터 공통 스크립트. kind 로 종류를 고른다 (표: scripts/game_data.gd 의 MONSTERS).
## 기본 움직임은 낙서 슬라임과 같다.
## 평소에는 제자리 근처를 어슬렁거린다. 플레이어가 aggro_range 안으로 들어오면 쫓아오고,
## attack_range 까지 붙으면 움츠렸다가(예고) 몸통 박치기를 한다. 박치기 중에만 피해를 준다.
## 박치기 뒤에는 잠깐 쉬고, 플레이어가 멀어지거나 자기 자리에서 너무 벗어나면 포기한다.

signal died(home: Vector2)

const PickupScript := preload("res://scripts/pickup.gd")
const Fx := preload("res://scripts/fx_frames.gd")
const Data := preload("res://scripts/game_data.gd")
const Items := preload("res://scripts/items.gd")
const FallenScript := preload("res://scripts/fallen.gd")
const EQUIP_DROP_RATE := 0.05   # 장비가 떨어질 확률 ("흐릿한" 단계)

## 종류. add_child 하기 전에 정한다.
var kind := "slime"
var exp_reward := 3
var defense := 0
var grid_move := false
var _drops: Array = []
var _strip := false

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
	var cfg: Dictionary = Data.MONSTERS.get(kind, Data.MONSTERS["slime"])
	max_hp = int(cfg["hp"])
	speed = float(cfg["speed"])
	damage = int(cfg["damage"])
	radius = float(cfg["radius"])
	exp_reward = int(cfg["exp"])
	defense = int(cfg.get("def", 0))
	_drops = cfg["drops"]
	grid_move = bool(cfg.get("grid", false))
	aggro_range = float(cfg.get("aggro", aggro_range))
	windup_time = float(cfg.get("windup", windup_time))
	lunge_time = float(cfg.get("lunge_time", lunge_time))
	lunge_speed = float(cfg.get("lunge_speed", lunge_speed))
	if str(cfg["art"]) == "strip":
		var sheet := Art.tex("mon_" + str(cfg["sprite"]))
		if sheet:
			_strip = true
			use_placeholder_art = false
			_sprite = Art.make_sprite(self, sheet, FOOT, 6, 1)
			_sprite.show_behind_parent = true
	else:
		for f in ["idle", "squash", "jump", "hurt"]:
			var t := Art.tex(str(cfg["sprite"]) + "_" + f)
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
			# 하루에게 이야기를 듣기 전(튜토리얼 첫 단계)에는 먼저 덤비지 않는다
			var hostile := GameState.quest >= GameState.Quest.FIND_LEAD
			if hostile and dist < aggro_range and from_home < leash_range:
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

	if grid_move and state != State.LUNGE and move != Vector2.ZERO:
		# 모눈 선을 따라: 더 먼 축으로만 움직인다
		var spd := move.length()
		move = Vector2(signf(move.x) * spd, 0) if absf(move.x) > absf(move.y) else Vector2(0, signf(move.y) * spd)
	velocity = move + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 500.0 * delta)
	move_and_slide()

	if _sprite and _strip:
		# 6칸 시트: 기본, 움직임1, 움직임2, 예고, 공격, 맞음
		var col := 0
		if _flash > 0.0:
			col = 5
		elif state == State.WINDUP:
			col = 3
		elif state == State.LUNGE:
			col = 4
		elif move.length() > 1.0:
			col = 1 + int(_t * 6.0) % 2
		_sprite.frame = col
		if absf(move.x) > 1.0 or state == State.WINDUP:
			var dx := _lunge_dir.x if state == State.WINDUP else move.x
			_sprite.flip_h = dx < 0.0   # 원본은 오른쪽을 본다
		var shake2 := Vector2(sin(_t * 70.0) * 1.2, 0) if state == State.WINDUP else Vector2.ZERO
		_sprite.position = FOOT + shake2
	elif _sprite:
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


func take_damage(amount: int, dir: Vector2, crit: bool = false) -> void:
	hp -= amount
	_pop_number(amount, crit)
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
	# 재료: 흔한 것과 드문 것을 따로 굴린다
	for i in range(0, _drops.size(), 2):
		if randf() < float(_drops[i + 1]):
			var mat: Node2D = PickupScript.new()
			mat.set("mat_id", int(_drops[i]))
			mat.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(-6, 6))
			get_parent().add_child(mat)
	GameState.add_exp(exp_reward)
	GameState.on_kill(kind)
	GameState.add_coins(maxi(1, exp_reward / 2) + randi() % 2)
	# 장비: 많이 지워진 모습은 조금 더 잘 준다
	if randf() < EQUIP_DROP_RATE * (1.6 if kind.ends_with("_erased") else 1.0):
		var gear: Node2D = PickupScript.new()
		gear.set("item", Items.random_drop(maxi(1, GameState.level), 1))
		gear.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(-6, 6))
		get_parent().add_child(gear)
	# 도화지가 있으면 다시 그려 줄 수 있게 흐린 자국을 남긴다
	if not GameState.has_paper() and GameState.level >= 2:
		GameState.tip("capture", "도화지가 있으면 쓰러진 몬스터를 다시 그려 친구로 만들 수 있어요. (문방구에서 팔아요)")
	if GameState.has_paper() and Data.FRIENDS.has(Data.species_of(kind)):
		GameState.tip("capture_how", "흐린 자국에 다가가 F: 도화지에 다시 그려 주면 친구가 돼요.")
		var fallen: Node2D = FallenScript.new()
		fallen.set("kind", kind)
		fallen.global_position = global_position
		get_parent().add_child(fallen)
	var vanish := Art.tex("slime_vanish")
	if vanish:
		Fx.spawn(get_parent(), vanish, global_position + FOOT, 4, 11.0)
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
	# 체력 막대 (맞았을 때만)
	if hp < max_hp:
		var w := 22.0
		draw_rect(Rect2(-w * 0.5 - 1, -27, w + 2, 5), Color(0.2, 0.18, 0.2))
		draw_rect(Rect2(-w * 0.5, -26, w * clampf(float(hp) / float(max_hp), 0.0, 1.0), 3), Color(0.9, 0.3, 0.35))


## 머리 위로 떠오르는 피해 숫자
func _pop_number(amount: int, crit: bool) -> void:
	var l := Label.new()
	l.text = str(amount) + ("!" if crit else "")
	l.add_theme_font_size_override("font_size", 13 if crit else 10)
	l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if crit else Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0.2, 0.15, 0.15))
	l.add_theme_constant_override("outline_size", 4)
	l.z_index = 50
	l.position = global_position + Vector2(randf_range(-8, 4), -34)
	get_parent().add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 14.0, 0.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.2)
	tw.chain().tween_callback(l.queue_free)


## 공격 예고: 움츠리는 동안 머리 위에 빨간 느낌표
func _draw_alert() -> void:
	if state != State.WINDUP:
		return
	var red := Color(0.9, 0.25, 0.25)
	draw_rect(Rect2(-1.5, -34, 3, 8), red)
	draw_rect(Rect2(-1.5, -24, 3, 3), red)
