extends Node2D
## 첫 페이지: 공책 속 마을.
## 배경 그림 한 장(assets/sprites/bg.png)을 깔고, 충돌은 마스크 이미지에서 다각형으로 만든다.
## 격자 타일을 쓰지 않으므로 길·강·나무가 그림 모양 그대로 막힌다.
##
## 위치는 전부 "bg px"(배경 원본 1672×941 픽셀 좌표)로 적고 bg() 로 월드 좌표로 바꾼다.
## 충돌 마스크는 tools/import_art.gd 가 만든다 (mask_solid.png / mask_walk.png).

const Art := preload("res://scripts/core/art.gd")
const Validator := preload("res://scripts/drawing/blueprint_validator.gd")
const DrawingScript := preload("res://scripts/drawing/drawing_manager.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const GoalScript := preload("res://scripts/actors/goal.gd")
const TutorialScript := preload("res://scripts/maps/tutorial.gd")
const Lessons := preload("res://scripts/data/lessons.gd")
var lessons: Node
const PlayerScene := preload("res://scenes/player.tscn")
const Companion := preload("res://scripts/actors/companion.gd")
const SlimeScene := preload("res://scenes/enemy.tscn")
const NpcScene := preload("res://scenes/npc.tscn")
const VillagerScript := preload("res://scripts/actors/villager.gd")
const ShopkeeperScript := preload("res://scripts/actors/shopkeeper.gd")
const SpotScript := preload("res://scripts/actors/pickup_spot.gd")
const FISH_SPOT := Vector2(930, 600)   # 다리 아래쪽 강가
const SHOP_POS := Vector2(250, 452)

const BG_SIZE := Vector2(1672, 941)
const WORLD_PER_BG := 640.0 / 1672.0
const MASK_BLOCK := 4
const CAMERA_ZOOM := 1.5
const SLIME_RESPAWN_SEC := 8.0
const GUIDE_TOLERANCE := 8.0

# ---- 배치 (bg px) ----
const PLAYER_SPAWN := Vector2(290, 515)
const NPC_POS := Vector2(880, 438)
const GOAL_POS := Vector2(1502, 486)
const RETURN_SPAWN := Vector2(1380, 540)
## 아래쪽 문: 갈림길로 이어진다 (bg px)
const SOUTH_GATE_X := 805.0
const SOUTH_GATE_ARRIVE := Vector2(805, 800)
const EXIT_MARGIN := 34.0
const SLIME_SPAWNS := [Vector2(300, 735), Vector2(520, 740), Vector2(760, 760)]
## 몬스터 배치: [종류, 위치]. 강 왼쪽은 조금 지워진 것, 다리 건너는 많이 지워진 것.
## 마을에는 슬라임 위주로 조금만 둔다. 나머지 종은 아래쪽 문 너머의 사냥터 화면에 있다 (game_data.gd 의 FIELDS).
const MONSTER_SPAWNS := [
	["slime_faded", Vector2(300, 735)], ["slime_faded", Vector2(520, 740)], ["slime_faded", Vector2(620, 620)],
	["dots_faded", Vector2(170, 720)],
	["slime_erased", Vector2(1300, 300)], ["grass_erased", Vector2(1280, 720)],
]
## 흰 자국(완전히 지워진 것의 자리): [그림, 발 위치]
const WHITE_MARKS := [
	["mark_house_small", Vector2(450, 700)], ["mark_tree", Vector2(150, 500)], ["mark_person", Vector2(640, 520)],
	["mark_person", Vector2(1380, 420)],
]
## 주민: [그림, 위치, 대사]. 이름이 먼저 지워져서 이름표가 비어 있다.
const VILLAGERS := [
	["villager_0", Vector2(400, 440), ["어서 와. 빵 사러 왔니?", "…어머, 내 이름? 그게… 뭐였더라.", "이름표에 적어 뒀는데, 자꾸 비어 있네."]],
	["villager_1", Vector2(620, 440), ["저기 흰 자국 보이지? 저기 누가 서 있었는데.", "누구였는지는… 아무도 몰라.", "완전히 지워지면 돌아오지 않는단다."]],
	["villager_2", Vector2(800, 520), ["풍선 받았어! 누가 줬는지는 기억 안 나.", "하루 누나가 그러는데, 그린이가 오면 다 고쳐 준대!"]],
]
const BRIDGE_RECT := Rect2(962, 470, 246, 86)

var actors: Node2D
var drawing: Node2D
var player: CharacterBody2D
var hud: CanvasLayer
var companion: Node2D
var goal: Node2D
var tutorial: Node
var bridge_sprite: Sprite2D
var bridge_blocker: StaticBody2D
var shopkeeper: Node2D


static func bg(p: Vector2) -> Vector2:
	return p * WORLD_PER_BG


func _ready() -> void:
	if get_tree().current_scene == self:
		add_to_group("game_map")
	# 배경
	var bg_tex := Art.tex("bg_ch1_village")   # 아래쪽 문이 열린 새 배경
	if bg_tex == null:
		bg_tex = Art.tex("bg")
	if bg_tex:
		var back := Sprite2D.new()
		back.name = "Background"
		back.texture = bg_tex
		back.centered = false
		back.scale = Vector2.ONE * WORLD_PER_BG
		back.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		back.z_index = -10
		add_child(back)
	else:
		push_error("assets/sprites/bg.png 가 없습니다. tools/import_art.gd 를 먼저 실행하세요.")

	_build_collision()

	# 다리 (완성 전에는 숨김 + 통행 차단)
	var bridge_world := Rect2(bg(BRIDGE_RECT.position), BRIDGE_RECT.size * WORLD_PER_BG)
	var bridge_tex := Art.tex("prop_bridge")
	if bridge_tex:
		bridge_sprite = Sprite2D.new()
		bridge_sprite.texture = bridge_tex
		bridge_sprite.scale = Art.SCALE
		bridge_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		bridge_sprite.position = bridge_world.get_center()
		bridge_sprite.z_index = -5
		bridge_sprite.visible = false
		add_child(bridge_sprite)

	bridge_blocker = StaticBody2D.new()
	bridge_blocker.name = "BridgeBlocker"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = bridge_world.size
	shape.shape = rect
	bridge_blocker.position = bridge_world.get_center()
	bridge_blocker.add_child(shape)
	add_child(bridge_blocker)

	if GameState.bridge_built:
		_build_bridge(false)

	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)

	# NPC
	var npc: Node2D = NpcScene.instantiate()
	npc.position = bg(NPC_POS)
	actors.add_child(npc)

	# 빨간 문 (목표)
	goal = GoalScript.new()
	goal.position = bg(GOAL_POS)
	actors.add_child(goal)

	# 흰 자국 (바닥 그림)
	for m in WHITE_MARKS:
		var mt := Art.tex(str(m[0]))
		if mt:
			var ms := Art.make_sprite(self, mt, bg(m[1]))
			ms.z_index = -6
			ms.modulate.a = 0.85

	# 주민
	var vids := ["baker", "elder", "kid"]
	for vi in VILLAGERS.size():
		var v: Array = VILLAGERS[vi]
		if int(GameState.villager(str(vids[vi]))["q"]) == 3:
			continue      # 내 마을로 이사 갔다
		var vn: Node2D = VillagerScript.new()
		vn.set("vid", vids[vi])
		vn.set("sprite_name", v[0])
		vn.set("lines", v[2])
		vn.position = bg(v[1])
		actors.add_child(vn)

	# 강가의 낚시 자리
	var fish_spot: Node2D = SpotScript.new()
	fish_spot.set("mode", "fish")
	fish_spot.set("key", "ch1")
	fish_spot.position = bg(FISH_SPOT)
	actors.add_child(fish_spot)

	# 몬스터
	for sp in MONSTER_SPAWNS:
		_spawn_monster(str(sp[0]), bg(sp[1]))

	# 플레이어 + 카메라
	player = PlayerScene.instantiate()
	player.set("spawn_point", bg(PLAYER_SPAWN))
	player.position = GameState.saved_position if GameState.has_saved_position else bg(PLAYER_SPAWN)
	if GameState.spawn_tag == "from_home":
		player.position = bg(RETURN_SPAWN)   # 내 마을에서 돌아오면 빨간 문 앞
	elif GameState.spawn_tag == "gate_bottom":
		player.position = bg(SOUTH_GATE_ARRIVE)   # 갈림길에서 올라오면 아래쪽 문 앞
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

	# 연필 모드
	drawing = DrawingScript.new()
	drawing.name = "Drawing"
	add_child(drawing)
	drawing.set("guides", _bridge_guides())
	drawing.set("show_guides", not GameState.bridge_built)
	drawing.connect("submitted", _on_blueprint_submitted)

	# HUD
	hud = HudScript.new()
	hud.name = "HUD"
	add_child(hud)

	# 문방구 할아버지
	shopkeeper = ShopkeeperScript.new()
	shopkeeper.set("hud", hud)
	shopkeeper.position = bg(SHOP_POS)
	actors.add_child(shopkeeper)

	# 튜토리얼 연출 (오프닝, 조작 안내, 문 열기, 페이지 넘김)
	tutorial = TutorialScript.new()
	tutorial.name = "Tutorial"
	tutorial.set("village", self)
	tutorial.set("hud", hud)
	tutorial.set("goal", goal)
	tutorial.set("drawing", drawing)
	add_child(tutorial)

	# 하루의 수업 (새 캐릭터만): 할 일을 하나씩 준다
	lessons = Lessons.new()
	lessons.name = "Lessons"
	lessons.set("hud", hud)
	lessons.set("spawn_dummy", _spawn_dummy)
	add_child(lessons)


# ---------- 아래쪽 문 ----------

var last_exit := ""
var _leaving := false
var _gate_notice := 0.0


func _physics_process(delta: float) -> void:
	_gate_notice = maxf(0.0, _gate_notice - delta)
	if _leaving or not is_instance_valid(player):
		return
	var p := player.global_position / WORLD_PER_BG
	if p.y < BG_SIZE.y - EXIT_MARGIN:
		return
	if GameState.quest == GameState.Quest.NOT_STARTED:
		# 이야기를 듣기 전에는 마을 밖으로 나가지 않는다
		player.global_position.y = bg(Vector2(0, BG_SIZE.y - EXIT_MARGIN - 30)).y
		if _gate_notice <= 0.0:
			_gate_notice = 2.0
			GameState.notify("먼저 마을 사람에게 이야기를 들어 보자.")
		return
	last_exit = "bottom"
	_leaving = GameState.goto_map("ch1_crossroad", "gate_top")


# ---------- 충돌 ----------

## 마스크 이미지의 윤곽선을 따라 충돌선을 만든다.
##  - mask_walk : 걸을 수 있는 영역의 바깥 윤곽 (강가, 나무 테두리)
##  - mask_solid: 막힌 덩어리의 윤곽 (걸을 수 있는 영역 안에 섬처럼 있는 집·덤불)
func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "MapCollision"
	add_child(body)
	var to_world := MASK_BLOCK * WORLD_PER_BG
	for mask_name in ["mask_walk", "mask_solid"]:
		var t := Art.tex(mask_name)
		if t == null:
			push_error("assets/sprites/%s.png 가 없습니다." % mask_name)
			continue
		var img := t.get_image()
		var bm := BitMap.new()
		bm.create_from_image_alpha(img, 0.5)
		var polys := bm.opaque_to_polygons(Rect2i(Vector2i.ZERO, bm.get_size()), 1.0)
		for poly in polys:
			var pts := PackedVector2Array()
			for p in (poly as PackedVector2Array):
				pts.append(p * to_world)
			if pts.size() < 3:
				continue
			var cp := CollisionPolygon2D.new()
			cp.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
			cp.polygon = pts
			body.add_child(cp)


## 스킬 체험용 허수아비를 주인공 옆에 세운다
func _spawn_dummy() -> Node:
	var d: Node2D = SlimeScene.instantiate()
	d.set("kind", "dummy")
	d.position = (player.global_position if is_instance_valid(player) else bg(SHOP_POS)) + Vector2(56, 0)
	actors.add_child(d)
	return d


func _spawn_monster(kind: String, pos: Vector2) -> void:
	var s: Node2D = SlimeScene.instantiate()
	s.set("kind", kind)
	s.position = pos
	s.connect("died", _on_monster_died.bind(kind))
	actors.add_child(s)


func _on_monster_died(home: Vector2, kind: String) -> void:
	await get_tree().create_timer(SLIME_RESPAWN_SEC, false).timeout
	if is_inside_tree():
		_spawn_monster(kind, home)


# ---------- 다리 설계도 ----------

## 다리 설계도 안내선: 위·아래 난간 2줄 + 가운데 기둥 2개 (월드 좌표)
func _bridge_guides() -> Array:
	var r := Rect2(bg(BRIDGE_RECT.position), BRIDGE_RECT.size * WORLD_PER_BG)
	var left := r.position.x + 3.0
	var right := r.end.x - 3.0
	var top := r.position.y + 2.0
	var bottom := r.end.y - 2.0
	var mid1 := r.position.x + r.size.x / 3.0
	var mid2 := r.position.x + r.size.x * 2.0 / 3.0
	return [
		PackedVector2Array([Vector2(left, top), Vector2(right, top)]),
		PackedVector2Array([Vector2(left, bottom), Vector2(right, bottom)]),
		PackedVector2Array([Vector2(mid1, top), Vector2(mid1, bottom)]),
		PackedVector2Array([Vector2(mid2, top), Vector2(mid2, bottom)]),
	]


func _on_blueprint_submitted(strokes: Array) -> void:
	var Q := GameState.Quest
	var need := GameState.BRIDGE_COST
	if GameState.bridge_built:
		GameState.notify("다리는 이미 완성됐어요. (자유 낙서는 아직 저장되지 않아요)")
		return
	if GameState.quest == Q.NOT_STARTED:
		GameState.notify("먼저 마을 사람에게 이야기를 들어 보자. [F]")
		return
	if GameState.lessons_on and Lessons.VILLAGE.has(GameState.lesson) and Lessons.VILLAGE.find(GameState.lesson) < Lessons.VILLAGE.find("bridge"):
		GameState.notify("먼저 하루가 알려 주는 것부터 해 보자.")
		return
	if GameState.pencil_lead < need:
		GameState.notify("연필심이 부족해요. (%d/%d)" % [GameState.pencil_lead, need])
		return

	var result: Dictionary = Validator.evaluate(drawing.get("guides"), strokes, GUIDE_TOLERANCE)
	if not result["success"]:
		GameState.notify(result["reason"])
		return

	GameState.add_lead(-need)
	_build_bridge(true)
	drawing.set("show_guides", false)
	drawing.call("set_active", false)
	GameState.set_quest(Q.BRIDGE_BUILT)  # set_quest 안에서 자동 저장
	GameState.notify("다리 완성!  " + str(result["reason"]))


func _build_bridge(animate: bool) -> void:
	GameState.bridge_built = true
	if is_instance_valid(bridge_blocker):
		bridge_blocker.queue_free()
	bridge_blocker = null
	if bridge_sprite == null:
		return
	bridge_sprite.visible = true
	if animate:
		# 종이 위에 톡 하고 나타나는 연출
		bridge_sprite.modulate.a = 0.0
		bridge_sprite.scale = Art.SCALE * 1.25
		var tw := bridge_sprite.create_tween().set_parallel(true)
		tw.tween_property(bridge_sprite, "modulate:a", 1.0, 0.35)
		tw.tween_property(bridge_sprite, "scale", Art.SCALE, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
