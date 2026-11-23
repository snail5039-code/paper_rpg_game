extends Node2D
## 박물관 안 (내 마을의 박물관 건물에 F 로 들어온다). 기증한 것이 전시된다 (docs/세부설정.md 15).
##  - 안쪽 가운데 안내 데스크(F): 부엉이 관장에게 기증한다 (기증 창, 채운 만큼 보상).
##  - 왼쪽 뒤 수조 둘: 물고기 50종이 헤엄친다.
##  - 오른쪽 뒤 곤충 표본장 셋, 화단 둘, 진열 탁자 둘: 채집물 50종 (곤충 18, 꽃 12, 과일·그 밖의 것 20).
##  - 왼쪽 코르크 판 여섯: 몬스터 스케치 90장. 그 옆 유리 진열장 넷: 장비 모양 60가지.
##  - 전시대 앞에서 F: 그 전시대를 크게 보고, 하나를 누르면 설명이 나온다.
##  - 아래 가운데 문(F): 내 마을로 나간다.
## 전시물은 가구 그림 위에 코드로 그린다 (가구 그림은 비어 있다: tools/import_ui_v7.py 의 86번).

const Art := preload("res://scripts/core/art.gd")
const Data := preload("res://scripts/data/game_data.gd")
const Items := preload("res://scripts/data/items.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const PlayerScene := preload("res://scenes/player.tscn")
const Companion := preload("res://scripts/actors/companion.gd")
const SpotScript := preload("res://scripts/actors/room_spot.gd")
const MD := preload("res://scripts/data/museum_data.gd")
const DISPLAYS := MD.DISPLAYS
const GROUP_NAMES := MD.GROUP_NAMES

const SIZE := Vector2(960, 540)
const FLOOR := Rect2(34, 218, 892, 300)       # 걸을 수 있는 바닥
const DOOR := Vector2(480, 528)
const PROP_K := 0.42                          # 가구 그림 → 월드
const CAMERA_ZOOM := 1.0

const DESK := Vector2(480, 300)
const CURATOR := Vector2(480, 262)

var actors: Node2D
var player: CharacterBody2D
var hud: CanvasLayer
var companion: Node2D
var _bg: Texture2D
var _t := 0.0
var _tex_cache: Dictionary = {}
var _groups: Dictionary = {}      # 전시 묶음 → [id, ...] (가구에 놓는 차례)


func _ready() -> void:
	if get_tree().current_scene == self:
		add_to_group("game_map")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_bg = Art.tex("bg_room_museum")
	_groups = MD.groups()
	_build_walls()
	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)
	for i in DISPLAYS.size():
		var d: Array = DISPLAYS[i]
		actors.add_child(_display(d))
		# 전시대 앞에서 F: 크게 보기
		var look := Node2D.new()
		look.set_script(SpotScript)
		look.set("mode", "view")
		look.set_meta("index", i)
		look.position = (d[1] as Vector2) + Vector2(0, 10)
		actors.add_child(look)
	actors.add_child(_prop("npc_curator", CURATOR, 0.3, false))
	actors.add_child(_prop("prop_desk", DESK, PROP_K, true))
	var desk := Node2D.new()
	desk.set_script(SpotScript)
	desk.set("mode", "use")
	desk.position = DESK + Vector2(0, 14)
	actors.add_child(desk)
	var door := Node2D.new()
	door.set_script(SpotScript)
	door.set("mode", "door")
	door.position = DOOR
	actors.add_child(door)

	player = PlayerScene.instantiate()
	player.set("spawn_point", DOOR + Vector2(0, -26))
	player.position = DOOR + Vector2(0, -26)
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
	add_child(hud)
	_refresh_title()
	hud.call("set_hints", [["key_wasd", "이동"], ["key_f", "데스크: 기증 / 전시대: 크게 보기 / 문: 나가기"]])
	GameState.changed.connect(_refresh_title)
	GameState.tip("museum", "부엉이 관장에게 가방 속 물고기·채집물·몬스터 스케치·장비를 기증하면 여기에 전시돼요.")


func _refresh_title() -> void:
	if hud:
		var n := 0
		var total := 0
		for c in GameState.MUSEUM_CATS:
			n += GameState.museum_count(c)
			total += GameState.museum_entries(c).size()
		hud.set("quest_text_override", "박물관  (전시 %d / %d)" % [n, total])
		hud.call("_refresh")


func _prop(tex_name: String, foot: Vector2, k: float, solid: bool) -> Node2D:
	var body := StaticBody2D.new()
	body.position = foot
	var tex := Art.tex(tex_name)
	var s := Art.make_sprite(body, tex, Vector2.ZERO) if tex else null
	if s:
		s.scale = Vector2.ONE * k
	if solid and tex:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(tex.get_width() * k * 0.92, maxf(8.0, tex.get_height() * k * 0.35))
		shape.shape = rect
		shape.position = Vector2(0, -rect.size.y * 0.5)
		body.add_child(shape)
	return body


## 전시 가구 하나: 가구 그림 + 그 위에 그리는 전시물
func _display(d: Array) -> Node2D:
	var body := _prop(str(d[0]), d[1], PROP_K, true)
	var tex := Art.tex(str(d[0]))
	var shows := Node2D.new()
	shows.set_script(load("res://scripts/maps/museum_display.gd"))
	shows.set("museum", self)
	shows.set("spec", d)
	shows.set("size", Vector2(tex.get_width(), tex.get_height()) * PROP_K if tex else Vector2(60, 60))
	body.add_child(shows)
	return body


## 전시물 하나의 그림 (몬스터는 띠의 첫 칸)
func exhibit_tex(group: String, id: String) -> Texture2D:
	var key := group + ":" + id
	if _tex_cache.has(key):
		return _tex_cache[key]
	var t: Texture2D = null
	match group:
		"fish", "bug", "flower", "thing":
			t = Art.tex(GameState.consumable_icon(id))
		"gear":
			t = Art.tex("equip_" + id)
		"mon":
			var kind := id + "_faded"
			var cfg: Dictionary = Data.MONSTERS.get(kind, {})
			if str(cfg.get("art", "")) == "strip":
				var strip := Art.tex("mon_" + str(cfg["sprite"]))
				if strip:
					var at := AtlasTexture.new()
					at.atlas = strip
					at.region = Rect2(0, 0, strip.get_width() / 6.0, strip.get_height())
					t = at
			elif not cfg.is_empty():
				t = Art.tex(str(cfg["sprite"]) + "_idle")
	_tex_cache[key] = t
	return t


func group_ids(group: String) -> Array:
	return _groups.get(group, [])


func _build_walls() -> void:
	var body := StaticBody2D.new()
	add_child(body)
	var t := 40.0
	for r in [Rect2(FLOOR.position.x - t, FLOOR.position.y - t, FLOOR.size.x + t * 2, t),
			Rect2(FLOOR.position.x - t, FLOOR.end.y, FLOOR.size.x + t * 2, t),
			Rect2(FLOOR.position.x - t, FLOOR.position.y, t, FLOOR.size.y),
			Rect2(FLOOR.end.x, FLOOR.position.y, t, FLOOR.size.y)]:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = (r as Rect2).size
		shape.shape = rect
		shape.position = (r as Rect2).get_center()
		body.add_child(shape)


func _process(delta: float) -> void:
	_t += delta


# room_spot.gd 가 부르는 것들 (데스크는 "use", 문은 "door")
func use_bed() -> void:
	pass


func use_fixture() -> void:
	if hud:
		hud.call("toggle_menu", "donate")


## 전시대 하나를 크게 본다 (room_spot.gd 의 "view")
func use_view(spot: Node) -> void:
	if hud:
		hud.call("open_menu", "exhibit", str(int(spot.get_meta("index", 0))))


func leave() -> void:
	GameState.goto_map("home", "from_room")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.24, 0.2, 0.19))
	if _bg:
		draw_texture_rect(_bg, Rect2(Vector2.ZERO, SIZE), false)
