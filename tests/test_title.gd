extends Node
## 시작 화면, 캐릭터 칸, 설정, 소리, 장비 겉모습 테스트 + 화면 캡처.
## 실행: godot --headless --path . res://tests/test_title.tscn
##       godot --path . res://tests/test_title.tscn -- <캡처 폴더>
## 실제 저장 파일을 건드리지 않게 user://test_title/ 폴더에서만 쓴다.

const TitleScene := preload("res://scenes/title.tscn")
const MainScene := preload("res://scenes/main.tscn")
const Items := preload("res://scripts/items.gd")
const DIR := "user://test_title/"

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


func wipe() -> void:
	var d := DirAccess.open(DIR)
	if d:
		for f in d.get_files():
			d.remove(f)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else ""
	wipe()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	GameState.save_dir = DIR
	GameState.settings = {"master": 0.8, "music": 0.6, "sfx": 0.8, "fullscreen": false, "last_slot": 0}

	print("[캐릭터 칸과 같이 쓰는 저장]")
	check(GameState.slot_info(1).is_empty(), "처음에는 칸이 비어 있음")
	GameState.call("_reset_state")
	GameState.slot = 1
	GameState.save_path = GameState.slot_path(1)
	GameState.level = 5
	GameState.day = 3
	GameState.coins = 77
	GameState.home_sheets = 6
	GameState.storage = [Items.make("hat", 0, 0, 1)]
	check(GameState.save_game(), "1번 칸에 저장")
	check(FileAccess.file_exists(DIR + "slot_1.json") and FileAccess.file_exists(DIR + "shared.json"), "캐릭터 파일과 공유 파일이 따로 생김")
	var info := GameState.slot_info(1)
	check(int(info.get("level", 0)) == 5 and int(info.get("day", 0)) == 3, "칸 요약에 필력과 날짜가 나옴")
	var raw := FileAccess.get_file_as_string(DIR + "slot_1.json")
	check(not raw.contains("home_sheets") and raw.contains("coins"), "마을 크기는 캐릭터 파일에 들어가지 않음")
	# 2번 칸에 새 캐릭터: 레벨은 처음부터, 마을과 창고는 이어받는다
	GameState.slot = 2
	GameState.save_path = GameState.slot_path(2)
	GameState.call("_reset_state")
	GameState.load_game()
	check(GameState.level == 1 and GameState.coins == 0, "새 캐릭터는 필력 1, 동전 0 에서 시작")
	check(GameState.home_sheets == 6 and GameState.storage.size() == 1, "내 마을과 창고는 이어받음")
	GameState.save_game()
	GameState.slot = 1
	GameState.save_path = GameState.slot_path(1)
	GameState.call("_reset_state")
	GameState.load_game()
	check(GameState.level == 5 and GameState.coins == 77, "1번 캐릭터로 돌아오면 그대로")
	GameState.delete_slot(2)
	check(GameState.slot_info(2).is_empty() and not GameState.slot_info(1).is_empty(), "칸을 지우면 그 칸만 비워짐")

	print("[설정과 소리]")
	GameState.set_setting("music", 0.3)
	var bus := AudioServer.get_bus_index("Music")
	check(bus >= 0 and absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.3)) < 0.1, "배경음 크기가 바로 적용됨")
	GameState.set_setting("sfx", 0.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Sfx")), "0 이면 소리가 꺼짐")
	GameState.settings["music"] = 0.9
	GameState.load_settings()
	check(is_equal_approx(float(GameState.settings.get("music", 0)), 0.3), "설정이 파일에 저장되고 다시 읽힘")
	GameState.set_setting("sfx", 0.8)
	for id in ["swing", "hit", "hurt", "pickup", "levelup", "click", "craft", "capture", "fail"]:
		Sound.play(id)
	check((Sound.get("_sfx") as Dictionary).size() == 9, "효과음 9가지가 만들어짐")

	print("[시작 화면]")
	GameState.settings["last_slot"] = 1
	var title: Node = TitleScene.instantiate()
	add_child(title)
	await frames(5)
	check(not (title.get("_continue") as Button).disabled, "하던 캐릭터가 있으면 이어하기를 누를 수 있음")
	await shot("title_1.png")
	title.call("_open", "slots")
	await frames(3)
	check((title.call("menu", "slots") as Control).visible, "캐릭터 고르기 창이 열림")
	await shot("title_2_slots.png")
	title.call("_open", "settings")
	await frames(3)
	check((title.call("menu", "settings") as Control).visible and not (title.call("menu", "slots") as Control).visible, "설정 창으로 바뀜")
	await shot("title_3_settings.png")
	title.queue_free()
	await frames(3)

	print("[장비 겉모습]")
	GameState.slot = 0
	GameState.save_path = DIR + "look.json"
	GameState.call("_reset_state")
	GameState.quest = GameState.Quest.FIND_LEAD
	GameState.intro_seen = true
	var world: Node2D = MainScene.instantiate()
	add_child(world)
	await frames(5)
	var player: Node2D = world.get("player")
	var hat: Sprite2D = player.get("_hat")
	var mat: ShaderMaterial = player.get("_look_mat")
	check(not hat.visible and float(mat.get_shader_parameter("hue")) < 0.0 and float(mat.get_shader_parameter("tool_hue")) < 0.0,
		"기본 차림: 모자 없음, 노란 연필, 파란 후드티")
	GameState.equipped["hat"] = Items.make("hat", 2, 0, 1)
	GameState.equipped["cloth"] = Items.make("cloth", 2, 0, 1)
	GameState.equipped["tool"] = Items.make("tool", 7, 0, 1)
	GameState.changed.emit()
	await frames(3)
	check(hat.visible and hat.texture != null, "모자를 쓰면 머리 위에 보임")
	check(is_equal_approx(float(mat.get_shader_parameter("hue")), 0.14), "옷을 입으면 옷 색이 바뀜 (우비는 노란색)")
	check(is_equal_approx(float(mat.get_shader_parameter("tool_hue")), 0.0), "도구를 바꾸면 손에 든 연필의 색이 바뀜 (사인펜은 빨간색)")
	# 네 방향에서 모자가 머리 위에 붙어 있는지: 모자의 가운데가 머리 가운데에서 크게 벗어나지 않아야 한다
	var Anchors := preload("res://scripts/player_anchors.gd")
	var ok_all := true
	var views := {}
	for dir in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
		player.set("facing", dir)
		await frames(3)
		var sp: Sprite2D = player.get("_sprite")
		var fc: Vector2i = sp.frame_coords
		var head: Array = Anchors.WALK[fc.y * 4 + fc.x]
		var head_x := (float(head[0]) - Anchors.WALK_FRAME.x * 0.5) / 3.0
		if absf(hat.position.x - head_x) > 0.6 or hat.position.y > -20.0:
			ok_all = false
		views[hat.texture] = true
		await shot("title_4_look_%d.png" % fc.y)
	check(ok_all, "네 방향 모두 모자가 머리 가운데 위에 놓임")
	check(views.size() == 3 and hat.flip_h == false, "앞·옆·뒤 그림이 따로 쓰이고, 오른쪽을 볼 때만 뒤집힘")
	player.set("facing", Vector2.RIGHT)
	await frames(2)
	check(hat.flip_h, "오른쪽을 보면 옆 그림을 뒤집어 씀")
	player.call("attack", Vector2(10, 0))
	await frames(4)
	await shot("title_5_attack.png")
	check(hat.visible, "공격하는 동안에도 모자가 머리에 붙어 있음")
	for shape in 10:
		check(preload("res://scripts/art.gd").tex("hat_%d_0" % shape) != null and preload("res://scripts/art.gd").tex("hat_%d_1" % shape) != null
			and preload("res://scripts/art.gd").tex("hat_%d_2" % shape) != null, "모자 %d번의 앞·옆·뒤 그림이 있음" % shape)
	GameState.equipped.erase("hat")
	GameState.changed.emit()
	await frames(2)
	check(not hat.visible, "벗으면 사라짐")

	wipe()
	GameState.save_dir = "user://"
	GameState.load_settings()
	Sound.apply_settings()
	print("\n결과: %d 통과 / %d 실패" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
