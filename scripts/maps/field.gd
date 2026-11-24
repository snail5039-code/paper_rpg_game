extends Node2D
## 사냥터 화면 한 장. 배경 그림 한 장 + 나무 테두리 + 변 가운데의 문(gate).
## 어느 화면인지는 GameState.current_map (또는 field_id) 으로 정하고, 내용은 game_data.gd 의 FIELDS 표에서 읽는다.
## 문으로 걸어 나가면 이웃 화면으로 넘어간다.
##
## 위치는 전부 "bg px"(배경 1672×941 픽셀 좌표)로 적고 bg() 로 월드 좌표로 바꾼다.

const Art := preload("res://scripts/core/art.gd")
const Data := preload("res://scripts/data/game_data.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const PlayerScene := preload("res://scenes/player.tscn")
const Companion := preload("res://scripts/actors/companion.gd")
const MonsterScene := preload("res://scenes/enemy.tscn")
const SpotScript := preload("res://scripts/actors/pickup_spot.gd")
const BugScript := preload("res://scripts/actors/bug.gd")
const TreeScript := preload("res://scripts/actors/tree.gd")
const FORAGE_SPOTS := 4
const TREE_SPOTS := 3           # 흔들거나 벨 수 있는 나무 (대장 방에는 없다)
const BUG_SLOTS := 3            # 화면에 들어올 때마다 곤충 자리 셋 (자리마다 70%)
const POND_SPOT := Vector2(470, 300)   # 들판 연못의 낚시 표지판 (bg px)

const BG_SIZE := Vector2(1672, 941)
const WORLD_PER_BG := 640.0 / 1672.0
const CAMERA_ZOOM := 1.5
const RESPAWN_SEC := 8.0

# 나무 테두리 안쪽 (걸을 수 있는 영역) 과 문의 크기 (bg px)
const PLAY := Rect2(108, 112, 1456, 706)
const GATE_HALF_W := 95.0    # 위·아래 문의 반폭
const GATE_HALF_H := 85.0    # 왼·오른쪽 문의 반높이
const EXIT_MARGIN := 34.0    # 화면 끝에서 이만큼 안으로 들어오면 넘어간다
const OPPOSITE := {"top": "bottom", "bottom": "top", "left": "right", "right": "left"}
# 문으로 들어왔을 때 서는 자리
const ARRIVE := {
	"top": Vector2(836, 160), "bottom": Vector2(836, 772),
	"left": Vector2(160, 470), "right": Vector2(1512, 470),
}

## 테스트에서 화면을 직접 고를 때 쓴다. 비어 있으면 GameState.current_map.
var field_id := ""
var cfg: Dictionary
var actors: Node2D
var player: CharacterBody2D
var hud: CanvasLayer
var companion: Node2D
var last_exit := ""          # 마지막으로 나간 문 (테스트용)
var _leaving := false


static func bg(p: Vector2) -> Vector2:
	return p * WORLD_PER_BG


func _ready() -> void:
	if get_tree().current_scene == self:
		add_to_group("game_map")
	if field_id == "":
		field_id = GameState.current_map
	cfg = _make_config()

	var tex := Art.tex(str(cfg["bg"]))
	if tex:
		var back := Sprite2D.new()
		back.name = "Background"
		back.texture = tex
		back.centered = false
		back.scale = Vector2.ONE * WORLD_PER_BG
		back.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		back.z_index = -10
		back.modulate = cfg.get("tint", Color.WHITE)
		add_child(back)
	else:
		push_error("assets/sprites/%s.png 가 없습니다. tools/import_map_v6.py 를 먼저 실행하세요." % cfg["bg"])

	_build_collision()

	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)

	for m in cfg["monsters"]:
		_spawn_monster(str(m[0]), bg(m[1]))
	_extras()

	player = PlayerScene.instantiate()
	var gates: Dictionary = cfg["gates"]
	var arrive := str(GameState.spawn_tag).trim_prefix("gate_")
	if not gates.has(arrive):
		arrive = str(gates.keys()[0])
	var start: Vector2 = bg(ARRIVE[arrive])
	player.set("spawn_point", start)
	player.position = GameState.saved_position if GameState.has_saved_position and GameState.spawn_tag == "" else start
	GameState.spawn_tag = ""
	actors.add_child(player)
	companion = Companion.attach(actors, player)

	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE * CAMERA_ZOOM
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = roundi(BG_SIZE.x * WORLD_PER_BG)
	cam.limit_bottom = roundi(BG_SIZE.y * WORLD_PER_BG)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	player.add_child(cam)

	hud = HudScript.new()
	hud.name = "HUD"
	hud.set("quest_text_override", _title_text())
	add_child(hud)
	hud.call("set_hints", [["key_wasd", "이동"], ["key_mouse_l", "공격"], ["key_space", "회피"]])
	_tips.call_deferred()
	# 2장: 이야기와 색이 빠지는 경계
	if Data.chapter_of(field_id) == "ch2":
		var story: Node = load("res://scripts/maps/ch2_story.gd").new()
		story.name = "Ch2Story"
		add_child(story)
		if DRAIN_MAPS.has(field_id):
			_color_drain()


# ---------- 2장: 색이 빠지는 경계 ----------
## 화면 오른쪽부터 색이 빠진다. 이 화면에 머무는 동안 경계가 천천히 다가온다 (나갔다 오면 처음 자리).
const DRAIN_MAPS := ["ch2_path", "ch2_grove", "ch2_cliff", "ch2_mushroom", "ch2_bigtree"]
const DRAIN_START := 0.9        # 처음 경계 (화면 가로의 비율)
const DRAIN_END := 0.55         # 가장 가까이 오는 곳
const DRAIN_SPEED := 0.0016     # 1초에 다가오는 비율
var drain: ColorRect
var _drain_x := DRAIN_START

const DRAIN_SHADER := "shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float edge_x = 600.0;
uniform float soft = 18.0;
varying vec2 local_pos;
void vertex() { local_pos = VERTEX; }
void fragment() {
	vec4 c = textureLod(screen_tex, SCREEN_UV, 0.0);
	float wob = sin(local_pos.y * 0.045) * 9.0 + sin(local_pos.y * 0.13 + TIME * 0.6) * 3.0;
	float t = smoothstep(edge_x - soft, edge_x + soft, local_pos.x + wob);
	float g = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 grey = mix(vec3(g), vec3(0.94, 0.92, 0.87), 0.3);
	COLOR = vec4(mix(c.rgb, grey, t * 0.88), 1.0);
}"


func _color_drain() -> void:
	drain = ColorRect.new()
	drain.name = "ColorDrain"
	drain.size = BG_SIZE * WORLD_PER_BG
	drain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drain.z_index = 50
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = DRAIN_SHADER
	mat.shader = sh
	drain.material = mat
	add_child(drain)
	_set_drain(DRAIN_START)


func _set_drain(ratio: float) -> void:
	_drain_x = ratio
	if drain:
		(drain.material as ShaderMaterial).set_shader_parameter("edge_x", drain.size.x * ratio)


func _process(delta: float) -> void:
	if drain and not GameState.menu_open and not GameState.dialogue_open and _drain_x > DRAIN_END:
		_set_drain(maxf(DRAIN_END, _drain_x - DRAIN_SPEED * delta))


## 이 화면의 내용 (FIELDS 표). 끝없는 탑(scripts/maps/tower.gd)은 층마다 만들어 쓴다.
func _make_config() -> Dictionary:
	if not Data.FIELDS.has(field_id):
		field_id = "ch1_crossroad"
	return Data.FIELDS[field_id]


func _title_text() -> String:
	var ch := Data.chapter_of(field_id)
	var num := int(Data.CHAPTERS[ch]["num"]) if ch != "" else 1
	if bool(cfg.get("town", false)):
		return "%d장 · %s" % [num, cfg["name"]]
	return "%d장 · %s  (%s)" % [num, cfg["name"], GameState.diff()["name"]]


## 사냥터에만 있는 것: 오늘의 필드 보스, 채집 자리, 풍선
func _extras() -> void:
	var ch := Data.chapter_of(field_id)
	# 대장 방에 들어오면 나팔 소리
	if ch != "" and field_id == str(Data.CHAPTERS[ch]["bossroom"]):
		Sound.play.call_deferred("boss_appear")
	# 1장 대장을 물리친 뒤에는 구깃이의 방에 2장으로 가는 문이 생긴다
	if field_id == "ch1_bossroom" and GameState.bosses_beaten.has(Data.CH2_UNLOCK_BOSS):
		var Portal := load("res://scripts/actors/portal.gd")
		var door: Node2D = Portal.new()
		door.set("target_map", "ch2")
		door.set("title", "2장  색연필 숲")
		door.set("spawn_tag", "gate_bottom")
		door.position = bg(Vector2(836, 300))
		actors.add_child(door)
	# 오늘의 필드 보스 (장마다 하나)
	if ch != "" and GameState.field_boss_map(ch) == field_id:
		var fb := str(Data.CHAPTERS[ch]["field_boss"])
		_spawn_monster(fb, bg(Vector2(836, 470)))
		GameState.notify.call_deferred("필드 보스 \"%s\" 가 이 근처에 있어요!" % Data.MONSTERS[fb]["name"])
		Sound.play.call_deferred("boss_appear")
	if bool(cfg.get("town", false)):
		return      # 마을에는 채집 자리·곤충이 없다
	# 나무 (하루에 한 번 흔들고, 한 번 벤다). 자리는 화면마다 정해져 있다.
	var trees := tree_spots()
	for i in trees.size():
		var tree: Node2D = TreeScript.new()
		tree.set("key", "%s:tree%d" % [field_id, i])
		tree.set("look", 1 if ch == "ch2" else 0)
		tree.position = bg(trees[i])
		actors.add_child(tree)
	# 채집 자리 (하루에 한 번). 자리는 화면마다 정해져 있다.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(field_id)
	var made := 0
	var tries := 0
	while made < FORAGE_SPOTS and tries < 60:
		tries += 1
		var at := Vector2(rng.randf_range(PLAY.position.x + 80, PLAY.end.x - 80), rng.randf_range(PLAY.position.y + 80, PLAY.end.y - 80))
		var blocked := false
		for r in cfg["solids"]:
			if (r as Rect2).grow(40).has_point(at):
				blocked = true
		for t in trees:
			if (t as Vector2).distance_to(at) < 110.0:
				blocked = true
		if blocked:
			continue
		var spot: Node2D = SpotScript.new()
		spot.set("mode", "forage")
		spot.set("key", "%s:%d" % [field_id, made])
		spot.position = bg(at)
		actors.add_child(spot)
		made += 1
	# 곤충 (잠자리채로 잡는다). 들어올 때마다 새로 나온다.
	for i in BUG_SLOTS:
		if randf() > 0.7:
			continue
		var at := Vector2.ZERO
		for t in 20:
			at = Vector2(randf_range(PLAY.position.x + 100, PLAY.end.x - 100), randf_range(PLAY.position.y + 90, PLAY.end.y - 90))
			var ok := true
			for r in cfg["solids"]:
				if (r as Rect2).grow(50).has_point(at):
					ok = false
			if ok:
				break
		var bug: Node2D = BugScript.new()
		bug.set("id", GameState.roll_forage("bug"))
		bug.position = bg(at)
		bug.set("area", Rect2(bg(at) - Vector2(40, 30), Vector2(80, 60)))
		actors.add_child(bug)
	# 들판 연못의 낚시 자리 (연못에서만 낚이는 물고기가 있다)
	if field_id == "ch1_meadow":
		var fs: Node2D = SpotScript.new()
		fs.set("mode", "fish")
		fs.set("key", "pond")
		fs.position = bg(POND_SPOT)
		fs.set("cast_to", bg(Vector2(330, 280)) - bg(POND_SPOT))
		actors.add_child(fs)
	# 풍선 아이의 날아간 풍선
	if Data.BALLOONS.has(field_id):
		var balloon: Node2D = SpotScript.new()
		balloon.set("mode", "balloon")
		balloon.set("key", field_id)
		balloon.position = bg(Data.BALLOONS[field_id])
		actors.add_child(balloon)


## 이 화면의 나무 자리 (bg px). 막힌 곳, 문 앞, 화면 가운데(대장 자리)를 피해 화면마다 늘 같은 곳.
func tree_spots() -> Array:
	var out: Array = []
	if field_id.ends_with("bossroom") or bool(cfg.get("town", false)):
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(field_id + ":trees")
	var tries := 0
	while out.size() < TREE_SPOTS and tries < 160:
		tries += 1
		var at := Vector2(rng.randf_range(PLAY.position.x + 110, PLAY.end.x - 110), rng.randf_range(PLAY.position.y + 150, PLAY.end.y - 50))
		var ok := at.distance_to(Vector2(836, 470)) > 160.0
		for r in cfg["solids"]:
			if (r as Rect2).grow(70).has_point(at):
				ok = false
		for g in ARRIVE.values():
			if (g as Vector2).distance_to(at) < 220.0:
				ok = false
		for t in out:
			if (t as Vector2).distance_to(at) < 260.0:
				ok = false
		for m in cfg["monsters"]:
			if (m[1] as Vector2).distance_to(at) < 70.0:
				ok = false
		if ok:
			out.append(at)
	return out


func _tips() -> void:
	await get_tree().create_timer(0.6, false).timeout
	GameState.tip("fatigue", "사냥터 화면에 들어갈 때마다 피로도가 2 줄어요. 아침 6시가 되거나 내 집에서 자면 가득 차요.")


# ---------- 충돌 ----------

## 나무 테두리(문 자리는 비움)와 화면 안의 막힌 물건을 사각형으로 막는다.
func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "MapCollision"
	add_child(body)
	var gates: Dictionary = cfg["gates"]
	var w := BG_SIZE.x
	var h := BG_SIZE.y
	var cx := w * 0.5
	var cy := h * 0.5
	var rects: Array = []
	# 위, 아래
	for side in ["top", "bottom"]:
		var y0 := 0.0 if side == "top" else PLAY.end.y
		var y1 := PLAY.position.y if side == "top" else h
		if gates.has(side):
			rects.append(Rect2(0, y0, cx - GATE_HALF_W, y1 - y0))
			rects.append(Rect2(cx + GATE_HALF_W, y0, w - cx - GATE_HALF_W, y1 - y0))
		else:
			rects.append(Rect2(0, y0, w, y1 - y0))
	# 왼쪽, 오른쪽
	for side in ["left", "right"]:
		var x0 := 0.0 if side == "left" else PLAY.end.x
		var x1 := PLAY.position.x if side == "left" else w
		if gates.has(side):
			rects.append(Rect2(x0, 0, x1 - x0, cy - GATE_HALF_H))
			rects.append(Rect2(x0, cy + GATE_HALF_H, x1 - x0, h - cy - GATE_HALF_H))
		else:
			rects.append(Rect2(x0, 0, x1 - x0, h))
	# 화면 밖으로 떨어지지 않게 바깥 벽
	rects.append(Rect2(-60, -60, w + 120, 60))
	rects.append(Rect2(-60, h, w + 120, 60))
	rects.append(Rect2(-60, 0, 60, h))
	rects.append(Rect2(w, 0, 60, h))
	for r in cfg.get("solids", []):
		rects.append(r)
	for r in rects:
		var rect: Rect2 = r
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size * WORLD_PER_BG
		shape.shape = box
		shape.position = bg(rect.get_center())
		body.add_child(shape)


# ---------- 몬스터 ----------

func _spawn_monster(kind: String, pos: Vector2) -> void:
	var m: Node2D = MonsterScene.instantiate()
	# 밤에는 조금 지워진 몬스터 대신 많이 지워진(더 센) 모습이 나온다
	var shown := kind
	if GameState.is_night() and kind.ends_with("_faded") and Data.MONSTERS.has(kind.replace("_faded", "_erased")):
		shown = kind.replace("_faded", "_erased")
	m.set("kind", shown)
	m.set("tier", GameState.difficulty)
	m.position = pos
	_setup_monster(m, kind)
	actors.add_child(m)


## 몬스터를 놓기 전에 손본다. 사냥터: 보스가 아니면 쓰러진 뒤 다시 나온다 (보스는 화면을 나갔다 들어와야 다시 나온다)
func _setup_monster(m: Node2D, kind: String) -> void:
	if not Data.MONSTERS[str(m.get("kind"))].has("boss"):
		m.connect("died", _on_monster_died.bind(kind))


func _on_monster_died(home: Vector2, kind: String) -> void:
	await get_tree().create_timer(RESPAWN_SEC, false).timeout
	if is_inside_tree():
		_spawn_monster(kind, home)


# ---------- 문 ----------

func _physics_process(_delta: float) -> void:
	if _leaving or not is_instance_valid(player):
		return
	var p := player.global_position / WORLD_PER_BG
	var side := ""
	if p.y < EXIT_MARGIN:
		side = "top"
	elif p.y > BG_SIZE.y - EXIT_MARGIN:
		side = "bottom"
	elif p.x < EXIT_MARGIN:
		side = "left"
	elif p.x > BG_SIZE.x - EXIT_MARGIN:
		side = "right"
	var gates: Dictionary = cfg["gates"]
	if side == "" or not gates.has(side):
		return
	# 2장 대장 방은 덩굴이까지 만난 뒤에 열린다
	if str(gates[side]) == "ch2_bossroom" and GameState.ch2_step < 5:
		player.global_position.y -= 24.0
		GameState.notify("큰 뿌리가 길을 막고 있다. 숲의 친구들을 먼저 만나 보자.")
		return
	last_exit = side
	_leaving = GameState.goto_map(str(gates[side]), "gate_" + str(OPPOSITE[side]))
