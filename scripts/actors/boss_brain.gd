extends Node
## 보스의 머리 (enemy_slime.gd 가 보스에게 붙인다). 표: scripts/data/boss_data.gd
##   등장 장면 — 처음 주인공을 알아챘을 때(쫓기 시작하거나 맞았을 때). 그 보스를 처음 보면 길게(화면이 비추고 보스마다 다르게 나타나 포효,
##               이름표), 두 번째부터는 이름표와 포효만 짧게. GameState.bosses_met 에 남는다.
##   전용 기술 두 개 — 쫓는 동안 몇 초마다 번갈아 쓴다. 기술 동안 보스는 State.SKILL 이고, 움직임·모습은 여기서 정한다.
##   2페이즈 — 체력이 절반 아래가 되면 포효하며 화가 난다: 빨라지고, 기술을 더 자주 쓰고 더 세게(탄이 많아지고 두 번씩), 가끔 이어서 쓴다.
## 기술은 _sk_<이름>(p) 함수로, 기술이 시작된 뒤 지난 시간(_st)을 보고 _at(초) 로 그 순간에 한 번 일을 한다. 끝나면 true.

const BossData := preload("res://scripts/data/boss_data.gd")
const Hazard := preload("res://scripts/actors/boss_hazard.gd")
const Shot := preload("res://scripts/actors/boss_shot.gd")
const MonFx := preload("res://scripts/actors/mon_fx.gd")
const Art := preload("res://scripts/core/art.gd")

const S_WANDER := 0
const S_CHASE := 1
const S_REST := 4
const S_SKILL := 5

var boss: CharacterBody2D
var cfg: Dictionary = {}
var phase := 1
var skill := ""
var intro_done := false
var _st := 0.0
var _pt := -1.0
var _cd := 3.0
var _last := ""
var _chained := false
var _v: Dictionary = {}
var _mound: Sprite2D
var _in_intro := false
var _age := 0.0
var _cam_base := Vector2.ZERO


## 등장 장면 도중에 보스가 사라지면(맵을 떠나거나 쓰러짐) 멈춘 화면을 풀어 준다
func _exit_tree() -> void:
	if _in_intro:
		_in_intro = false
		GameState.set_cutscene(false)
		var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
		if cam:
			cam.offset = _cam_base
	if is_instance_valid(_mound):
		_mound.queue_free()


func _ready() -> void:
	boss = get_parent()
	cfg = BossData.of(str(boss.get("kind")))
	_cd = randf_range(2.0, 3.0)


func _physics_process(delta: float) -> void:
	if cfg.is_empty():
		return
	var p := GameState.player_ref
	if not is_instance_valid(p):
		return
	_age += delta
	if not intro_done:
		# 맵에 들어오자마자 이야기(보스가 말을 거는 장면)가 먼저 나오도록 잠깐 기다리고, 말이 끝난 뒤에 등장한다
		if _age < 1.0 or GameState.dialogue_open or GameState.cutscene:
			return
		if int(boss.get("state")) != S_WANDER or int(boss.get("hp")) < int(boss.get("max_hp")):
			intro_done = true
			_intro()
		return
	if phase == 1 and int(boss.get("hp")) <= int(boss.get("max_hp")) / 2 and int(boss.get("hp")) > 0:
		phase = 2
		_begin("enrage")
	if skill != "":
		_pt = _st
		_st += delta
		if bool(call("_sk_" + skill, p)):
			_finish()
		return
	_cd -= delta
	var dist := p.global_position.distance_to(boss.global_position)
	if _cd <= 0.0 and int(boss.get("state")) == S_CHASE and float(boss.get("_slam_warn")) <= 0.0 and dist < 230.0:
		var list: Array = cfg["skills"]
		var pick: String = list[0] if _last == list[1] else (list[1] if _last == list[0] else list[randi() % 2])
		_begin(pick)


## 지금 쓰는 기술 이름 (테스트·화면용)
func current() -> String:
	return skill


## 기술 하나를 바로 시작한다 (테스트·캡처에서도 쓴다)
func use(name: String) -> void:
	intro_done = true
	_begin(name)


func _begin(name: String) -> void:
	_end_look()
	skill = name
	_st = -0.001     # 첫 프레임에 _at(0.0) 이 한 번 일어나도록 0 보다 조금 앞에서 시작
	_pt = -0.002
	_v = {}
	boss.call("_set_state", S_SKILL)
	boss.set("skill_pose", 3)
	_face(GameState.player_ref)


func _finish() -> void:
	var was := skill
	skill = ""
	_end_look()
	if was != "enrage":
		_last = was
	boss.call("_set_state", S_REST)
	boss.set("_state_t", float(boss.get("rest_time")) - 0.3)
	_cd = randf_range(2.4, 3.4) if phase == 2 else randf_range(4.0, 5.5)
	# 2페이즈: 가끔 다른 기술을 곧바로 이어서 쓴다
	if phase == 2 and was != "enrage" and not _chained and randf() < 0.45:
		_chained = true
		var list: Array = cfg["skills"]
		_begin(list[1] if was == list[0] else list[0])
	else:
		_chained = false


## 기술이 바꿔 놓은 보스 모습·움직임을 되돌린다
func _end_look() -> void:
	boss.set("skill_pose", -1)
	boss.set("skill_move", Vector2.ZERO)
	boss.set("skill_lift", 0.0)
	boss.set("skill_spin", false)
	_hide(false)
	if is_instance_valid(_mound):
		_mound.queue_free()
	_mound = null


func _hide(on: bool) -> void:
	boss.set("skill_hide", on)
	boss.set("immune", on)
	boss.collision_layer = 0 if on else 4
	boss.collision_mask = 0 if on else 1


func _at(t: float) -> bool:
	return _pt < t and _st >= t


func _pose(col: int) -> void:
	boss.set("skill_pose", col)


func _face(p: Node2D) -> void:
	if is_instance_valid(p):
		boss.set("skill_face", p.global_position.x - boss.global_position.x)


func _par() -> Node:
	return boss.get_parent()


func _dmg(mult: float) -> int:
	return maxi(1, roundi(int(boss.get("damage")) * mult))


func _r() -> float:
	return float(boss.get("radius"))


func _hz(at: Vector2, props: Dictionary) -> Node2D:
	var h: Node2D = Hazard.new()
	for k in props:
		h.set(k, props[k])
	h.position = at
	_par().add_child(h)
	return h


func _aim(p: Node2D) -> Vector2:
	var d := p.global_position - boss.global_position
	return d.normalized() if d.length() > 1.0 else Vector2.RIGHT


func _mouth() -> Vector2:
	return boss.global_position + Vector2(0, -_r() * 0.8)


# ---------- 2페이즈 ----------

func _sk_enrage(p: Node2D) -> bool:
	if _at(0.0):
		_pose(3)
		boss.set("enraged", true)
		boss.set("speed", float(boss.get("speed")) * 1.3)
		MonFx.pop(_par(), "fx_boss_roar", _mouth(), _r() * 4.5, 0.7, 0.0, 1.3, false, 0)
		Sound.play("boss_roar", 0.85, 3.0)
		shake(4.0, 0.5)
		GameState.notify("%s이(가) 화가 났어요! 더 빠르고 거칠어져요." % str(boss.get("display_name")))
	if _at(0.35):
		MonFx.pop(_par(), "fx_boss_roar", _mouth(), _r() * 5.5, 0.6, 0.3, 1.3, false, 0)
	return _st >= 0.9


# ---------- 큰 가위표 ----------

## 주인공 자리에 X 자로 빨간 띠 두 줄 → 크레용으로 쫙 긋는다. 2페이즈는 한 번 더.
func _sk_x_slash(p: Node2D) -> bool:
	for k in ([0.0, 0.7] if phase == 2 else [0.0]):
		if _at(k):
			_pose(3)
			_face(p)
			var c := p.global_position
			for d in [Vector2(1, -1).normalized(), Vector2(1, 1).normalized()]:
				_hz(c - d * 85.0, {"shape": "line", "to": c + d * 85.0, "width": 22.0, "warn": 0.8, "damage": _dmg(1.3), "sound": "slam"})
		if _at(k + 0.8):
			_pose(4)
			shake(2.0, 0.2)
	return _st >= (1.9 if phase == 2 else 1.2)


## 체크표 탄을 부채꼴로 던진다. 2페이즈는 탄이 늘고 두 번.
func _sk_check_fan(p: Node2D) -> bool:
	for k in ([0.45, 0.95] if phase == 2 else [0.45]):
		if _at(k - 0.45):
			_pose(3)
			_face(p)
		if _at(k):
			_pose(4)
			var n := 5 if phase == 2 else 3
			var aim := _aim(p)
			for i in n:
				var a := aim.rotated((i - (n - 1) * 0.5) * 0.3)
				Shot.fire(_par(), "fx_boss_check", _mouth(), a * 150.0, 15.0, _dmg(0.9), 2.2, 9.0)
			Sound.play("swing", 1.3)
	return _st >= (1.3 if phase == 2 else 0.85)


# ---------- 왕 지우개똥 벌레 ----------

## 주인공 쪽으로 세 번(2페이즈 네 번) 이어서 데굴데굴 구른다. 구를 때마다 겨눈다.
func _sk_roll_combo(p: Node2D) -> bool:
	const CYCLE := 0.8
	var n := 4 if phase == 2 else 3
	var i := int(_st / CYCLE)
	if i >= n:
		return true
	var t := _st - i * CYCLE
	if _at(i * CYCLE):
		_v["dir"] = _aim(p)
		_v["hit"] = false
		_face(p)
		boss.set("skill_move", Vector2.ZERO)
		boss.set("skill_spin", false)
		_pose(3)
	if t >= 0.32:
		_pose(4)
		var dir: Vector2 = _v["dir"]
		boss.set("skill_move", dir * (290.0 if phase == 2 else 250.0))
		boss.set("skill_spin", true)
		if _at(i * CYCLE + 0.32):
			Sound.play("dash", 0.8)
			MonFx.ground(_par(), "fx_mon_dust", boss.global_position + Vector2(0, 7), _r() * 2.4, 0.4)
		if int(_st * 12.0) != int(_pt * 12.0):
			MonFx.ground(_par(), "fx_boss_crumb", boss.global_position + Vector2(randf_range(-8, 8), 8), 12.0, 0.6, 1.0)
		if not bool(_v["hit"]) and p.global_position.distance_to(boss.global_position) < _r() + 12.0:
			_v["hit"] = true
			p.call("take_damage", _dmg(1.1), dir)
			MonFx.pop(_par(), "fx_mon_impact", p.global_position + Vector2(0, -12), 16.0, 0.2)
	return false


## 웅크렸다가 지우개 가루 탄을 사방으로 터뜨린다. 2페이즈는 두 겹.
func _sk_crumb_ring(p: Node2D) -> bool:
	if _at(0.0):
		_pose(3)
	boss.set("skill_lift", 10.0 * sin(clampf(_st / 0.5, 0.0, 1.0) * PI) if _st < 0.5 else 0.0)
	for k in ([0.5, 1.0] if phase == 2 else [0.5]):
		if _at(k):
			_pose(4)
			var n := 14 if phase == 2 else 10
			var off := randf() * TAU
			for i in n:
				var a := Vector2.from_angle(off + TAU * i / n)
				Shot.fire(_par(), "fx_boss_crumb", boss.global_position + a * _r() * 0.6, a * 105.0, 13.0, _dmg(0.8), 2.6, 6.0)
			MonFx.ground(_par(), "fx_mon_shock", boss.global_position + Vector2(0, 7), _r() * 3.0, 0.4, 1.3)
			Sound.play("slam", 1.2)
	return _st >= (1.4 if phase == 2 else 0.95)


# ---------- 구깃이 ----------

## 종이 공을 주인공 쪽으로 포물선으로 던진다 (떨어질 자리에 과녁). 2페이즈는 다섯 개.
func _sk_paper_lob(p: Node2D) -> bool:
	var n := 5 if phase == 2 else 3
	for i in n:
		var k := 0.3 + i * 0.28
		if _at(k):
			_pose(4)
			_face(p)
			var spot := p.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(18.0, 40.0))
			_hz(spot, {"radius": 20.0, "warn": 0.85, "damage": _dmg(1.0), "drop_tex": "fx_boss_paper", "drop_w": 22.0,
				"from": _mouth(), "sound": "hit"})
			Sound.play("swing", 0.9)
		if _at(k + 0.14):
			_pose(3)
	return _st >= 0.3 + n * 0.28 + 0.35


## 주먹으로 바닥을 쾅쾅쾅: 주인공 쪽으로 이어지는 과녁이 차례로 터진다. 2페이즈는 더 길게.
func _sk_slam_line(p: Node2D) -> bool:
	var n := 7 if phase == 2 else 5
	if _at(0.0):
		_v["dir"] = _aim(p)
		_face(p)
	if _at(0.45):
		var dir: Vector2 = _v["dir"]
		for i in n:
			_hz(boss.global_position + dir * (34.0 + i * 36.0) + Vector2(0, 6), {"radius": 24.0, "warn": 0.4 + i * 0.15, "damage": _dmg(1.2)})
	if _st >= 0.85:
		_pose(4 if int(_st / 0.15) % 2 == 0 else 3)
		if int(_st / 0.15) != int(_pt / 0.15):
			shake(1.5, 0.1)
	return _st >= 0.85 + n * 0.15 + 0.2


# ---------- 떠돌이 큰 낙서 ----------

## 엉킨 선 탄이 빙글빙글 소용돌이로 퍼진다. 2페이즈는 세 갈래.
func _sk_spiral(p: Node2D) -> bool:
	if _at(0.0):
		_v["a"] = randf() * TAU
	if _st >= 0.4 and _st < 2.2:
		_pose(4)
		if int(_st / 0.11) != int(_pt / 0.11):
			var arms := 3 if phase == 2 else 2
			_v["a"] = float(_v["a"]) + 0.38
			for i in arms:
				var a := Vector2.from_angle(float(_v["a"]) + TAU * i / arms)
				Shot.fire(_par(), "fx_boss_scrib", boss.global_position + a * _r() * 0.5, a * 92.0, 13.0, _dmg(0.7), 3.0, 7.0)
			if int(_st / 0.33) != int(_pt / 0.33):
				Sound.play("swing", 0.7, -8.0)
	return _st >= 2.4


## 낙서 구름으로 사라졌다가 주인공 곁에서 튀어나온다. 2페이즈는 두 번.
func _sk_blink(p: Node2D) -> bool:
	const CYCLE := 1.3
	var n := 2 if phase == 2 else 1
	var i := int(_st / CYCLE)
	if i >= n:
		return true
	var b := i * CYCLE
	if _at(b):
		_pose(3)
		_face(p)
	if _at(b + 0.3):
		MonFx.pop(_par(), "fx_boss_cloud", boss.global_position + Vector2(0, -_r() * 0.6), _r() * 3.4, 0.5, 0.0, 1.2)
		Sound.play("swing", 0.6)
		_hide(true)
		var spot := p.global_position + Vector2.from_angle(randf() * TAU) * randf_range(30.0, 55.0)
		_v["spot"] = spot
		_hz(spot, {"radius": 34.0, "warn": 0.7, "damage": _dmg(1.3), "burst_tex": "fx_boss_cloud", "burst_w": _r() * 3.6, "burst_up": _r() * 0.6})
	if _at(b + 1.0):
		boss.global_position = _v["spot"]
		_hide(false)
		_pose(4)
		_face(p)
		boss.set("_smash_t", 0.3)
	return false


# ---------- 큰나무 할아범 ----------

## 주인공 쪽으로 땅에서 뿌리 가시가 줄지어 솟는다. 2페이즈는 세 줄.
func _sk_root_line(p: Node2D) -> bool:
	if _at(0.0):
		_v["dir"] = _aim(p)
		_face(p)
	if _at(0.5):
		_pose(4)
		shake(2.0, 0.25)
		var base: Vector2 = _v["dir"]
		var lines := [base.rotated(-0.42), base, base.rotated(0.42)] if phase == 2 else [base]
		for d in lines:
			for i in 8:
				_hz(boss.global_position + (d as Vector2) * (32.0 + i * 27.0) + Vector2(0, 6), {"radius": 15.0, "warn": 0.35 + i * 0.08,
					"damage": _dmg(1.1), "burst_tex": "fx_boss_root", "burst_w": 30.0, "burst_up": 12.0, "sound": "slam" if i % 3 == 0 else ""})
	return _st >= 1.6


## 나무를 흔들어 도토리를 비처럼 떨어뜨린다 (떨어질 자리에 과녁). 2페이즈는 더 많이.
func _sk_acorn_rain(p: Node2D) -> bool:
	var n := 11 if phase == 2 else 7
	boss.set("skill_lift", 0.0)
	if _st < 0.2 + n * 0.16:
		_pose(3 if int(_st * 10.0) % 2 == 0 else 4)
	for i in n:
		if _at(0.2 + i * 0.16):
			var spot := p.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(15.0, 90.0))
			_hz(spot, {"radius": 17.0, "warn": 0.75, "damage": _dmg(0.9), "drop_tex": "fx_boss_acorn", "drop_w": 16.0, "sound": "hit"})
	return _st >= 0.2 + n * 0.16 + 0.9


# ---------- 색 빠진 왕버섯 ----------

## 회색 포자 구름을 던진다. 떨어진 자리에 한동안 남아 그 안에 있으면 조금씩 아프다. 2페이즈는 다섯 개.
func _sk_spore_clouds(p: Node2D) -> bool:
	if _at(0.5):
		_pose(4)
		_face(p)
		var n := 5 if phase == 2 else 3
		for i in n:
			var spot := p.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(TAU * i / (n - 1) + randf() * 0.5) * randf_range(45.0, 75.0))
			_hz(spot, {"radius": 26.0, "warn": 0.7, "damage": _dmg(0.8), "drop_tex": "fx_boss_spore", "drop_w": 20.0, "from": _mouth(),
				"linger": 3.5, "tick": 0.6, "linger_tex": "fx_boss_spore", "linger_w": 70.0, "burst_tex": "fx_boss_spore", "burst_w": 60.0, "sound": ""})
		Sound.play("swing", 0.7)
	return _st >= 1.0


## 높이 뛰어올라 주인공 머리 위로 떨어진다 (떨어질 자리에 큰 과녁). 2페이즈는 두 번.
func _sk_jump_slam(p: Node2D) -> bool:
	const CYCLE := 1.45
	var n := 2 if phase == 2 else 1
	var i := int(_st / CYCLE)
	if i >= n:
		return true
	var b := i * CYCLE
	var t := _st - b
	if _at(b):
		_pose(3)
		_face(p)
	if _at(b + 0.35):
		_pose(4)
		_v["spot"] = p.global_position
		_hz(p.global_position, {"radius": 46.0, "warn": 0.85, "damage": _dmg(1.4)})
		_hide(false)
		boss.set("immune", true)
		boss.collision_layer = 0
		boss.collision_mask = 0
		Sound.play("dash", 0.7)
	if t >= 0.35 and t < 1.2:
		var k := (t - 0.35) / 0.85
		boss.set("skill_lift", 150.0 * sin(k * PI))
		if k >= 0.5 and not _v.has("moved%d" % i):
			_v["moved%d" % i] = true
			boss.global_position = _v["spot"]
	if _at(b + 1.2):
		boss.set("skill_lift", 0.0)
		boss.set("immune", false)
		boss.collision_layer = 4
		boss.collision_mask = 1
		boss.set("_smash_t", 0.3)
		shake(4.0, 0.3)
	return false


# ---------- 색 먹는 애벌레 ----------

## 땅속으로 파고들어 흙 둔덕이 주인공을 쫓아오다, 멈춘 자리에서 튀어나온다.
func _sk_burrow(p: Node2D) -> bool:
	if _at(0.3):
		MonFx.ground(_par(), "fx_mon_dust", boss.global_position + Vector2(0, 6), _r() * 3.0, 0.5)
		_hide(true)
		_mound = Sprite2D.new()
		_mound.texture = Art.tex("fx_boss_mound")
		_mound.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if _mound.texture:
			_mound.scale = Vector2.ONE * (_r() * 2.2 / _mound.texture.get_width())
		_mound.position = boss.global_position + Vector2(0, 6)
		_mound.z_index = -1
		_par().add_child(_mound)
		_v["stop"] = 99.0
		Sound.play("dash", 0.6)
	var stop: float = _v.get("stop", 99.0)
	if _st > 0.3 and _st < stop and is_instance_valid(_mound):
		var to := p.global_position + Vector2(0, 6) - _mound.position
		var spd := 150.0 if phase == 2 else 115.0
		if to.length() < 8.0 or _st >= 1.9:
			_v["stop"] = _st
			_hz(_mound.position, {"radius": 36.0, "warn": 0.45, "damage": _dmg(1.4), "burst_tex": "fx_boss_crack", "burst_w": _r() * 4.0})
		else:
			_mound.position += to.normalized() * minf(to.length(), spd * get_physics_process_delta_time())
			boss.global_position = _mound.position - Vector2(0, 6)
			_mound.rotation = sin(_st * 30.0) * 0.08
			if int(_st * 8.0) != int(_pt * 8.0):
				MonFx.ground(_par(), "fx_mon_dust", _mound.position, 22.0, 0.35)
	stop = _v.get("stop", 99.0)
	if _at(stop + 0.45):
		if is_instance_valid(_mound):
			_mound.queue_free()
		_hide(false)
		_pose(4)
		shake(3.0, 0.25)
	if _st > stop + 0.45:
		boss.set("skill_lift", 36.0 * sin(clampf((_st - stop - 0.45) / 0.45, 0.0, 1.0) * PI))
	return _st >= stop + 0.95


## 물감 침을 부채꼴로 뱉는다. 날아간 자리에 잠깐 물감 웅덩이가 남는다. 2페이즈는 많이, 두 번.
func _sk_paint_spit(p: Node2D) -> bool:
	for k in ([0.4, 0.9] if phase == 2 else [0.4]):
		if _at(k - 0.4):
			_pose(3)
			_face(p)
		if _at(k):
			_pose(4)
			var n := 7 if phase == 2 else 5
			var aim := _aim(p)
			for i in n:
				var a := aim.rotated((i - (n - 1) * 0.5) * 0.22)
				var s := Shot.fire(_par(), "fx_boss_paint", _mouth(), a * 140.0, 17.0, _dmg(0.9), 0.95)
				s.set("puddle", {"radius": 18.0, "warn": 0.05, "damage": _dmg(0.5), "linger": 3.0, "tick": 0.6,
					"linger_tex": "fx_boss_puddle", "linger_w": 44.0, "burst_tex": "fx_mon_dust", "burst_w": 20.0, "sound": ""})
			Sound.play("swing", 1.1)
	return _st >= (1.4 if phase == 2 else 0.95)


# ---------- 화면 흔들기 ----------

func shake(amount: float, dur: float) -> void:
	var cam := boss.get_viewport().get_camera_2d() if boss.is_inside_tree() else null
	if cam == null or GameState.get("screen_shake") == false:
		return
	var base := cam.offset
	var tw := cam.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_method(func(k: float): cam.offset = base + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amount * (1.0 - k), 0.0, 1.0, dur)
	tw.tween_callback(func(): cam.offset = base)


# ---------- 등장 장면 ----------

func _intro() -> void:
	var kind := str(boss.get("kind"))
	var long := not GameState.bosses_met.has(kind)
	GameState.bosses_met[kind] = true
	if not long or GameState.cutscene or GameState.dialogue_open:
		MonFx.pop(_par(), "fx_boss_roar", _mouth(), _r() * 4.5, 0.6, 0.0, 1.3, false, 0)
		Sound.play("boss_roar")
		banner(false)
		return
	var sp: Sprite2D = boss.get("_sprite")
	var cam := boss.get_viewport().get_camera_2d()
	if sp == null:
		banner(false)
		return
	GameState.set_cutscene(true)
	_in_intro = true
	sp.visible = false
	var base_off := cam.offset if cam else Vector2.ZERO
	_cam_base = base_off
	if cam:
		var half := cam.get_viewport_rect().size / cam.zoom / 2.0
		var bp := boss.global_position + Vector2(0, -_r())
		var want := Vector2(clampf(bp.x, cam.limit_left + half.x, cam.limit_right - half.x),
			clampf(bp.y, cam.limit_top + half.y, cam.limit_bottom - half.y))
		var tw := cam.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(cam, "offset", base_off + want - cam.get_screen_center_position(), 0.6).set_trans(Tween.TRANS_SINE)
		await tw.finished
	await _appear(str(cfg["intro"]), sp)
	# 포효
	if boss.get("_anim"):
		sp.frame = 3
	MonFx.pop(_par(), "fx_boss_roar", _mouth(), _r() * 5.0, 0.7, 0.0, 1.35, false, 0)
	Sound.play("boss_roar", 0.9, 3.0)
	shake(4.0, 0.6)
	await get_tree().create_timer(0.7).timeout
	if boss.get("_anim"):
		sp.frame = 0
	banner(true)
	await get_tree().create_timer(1.7).timeout
	if cam:
		var tw2 := cam.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw2.tween_property(cam, "offset", base_off, 0.5).set_trans(Tween.TRANS_SINE)
		await tw2.finished
	_in_intro = false
	GameState.set_cutscene(false)


func _tw() -> Tween:
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)


func _fx_sprite(tex_name: String, at: Vector2, w: float, z := 30) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Art.tex(tex_name)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if s.texture:
		s.scale = Vector2.ONE * w / s.texture.get_width()
	s.global_position = at
	s.z_index = z
	_par().add_child(s)
	return s


## 보스마다 다르게 나타난다
func _appear(how: String, sp: Sprite2D) -> void:
	var bs: Vector2 = boss.get("_base_scale")
	var foot := Vector2(0, 7)   # enemy_slime.gd 의 FOOT
	var at := boss.global_position
	var r := _r()
	var mid := at + Vector2(0, -r * 0.8)
	match how:
		"x":   # 공책에 빨간 X 가 쫙쫙 그어지고, 그 자리에서 가위표가 튀어나온다
			var slashes: Array = []
			for i in 2:
				var s := _fx_sprite("fx_boss_slash", mid, r * 3.6)
				s.flip_h = i == 1
				var full := s.scale
				s.scale = full * 0.1
				s.modulate.a = 0.0
				slashes.append(s)
				var tw := _tw()
				tw.tween_property(s, "modulate:a", 1.0, 0.05)
				tw.parallel().tween_property(s, "scale", full, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				Sound.play("swing", 1.1 + i * 0.2)
				await tw.finished
			sp.visible = true
			sp.scale = bs * 0.1
			var tw2 := _tw()
			tw2.tween_property(sp, "scale", bs, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			for s in slashes:
				tw2.parallel().tween_property(s, "modulate:a", 0.0, 0.4)
			await tw2.finished
			for s in slashes:
				s.queue_free()
		"roll":   # 옆에서 데굴데굴 굴러 들어온다
			sp.visible = true
			sp.position = foot + Vector2(-110, 0)
			sp.rotation = -TAU * 2.0
			var tw := _tw()
			tw.tween_property(sp, "position", foot, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(sp, "rotation", 0.0, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			for k in 4:
				tw.parallel().tween_callback(func(): MonFx.ground(_par(), "fx_mon_dust", boss.global_position + sp.position + Vector2(0, 2), r * 2.0, 0.4)).set_delay(k * 0.18)
			tw.tween_property(sp, "scale", bs * Vector2(1.2, 0.8), 0.1)
			tw.tween_property(sp, "scale", bs, 0.2).set_trans(Tween.TRANS_BACK)
			await tw.finished
		"paper":   # 구겨진 종이 공이 들썩이다 확 펴지며 구깃이가 된다
			var ball := _fx_sprite("fx_boss_paper", mid + Vector2(0, r * 0.3), r * 1.6)
			var tw := _tw()
			for k in 3:
				tw.tween_property(ball, "rotation", 0.3 if k % 2 == 0 else -0.3, 0.12)
				tw.tween_property(ball, "position:y", ball.position.y - 8.0, 0.08)
				tw.tween_property(ball, "position:y", ball.position.y, 0.08)
			await tw.finished
			sp.visible = true
			sp.scale = bs * 0.3
			var tw2 := _tw()
			tw2.tween_property(ball, "scale", ball.scale * 1.8, 0.2)
			tw2.parallel().tween_property(ball, "modulate:a", 0.0, 0.2)
			tw2.parallel().tween_property(sp, "scale", bs, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			Sound.play("hit", 0.7)
			await tw2.finished
			ball.queue_free()
		"scribble":   # 연필 낙서가 소용돌이치며 뭉쳐 큰 낙서가 된다
			var cloud := _fx_sprite("fx_boss_cloud", mid, r * 1.2)
			var full := cloud.scale * 3.4
			var tw := _tw()
			tw.tween_property(cloud, "scale", full, 0.8).set_trans(Tween.TRANS_QUAD)
			tw.parallel().tween_property(cloud, "rotation", TAU * 1.5, 0.8)
			await tw.finished
			sp.visible = true
			sp.modulate.a = 0.0
			sp.rotation = -0.8
			var tw2 := _tw()
			tw2.tween_property(sp, "modulate:a", 1.0, 0.35)
			tw2.parallel().tween_property(sp, "rotation", 0.0, 0.45).set_trans(Tween.TRANS_BACK)
			tw2.parallel().tween_property(cloud, "modulate:a", 0.0, 0.45)
			await tw2.finished
			cloud.queue_free()
		"rise":   # 땅이 쩍 갈라지고 큰나무가 쑥 솟아오른다
			var crack := _fx_sprite("fx_boss_crack", at + Vector2(0, 6), r * 3.6, -1)
			shake(3.0, 0.9)
			sp.visible = true
			sp.position = foot + Vector2(0, r * 1.2)
			sp.scale = Vector2(bs.x * 0.8, bs.y * 0.1)
			var tw := _tw()
			tw.tween_property(sp, "position", foot, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(sp, "scale", bs, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			for k in 3:
				tw.parallel().tween_callback(func(): MonFx.ground(_par(), "fx_mon_dust", at + Vector2(randf_range(-r, r), 6), r * 1.8, 0.5)).set_delay(k * 0.25)
			tw.tween_property(crack, "modulate:a", 0.0, 0.4)
			await tw.finished
			crack.queue_free()
		"sprout":   # 회색 포자가 퍼지는 가운데 쑥쑥 자란다
			for k in 3:
				MonFx.pop(_par(), "fx_boss_spore", at + Vector2(randf_range(-r, r), randf_range(-r * 1.4, 0)), r * 2.4, 0.9, 0.0, 1.4)
			sp.visible = true
			sp.scale = bs * 0.05
			var tw := _tw()
			tw.tween_property(sp, "scale", bs, 1.0).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			await tw.finished
		"erupt":   # 흙 둔덕이 들썩이다 땅을 뚫고 튀어나온다
			var mound := _fx_sprite("fx_boss_mound", at + Vector2(0, 6), r * 2.4, -1)
			var tw := _tw()
			for k in 4:
				tw.tween_property(mound, "rotation", 0.12 if k % 2 == 0 else -0.12, 0.09)
			await tw.finished
			mound.queue_free()
			MonFx.ground(_par(), "fx_boss_crack", at + Vector2(0, 6), r * 3.6, 0.8, 1.1)
			sp.visible = true
			sp.position = foot + Vector2(0, 20)
			var tw2 := _tw()
			tw2.tween_property(sp, "position", foot + Vector2(0, -50), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw2.tween_property(sp, "position", foot, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw2.tween_callback(func(): MonFx.ground(_par(), "fx_mon_dust", at + Vector2(0, 6), r * 2.6, 0.45))
			Sound.play("dash", 0.6)
			await tw2.finished
		_:
			sp.visible = true
	sp.visible = true
	sp.scale = bs
	sp.position = foot
	sp.rotation = 0.0
	sp.modulate = Color.WHITE


## 이름표: 찢어진 공책 띠가 화면 위쪽에 미끄러져 들어와 등급·이름·별명을 보이고 사라진다.
func banner(long: bool) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 26
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	boss.get_tree().root.add_child(layer)
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size = Vector2(300, 74)
	var vw := boss.get_viewport().get_visible_rect().size
	box.position = Vector2((vw.x - box.size.x) * 0.5, vw.y * 0.66)   # 보스(화면 가운데) 아래
	layer.add_child(box)
	var tex := Art.tex("ui_boss_banner")
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.size = box.size
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tr)
	var lines := [
		[str(BossData.RANK.get(str(boss.get("boss")), "보스")), 9, Color(0.75, 0.2, 0.2), 10.0],
		[str(boss.get("display_name")), 17, Color(0.22, 0.16, 0.14), 23.0],
		["— %s —" % str(cfg.get("title", "")), 9, Color(0.4, 0.32, 0.28), 46.0],
	]
	for ln in lines:
		var l := Label.new()
		l.text = ln[0]
		l.add_theme_font_size_override("font_size", int(ln[1]))
		l.add_theme_color_override("font_color", ln[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(box.size.x, 20)
		l.position = Vector2(0, float(ln[3]))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
	var x := box.position.x
	box.position.x = -box.size.x
	box.modulate.a = 0.0
	var tw := layer.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(box, "position:x", x, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(box, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.3 if long else 0.9)
	tw.tween_property(box, "position:x", vw.x, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(box, "modulate:a", 0.0, 0.3)
	tw.tween_callback(layer.queue_free)
