extends Node2D
## 첫 페이지: 공책 속 일본풍 마을.
## 맵(MAP)을 읽어 타일을 깔고, 플레이어·NPC·슬라임·도리이·연필 모드·HUD를 배치한다.
##
## 맵 기호
##   #  나무(막힘)     .  풀        ,  흙길
##   H  집(막힘)       D  입구(막힘)  ~  강(막힘)
##   =  끊어진 다리 자리 (설계도로 그리면 다리가 생김)
##   P  플레이어 시작   N  NPC       S  슬라임    G  도리이(목표)

const Tiles := preload("res://scripts/placeholder_tiles.gd")
const Validator := preload("res://scripts/blueprint_validator.gd")
const DrawingScript := preload("res://scripts/drawing_manager.gd")
const HudScript := preload("res://scripts/hud.gd")
const GoalScript := preload("res://scripts/goal.gd")
const PlayerScene := preload("res://scenes/player.tscn")
const SlimeScene := preload("res://scenes/enemy.tscn")
const NpcScene := preload("res://scenes/npc.tscn")

const TILE := 16
const SLIME_RESPAWN_SEC := 8.0
const GUIDE_TOLERANCE := 8.0

const MAP: Array[String] = [
	"########################################",
	"#.......................~~~~...........#",
	"#..HHHH......HHHH.......~~~~...........#",
	"#..HHHH......HHHH.......~~~~....#......#",
	"#..HDHH......HHDH.......~~~~...........#",
	"#...,..........,........~~~~......#....#",
	"#...,,,,,,,,,,,,........~~~~...........#",
	"#.........,.............~~~~..#........#",
	"#...P.....,.............~~~~...........#",
	"#.........,,,,,,,,,,,N..~~~~...........#",
	"#....................,,,====,,,,,,G....#",
	"#....................,,,====,,,,,,.....#",
	"#.........,.............~~~~...........#",
	"#..S......,.....S.......~~~~......#....#",
	"#.........,.............~~~~...........#",
	"#...........S...........~~~~...#.......#",
	"#..##.........##........~~~~...........#",
	"#..##.....S...##........~~~~.......#...#",
	"#.......................~~~~...........#",
	"#.......................~~~~...........#",
	"#.......................~~~~...........#",
	"########################################",
]

var ground: TileMapLayer
var actors: Node2D
var drawing: Node2D
var player: CharacterBody2D
var hud: CanvasLayer
var bridge_cells: Array[Vector2i] = []


func _ready() -> void:
	ground = TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = Tiles.build(TILE)
	add_child(ground)

	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)

	var player_spawn := Vector2.ZERO
	var npc_pos := Vector2.ZERO
	var goal_pos := Vector2.ZERO
	var slime_spawns: Array[Vector2] = []

	for y in MAP.size():
		var row := MAP[y]
		for x in row.length():
			var c := row[x]
			var cell := Vector2i(x, y)
			var center := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
			match c:
				"#": _set_tile(cell, Tiles.T.TREE)
				",": _set_tile(cell, Tiles.T.PATH)
				"H":
					var is_top := y == 0 or MAP[y - 1][x] != "H"
					_set_tile(cell, Tiles.T.ROOF if is_top else Tiles.T.HOUSE)
				"D": _set_tile(cell, Tiles.T.DOOR)
				"~": _set_tile(cell, Tiles.T.WATER)
				"=":
					_set_tile(cell, Tiles.T.WATER)
					bridge_cells.append(cell)
				"P":
					_set_tile(cell, Tiles.T.GRASS)
					player_spawn = center
				"N":
					_set_tile(cell, Tiles.T.GRASS)
					npc_pos = center
				"S":
					_set_tile(cell, Tiles.T.GRASS)
					slime_spawns.append(center)
				"G":
					_set_tile(cell, Tiles.T.PATH)
					goal_pos = center
				_:
					_set_tile(cell, Tiles.T.GRASS)

	if GameState.bridge_built:
		_build_bridge(false)

	# NPC
	var npc: Node2D = NpcScene.instantiate()
	npc.position = npc_pos
	actors.add_child(npc)

	# 도리이
	var goal: Node2D = GoalScript.new()
	goal.position = goal_pos
	actors.add_child(goal)

	# 슬라임
	for sp in slime_spawns:
		_spawn_slime(sp)

	# 플레이어 + 카메라
	player = PlayerScene.instantiate()
	player.set("spawn_point", player_spawn)
	player.position = GameState.saved_position if GameState.has_saved_position else player_spawn
	actors.add_child(player)

	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = MAP[0].length() * TILE
	cam.limit_bottom = MAP.size() * TILE
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


func _set_tile(cell: Vector2i, t: int) -> void:
	ground.set_cell(cell, 0, Vector2i(t, 0))


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

func _bridge_rect() -> Rect2:
	var min_c := bridge_cells[0]
	var max_c := bridge_cells[0]
	for c in bridge_cells:
		min_c = Vector2i(mini(min_c.x, c.x), mini(min_c.y, c.y))
		max_c = Vector2i(maxi(max_c.x, c.x), maxi(max_c.y, c.y))
	return Rect2(Vector2(min_c * TILE), Vector2((max_c - min_c + Vector2i.ONE) * TILE))


## 다리 설계도 안내선: 위·아래 난간 2줄 + 가운데 기둥 2개
func _bridge_guides() -> Array:
	var r := _bridge_rect()
	var left := r.position.x - 6.0
	var right := r.end.x + 6.0
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
	for c in bridge_cells:
		_set_tile(c, Tiles.T.BRIDGE)
	GameState.bridge_built = true
	if animate:
		var r := _bridge_rect()
		var flash := ColorRect.new()
		flash.color = Color(1, 1, 1, 0.9)
		flash.position = r.position
		flash.size = r.size
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.z_index = 50
		add_child(flash)
		var tw := flash.create_tween()
		tw.tween_property(flash, "color:a", 0.0, 0.6)
		tw.tween_callback(flash.queue_free)
