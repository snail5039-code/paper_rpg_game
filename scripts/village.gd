extends Node2D
## 첫 페이지: 공책 속 마을.
## 배경 그림 한 장(assets/sprites/bg.png)을 깔고, 충돌은 마스크 이미지에서 다각형으로 만든다.
## 격자 타일을 쓰지 않으므로 길·강·나무가 그림 모양 그대로 막힌다.
##
## 위치는 전부 "bg px"(배경 원본 1672×941 픽셀 좌표)로 적고 bg() 로 월드 좌표로 바꾼다.
## 충돌 마스크는 tools/import_art.gd 가 만든다 (mask_solid.png / mask_walk.png).

const Art := preload("res://scripts/art.gd")
const Validator := preload("res://scripts/blueprint_validator.gd")
const DrawingScript := preload("res://scripts/drawing_manager.gd")
const HudScript := preload("res://scripts/hud.gd")
const GoalScript := preload("res://scripts/goal.gd")
const PlayerScene := preload("res://scenes/player.tscn")
const SlimeScene := preload("res://scenes/enemy.tscn")
const NpcScene := preload("res://scenes/npc.tscn")

const BG_SIZE := Vector2(1672, 941)
const WORLD_PER_BG := 640.0 / 1672.0
const MASK_BLOCK := 4
const CAMERA_ZOOM := 1.5
const SLIME_RESPAWN_SEC := 8.0
const GUIDE_TOLERANCE := 8.0

# ---- 배치 (bg px) ----
const PLAYER_SPAWN := Vector2(300, 525)
const NPC_POS := Vector2(880, 438)
const GOAL_POS := Vector2(1502, 486)
const SLIME_SPAWNS := [Vector2(330, 670), Vector2(520, 730), Vector2(700, 650), Vector2(810, 745)]
const BRIDGE_RECT := Rect2(962, 470, 246, 86)

var actors: Node2D
var drawing: Node2D
var player: CharacterBody2D
var hud: CanvasLayer
var bridge_sprite: Sprite2D
var bridge_blocker: StaticBody2D


static func bg(p: Vector2) -> Vector2:
	return p * WORLD_PER_BG


func _ready() -> void:
	# 배경
	var bg_tex := Art.tex("bg")
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
	var goal: Node2D = GoalScript.new()
	goal.position = bg(GOAL_POS)
	actors.add_child(goal)

	# 슬라임
	for sp in SLIME_SPAWNS:
		_spawn_slime(bg(sp))

	# 플레이어 + 카메라
	player = PlayerScene.instantiate()
	player.set("spawn_point", bg(PLAYER_SPAWN))
	player.position = GameState.saved_position if GameState.has_saved_position else bg(PLAYER_SPAWN)
	actors.add_child(player)

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


func _spawn_slime(pos: Vector2) -> void:
	var s: Node2D = SlimeScene.instantiate()
	s.position = pos
	s.connect("died", _on_slime_died)
	actors.add_child(s)


func _on_slime_died(home: Vector2) -> void:
	await get_tree().create_timer(SLIME_RESPAWN_SEC, false).timeout
	if is_inside_tree():
		_spawn_slime(home)


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
