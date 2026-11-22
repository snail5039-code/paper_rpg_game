extends Node2D
## 내 마을: 플레이어가 직접 그리는 빈 모눈종이 페이지 (거점).
##  - 크기는 화면 3×3장 (1920×1080 월드).
##  - 칠하기 모드(B): 크레용으로 풀밭·길·물을 칠한다. 물은 건널 수 없다.
##  - 연필 모드(Tab): 자유 낙서. 그린 선은 저장되어 바닥에 남는다.
##  - 포탈(책갈피 문): 각 장의 맵으로 들어간다.

const Art := preload("res://scripts/art.gd")
const DrawingScript := preload("res://scripts/drawing_manager.gd")
const HudScript := preload("res://scripts/hud.gd")
const PortalScript := preload("res://scripts/portal.gd")
const PlayerScene := preload("res://scenes/player.tscn")

const SIZE := Vector2(1920, 1080)
const CELL := 16.0
const COLS := 120
const ROWS := 68
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
## 포탈: [맵 이름, 표시 이름, 위치, 열려면 필요한 퀘스트 단계(-1 = 아직 준비 안 됨)]
const PORTALS := [
	["ch1", "1장  공책 마을", Vector2(1780, 540), 0],
	["", "2장  색연필 숲", Vector2(1780, 380), -1],
	["", "3장  물감 호수", Vector2(1780, 700), -1],
]

var cells := PackedByteArray()
var actors: Node2D
var player: CharacterBody2D
var hud: CanvasLayer
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
		portal.position = p[2]
		actors.add_child(portal)
		portals.append(portal)

	player = PlayerScene.instantiate()
	player.set("spawn_point", SPAWN)
	if GameState.spawn_tag == "from_ch1":
		player.position = (PORTALS[0][2] as Vector2) + Vector2(-60, 10)
	elif GameState.has_saved_position:
		player.position = GameState.saved_position
	else:
		player.position = SPAWN
	GameState.spawn_tag = ""
	actors.add_child(player)

	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE * CAMERA_ZOOM
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(SIZE.x)
	cam.limit_bottom = int(SIZE.y)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	player.add_child(cam)

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

	if not GameState.home_intro_seen:
		_first_visit.call_deferred()


func _first_visit() -> void:
	await get_tree().create_timer(0.4, true).timeout
	await GameState.say("나", [
		"여긴… 아무것도 없는 빈 페이지다.",
		"지워진 게 아니라, 아직 아무도 그리지 않은 곳.",
		"여기라면 내가 새로 그릴 수 있을지도 몰라.",
	], "player")
	GameState.notify("B 키로 크레용을 꺼내 바닥을 칠할 수 있어요.")
	GameState.home_intro_seen = true
	GameState.save_game()


# ---------- 바닥 칸 ----------

func cell_at(world: Vector2) -> Vector2i:
	return Vector2i(clampi(int(world.x / CELL), 0, COLS - 1), clampi(int(world.y / CELL), 0, ROWS - 1))


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


func _build_walls() -> void:
	var body := StaticBody2D.new()
	body.name = "Walls"
	add_child(body)
	var t := 40.0
	for r in [Rect2(-t, -t, SIZE.x + t * 2, t), Rect2(-t, SIZE.y, SIZE.x + t * 2, t),
			Rect2(-t, 0, t, SIZE.y), Rect2(SIZE.x, 0, t, SIZE.y)]:
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
		if key == KEY_B:
			set_paint_mode(not paint_mode)
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
	if paint_mode:
		_cursor.queue_redraw()
		hud.call("set_hints", [
			["key_mouse_l", "칠하기: " + GROUND_NAMES[paint_tool]], ["key_mouse_r", "지우기"],
			["", "1 풀밭  2 길  3 물  4 지우개"], ["", "B 닫기"]])
	elif GameState.draw_mode:
		hud.call("set_hints", [["key_mouse_l", "낙서하기"], ["key_mouse_r", "지우기"], ["key_tab", "닫기"]])
	else:
		hud.call("set_hints", [["key_wasd", "이동"], ["", "B 바닥 칠하기"], ["key_tab", "낙서"], ["key_f", "문으로 들어가기"]])


# ---------- 그리기 ----------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), PAPER)
	# 칠한 칸: 조금 겹치는 동그라미로 그려 크레용처럼 가장자리가 울퉁불퉁하게
	for ground in [Ground.GRASS, Ground.PATH, Ground.WATER]:
		var base: Color = GROUND_COLORS[ground]
		var tex: Texture2D = _ground_tex[ground]
		for y in ROWS:
			for x in COLS:
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
	while x2 <= SIZE.x:
		draw_line(Vector2(x2, 0), Vector2(x2, SIZE.y), GRID_LINE, 1.0)
		x2 += g
	var y2 := 0.0
	while y2 <= SIZE.y:
		draw_line(Vector2(0, y2), Vector2(SIZE.x, y2), GRID_LINE, 1.0)
		y2 += g
	# 공책 가장자리
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.75, 0.6, 0.5), false, 4.0)


func _draw_cursor() -> void:
	if not paint_mode:
		return
	var m := get_global_mouse_position()
	var col: Color = GROUND_COLORS[paint_tool] if paint_tool != Ground.NONE else Color(0.9, 0.5, 0.6)
	col.a = 0.45
	_cursor.draw_circle(m, BRUSH_RADIUS, col)
	_cursor.draw_arc(m, BRUSH_RADIUS, 0, TAU, 24, Color(0.3, 0.25, 0.25, 0.8), 1.0)
