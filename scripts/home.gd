extends Node2D
## 내 마을: 플레이어가 직접 그리는 빈 모눈종이 페이지 (거점).
##  - 크기는 화면 2×2장(1280×720)에서 시작해 종이를 이어 붙여 4×4장까지 넓힌다.
##  - 짓기(N): 건물과 소품을 놓는다. 건물은 자리를 고른 뒤 점선을 따라 그려서 짓는다.
##  - 칠하기 모드(B): 크레용으로 풀밭·길·물을 칠한다. 물은 건널 수 없다.
##  - 연필 모드(Tab): 자유 낙서. 그린 선은 저장되어 바닥에 남는다.
##  - 포탈(책갈피 문): 각 장의 맵으로 들어간다.

const Art := preload("res://scripts/art.gd")
const DrawingScript := preload("res://scripts/drawing_manager.gd")
const HudScript := preload("res://scripts/hud.gd")
const PortalScript := preload("res://scripts/portal.gd")
const PlayerScene := preload("res://scenes/player.tscn")
const Companion := preload("res://scripts/companion.gd")

const CELL := 16.0
const COLS := 160            # 가장 넓을 때(4×4장) 의 칸 수. 바닥 칸은 처음부터 이 크기로 갖고 있다.
const ROWS := 90
const OLD_COLS := 120        # 예전 저장(3×3장 고정)의 칸 수
const OLD_ROWS := 68
const ObjectScript := preload("res://scripts/home_object.gd")
const Data := preload("res://scripts/game_data.gd")
const TracePanel := preload("res://scripts/trace_panel.gd")
const FINE_SCORE := 0.85     # 이만큼 잘 따라 그리면 "정성" 건물
const CAMERA_ZOOM := 1.5
const BRUSH_RADIUS := 18.0

enum Ground { NONE, GRASS, PATH, WATER }
const GROUND_NAMES := ["지우기", "풀밭", "길", "물"]
const GROUND_COLORS := [Color(0, 0, 0, 0), Color(0.72, 0.86, 0.55), Color(0.96, 0.84, 0.6), Color(0.45, 0.72, 0.95)]
const PAPER := Color(0.99, 0.97, 0.9)
const GRID_LINE := Color(0.55, 0.7, 0.9, 0.28)
const GROUND_TEX_NAMES := ["", "ground_grass", "ground_path", "ground_water"]
const GROUND_TEX_SCALE := 2.0   # 질감 2텍셀 = 1 월드 (512px 한 장이 256 월드를 덮는다)

const SPAWN := Vector2(960, 540)
## 포탈: [맵 이름, 표시 이름, 오른쪽 가장자리 가운데에서 떨어진 위치, 열려면 필요한 퀘스트 단계(-1 = 아직 준비 안 됨)]
const PORTALS := [
	["ch1", "1장  공책 마을", Vector2(-140, 0), 0],
	["", "2장  색연필 숲", Vector2(-140, -160), -1],
	["", "3장  물감 호수", Vector2(-140, 160), -1],
]

var size := Vector2(1280, 720)   # 지금 마을 크기 (GameState.home_sheets 에 따라)
var cells := PackedByteArray()
var objects: Array = []          # 지은 것들 (home_object.gd 노드). GameState.home_objects 와 순서가 같다
var placing := ""                # 놓을 자리를 고르는 중인 것의 id
var removing := false            # 치우기 모드
var _ghost: Node2D
var _remove_mark: Node2D          # 치우려고 한 번 누른 것 (빨갛게 보인다)
var _cam: Camera2D
var _walls: StaticBody2D
var actors: Node2D
var player: CharacterBody2D
var hud: CanvasLayer
var companion: Node2D
var drawing: Node2D
var portals: Array = []

var paint_mode := false
var paint_tool: int = Ground.GRASS
var _painting := 0          # 0 안 함, 1 칠하기, 2 지우기
var _dirty_water := false
var _water_body: StaticBody2D
var _cursor: Node2D
## 바닥 질감. _draw 에서 쓰는 텍스처는 여기서 잡고 있어야 한다 (지역 변수로만 두면 그리기 전에 해제되어 하얗게 나온다)
var _ground_tex: Array = [null, null, null, null]


func _ready() -> void:
	if get_tree().current_scene == self:
		add_to_group("game_map")
	cells.resize(COLS * ROWS)
	for i in range(1, GROUND_TEX_NAMES.size()):
		_ground_tex[i] = Art.tex(GROUND_TEX_NAMES[i])
	size = GameState.home_size()
	_load_cells()
	_build_walls()
	_water_body = StaticBody2D.new()
	_water_body.name = "Water"
	add_child(_water_body)
	_rebuild_water()

	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)

	for p in PORTALS:
		var portal: Node2D = PortalScript.new()
		portal.set("target_map", p[0])
		portal.set("title", p[1])
		portal.set("spawn_tag", "from_home")
		portal.set("locked", int(p[3]) < 0)
		portal.position = portal_pos(portals.size())
		actors.add_child(portal)
		portals.append(portal)

	player = PlayerScene.instantiate()
	player.set("spawn_point", SPAWN)
	if GameState.spawn_tag == "from_ch1":
		player.position = portal_pos(0) + Vector2(-60, 10)
	elif GameState.has_saved_position:
		player.position = GameState.saved_position
	else:
		player.position = SPAWN
	GameState.spawn_tag = ""
	actors.add_child(player)
	companion = Companion.attach(actors, player)

	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE * CAMERA_ZOOM
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(size.x)
	cam.limit_bottom = int(size.y)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	player.add_child(cam)
	_cam = cam

	for o in GameState.home_objects:
		_spawn_object(o)

	# 자유 낙서 (연필 모드). 그린 선이 남는다.
	drawing = DrawingScript.new()
	drawing.name = "Drawing"
	drawing.set("persist", true)
	drawing.set("show_guides", false)
	add_child(drawing)
	drawing.set("strokes", _load_doodles())
	drawing.connect("closed", _save_doodles)

	_cursor = Node2D.new()
	_cursor.z_index = 90
	_cursor.draw.connect(_draw_cursor)
	add_child(_cursor)

	hud = HudScript.new()
	hud.name = "HUD"
	hud.set("quest_text_override", "내 마을: 빈 페이지에 마을을 그려 보자")
	add_child(hud)
	(hud.call("menu", "build") as Control).connect("build_chosen", _on_build_chosen)

	if not GameState.home_intro_seen:
		_first_visit.call_deferred()
	else:
		GameState.tip.call_deferred("build", "N 키: 건물과 소품을 짓고, 종이를 붙여 마을을 넓힐 수 있어요.")


func _first_visit() -> void:
	await get_tree().create_timer(0.4, true).timeout
	await GameState.say("나", [
		"여긴… 아무것도 없는 빈 페이지다.",
		"지워진 게 아니라, 아직 아무도 그리지 않은 곳.",
		"여기라면 내가 새로 그릴 수 있을지도 몰라.",
	], "player")
	GameState.notify("B 키로 크레용을 꺼내 바닥을 칠할 수 있어요.")
	GameState.tip("build", "N 키: 건물과 소품을 짓고, 종이를 붙여 마을을 넓힐 수 있어요.")
	GameState.home_intro_seen = true
	GameState.save_game()


# ---------- 바닥 칸 ----------

func cell_at(world: Vector2) -> Vector2i:
	return Vector2i(clampi(int(world.x / CELL), 0, int(size.x / CELL) - 1), clampi(int(world.y / CELL), 0, int(size.y / CELL) - 1))


func get_cell(c: Vector2i) -> int:
	return cells[c.y * COLS + c.x]


func set_cell(c: Vector2i, ground: int) -> void:
	var i := c.y * COLS + c.x
	if cells[i] == ground:
		return
	if cells[i] == Ground.WATER or ground == Ground.WATER:
		_dirty_water = true
	cells[i] = ground
	queue_redraw()


## 월드 좌표 p 주변을 붓 크기만큼 칠한다. 물은 플레이어가 서 있는 자리에는 칠하지 않는다.
func paint_at(p: Vector2, ground: int) -> void:
	var r := BRUSH_RADIUS
	var c0 := cell_at(p - Vector2(r, r))
	var c1 := cell_at(p + Vector2(r, r))
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			var center := Vector2((x + 0.5) * CELL, (y + 0.5) * CELL)
			if center.distance_to(p) > r:
				continue
			if ground == Ground.WATER and is_instance_valid(player) \
					and center.distance_to(player.global_position) < CELL * 1.6:
				continue
			set_cell(Vector2i(x, y), ground)


func count_cells(ground: int) -> int:
	return cells.count(ground)


func finish_painting() -> void:
	if _dirty_water:
		_rebuild_water()
	_save_cells()


func _save_cells() -> void:
	GameState.home_cells = Marshalls.raw_to_base64(cells.compress(FileAccess.COMPRESSION_DEFLATE))
	GameState.save_game()


func _load_cells() -> void:
	if GameState.home_cells == "":
		return
	var raw := Marshalls.base64_to_raw(GameState.home_cells)
	var data := raw.decompress(COLS * ROWS, FileAccess.COMPRESSION_DEFLATE)
	if data.size() == COLS * ROWS:
		cells = data
	elif data.size() == OLD_COLS * OLD_ROWS:
		# 예전 저장: 칸을 새 크기의 왼쪽 위에 옮겨 담는다
		for y in OLD_ROWS:
			for x in OLD_COLS:
				cells[y * COLS + x] = data[y * OLD_COLS + x]


## 물 칸을 가로줄 단위로 묶어 충돌 사각형을 만든다
func _rebuild_water() -> void:
	_dirty_water = false
	for c in _water_body.get_children():
		c.queue_free()
	for y in ROWS:
		var x := 0
		while x < COLS:
			if cells[y * COLS + x] != Ground.WATER:
				x += 1
				continue
			var start := x
			while x < COLS and cells[y * COLS + x] == Ground.WATER:
				x += 1
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2((x - start) * CELL, CELL)
			shape.shape = rect
			shape.position = Vector2((start + x) * 0.5 * CELL, (y + 0.5) * CELL)
			_water_body.add_child(shape)


func water_shape_count() -> int:
	var n := 0
	for c in _water_body.get_children():
		if not c.is_queued_for_deletion():
			n += 1
	return n


func portal_pos(i: int) -> Vector2:
	return Vector2(size.x, size.y * 0.5) + (PORTALS[i][2] as Vector2)


func _build_walls() -> void:
	if is_instance_valid(_walls):
		_walls.queue_free()
	var body := StaticBody2D.new()
	body.name = "Walls"
	add_child(body)
	_walls = body
	var t := 40.0
	for r in [Rect2(-t, -t, size.x + t * 2, t), Rect2(-t, size.y, size.x + t * 2, t),
			Rect2(-t, 0, t, size.y), Rect2(size.x, 0, t, size.y)]:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.get_center()
		body.add_child(shape)


# ---------- 자유 낙서 저장 ----------

func _save_doodles() -> void:
	var out: Array = []
	for s in (drawing.get("strokes") as Array):
		var flat: Array = []
		for p in (s as PackedVector2Array):
			flat.append(snappedf(p.x, 0.1))
			flat.append(snappedf(p.y, 0.1))
		out.append(flat)
	GameState.home_doodles = out
	GameState.save_game()


func _load_doodles() -> Array:
	var out: Array = []
	for flat in GameState.home_doodles:
		var s := PackedVector2Array()
		var arr: Array = flat
		for i in range(0, arr.size() - 1, 2):
			s.append(Vector2(float(arr[i]), float(arr[i + 1])))
		if s.size() >= 1:
			out.append(s)
	return out


# ---------- 칠하기 모드 ----------

func set_paint_mode(on: bool) -> void:
	if on and (GameState.dialogue_open or GameState.cutscene or GameState.draw_mode or GameState.menu_open):
		return
	paint_mode = on
	if not on and _painting != 0:
		_painting = 0
		finish_painting()
	_cursor.queue_redraw()


func _input(event: InputEvent) -> void:
	if GameState.dialogue_open or GameState.cutscene or GameState.draw_mode or GameState.menu_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		if key == KEY_B and placing == "" and not removing:
			set_paint_mode(not paint_mode)
			get_viewport().set_input_as_handled()
			return
		if key == KEY_N and not paint_mode:
			stop_placing()
			hud.call("toggle_menu", "build")
			get_viewport().set_input_as_handled()
			return
		if (placing != "" or removing) and key == KEY_ESCAPE:
			stop_placing()
			get_viewport().set_input_as_handled()
			return
		if paint_mode and key >= KEY_1 and key <= KEY_4:
			paint_tool = [Ground.GRASS, Ground.PATH, Ground.WATER, Ground.NONE][key - KEY_1]
			get_viewport().set_input_as_handled()
			return
		if paint_mode and key == KEY_ESCAPE:
			set_paint_mode(false)
			get_viewport().set_input_as_handled()
			return
	if placing != "" or removing:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if removing:
					remove_at(get_global_mouse_position())
				else:
					place_at(get_global_mouse_position())
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				stop_placing()
			get_viewport().set_input_as_handled()
		return
	if not paint_mode:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_painting = 1 if mb.button_index == MOUSE_BUTTON_LEFT else 2
				_paint_mouse()
			elif _painting != 0:
				_painting = 0
				finish_painting()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _painting != 0:
		_paint_mouse()


func _paint_mouse() -> void:
	paint_at(get_global_mouse_position(), paint_tool if _painting == 1 else Ground.NONE)


func _process(_delta: float) -> void:
	if GameState.draw_mode and paint_mode:
		set_paint_mode(false)
	if is_instance_valid(_ghost):
		_ghost.global_position = get_global_mouse_position()
		_ghost.modulate = Color(1, 1, 1, 0.6) if can_place(placing, _ghost.global_position) else Color(1, 0.4, 0.4, 0.6)
	if placing != "":
		hud.call("set_hints", [["key_mouse_l", "놓기: " + str(Data.BUILDS[placing]["name"])], ["key_mouse_r", "그만"]])
	elif removing:
		hud.call("set_hints", [["key_mouse_l", "치우기"], ["key_mouse_r", "그만"]])
	elif paint_mode:
		_cursor.queue_redraw()
		hud.call("set_hints", [
			["key_mouse_l", "칠하기: " + GROUND_NAMES[paint_tool]], ["key_mouse_r", "지우기"],
			["", "1 풀밭  2 길  3 물  4 지우개"], ["", "B 닫기"]])
	elif GameState.draw_mode:
		hud.call("set_hints", [["key_mouse_l", "낙서하기"], ["key_mouse_r", "지우기"], ["key_tab", "닫기"]])
	else:
		hud.call("set_hints", [["key_wasd", "이동"], ["", "B 칠하기  N 짓기"], ["key_tab", "낙서"], ["key_f", "들어가기"]])


# ---------- 그리기 ----------

func _draw() -> void:
	var cols := mini(COLS, int(size.x / CELL))
	var rows := mini(ROWS, int(size.y / CELL))
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	# 칠한 칸: 조금 겹치는 동그라미로 그려 크레용처럼 가장자리가 울퉁불퉁하게
	for ground in [Ground.GRASS, Ground.PATH, Ground.WATER]:
		var base: Color = GROUND_COLORS[ground]
		var tex: Texture2D = _ground_tex[ground]
		for y in rows:
			for x in cols:
				if cells[y * COLS + x] != ground:
					continue
				if tex:
					# 크레용 질감: 칸 위치에 맞는 부분을 잘라 그려서 칸끼리 무늬가 이어진다
					var src := Vector2(fposmod(x * CELL * GROUND_TEX_SCALE, tex.get_width()),
						fposmod(y * CELL * GROUND_TEX_SCALE, tex.get_height()))
					draw_texture_rect_region(tex, Rect2(x * CELL, y * CELL, CELL + 0.5, CELL + 0.5),
						Rect2(src, Vector2(CELL, CELL) * GROUND_TEX_SCALE))
					continue
				var h := float((x * 73 + y * 151) % 17) / 17.0
				var col := base.lightened(h * 0.08)
				var jitter := Vector2(h - 0.5, float((x * 31 + y * 57) % 13) / 13.0 - 0.5) * 3.0
				draw_circle(Vector2((x + 0.5) * CELL, (y + 0.5) * CELL) + jitter, CELL * 0.74, col)
	# 모눈
	var g := 8.0
	var x2 := 0.0
	while x2 <= size.x:
		draw_line(Vector2(x2, 0), Vector2(x2, size.y), GRID_LINE, 1.0)
		x2 += g
	var y2 := 0.0
	while y2 <= size.y:
		draw_line(Vector2(0, y2), Vector2(size.x, y2), GRID_LINE, 1.0)
		y2 += g
	# 공책 가장자리
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.6, 0.5), false, 4.0)


func _draw_cursor() -> void:
	if not paint_mode:
		return
	var m := get_global_mouse_position()
	var col: Color = GROUND_COLORS[paint_tool] if paint_tool != Ground.NONE else Color(0.9, 0.5, 0.6)
	col.a = 0.45
	_cursor.draw_circle(m, BRUSH_RADIUS, col)
	_cursor.draw_arc(m, BRUSH_RADIUS, 0, TAU, 24, Color(0.3, 0.25, 0.25, 0.8), 1.0)


# ---------- 짓기 (N) ----------

func _spawn_object(o: Dictionary) -> Node2D:
	var node: Node2D = ObjectScript.new()
	node.set("id", str(o["id"]))
	node.set("fine", bool(o.get("fine", false)))
	node.position = Vector2(float(o["x"]), float(o["y"]))
	actors.add_child(node)
	objects.append(node)
	return node


## 짓기 창에서 고른 것: "expand" 넓히기, "" 치우기, 그 밖은 놓을 것의 id
func _on_build_chosen(id: String) -> void:
	if bool(hud.call("is_menu_open", "build")):
		hud.call("toggle_menu", "build")
	if id == "expand":
		expand()
	elif id == "":
		stop_placing()
		removing = true
	else:
		start_placing(id)


func start_placing(id: String) -> void:
	stop_placing()
	if not Data.BUILDS.has(id):
		return
	set_paint_mode(false)
	placing = id
	_ghost = ObjectScript.new()
	_ghost.set("id", id)
	_ghost.set("ghost", true)
	_ghost.z_index = 80
	add_child(_ghost)


func stop_placing() -> void:
	placing = ""
	removing = false
	if is_instance_valid(_remove_mark):
		_remove_mark.modulate = Color.WHITE
	_remove_mark = null
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null


func can_place(id: String, pos: Vector2) -> bool:
	return place_error(id, pos) == ""


## 놓을 수 없는 까닭 (놓을 수 있으면 빈 글): 마을 밖, 물 위, 다른 것과 겹침, 값이 모자람
func place_error(id: String, pos: Vector2) -> String:
	if not Data.BUILDS.has(id):
		return "지을 수 없는 것이에요."
	var info: Dictionary = Data.BUILDS[id]
	var half := float(info["w"]) * 0.5
	if pos.x < half + 8 or pos.x > size.x - half - 8 or pos.y < 60 or pos.y > size.y - 12:
		return "마을 가장자리 밖이에요. 조금 안쪽에 놓아 주세요."
	if get_cell(cell_at(pos)) == Ground.WATER and not bool(info.get("walk", false)):
		return "물 위에는 놓을 수 없어요."
	for o in objects:
		var other := o as Node2D
		var gap := half + float((other.get("info") as Dictionary)["w"]) * 0.5
		if absf(other.position.x - pos.x) < gap * 0.8 and absf(other.position.y - pos.y) < 14.0:
			return "다른 것과 겹쳐요."
	for p in portals:
		if (p as Node2D).position.distance_to(pos) < half + 30.0:
			return "문 앞은 비워 둬야 해요."
	if not GameState.can_afford(info["cost"]):
		return "값이 모자라요. (%s)" % GameState.cost_text(info["cost"])
	return ""


## pos 에 지금 고른 것을 놓는다. 건물은 점선을 따라 그린 뒤에 지어진다. score 를 주면 그리기를 건너뛴다 (테스트).
func place_at(pos: Vector2, score: float = -2.0) -> bool:
	var id := placing
	if id == "":
		return false
	var why := place_error(id, pos)
	if why != "":
		GameState.notify(why)
		return false
	var info: Dictionary = Data.BUILDS[id]
	var fine := false
	if str(info["kind"]) == "building":
		if score <= -2.0:
			var panel: Control = hud.call("trace_panel")
			if is_instance_valid(_ghost):
				_ghost.visible = false
			panel.call("start", "%s 짓기" % info["name"], TracePanel.house(Rect2(245, 170, 150, 100)), 8.0,
				Art.tex(id), Rect2(220, 80, 200, 200), Color(1, 1, 1, 0.3))
			score = await panel.finished
			if is_instance_valid(_ghost):
				_ghost.visible = true
		if score < 0.0:
			return false          # 그만뒀다
		fine = score >= FINE_SCORE
	if not GameState.pay(info["cost"]):
		return false
	var o := {"id": id, "x": snappedf(pos.x, 0.1), "y": snappedf(pos.y, 0.1), "fine": fine}
	GameState.home_objects.append(o)
	_spawn_object(o)
	GameState.save_game()
	if str(info["kind"]) == "building":
		GameState.notify("%s 을(를) 지었어요!%s" % [info["name"], "  정성이 가득해요. (%d%%)" % roundi(score * 100.0) if fine else ""])
		stop_placing()
	elif not GameState.can_afford(info["cost"]):
		stop_placing()
	return true


## pos 에서 가장 가까운 것을 치운다. 값의 절반을 돌려받는다.
## 실수로 치우지 않게, 같은 것을 한 번 더 눌러야 치워진다 (sure 를 주면 바로).
func remove_at(pos: Vector2, sure: bool = false) -> bool:
	var best := -1
	var best_d := 26.0
	for i in objects.size():
		var d := ((objects[i] as Node2D).position + Vector2(0, -8)).distance_to(pos)
		if d < best_d:
			best = i
			best_d = d
	if best < 0:
		return false
	var info: Dictionary = (objects[best] as Node2D).get("info")
	if not sure and not is_same(_remove_mark, objects[best]):
		if is_instance_valid(_remove_mark):
			_remove_mark.modulate = Color.WHITE
		_remove_mark = objects[best]
		_remove_mark.modulate = Color(1.0, 0.55, 0.55)
		GameState.notify("%s: 한 번 더 누르면 치워요. (값의 절반을 돌려받아요)" % info["name"])
		return false
	_remove_mark = null
	GameState.pencil_lead += int(info["cost"].get("lead", 0)) / 2
	GameState.add_coins(int(info["cost"].get("coins", 0)) / 2)
	(objects[best] as Node2D).queue_free()
	objects.remove_at(best)
	GameState.home_objects.remove_at(best)
	GameState.save_game()
	return true


## 종이를 이어 붙여 마을을 넓힌다
func expand() -> bool:
	if not GameState.expand_home():
		GameState.notify("연필심이나 동전이 모자라요.")
		return false
	size = GameState.home_size()
	_build_walls()
	_cam.limit_right = int(size.x)
	_cam.limit_bottom = int(size.y)
	for i in portals.size():
		(portals[i] as Node2D).position = portal_pos(i)
	queue_redraw()
	GameState.save_game()
	GameState.notify("종이를 이어 붙였어요. 마을이 %d장으로 넓어졌어요." % GameState.home_sheets)
	return true
