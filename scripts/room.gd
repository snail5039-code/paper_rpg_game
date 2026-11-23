extends Node2D
## 건물 안 (방 한 칸). 내 마을의 지붕 있는 건물에 F 로 들어온다. 어느 건물인지는 GameState.room_ctx.
##  - 내 집: 침대(F)에서 잔다. 다음 날 아침으로 넘어가고 피로가 풀린다 (한 번 더 눌러 확인).
##  - 문방구·조합대·창고·식당: 안쪽 가운데의 계산대·작업대·상자·솥(F)에서 그 건물의 창이 열린다.
##  - 주민 집: 안에 사는 주민에게 말을 건다.
##  - 문(아래쪽, F): 내 마을로 나간다.
##  - 꾸미기(N): 가진 가구를 골라 놓는다. 가구는 문방구에서 사거나 주민에게 받는다. 치우면 다시 가방으로 돌아온다.
## 건물의 단계가 오르면 방이 넓어지고 (Data.ROOM_SCALE) 가구를 더 많이 놓을 수 있다 (Data.ROOM_FURN_CAP).
## 가구의 자리는 5단계(가장 넓은) 방을 기준으로 저장하고, 보여 줄 때 방의 크기에 맞춰 옮긴다.

const Art := preload("res://scripts/art.gd")
const Data := preload("res://scripts/game_data.gd")
const Items := preload("res://scripts/items.gd")
const HudScript := preload("res://scripts/hud.gd")
const PlayerScene := preload("res://scenes/player.tscn")
const Companion := preload("res://scripts/companion.gd")
const SpotScript := preload("res://scripts/room_spot.gd")
const DoodleCanvas := preload("res://scripts/doodle_canvas.gd")
const PICTURE_W := 17.0     # 액자 안에 거는 그림의 크기 (월드)
const PICTURE_Y := -10.0    # 액자 안쪽의 가운데 (가구의 발에서 위로)

const SIZE := Vector2(640, 360)
const FULL_FLOOR := Rect2(56, 128, 528, 196)   # 걸을 수 있는 바닥 (5단계 방 기준)
const FULL_BED := Vector2(120, 176)
const FULL_DOOR := Vector2(320, 318)
const FULL_FIX := Vector2(320, 214)            # 계산대·작업대·상자·솥의 앞, 주민이 서는 깔개 (방 그림의 안쪽 가운데)
## 건물마다 방 그림의 벽 높이가 달라서 바닥이 시작하는 높이도 다르다 (가게 방은 계산대·선반이 벽 앞을 차지한다)
const FLOOR_TOP := {"sleep": 128.0, "villager": 174.0}
const FLOOR_TOP_SHOP := 200.0
const CAMERA_ZOOM := 1.0                      # 방 전체가 한 화면에 보인다
const FURN_W := 34.0                           # 가구의 가로 크기 (월드)
const TITLES := {"sleep": "내 집", "shop": "문방구 안", "craft": "조합대 안", "storage": "창고 안", "cook": "식당 안", "villager": "주민 집 안"}
const FIX_HINT := {"sleep": "침대: 자기", "shop": "계산대: 물건 사기", "craft": "작업대: 만들기", "storage": "상자: 창고 열기",
	"cook": "솥: 요리하기", "villager": "주민: 말 걸기"}

var bld_id := "bld_house"    # 어느 건물 안인지
var key := ""                # 그 건물의 자리 (GameState.house_key)
var use := "sleep"           # 그 건물이 하는 일 (Data.BUILDS 의 "use")
var lv := 3                  # 그 건물의 단계
var k := 1.0                 # 방의 크기 (1 이 5단계)
var FLOOR := FULL_FLOOR      # 지금 방의 바닥
var BED_POS := FULL_BED
var DOOR_POS := FULL_DOOR
var FIX_POS := FULL_FIX
var actors: Node2D
var player: CharacterBody2D
var hud: CanvasLayer
var companion: Node2D
var items: Array = []        # 놓은 가구 노드 (GameState.room_list 와 순서가 같다)
var placing := ""
var removing := false
var _ghost: Sprite2D
var _bed_asked := -10.0
var _t := 0.0
var _bg: Texture2D
var _key: Texture2D
var _canvas: Control        # 액자 그림판


## 5단계 방 기준의 자리를 지금 방의 자리로 (방은 화면 가운데를 중심으로 줄어든다)
func at(p: Vector2) -> Vector2:
	return SIZE * 0.5 + (p - SIZE * 0.5) * k


## 지금 방의 자리를 5단계 방 기준의 자리로 (저장할 때)
func full(p: Vector2) -> Vector2:
	return SIZE * 0.5 + (p - SIZE * 0.5) / k


## 이 방에 놓은 가구 목록 (GameState 의 것 그대로)
func stored() -> Array:
	return GameState.room_list(key, bld_id)


func furn_cap() -> int:
	return int(Data.ROOM_FURN_CAP[lv - 1])


func _ready() -> void:
	if get_tree().current_scene == self:
		add_to_group("game_map")
	# 어느 건물인지: 들어올 때 적어 둔 것. 없으면 (테스트에서 방만 띄웠을 때) 내 집.
	var ctx: Dictionary = GameState.room_ctx
	if Data.ROOMS.has(str(ctx.get("id", ""))):
		bld_id = str(ctx["id"])
		key = str(ctx.get("key", ""))
	use = str(Data.BUILDS[bld_id]["use"])
	var o := GameState.object_at(key)
	lv = clampi(int(o.get("lv", 3)) if not o.is_empty() else GameState.build_lv(bld_id), 1, Data.BUILD_MAX_LV)
	k = float(Data.ROOM_SCALE[lv - 1])
	var top := float(FLOOR_TOP.get(use, FLOOR_TOP_SHOP))
	var whole := Rect2(FULL_FLOOR.position.x, top, FULL_FLOOR.size.x, FULL_FLOOR.end.y - top)
	FLOOR = Rect2(at(whole.position), whole.size * k)
	BED_POS = at(FULL_BED)
	DOOR_POS = at(FULL_DOOR)
	FIX_POS = at(FULL_FIX)
	_bg = Art.tex(str(Data.ROOMS[bld_id]))
	if _bg == null:
		_bg = Art.tex("bg_room")
	_key = Art.tex("key_f")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_build_walls()
	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)
	if use == "sleep":
		_spawn_fixed("furn_1", BED_POS, "bed")
	else:
		_spawn_fixture()
	for it in stored():
		_spawn_item(it)
	var door := Node2D.new()
	door.position = DOOR_POS
	door.set_script(SpotScript)
	door.set("mode", "door")
	actors.add_child(door)

	player = PlayerScene.instantiate()
	player.set("spawn_point", DOOR_POS + Vector2(0, -24))
	player.position = DOOR_POS + Vector2(0, -24)
	GameState.spawn_tag = ""
	actors.add_child(player)
	companion = Companion.attach(actors, player)
	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE * CAMERA_ZOOM
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(SIZE.x)
	cam.limit_bottom = int(SIZE.y)
	player.add_child(cam)

	hud = HudScript.new()
	hud.name = "HUD"
	hud.set("quest_text_override", "%s  (%d단계 %s · 가구 %d/%d)" % [TITLES.get(use, "건물 안"), lv, Data.BUILD_LV_NAMES[lv - 1], stored().size(), furn_cap()])
	add_child(hud)
	hud.call("set_hints", [["key_wasd", "이동"], ["", "N 꾸미기"], ["key_f", "%s / 문: 나가기" % FIX_HINT.get(use, "")]])
	(hud.call("menu", "furnish") as Control).connect("build_chosen", _on_chosen)


func _title() -> void:
	hud.set("quest_text_override", "%s  (%d단계 %s · 가구 %d/%d)" % [TITLES.get(use, "건물 안"), lv, Data.BUILD_LV_NAMES[lv - 1], stored().size(), furn_cap()])
	GameState.changed.emit()


func _build_walls() -> void:
	var body := StaticBody2D.new()
	add_child(body)
	var t := 60.0
	for r in [Rect2(FLOOR.position.x - t, FLOOR.position.y - t, FLOOR.size.x + t * 2, t), Rect2(FLOOR.position.x - t, FLOOR.end.y, FLOOR.size.x + t * 2, t),
			Rect2(FLOOR.position.x - t, FLOOR.position.y, t, FLOOR.size.y), Rect2(FLOOR.end.x, FLOOR.position.y, t, FLOOR.size.y)]:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		shape.position = r.get_center()
		body.add_child(shape)


func _make(id: String, pos: Vector2, solid: bool) -> StaticBody2D:
	var node := StaticBody2D.new()
	node.position = pos
	node.collision_layer = 1 if solid else 0
	var tex := Art.tex(id)
	if tex:
		var s := Art.make_sprite(node, tex, Vector2(0, 4))
		s.scale = Vector2.ONE * (FURN_W / tex.get_width())
	if solid:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(FURN_W * 0.8, 10)
		shape.shape = rect
		node.add_child(shape)
	actors.add_child(node)
	return node


func _spawn_fixed(id: String, pos: Vector2, mode: String) -> void:
	var node := _make(id, pos, true)
	var spot := Node2D.new()
	spot.set_script(SpotScript)
	spot.set("mode", mode)
	spot.position = Vector2(0, 8)
	node.add_child(spot)


## 내 집이 아닌 건물: 방 그림 안쪽 가운데의 계산대·작업대·상자·솥 앞에 F 자리를 둔다. 주민 집에는 주민이 서 있다.
func _spawn_fixture() -> void:
	var spot := Node2D.new()
	spot.set_script(SpotScript)
	spot.set("mode", "use")
	spot.position = FIX_POS + Vector2(0, 0 if use == "villager" else -8)
	actors.add_child(spot)
	if use == "villager":
		# 주민 집에는 계산대 대신 주민이 서 있다
		var who := GameState.resident_of(key)
		var tex := Art.tex(str(GameState.villager_info(who)["sprite"])) if who != "" else null
		if tex:
			var body := Node2D.new()
			body.position = FIX_POS + Vector2(0, -6)
			actors.add_child(body)
			Art.make_sprite(body, tex)
		return


func _spawn_item(o: Dictionary) -> void:
	# 러그는 밟고 지나갈 수 있다. 저장된 자리는 5단계 방 기준이다.
	var node := _make(str(o["id"]), at(Vector2(float(o["x"]), float(o["y"]))), str(o["id"]) != "furn_4")
	items.append(node)
	# 액자: 앞에서 F 로 내 낙서를 건다. 건 그림은 액자 안에 보인다.
	if str(o["id"]) == GameState.FRAME_ID:
		var spot := Node2D.new()
		spot.set_script(SpotScript)
		spot.set("mode", "frame")
		spot.position = Vector2(0, 8)
		node.add_child(spot)
		_show_picture(node, str(o.get("art", "")))


## 액자 안의 그림을 바꾼다 (액자 그림의 안쪽: 가운데에서 조금 위)
func _show_picture(node: Node2D, art: String) -> void:
	var old := node.get_node_or_null("Picture")
	if old:
		old.queue_free()
	var tex := Art.tex(art) if art != "" else null
	if tex == null:
		return
	var pic := Sprite2D.new()
	pic.name = "Picture"
	pic.texture = tex
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.scale = Vector2.ONE * (PICTURE_W / tex.get_width())
	pic.position = Vector2(0, PICTURE_Y)
	node.add_child(pic)


## 액자 앞에서 F: 그림판을 열고, 완성하면 그 액자에 건다
func use_frame(spot: Node) -> void:
	var i := items.find(spot.get_parent())
	if i < 0 or is_instance_valid(_canvas):
		return
	_canvas = DoodleCanvas.new()
	_canvas.call("setup", "액자에 걸 그림", "그린 그림이 액자 안에 도트로 걸려요." if str(stored()[i].get("art", "")) == "" else "새로 그리면 지금 그림과 바뀌어요.")
	hud.add_child(_canvas)
	GameState.set_menu_open(true)
	_canvas.connect("done", func(art: String) -> void:
		GameState.set_menu_open(false)
		if art != "" and GameState.hang_frame(key, bld_id, i, art):
			_show_picture(items[i] as Node2D, art)
			GameState.notify("액자에 그림을 걸었어요."))


## 꾸미기 창에서 고른 것: "" 은 치우기, 그 밖은 놓을 가구
func _on_chosen(id: String) -> void:
	if bool(hud.call("is_menu_open", "furnish")):
		hud.call("toggle_menu", "furnish")
	stop_placing()
	if id == "":
		removing = true
	elif GameState.furniture_count(id) > 0:
		placing = id
		_ghost = Sprite2D.new()
		_ghost.texture = Art.tex(id)
		if _ghost.texture:
			_ghost.scale = Vector2.ONE * (FURN_W / _ghost.texture.get_width())
			_ghost.offset = Vector2(0, -_ghost.texture.get_height() * 0.5)
		_ghost.modulate = Color(1, 1, 1, 0.6)
		_ghost.z_index = 50
		add_child(_ghost)


func stop_placing() -> void:
	placing = ""
	removing = false
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null


func can_place(pos: Vector2) -> bool:
	var fixed := BED_POS if use == "sleep" else FIX_POS
	return FLOOR.grow(-10).has_point(pos) and pos.distance_to(DOOR_POS) > 36.0 and pos.distance_to(fixed) > 30.0


func place_at(pos: Vector2) -> bool:
	if placing == "" or GameState.furniture_count(placing) <= 0:
		return false
	if stored().size() >= furn_cap():
		GameState.notify("이 방에는 가구를 %d개까지 놓을 수 있어요. 건물을 올리면 방이 넓어져요. (지금 %d단계)" % [furn_cap(), lv])
		stop_placing()
		return false
	if not can_place(pos):
		GameState.notify("여기에는 놓을 수 없어요.")
		return false
	GameState.furniture[placing] = GameState.furniture_count(placing) - 1
	var home := full(pos)
	var o := {"id": placing, "x": snappedf(home.x, 0.1), "y": snappedf(home.y, 0.1)}
	stored().append(o)
	_spawn_item(o)
	GameState.save_game()
	_title()
	if GameState.furniture_count(placing) <= 0:
		stop_placing()
	return true


## pos 에서 가장 가까운 가구를 치워 가방으로 돌려보낸다
func remove_at(pos: Vector2) -> bool:
	var best := -1
	var best_d := 24.0
	for i in items.size():
		var d := ((items[i] as Node2D).position + Vector2(0, -8)).distance_to(pos)
		if d < best_d:
			best = i
			best_d = d
	if best < 0:
		return false
	GameState.add_furniture(str(stored()[best]["id"]))
	(items[best] as Node2D).queue_free()
	items.remove_at(best)
	stored().remove_at(best)
	GameState.save_game()
	_title()
	return true


func _input(event: InputEvent) -> void:
	if GameState.dialogue_open or GameState.cutscene or GameState.draw_mode or GameState.menu_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_N:
			stop_placing()
			hud.call("toggle_menu", "furnish")
			get_viewport().set_input_as_handled()
		elif (placing != "" or removing) and event.physical_keycode == KEY_ESCAPE:
			stop_placing()
			get_viewport().set_input_as_handled()
	elif (placing != "" or removing) and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if removing:
				remove_at(get_global_mouse_position())
			else:
				place_at(get_global_mouse_position())
		else:
			stop_placing()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(_ghost):
		_ghost.global_position = get_global_mouse_position()
		_ghost.modulate = Color(1, 1, 1, 0.6) if can_place(_ghost.global_position) else Color(1, 0.4, 0.4, 0.6)


## 침대: 3초 안에 한 번 더 눌러야 잔다
func use_bed() -> void:
	if _t - _bed_asked > 3.0:
		_bed_asked = _t
		GameState.notify("잠을 자면 다음 날 아침이 돼요. 한 번 더 F 를 누르면 자요.")
		return
	_bed_asked = -10.0
	GameState.sleep()
	player.set("hp", player.get("max_hp"))
	player.set("mp", float(player.get("max_mp")))
	player.emit_signal("hp_changed", player.get("hp"), player.get("max_hp"))
	GameState.notify("푹 잤어요. HP 와 MP 가 가득 찼고 저장했어요.")


## 계산대·작업대·상자·솥·주민: 그 건물의 창을 연다
func use_fixture() -> void:
	match use:
		"shop":
			hud.call("open_shop", 0)
		"craft":
			hud.call("open_shop", 2)
		"storage":
			hud.call("toggle_menu", "storage")
		"cook":
			hud.call("open_menu", "cook", "")
		"villager":
			var who := GameState.resident_of(key)
			if who == "":
				GameState.notify("빈 집이에요. 1장 마을 사람의 부탁을 들어주면 이사 와요.")
			else:
				hud.call("open_menu", "resident", who)


func leave() -> void:
	GameState.goto_map("home", "from_room")


func _draw() -> void:
	# 방 밖은 어두운 종이. 방 그림은 단계에 맞춰 가운데에 작게 또는 크게 그린다.
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.24, 0.2, 0.19))
	var room := Rect2(at(Vector2.ZERO), SIZE * k)
	if _bg:
		draw_texture_rect(_bg, room, false)
	else:
		draw_rect(room, Color(0.93, 0.87, 0.75))
		draw_rect(FLOOR, Color(0.82, 0.68, 0.5))
