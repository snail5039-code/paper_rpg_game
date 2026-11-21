extends Node
## 내 마을 테스트 + 화면 캡처.
## 실행: godot --headless --path . res://tests/test_home.tscn
##       godot --path . res://tests/test_home.tscn -- <캡처 폴더>   (캡처도 저장)

const HomeScene := preload("res://scenes/home.tscn")

var passed := 0
var failed := 0
var _dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(ok: bool, text: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", text])


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func shot(file: String) -> void:
	if _dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_dir.path_join(file))


func key(code: int) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = down
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await frames(2)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else ""
	GameState.save_path = "user://test_home_save.json"
	GameState.home_cells = ""
	GameState.home_doodles = []
	GameState.home_intro_seen = true
	GameState.has_saved_position = false
	GameState.spawn_tag = ""
	GameState.quest = GameState.Quest.CLEARED

	print("[내 마을]")
	var home: Node2D = HomeScene.instantiate()
	add_child(home)
	await frames(5)
	var player: Node2D = home.get("player")
	var G: Dictionary = home.get("Ground")
	check(player != null and player.global_position.distance_to(Vector2(960, 540)) < 2.0, "빈 페이지 가운데에서 시작")
	check(int(home.call("count_cells", G.GRASS)) == 0, "처음에는 아무것도 칠해져 있지 않음")

	print("[바닥 칠하기]")
	await key(KEY_B)
	check(bool(home.get("paint_mode")), "B 키로 칠하기 모드")
	for i in 30:
		home.call("paint_at", Vector2(700 + i * 12, 600), G.GRASS)
	for i in 30:
		home.call("paint_at", Vector2(700 + i * 12, 520), G.PATH)
	check(int(home.call("count_cells", G.GRASS)) > 40, "풀밭이 칠해짐 (%d칸)" % int(home.call("count_cells", G.GRASS)))
	check(int(home.call("count_cells", G.PATH)) > 40, "길이 칠해짐")
	await key(KEY_3)
	check(int(home.get("paint_tool")) == G.WATER, "숫자 키로 도구 바꾸기 (물)")
	for i in 20:
		home.call("paint_at", Vector2(1080, 380 + i * 12), G.WATER)
	home.call("paint_at", player.global_position, G.WATER)
	var pc: Vector2i = home.call("cell_at", player.global_position)
	check(int(home.call("get_cell", pc)) != G.WATER, "플레이어가 선 자리에는 물이 칠해지지 않음")
	home.call("finish_painting")
	await frames(3)
	check(int(home.call("water_shape_count")) > 5, "물에 충돌이 생김 (%d개)" % int(home.call("water_shape_count")))
	await shot("home_1_paint.png")
	await key(KEY_B)
	check(not bool(home.get("paint_mode")), "B 키로 칠하기 모드 닫기")

	# 물은 건널 수 없다
	player.global_position = Vector2(1030, 480)
	await frames(2)
	Input.action_press("move_right")
	await frames(80)
	Input.action_release("move_right")
	check(player.global_position.x < 1080.0, "물은 건널 수 없음 (x=%.0f)" % player.global_position.x)

	print("[자유 낙서]")
	var drawing: Node2D = home.get("drawing")
	drawing.call("set_active", true)
	drawing.set("strokes", [PackedVector2Array([Vector2(900, 620), Vector2(940, 600), Vector2(980, 620)])])
	drawing.call("set_active", false)
	await frames(2)
	check((drawing.get("strokes") as Array).size() == 1, "연필 모드를 닫아도 낙서가 남음")
	check(GameState.home_doodles.size() == 1, "낙서가 저장 데이터에 들어감")

	print("[포탈]")
	var portals: Array = home.get("portals")
	check(portals.size() >= 2 and not bool(portals[0].get("locked")) and bool(portals[1].get("locked")),
		"1장 포탈은 열려 있고 2장 포탈은 잠겨 있음")
	player.global_position = (portals[0] as Node2D).global_position + Vector2(-40, 8)
	await frames(20)
	await shot("home_2_portal.png")

	print("[저장/불러오기]")
	var grass_before := int(home.call("count_cells", G.GRASS))
	check(GameState.save_game(), "저장 성공")
	GameState.home_cells = ""
	GameState.home_doodles = []
	check(GameState.load_game() and GameState.home_cells != "", "불러오기 성공")
	home.queue_free()
	await frames(3)
	home = HomeScene.instantiate()
	add_child(home)
	await frames(5)
	check(int(home.call("count_cells", G.GRASS)) == grass_before, "다시 열어도 칠한 바닥이 그대로 (%d칸)" % grass_before)
	check(((home.get("drawing") as Node2D).get("strokes") as Array).size() == 1, "다시 열어도 낙서가 그대로")
	check(int(home.call("water_shape_count")) > 5, "다시 열어도 물 충돌이 있음")
	(home.get("player") as Node2D).global_position = Vector2(900, 560)
	await frames(30)
	await shot("home_3_reload.png")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	print("\n결과: %d 통과 / %d 실패" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
