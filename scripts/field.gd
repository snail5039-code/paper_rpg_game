extends Node2D
## 사냥터 화면 한 장. 배경 그림 한 장 + 나무 테두리 + 변 가운데의 문(gate).
## 어느 화면인지는 GameState.current_map (또는 field_id) 으로 정하고, 내용은 game_data.gd 의 FIELDS 표에서 읽는다.
## 문으로 걸어 나가면 이웃 화면으로 넘어간다.
##
## 위치는 전부 "bg px"(배경 1672×941 픽셀 좌표)로 적고 bg() 로 월드 좌표로 바꾼다.

const Art := preload("res://scripts/art.gd")
const Data := preload("res://scripts/game_data.gd")
const HudScript := preload("res://scripts/hud.gd")
const PlayerScene := preload("res://scenes/player.tscn")
const Companion := preload("res://scripts/companion.gd")
const MonsterScene := preload("res://scenes/enemy.tscn")
const SpotScript := preload("res://scripts/pickup_spot.gd")
const FORAGE_SPOTS := 4

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
	hud.call("set_hints", [["key_wasd", "이동"], ["key_mouse_l", "공격"], ["key_space", "회피"], ["", "I 가방  K 스킬  M 지도"]])
	_tips.call_deferred()


## 이 화면의 내용 (FIELDS 표). 끝없는 탑(scripts/tower.gd)은 층마다 만들어 쓴다.
func _make_config() -> Dictionary:
	if not Data.FIELDS.has(field_id):
		field_id = "ch1_crossroad"
	return Data.FIELDS[field_id]


func _title_text() -> String:
	return "1장 · %s  (%s)" % [cfg["name"], GameState.diff()["name"]]


## 사냥터에만 있는 것: 오늘의 필드 보스, 채집 자리, 풍선
func _extras() -> void:
	# 대장 방에 들어오면 나팔 소리
	if field_id == "ch1_bossroom":
		Sound.play.call_deferred("boss_appear")
	# 오늘의 필드 보스
	if GameState.field_boss_map() == field_id:
		_spawn_monster("boss_scribble", bg(Vector2(836, 470)))
		GameState.notify.call_deferred("필드 보스 \"떠돌이 큰 낙서\" 가 이 근처에 있어요!")
		Sound.play.call_deferred("boss_appear")
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
		if blocked:
			continue
		var spot: Node2D = SpotScript.new()
		spot.set("mode", "forage")
		spot.set("key", "%s:%d" % [field_id, made])
		spot.position = bg(at)
		actors.add_child(spot)
		made += 1
	# 풍선 아이의 날아간 풍선
	if Data.BALLOONS.has(field_id):
		var balloon: Node2D = SpotScript.new()
		balloon.set("mode", "balloon")
		balloon.set("key", field_id)
		balloon.position = bg(Data.BALLOONS[field_id])
		actors.add_child(balloon)


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
	last_exit = side
	_leaving = GameState.goto_map(str(gates[side]), "gate_" + str(OPPOSITE[side]))
