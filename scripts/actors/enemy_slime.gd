extends CharacterBody2D
## 몬스터 공통 스크립트. kind 로 종류를 고른다 (표: scripts/data/game_data.gd 의 MONSTERS).
## 기본 움직임은 낙서 슬라임과 같다.
## 평소에는 제자리 근처를 어슬렁거린다. 플레이어가 aggro_range 안으로 들어오면 쫓아오고,
## attack_range 까지 붙으면 움츠렸다가(예고) 몸통 박치기를 한다. 박치기 중에만 피해를 준다.
## 박치기 뒤에는 잠깐 쉬고, 플레이어가 멀어지거나 자기 자리에서 너무 벗어나면 포기한다.

signal died(home: Vector2)

const PickupScript := preload("res://scripts/actors/pickup.gd")
const Fx := preload("res://scripts/actors/fx_frames.gd")
const Data := preload("res://scripts/data/game_data.gd")
const Items := preload("res://scripts/data/items.gd")
const FallenScript := preload("res://scripts/actors/fallen.gd")
const EQUIP_DROP_RATE := 0.02   # 몬스터가 장비를 떨어뜨릴 확률 (세부설정 6)
const MID_BOSS_DROP_RATE := 0.3 # 중간 보스. 대장과 필드 보스는 반드시 준다

## 종류. add_child 하기 전에 정한다.
var kind := "slime"
var exp_reward := 3
var defense := 0
var grid_move := false
var _drops: Array = []
var _strip := false
var _single := false         # 그림 한 장짜리 (보스)
var tier := 0                # 난이도 단계 (사냥터가 정해 준다)
var hp_mult := 1.0           # 끝없는 탑의 층 배율 (HP·경험치)
var dmg_mult := 1.0          # 끝없는 탑의 층 배율 (공격)
var boss := ""               # "mid", "boss", "field" (보스가 아니면 빈 글)
var display_name := ""
var _slam_every := 0.0       # 바닥 내리치기 간격 (0 은 안 함)
var _slam_t := 4.0
var _slam_warn := 0.0        # 내리치기 예고가 남은 시간
var _slam_pos := Vector2.ZERO
var _summon := ""
var _summoned := false
var _roar_t := 4.0
const ROAR_RANGE := 220.0
const SLAM_RADIUS := 46.0
const SLAM_WARN := 1.0

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


const Art := preload("res://scripts/core/art.gd")
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
	display_name = str(cfg["name"])
	boss = str(cfg.get("boss", ""))
	_slam_every = float(cfg.get("slam", 0.0))
	_summon = str(cfg.get("summon", ""))
	# 난이도 단계: HP·공격·경험치가 몇 배가 된다
	var d: Dictionary = Data.DIFFICULTY[clampi(tier, 0, Data.DIFFICULTY.size() - 1)]
	max_hp = roundi(max_hp * float(d["hp"]))
	damage = roundi(damage * float(d["dmg"]))
	exp_reward = roundi(exp_reward * float(d["exp"]))
	defense = roundi(defense * float(d["dmg"]))
	# 끝없는 탑: 층이 오를수록 더 세다 (tower.gd 가 정해 준다)
	max_hp = roundi(max_hp * hp_mult)
	damage = roundi(damage * dmg_mult)
	exp_reward = roundi(exp_reward * hp_mult)
	if boss != "":
		add_to_group("boss")
		leash_range = 400.0
		lose_range = 400.0
		# 보스 곁에서는 낮은 울림이 들린다 (가까울수록 크게). 필드 보스는 더 멀리서도 들린다.
		Sound.attach_boss_loop(self, 340.0 if boss == "field" else 260.0)
		_roar_t = randf_range(2.0, 4.0)
	if str(cfg["art"]) == "single":
		var one := Art.tex(str(cfg["sprite"]))
		if one:
			_single = true
			use_placeholder_art = false
			_sprite = Art.make_sprite(self, one, FOOT)
			_sprite.scale = Vector2.ONE * (radius * 3.4 / one.get_width())
			_sprite.show_behind_parent = true
	elif str(cfg["art"]) == "strip":
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
				Sound.play("mon_boss" if boss != "" else "mon_" + Data.species_of(kind))
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

	_boss_moves(delta, p, has_player)
	if _sprite and _single:
		if absf(move.x) > 1.0:
			_sprite.flip_h = move.x < 0.0
		var wob := Vector2(sin(_t * 70.0) * 1.5, 0) if state == State.WINDUP else Vector2.ZERO
		_sprite.position = FOOT + wob + Vector2(0, -hop * 3.0)
		_sprite.modulate = Color(1.6, 1.6, 1.6) if _flash > 0.0 else Color.WHITE
	elif _sprite and _strip:
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


## 보스의 추가 움직임: 바닥 내리치기(빨간 동그라미가 1초 보인 뒤 그 자리에 피해), 체력이 절반일 때 부하 부르기
func _boss_moves(delta: float, p: Node2D, has_player: bool) -> void:
	if boss == "" or not has_player:
		return
	# 가까이 있으면 가끔 으르렁댄다
	_roar_t -= delta
	if _roar_t <= 0.0:
		_roar_t = randf_range(5.0, 8.0)
		if p.global_position.distance_to(global_position) < ROAR_RANGE:
			Sound.play("boss_roar")
	if _slam_every > 0.0:
		if _slam_warn > 0.0:
			_slam_warn -= delta
			if _slam_warn <= 0.0 and p.global_position.distance_to(_slam_pos) <= SLAM_RADIUS:
				p.call("take_damage", roundi(damage * 1.5), (p.global_position - _slam_pos).normalized())
		else:
			_slam_t -= delta
			if _slam_t <= 0.0 and p.global_position.distance_to(global_position) < 170.0:
				_slam_t = _slam_every
				_slam_warn = SLAM_WARN
				Sound.play("slam")
				_slam_pos = p.global_position
	if _summon != "" and not _summoned and hp <= max_hp / 2:
		_summoned = true
		for side in [-1, 1]:
			var m: Node2D = load("res://scenes/enemy.tscn").instantiate()
			m.set("kind", _summon)
			m.set("tier", tier)
			m.position = position + Vector2(40 * side, 10)
			get_parent().add_child(m)
		GameState.notify("%s 이(가) 부하를 불렀어요!" % display_name)


func take_damage(amount: int, dir: Vector2, crit: bool = false) -> void:
	hp -= amount
	Sound.play("hit")
	_pop_number(amount, crit)
	_flash = 0.25
	_knock = dir.normalized() * (190.0 if boss == "" else 40.0)
	if kind == "dummy" or bool(Data.MONSTERS.get(kind, {}).get("dummy", false)):
		hp = max_hp          # 허수아비는 맞기만 한다
		_knock = Vector2.ZERO
		return
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
		if randf() < float(_drops[i + 1]) * GameState.drop_mult():
			var mat: Node2D = PickupScript.new()
			mat.set("mat_id", int(_drops[i]))
			mat.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(-6, 6))
			get_parent().add_child(mat)
	GameState.add_exp(exp_reward)
	GameState.on_kill(kind)
	GameState.add_coins(maxi(1, exp_reward / 2) + randi() % 2)
	# 장비: 많이 지워진 모습은 조금 더 잘 준다
	# 중간 보스는 30%, 필드 보스는 반드시 1개, 대장은 반드시 2개. 등급은 난이도 단계를 따른다.
	var tiers: Array = Data.DIFFICULTY[clampi(tier, 0, Data.DIFFICULTY.size() - 1)]["tier"]
	var gear_n := 0
	if boss != "":
		gear_n = 2 if boss == "boss" else (1 if boss == "field" or randf() < MID_BOSS_DROP_RATE * GameState.drop_mult() else 0)
		GameState.add_coins(exp_reward)
		GameState.on_boss_killed(kind)
		# 세트 장비: 그 보스의 세트 한 부위 (중간 보스 20%, 대장·필드 보스 35%)
		var set_item := GameState.roll_set_drop(kind, boss, int(tiers[1]))
		if not set_item.is_empty():
			var piece: Node2D = PickupScript.new()
			piece.set("item", set_item)
			piece.global_position = global_position + Vector2(-12, 12)
			get_parent().add_child(piece)
		# 유일 장비: 대장과 필드 보스가 마지막 단계("빈")에서만 떨어뜨린다
		var unique_id := str(Data.MONSTERS[kind].get("unique", ""))
		if unique_id != "" and tier >= Data.DIFFICULTY.size() - 1 and randf() < Items.UNIQUE_DROP_RATE * GameState.drop_mult():
			var prize: Node2D = PickupScript.new()
			prize.set("item", Items.make_unique(unique_id))
			prize.global_position = global_position + Vector2(0, 12)
			get_parent().add_child(prize)
	elif randf() < EQUIP_DROP_RATE * (1.6 if kind.ends_with("_erased") else 1.0) * GameState.drop_mult():
		gear_n = 1
	for i in gear_n:
		var gear: Node2D = PickupScript.new()
		var it := Items.random_drop(maxi(1, GameState.level), int(tiers[1]))
		it["tier"] = maxi(int(it["tier"]), int(tiers[0]) + (1 if boss == "boss" and int(tiers[0]) < int(tiers[1]) else 0))
		gear.set("item", Items.make(str(it["slot"]), int(it["shape"]), int(it["tier"]), int(it["level"])))
		gear.global_position = global_position + Vector2(randf_range(-14, 14), randf_range(-8, 8))
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
	_draw_slam()
	# 체력 막대 (맞았을 때만). 보스의 막대는 화면 위쪽에 따로 나온다.
	if hp < max_hp and boss == "":
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


## 내리치기 예고: 떨어질 자리에 빨간 동그라미가 차오른다
func _draw_slam() -> void:
	if _slam_warn <= 0.0:
		return
	var c := _slam_pos - global_position
	var k := 1.0 - _slam_warn / SLAM_WARN
	draw_circle(c, SLAM_RADIUS, Color(0.9, 0.25, 0.25, 0.18))
	draw_circle(c, SLAM_RADIUS * k, Color(0.9, 0.25, 0.25, 0.3))
	draw_arc(c, SLAM_RADIUS, 0, TAU, 32, Color(0.9, 0.25, 0.25, 0.9), 2.0)


## 공격 예고: 움츠리는 동안 머리 위에 빨간 느낌표
func _draw_alert() -> void:
	if state != State.WINDUP:
		return
	var red := Color(0.9, 0.25, 0.25)
	draw_rect(Rect2(-1.5, -34, 3, 8), red)
	draw_rect(Rect2(-1.5, -24, 3, 3), red)
