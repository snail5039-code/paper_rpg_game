extends Node2D
## 내 집 안 (방 한 칸). 내 마을의 내 집에 F 로 들어온다.
##  - 침대(F): 잠자기. 다음 날 아침으로 넘어가고 피로가 풀린다 (한 번 더 눌러 확인).
##  - 문(아래쪽, F): 내 마을로 나간다.
##  - 꾸미기(N): 가진 가구를 골라 놓는다. 가구는 문방구에서 사거나 주민에게 받는다. 치우면 다시 가방으로 돌아온다.

const Art := preload("res://scripts/art.gd")
const Items := preload("res://scripts/items.gd")
const HudScript := preload("res://scripts/hud.gd")
const PlayerScene := preload("res://scenes/player.tscn")
const Companion := preload("res://scripts/companion.gd")

const SIZE := Vector2(640, 360)
const FLOOR := Rect2(56, 128, 528, 196)      # 걸을 수 있는 바닥
const BED_POS := Vector2(120, 176)
const DOOR_POS := Vector2(320, 318)
const CAMERA_ZOOM := 1.0                    # 방 전체가 한 화면에 보인다
const FURN_W := 34.0                         # 가구의 가로 크기 (월드)

var actors: Node2D
var player: CharacterBody2D
var hud: CanvasLayer
var companion: Node2D
var items: Array = []        # 놓은 가구 노드 (GameState.room_items 와 순서가 같다)
var placing := ""
var removing := false
var _ghost: Sprite2D
var _bed_asked := -10.0
var _t := 0.0
var _bg: Texture2D
var _key: Texture2D


func _ready() -> void:
	if get_tree().current_scene == self:
		add_to_group("game_map")
	_bg = Art.tex("bg_room")
	_key = Art.tex("key_f")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_build_walls()
	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)
	_spawn_fixed("furn_1", BED_POS, "bed")
	for o in GameState.room_items:
		_spawn_item(o)
	var door := Node2D.new()
	door.position = DOOR_POS
	door.set_script(preload("res://scripts/room_spot.gd"))
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
	hud.set("quest_text_override", "내 집")
	add_child(hud)
	hud.call("set_hints", [["key_wasd", "이동"], ["", "N 꾸미기"], ["key_f", "침대: 자기 / 문: 나가기"]])
	(hud.call("menu", "furnish") as Control).connect("build_chosen", _on_chosen)


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
	spot.set_script(preload("res://scripts/room_spot.gd"))
	spot.set("mode", mode)
	spot.position = Vector2(0, 8)
	node.add_child(spot)


func _spawn_item(o: Dictionary) -> void:
	# 러그는 밟고 지나갈 수 있다
	items.append(_make(str(o["id"]), Vector2(float(o["x"]), float(o["y"])), str(o["id"]) != "furn_4"))


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
	return FLOOR.grow(-10).has_point(pos) and pos.distance_to(DOOR_POS) > 36.0 and pos.distance_to(BED_POS) > 30.0


func place_at(pos: Vector2) -> bool:
	if placing == "" or GameState.furniture_count(placing) <= 0 or not can_place(pos):
		GameState.notify("여기에는 놓을 수 없어요.")
		return false
	GameState.furniture[placing] = GameState.furniture_count(placing) - 1
	var o := {"id": placing, "x": snappedf(pos.x, 0.1), "y": snappedf(pos.y, 0.1)}
	GameState.room_items.append(o)
	_spawn_item(o)
	GameState.save_game()
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
	GameState.add_furniture(str(GameState.room_items[best]["id"]))
	(items[best] as Node2D).queue_free()
	items.remove_at(best)
	GameState.room_items.remove_at(best)
	GameState.save_game()
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


func leave() -> void:
	GameState.goto_map("home", "from_room")


func _draw() -> void:
	if _bg:
		draw_texture_rect(_bg, Rect2(Vector2.ZERO, SIZE), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.93, 0.87, 0.75))
		draw_rect(FLOOR, Color(0.82, 0.68, 0.5))
