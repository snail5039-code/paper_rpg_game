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
var combo := 0                  # 기본 공격 연타 (0, 1, 2 → 세 번째가 강하다)
var _combo_timer := 0.0
var skill_cd: Dictionary = {}   # 스킬 id → 남은 재사용 시간
var _dash_timer := 0.0
var _dash_dir := Vector2.ZERO
var _fx: Dictionary = {}        # 방금 쓴 스킬의 효과 그림
var _fx_tex: Dictionary = {}    # 효과 그림 (계속 쥐고 있어야 한다)
var _hat: Sprite2D              # 쓴 모자 (머리 모양에 맞춰 그린 앞·옆·뒤 그림)
var _aura: Sprite2D             # 강화 오라 (발밑)
var aura_plus := 0              # 오라를 정한 강화 단계 (입은 장비 중 가장 높은 것)
var _aura_t := 0.0
const AURA_W := 48.0            # 오라 고리의 가로 (월드)
var _hat_tex: Array = [null, null, null]   # 지금 모자의 앞, 옆(왼쪽을 봄), 뒤 그림
var _hat_shape := -1
var _tool: Sprite2D             # 손에 든 도구 (프레임마다 주먹 자리에 놓는다)
var _tool_tex: Texture2D
var _look := ""
var _pad_t := 0.0               # "두꺼운 솜" 효과: 1초마다 HP 1
var use_fail := ""              # 방금 소모품을 못 쓴 까닭 ("" 은 없음)
## 생활 동작 (낚시, 농사, 채집): 공격 그림의 자세로 생활 도구를 든다. 그동안은 움직이거나 공격하지 못한다.
##   {"kind": 도구 그림 이름, "tex": 그림, "t": 흐른 시간, "dur": 휘두르는 시간, "hold": 휘두른 뒤 자세를 유지, "dir": 방향, "done": 끝나면 부를 것}
var _act: Dictionary = {}
var _tool_tip := Vector2.ZERO   # 지금 든 도구의 끝 (캐릭터 기준)
var _levelup_t := 0.0           # 레벨 업 효과가 남은 시간
const LEVELUP_TIME := 1.4

const Anchors := preload("res://scripts/data/player_anchors.gd")
## 모자마다 [크기 배율, 머리 꼭대기에서 모자 아랫단까지 내려오는 길이(텍셀)]
const HAT_FIT := [[0.72, 24.0], [0.72, 24.0], [0.72, 27.0], [0.72, 29.0], [0.72, 27.0],
	[0.72, 23.0], [0.74, 28.0], [0.72, 22.0], [0.72, 29.0], [0.72, 26.0]]
const TOOL_K := 0.5             # 도구 그림은 주인공 그림보다 두 배 촘촘하다
const TOOL_TUCK := 6.0          # 도구의 쥐는 쪽을 주먹 안으로 이만큼 밀어 넣는다 (주인공 텍셀)
var ult := 0.0                  # 필살기 게이지 (0 ~ 100)


const Art := preload("res://scripts/core/art.gd")
const Items := preload("res://scripts/data/items.gd")
const FOOT := Vector2(0, 6)
const WALK_FPS := 8.0
const IDLE_FRAME := 1
const SWING_TIME := 0.24
const MP_REGEN := 1.0       # 초당
const MP_PER_HIT := 2.0    # 기본 공격이 맞을 때마다
const COMBO_WINDOW := 0.7  # 이 안에 다시 치면 연타가 이어진다
const COMBO_FINISH_MULT := 1.5
const FX_TIME := 0.3
const ULT_MAX := 100.0
const ULT_PER_HIT := 5.0   # 적을 맞힐 때마다
const ULT_PER_HURT := 8.0  # 맞을 때마다
const ULT_RANGE := 300.0   # 필살기가 닿는 거리 (화면 전체쯤)

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
	# 장비 겉모습: 옷은 옷마다 따로 그린 캐릭터 그림(맨손)으로 바꾸고,
	#  도구는 프레임마다 주먹 자리에, 모자는 머리 위에 놓는다
	_tool = Sprite2D.new()
	_tool.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_tool.show_behind_parent = true
	_tool.region_enabled = true
	_tool.visible = false
	add_child(_tool)
	_hat = Sprite2D.new()
	_hat.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_hat.visible = false
	add_child(_hat)
	# 강화 오라: 입은 장비의 강화 단계가 +4 이상이면 발밑에서 빛이 피어오른다
	var aura_tex := Art.tex("fx_aura")
	if aura_tex:
		_aura = Sprite2D.new()
		_aura.texture = aura_tex
		_aura.hframes = 4
		_aura.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_aura.scale = Vector2.ONE * (AURA_W / (aura_tex.get_width() / 4.0))
		_aura.offset = Vector2(0, -aura_tex.get_height() * 0.5)
		_aura.position = FOOT + Vector2(0, 3)
		_aura.show_behind_parent = true
		_aura.visible = false
		add_child(_aura)
		move_child(_aura, 0)
	_refresh_look()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for n in ["slash", "circle", "dot", "hatch", "press", "erase", "hit", "star"]:
		_fx_tex[n] = Art.tex("fx_" + n)
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
	mp = minf(float(max_mp), mp + MP_REGEN * (2.0 if GameState.has_buff("mpregen") else 1.0) * delta)
	if GameState.has_fx("pad") and hp > 0 and hp < max_hp:
		_pad_t += delta
		if _pad_t >= 1.0:
			_pad_t -= 1.0
			hp += 1
			hp_changed.emit(hp, max_hp)
	_levelup_t = maxf(0.0, _levelup_t - delta)
	_combo_timer = maxf(0.0, _combo_timer - delta)
	if _combo_timer <= 0.0:
		combo = 0
	for id in skill_cd:
		skill_cd[id] = maxf(0.0, float(skill_cd[id]) - delta)
	if not _fx.is_empty():
		_fx["t"] = float(_fx["t"]) - delta
		if float(_fx["t"]) <= 0.0:
			_fx = {}

	if not _act.is_empty():
		# 생활 동작 중: 제자리에서 도구를 휘두른다
		_act["t"] = float(_act["t"]) + delta
		facing = _act["dir"]
		velocity = Vector2.ZERO
		_knock = Vector2.ZERO
		_update_sprite(false)
		queue_redraw()
		if float(_act["t"]) >= float(_act["dur"]) and not bool(_act["hold"]):
			var done: Callable = _act["done"]
			_act = {}
			if done.is_valid():
				done.call()
		return

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
		velocity = dir * move_speed * GameState.move_speed_mult()
		if Input.is_action_just_pressed("dodge") and _dodge_cd <= 0.0:
			_dodge_timer = dodge_time
			GameState.lesson_note("dodge")
			_dodge_cd = dodge_cooldown * (0.8 if GameState.has_fx("light") else 1.0)

	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity = _dash_dir * 330.0
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
	var acting := not _act.is_empty()
	var swinging := _attack_sprite != null and (_swing_timer > 0.0 or acting)
	_sprite.visible = not blink and not swinging
	_sprite.modulate.a = 0.5 if is_dodging() else 1.0
	if _attack_sprite:
		_attack_sprite.visible = swinging and not blink
		if swinging:
			# 들기 → 휘두르기 → 마무리 3프레임
			var f := clampi(int((SWING_TIME - _swing_timer) / SWING_TIME * 3.0), 0, 2)
			var row_dir := _swing_dir
			if acting:
				# 들기 → 뻗기. 자세를 유지할 때는 팔을 뻗은 채(가운데 프레임)로 있는다.
				var k := float(_act["t"]) / maxf(0.01, float(_act["dur"]))
				f = (1 if k >= 0.5 else 0) if bool(_act["hold"]) else clampi(int(k * 3.0), 0, 2)
				row_dir = _act["dir"]
			_attack_sprite.frame_coords = Vector2i(f, Art.dir_row(row_dir))
	_place_look(moving)


## 생활 동작을 시작한다. kind: 도구 그림 이름 ("life_rod", "life_rake", "life_sickle", "life_can").
##  hold 가 참이면 휘두른 뒤 stop_act() 를 부를 때까지 자세를 유지한다 (낚시). done 은 다 휘두르면 부른다.
func act(kind: String, dir: Vector2, dur: float = 0.45, hold: bool = false, done: Callable = Callable()) -> void:
	_act = {"kind": kind, "tex": Art.tex(kind), "t": 0.0, "dur": dur, "hold": hold,
		"dir": dir.normalized() if dir.length() > 0.01 else facing, "done": done}
	facing = _act["dir"]
	_swing_timer = 0.0


func stop_act() -> void:
	_act = {}


func is_acting() -> bool:
	return not _act.is_empty()


## 지금 든 도구의 끝 (월드). 낚싯줄이 여기서 나간다.
func act_tip() -> Vector2:
	return global_position + _tool_tip


func _unhandled_input(event: InputEvent) -> void:
	if is_acting():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		attack()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		if try_interact():
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode
		var used := false
		if code == KEY_Q:
			used = use_skill_slot(0)
		elif code == KEY_E:
			used = use_skill_slot(1)
		elif code == KEY_T:
			used = GameState.swap_life()      # 무기 ↔ 생활 도구
		elif code == KEY_R:
			used = use_skill_slot(2)
		elif code == KEY_1:
			used = use_consumable(str(GameState.quick_slots[0]))
		elif code == KEY_2:
			used = use_consumable(str(GameState.quick_slots[1]))
		elif code == KEY_V:
			used = use_ultimate()
		if used:
			get_viewport().set_input_as_handled()


## aim_override 를 주면 마우스 대신 그 방향으로 공격 (테스트·패드 대응용)
func attack(aim_override := Vector2.ZERO) -> void:
	if _attack_cd > 0.0:
		return
	_attack_cd = attack_cooldown / GameState.attack_speed_mult()
	var finisher := combo == 2
	combo = (combo + 1) % 3
	_combo_timer = COMBO_WINDOW
	_swing_timer = SWING_TIME
	Sound.play("swing")
	var aim := aim_override if aim_override != Vector2.ZERO else get_global_mouse_position() - global_position
	_swing_dir = aim.normalized() if aim.length() > 1.0 else facing
	facing = _swing_dir

	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Node2D
		var to := enemy.global_position - global_position
		var reach := attack_range + float(enemy.get("radius"))
		if to.length() <= reach and absf(rad_to_deg(_swing_dir.angle_to(to))) <= attack_arc_deg * 0.5:
			_hit(enemy, COMBO_FINISH_MULT if finisher else 1.0, _swing_dir)
			mp = minf(float(max_mp), mp + MP_PER_HIT)


## 레벨이 오르면 최대 HP 가 늘고 전부 회복한다
func _on_level_up(_level: int) -> void:
	_levelup_t = LEVELUP_TIME
	max_hp = GameState.max_hp()
	hp = max_hp
	max_mp = GameState.max_mp()
	mp = max_mp
	hp_changed.emit(hp, max_hp)


## 능력치를 올리면 최대 HP·MP 가 바뀐다. 늘어난 만큼 지금 값도 채워 준다.
## 입은 장비가 바뀌면 겉모습을 맞춘다
func _refresh_look() -> void:
	var eq: Dictionary = GameState.equipped
	aura_plus = Items.best_plus(eq)
	if _aura:
		_aura.visible = aura_plus >= Items.AURA_MIN
		_aura.modulate = Items.aura_color(aura_plus)
	var key := ""
	for sl in ["hat", "tool", "cloth"]:
		key += str(eq[sl].get("shape", 0)) + str(eq[sl].get("unique", "")) + str(eq[sl].get("set", "")) + "," if eq.has(sl) else "-,"
	if key == _look:
		return
	_look = key
	_hat_shape = int(eq["hat"]["shape"]) if eq.has("hat") else -1
	# 세트 장비는 자기 그림이 있으면 그것을 쓴다 (없으면 모양 번호의 그림)
	var hat_set := Items.set_of(eq["hat"]) if eq.has("hat") else ""
	for v in 3:
		_hat_tex[v] = Art.tex("hat_%d_%d" % [_hat_shape, v]) if _hat_shape >= 0 else null
		if hat_set != "" and Art.tex("hat_set_%s_%d" % [hat_set, v]):
			_hat_tex[v] = Art.tex("hat_set_%s_%d" % [hat_set, v])
	# 옷: 옷마다 걷기·공격 그림이 따로 있다 (없으면 기본 후드티)
	var cloth := int(eq["cloth"]["shape"]) if eq.has("cloth") else 0
	var cloth_set := Items.set_of(eq["cloth"]) if eq.has("cloth") else ""
	var walk := Art.tex("player_walk_set_%s" % cloth_set) if cloth_set != "" else null
	var swing := Art.tex("player_attack_set_%s" % cloth_set) if cloth_set != "" else null
	if walk == null or swing == null:
		walk = Art.tex("player_walk_c%d" % cloth)
		swing = Art.tex("player_attack_c%d" % cloth)
	if walk and _sprite:
		_sprite.texture = walk
	if swing and _attack_sprite:
		_attack_sprite.texture = swing
	# 도구: 안 들었으면 처음부터 들고 있던 연필
	_tool_tex = Art.tex("tool_%d" % (int(eq["tool"]["shape"]) if eq.has("tool") else 0))
	if eq.has("tool") and Items.set_of(eq["tool"]) != "" and Art.tex("tool_set_%s" % Items.set_of(eq["tool"])):
		_tool_tex = Art.tex("tool_set_%s" % Items.set_of(eq["tool"]))
	# 유일 도구는 자기 그림이 있다
	if eq.has("tool") and Items.is_unique(eq["tool"]):
		var own := Art.tex(str(Items.UNIQUES[str(eq["tool"]["unique"])].get("held", "")))
		if own:
			_tool_tex = own
	# 생활 도구를 들었으면 그 도구 (등급 색을 입힌다)
	if eq.has("tool") and Items.is_life(eq["tool"]):
		_tool_tex = Art.tex(str(Items.LIFE_TOOLS[str(eq["tool"]["life"])]["held"]))
		if _tool:
			_tool.modulate = Items.LIFE_COLORS[int(eq["tool"]["grade"])]
	elif _tool:
		_tool.modulate = Color.WHITE


## 지금 보이는 프레임에 맞춰 도구를 주먹에, 모자를 머리 위에 놓는다 (걷기·공격 그림의 프레임마다 자리가 다르다)
func _place_look(_moving: bool) -> void:
	_animate_aura()
	if _sprite == null:
		_hat.visible = false
		_tool.visible = false
		return
	var swinging := _attack_sprite != null and _attack_sprite.visible
	var shown: Sprite2D = _attack_sprite if swinging else _sprite
	var fc: Vector2i = shown.frame_coords
	var cols := 3 if swinging else 4
	var frame: Vector2 = Anchors.ATTACK_FRAME if swinging else Anchors.WALK_FRAME
	_place_tool(shown, (Anchors.ATTACK_TOOL if swinging else Anchors.WALK_TOOL)[fc.y * cols + fc.x], frame, swinging)
	if _hat_shape < 0:
		_hat.visible = false
		return
	var head: Array = (Anchors.ATTACK if swinging else Anchors.WALK)[fc.y * cols + fc.x]
	var view := 0 if fc.y == 0 else (2 if fc.y == 3 else 1)
	var tex: Texture2D = _hat_tex[view]
	_hat.visible = tex != null and (shown.visible or _sprite.visible)
	if tex == null:
		return
	var fit: Array = HAT_FIT[_hat_shape % HAT_FIT.size()]
	var k := float(fit[0])
	_hat.texture = tex
	_hat.scale = Art.SCALE * k
	_hat.flip_h = fc.y == 2          # 옆 그림은 왼쪽을 본다. 오른쪽을 볼 때는 뒤집는다.
	# 프레임 왼쪽 위 기준 텍셀 → 캐릭터 기준 월드 좌표 (발이 FOOT 에 온다)
	var bottom := Vector2(float(head[0]) - frame.x * 0.5, float(head[1]) + float(fit[1]) - frame.y)
	_hat.position = FOOT + (bottom - Vector2(0, tex.get_height() * k * 0.5)) * Art.SCALE.x
	_hat.modulate.a = shown.modulate.a


## 도구를 주먹에 쥐여 준다. spot = [쥔 쪽 끝 x, y, 촉으로 가는 방향 x, y, 원래 연필이 보이던 길이, 몸 앞이면 1]
##  도구 그림은 촉이 위를 본다. 쥐는 쪽을 주먹 안으로 밀어 넣고, 몸 뒤에 그려서 주먹이 도구를 덮게 한다.
##  걸을 때는 원래 연필이 보이던 만큼만 (촉 쪽을) 보여 준다. 긴 도구가 땅에 끌리지 않게.
func _place_tool(shown: Sprite2D, spot: Array, frame: Vector2, swinging: bool) -> void:
	var tex: Texture2D = _tool_tex
	var kind := ""
	if not _act.is_empty():
		kind = str(_act["kind"])
		tex = _act["tex"]
	_tool.visible = tex != null and shown.visible
	if not _tool.visible:
		return
	var front := int(spot[5]) == 1
	var dir := Vector2(float(spot[2]), float(spot[3]))
	if kind == "life_can":
		# 물뿌리개는 기울이지 않고 주먹 앞에 든다 (그림의 주둥이는 왼쪽을 본다)
		var hand := Vector2(float(spot[0]) - frame.x * 0.5, float(spot[1]) - frame.y) + dir * 8.0
		_tool.texture = tex
		_tool.region_rect = Rect2(Vector2.ZERO, tex.get_size())
		_tool.scale = Art.SCALE * TOOL_K
		_tool.rotation = 0.0
		_tool.flip_h = (_act["dir"] as Vector2).x > 0.0
		_tool.position = FOOT + hand * Art.SCALE.x
		_tool_tip = _tool.position
		_tool.show_behind_parent = false
		if _tool.get_index() != get_child_count() - 1:
			move_child(_tool, get_child_count() - 1)
		return
	_tool.flip_h = false
	var full := tex.get_height() * TOOL_K
	var tuck := 0.0 if front else minf(TOOL_TUCK, full * 0.25)   # 몽당연필처럼 짧은 도구는 덜 밀어 넣는다
	var length := full if swinging else minf(full, float(spot[4]) + tuck)
	var base := Vector2(float(spot[0]) - frame.x * 0.5, float(spot[1]) - frame.y) - dir * tuck
	_tool.texture = tex
	_tool.region_rect = Rect2(0, 0, tex.get_width(), length / TOOL_K)
	_tool.scale = Art.SCALE * TOOL_K
	_tool.rotation = dir.angle() + PI * 0.5
	_tool.position = FOOT + (base + dir * length * 0.5) * Art.SCALE.x
	_tool_tip = FOOT + (base + dir * length) * Art.SCALE.x
	_tool.modulate.a = shown.modulate.a
	# 몸 뒤(맨 앞 자식) 또는 몸 앞(걷기·공격 그림 다음)
	var want := get_child_count() - 1 if front else 0
	if _tool.get_index() != want:
		move_child(_tool, want)
	_tool.show_behind_parent = not front


## 오라는 0→1→2→3→2→1 로 오르내리며 숨 쉬듯 깜빡인다. +7 부터는 든 도구도 그 빛으로 은은히 물든다.
func _animate_aura() -> void:
	if _aura == null or not _aura.visible:
		if _tool:
			_tool.self_modulate = Color.WHITE
		return
	_aura_t += get_physics_process_delta_time()
	var seq := [0, 1, 2, 3, 2, 1]
	_aura.frame = int(seq[int(_aura_t * 8.0) % seq.size()])
	var c := Items.aura_color(aura_plus)
	_aura.modulate.a = c.a * (0.75 + 0.25 * sin(_aura_t * 4.0))
	if _tool:
		_tool.self_modulate = Color.WHITE.lerp(Color(c.r, c.g, c.b), 0.3 + 0.2 * sin(_aura_t * 5.0)) if aura_plus >= 7 else Color.WHITE


func _on_state_changed() -> void:
	_refresh_look()
	var new_hp := GameState.max_hp()
	var new_mp := GameState.max_mp()
	if new_hp != max_hp:
		hp = clampi(hp + maxi(0, new_hp - max_hp), 1, new_hp)
		max_hp = new_hp
		hp_changed.emit(hp, max_hp)
	if new_mp != max_mp:
		mp = clampf(mp + maxf(0.0, new_mp - max_mp), 0.0, new_mp)
		max_mp = new_mp


# ---------- 스킬 (Q, E, R) ----------

## slot 번째 칸의 스킬을 쓴다. 못 쓰면 false.
func use_skill_slot(slot: int, aim_override := Vector2.ZERO) -> bool:
	var id := str(GameState.skill_slots[slot]) if slot < GameState.skill_slots.size() else ""
	return use_skill(id, aim_override) if id != "" else false


func use_skill(id: String, aim_override := Vector2.ZERO) -> bool:
	var rank := GameState.skill_rank(id)
	if rank <= 0 or not Items.SKILLS.has(id):
		return false
	var info: Dictionary = Items.SKILLS[id]
	if float(skill_cd.get(id, 0.0)) > 0.0:
		return false
	if not GameState.trial:
		if mp < float(info["mp"]):
			GameState.notify("MP 가 부족해요.")
			return false
		mp -= float(info["mp"])
	skill_cd[id] = float(info["cd"]) * (0.3 if GameState.trial else 1.0)   # 체험 중에는 MP 없이, 금방 다시
	GameState.lesson_skill(id)
	var aim := aim_override if aim_override != Vector2.ZERO else get_global_mouse_position() - global_position
	var dir := aim.normalized() if aim.length() > 1.0 else facing
	facing = dir
	_swing_dir = dir
	_swing_timer = SWING_TIME
	var mult := Items.skill_mult(id, rank)
	_fx = {"id": id, "t": FX_TIME, "dur": FX_TIME, "dir": dir, "from": global_position}
	Sound.play("sk_" + id)
	match id:
		"slash":
			# 앞으로 미끄러지며 지나가는 길의 적을 모두 벤다
			_dash_dir = dir
			_dash_timer = 0.16
			_invuln = maxf(_invuln, 0.2)
			for e in _enemies():
				var rel: Vector2 = e.global_position - global_position
				var along := rel.dot(dir)
				if along > -10.0 and along < 80.0 and absf(rel.dot(dir.orthogonal())) < 20.0 + float(e.get("radius")):
					_hit(e, mult, dir)
		"circle":
			for e in _enemies():
				if e.global_position.distance_to(global_position) < 48.0 + float(e.get("radius")):
					_hit(e, mult, (e.global_position - global_position).normalized())
		"dot":
			var target := _nearest_in_cone(dir, 170.0, 35.0)
			if target:
				_fx["to"] = target.global_position
				_hit(target, mult, dir)
			else:
				_fx["to"] = global_position + dir * 170.0
		"hatch":
			var target2 := _nearest_in_cone(dir, 46.0, 100.0)
			if target2:
				for i in 5:
					if is_instance_valid(target2) and int(target2.get("hp")) > 0:
						_hit(target2, mult, dir)
		"press":
			var target3 := _nearest_in_cone(dir, 44.0, 100.0)
			if target3:
				_hit(target3, mult, dir, true)
		"erase":
			_invuln = maxf(_invuln, mult)
	queue_redraw()
	return true


func _enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies")


func _hit(enemy: Node2D, mult: float, dir: Vector2, ignore_defense: bool = false) -> void:
	var roll: Array = GameState.roll_damage(mult, 0 if ignore_defense else int(enemy.get("defense")))
	enemy.call("take_damage", int(roll[0]), dir, bool(roll[1]))
	if GameState.skill_rank("ult") > 0:
		ult = minf(ULT_MAX, ult + ULT_PER_HIT * _ult_gain() + (5.0 if bool(roll[1]) and GameState.has_fx("u_star") else 0.0))
	# 장비의 고유 효과
	if bool(roll[1]) and GameState.has_fx("ink"):
		mp = minf(float(max_mp), mp + 3.0)
	if GameState.has_fx("u_pen") and hp < max_hp:
		hp += 1
		hp_changed.emit(hp, max_hp)
	if bool(roll[1]) and GameState.has_fx("set_crumple") and hp < max_hp:
		hp = mini(max_hp, hp + 2)
		hp_changed.emit(hp, max_hp)


## 소모품을 쓸 수 없는 까닭을 알리고 false 를 돌려준다
func _cannot_use(why: String) -> bool:
	use_fail = why
	GameState.notify(why)
	return false


func _ult_gain() -> float:
	return (1.3 if GameState.has_fx("spark") else 1.0) * (1.5 if GameState.has_fx("set_scribble") else 1.0)


func _heal_mult() -> float:
	return (1.3 if GameState.has_fx("pocket") else 1.0) + (0.2 if GameState.has_fx("v_brooch") else 0.0)


# ---------- 필살기 (V) ----------

## 게이지가 가득 차 있으면 필살기 화면(scripts/ui/ultimate.gd)을 연다
func use_ultimate() -> bool:
	if GameState.skill_rank("ult") <= 0:
		return false
	if ult < ULT_MAX:
		GameState.notify("필살기 게이지가 아직 차지 않았어요.")
		return false
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("start_ultimate"):
		hud.call("start_ultimate", self)
	else:
		finish_ultimate(0.5)
	return true


## 따라 그린 점수(0~1)만큼 강한 한 방을 화면의 모든 적에게 넣는다
func finish_ultimate(score: float) -> void:
	GameState.lesson_skill("ult")
	Sound.play("sk_ult")
	ult = 0.0
	var mult := 3.0 + 7.0 * clampf(score, 0.0, 1.0)
	_fx = {"id": "ult", "t": 0.6, "dur": 0.6, "dir": facing, "from": global_position}
	_invuln = maxf(_invuln, 0.6)
	for e in _enemies():
		if is_instance_valid(e) and e.global_position.distance_to(global_position) <= ULT_RANGE:
			_hit(e, mult, (e.global_position - global_position).normalized())
	ult = 0.0
	queue_redraw()


func _nearest_in_cone(dir: Vector2, reach: float, cone_deg: float) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for e in _enemies():
		var to: Vector2 = e.global_position - global_position
		var d := to.length() - float(e.get("radius"))
		if d <= reach and absf(rad_to_deg(dir.angle_to(to))) <= cone_deg * 0.5 and d < best_d:
			best = e
			best_d = d
	return best


## 소모품을 쓴다 (1, 2 번 키). 회복할 것이 없으면 쓰지 않는다.
func use_consumable(id: String) -> bool:
	if GameState.consumable_count(id) <= 0 or not Items.CONSUMABLES.has(id):
		return false
	var info: Array = Items.CONSUMABLES[id]
	use_fail = ""
	if str(info[4]) == "hp":
		if hp >= max_hp:
			return _cannot_use("체력이 가득 차 있어서 쓸 수 없어요.")
		hp = mini(max_hp, hp + ceili(max_hp * float(info[5]) * _heal_mult()))
		hp_changed.emit(hp, max_hp)
	elif str(info[4]) == "mp":
		if mp >= float(max_mp):
			return _cannot_use("MP 가 가득 차 있어서 쓸 수 없어요.")
		mp = minf(float(max_mp), mp + max_mp * float(info[5]) * _heal_mult())
	elif str(info[4]) == "food":
		# 요리: 회복과 한동안 이어지는 효과
		var fx: Dictionary = Items.FOOD_FX.get(id, {})
		var need := fx.has("buff") or (fx.has("hp") and hp < max_hp) or (fx.has("mp") and mp < float(max_mp))
		if not need:
			return _cannot_use("체력과 MP 가 가득 차 있어서 먹을 필요가 없어요.")
		if fx.has("hp"):
			hp = mini(max_hp, hp + ceili(max_hp * float(fx["hp"]) * _heal_mult()))
			hp_changed.emit(hp, max_hp)
		if fx.has("mp"):
			mp = minf(float(max_mp), mp + max_mp * float(fx["mp"]) * _heal_mult())
		if fx.has("buff"):
			GameState.add_buff(str(fx["buff"]), float(fx["time"]))
			GameState.notify("%s (%d분)" % [Items.BUFF_NAMES[str(fx["buff"])], int(float(fx["time"]) / 60.0)])
	else:
		return false
	GameState.add_consumable(id, -1)
	GameState.lesson_note("use")
	return true


func try_interact() -> bool:
	var best: Node2D = null
	var best_d := interact_range
	for n in get_tree().get_nodes_in_group("interactable"):
		var node := n as Node2D
		var d := node.global_position.distance_to(global_position)
		if node.is_in_group("fallen"):
			d += 14.0   # 사람이나 건물이 가까이 있으면 그쪽이 먼저다
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
	hp -= maxi(1, roundi((amount - GameState.defense()) * (0.9 if GameState.has_fx("brim") else 1.0) * (0.85 if GameState.has_fx("set_eraser") else 1.0)))
	stop_act()          # 맞으면 하던 생활 동작이 끊긴다
	Sound.play("hurt")
	if GameState.skill_rank("ult") > 0:
		ult = minf(ULT_MAX, ult + ULT_PER_HURT * _ult_gain())
	_invuln = invuln_time
	_knock = from_dir.normalized() * 160.0
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		_die()


## 쓰러지면 연필심의 10%를 잃고 내 마을로 돌아간다 (내 마을이 아직 없으면 이 맵의 입구로)
func _die() -> void:
	hp = max_hp
	if GameState.on_player_death():
		return
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
	_draw_skill_fx()
	_draw_levelup()
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


## 스킬 효과 그림 한 장을 가운데 기준으로 그린다. width 는 월드 크기.
func _fx_draw(name: String, center: Vector2, angle: float, width: float, alpha: float, flip_y: bool = false) -> bool:
	var t: Texture2D = _fx_tex.get(name)
	if t == null:
		return false
	var size := Vector2(width, width * t.get_height() / float(t.get_width()))
	draw_set_transform(center, angle, Vector2(1, -1 if flip_y else 1))
	draw_texture_rect(t, Rect2(-size * 0.5, size), false, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO)
	return true


## 스킬 효과 (assets/sprites/fx_*.png). 그림이 없으면 연필선으로 대신 그린다.
## 레벨 업: 발밑에서 퍼지는 금빛 고리, 위로 솟는 빛줄기, 머리 위의 글자
func _draw_levelup() -> void:
	if _levelup_t <= 0.0:
		return
	var p := 1.0 - _levelup_t / LEVELUP_TIME          # 0 → 1
	var fade := clampf(_levelup_t / (LEVELUP_TIME * 0.4), 0.0, 1.0)
	var gold := Color(1.0, 0.85, 0.3, fade)
	draw_set_transform(Vector2(0, FOOT.y), 0.0, Vector2(1.0, 0.45))
	for ring in 2:
		var rp := clampf(p * 1.6 - ring * 0.25, 0.0, 1.0)
		if rp > 0.0:
			draw_arc(Vector2.ZERO, 6.0 + rp * 34.0, 0.0, TAU, 40, Color(gold.r, gold.g, gold.b, fade * (1.0 - rp)), 2.5)
	draw_set_transform(Vector2.ZERO)
	for i in 7:
		var x := -18.0 + i * 6.0
		var h := (14.0 + 26.0 * absf(sin(i * 1.7))) * minf(1.0, p * 3.0)
		var lift := p * 18.0
		draw_line(Vector2(x, FOOT.y - lift), Vector2(x, FOOT.y - lift - h), Color(1.0, 0.95, 0.6, fade * 0.7), 1.5)
	for i in 6:
		var ang := i * TAU / 6.0 + p * 3.0
		var pos := Vector2(cos(ang) * 16.0, -20.0 - p * 30.0 + sin(ang) * 6.0)
		draw_circle(pos, 1.6, Color(1, 1, 0.8, fade))
	var font := ThemeDB.fallback_font
	var text := "필력 상승!"
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var at := Vector2(-w * 0.5, -46.0 - minf(1.0, p * 2.5) * 12.0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Color(0.35, 0.22, 0.1, fade))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, gold)


func _draw_skill_fx() -> void:
	if _fx.is_empty():
		return
	var a := clampf(float(_fx["t"]) / float(_fx.get("dur", FX_TIME)), 0.0, 1.0)   # 1 → 0
	var p := 1.0 - a                                                              # 0 → 1
	var fade := minf(1.0, a * 2.5)
	var col := Color(0.2, 0.2, 0.25, a)
	var d: Vector2 = _fx["dir"]
	var up := Vector2(0, -8)
	match str(_fx["id"]):
		"slash":
			var from: Vector2 = (_fx["from"] as Vector2) - global_position
			if not _fx_draw("slash", from + d * 40.0 + up, d.angle(), 92.0, fade, d.x < 0.0):
				draw_line(from + up, from + d * 80.0 + up, col, 3.0)
		"circle":
			if not _fx_draw("circle", up, p * TAU * 0.7, 104.0 * (0.75 + 0.25 * p), fade):
				draw_arc(up, 48.0, 0, TAU, 28, col, 3.0)
		"dot":
			var to: Vector2 = (_fx["to"] as Vector2) - global_position
			var fly := minf(1.0, p * 1.8)
			if not _fx_draw("dot", up.lerp(to + up, fly), d.angle(), 30.0, 1.0 if fly < 1.0 else 0.0, d.x < 0.0):
				draw_circle(to + up, 3.0, col)
			if fly >= 1.0:
				_fx_draw("hit", to + up, 0.0, 22.0 + 14.0 * p, fade)
		"hatch":
			if not _fx_draw("hatch", d * 28.0 + up, d.angle() - 0.2 + 0.4 * p, 46.0, fade):
				for i in 5:
					var o := d.orthogonal() * (i - 2) * 5.0 + d * 26.0 + up
					draw_line(o - d.rotated(0.6) * 9.0, o + d.rotated(0.6) * 9.0, col, 2.0)
		"press":
			if not _fx_draw("press", d * 30.0 + Vector2(0, -6), 0.0, 56.0 * (0.55 + 0.6 * p), fade):
				draw_circle(d * 30.0 + Vector2(0, -6), 9.0 * a + 3.0, col)
		"erase":
			if not _fx_draw("erase", Vector2(0, -10), p * 0.6, 52.0 * (0.7 + 0.5 * p), fade):
				draw_arc(Vector2(0, -10), 16.0, 0, TAU, 20, Color(0.95, 0.6, 0.7, a), 2.5)
		"ult":
			if not _fx_draw("star", Vector2(0, -10), p * 0.5, 70.0 + 420.0 * p, a):
				draw_arc(Vector2(0, -10), 40.0 + 200.0 * p, 0, TAU, 40, Color(1.0, 0.85, 0.3, a), 4.0)


func _draw_swing() -> void:
	# 공격 궤적
	if _swing_timer > 0.0:
		var ang := _swing_dir.angle()
		var half := deg_to_rad(attack_arc_deg * 0.5)
		draw_arc(Vector2(0, -12), attack_range * 0.8, ang - half, ang + half, 12, Color(1, 1, 1, 0.9), 3.0)
		draw_arc(Vector2(0, -12), attack_range * 0.8, ang - half, ang + half, 12, Color(0.2, 0.2, 0.25, 0.8), 1.0)
