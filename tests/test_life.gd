extends Node
## 포획·친구·합치기, 내 마을 짓기·넓히기, 쓰러짐·낮밤·피로도 테스트 + 화면 캡처.
## 실행: godot --headless --path . res://tests/test_life.tscn
##       godot --path . res://tests/test_life.tscn -- <캡처 폴더>

const FieldScene := preload("res://scenes/field.tscn")
const HomeScene := preload("res://scenes/home.tscn")
const Data := preload("res://scripts/game_data.gd")
const AiPixel := preload("res://scripts/ai_pixel.gd")

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


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else ""
	seed(4242)
	AiPixel.enabled = false
	GameState.save_path = "user://test_life_save.json"
	GameState.friends = []
	GameState.companion = -1
	GameState.consumables = {}
	GameState.home_objects = []
	GameState.home_sheets = 4
	GameState.home_cells = ""
	GameState.home_doodles = []
	GameState.fatigue = 100
	GameState.clock = 480.0
	GameState.day = 1
	GameState.coins = 0
	GameState.pencil_lead = 0
	GameState.visited = ["ch1"]
	GameState.has_saved_position = false
	GameState.spawn_tag = ""
	GameState.quest = GameState.Quest.CLEARED
	GameState.home_intro_seen = true
	GameState.level = 6

	print("[포획 확률]")
	check(is_equal_approx(GameState.capture_chance(0.6, "slime_faded", false), 0.4), "정확도 60%면 40%")
	check(is_equal_approx(GameState.capture_chance(0.95, "slime_faded", false), 0.8), "정확도 90% 이상이면 80%")
	check(is_equal_approx(GameState.capture_chance(0.95, "slime_erased", false), 0.65), "많이 지워진 모습은 -15%")
	check(is_equal_approx(GameState.capture_chance(0.95, "slime_erased", true), 0.85), "두꺼운 도화지는 +20%")
	check(GameState.try_capture("slime_faded", 1.0) == "no_paper", "도화지가 없으면 다시 그릴 수 없음")

	print("[사냥터에서 다시 그리기]")
	var field: Node2D = FieldScene.instantiate()
	field.set("field_id", "ch1_meadow")
	add_child(field)
	await frames(5)
	var player: Node2D = field.get("player")
	var hud: Node = field.get("hud")
	var foe: Node2D = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if str(e.get("kind")) == "slime_faded":
			foe = e
			break
	foe.set("speed", 0.0)
	foe.set("aggro_range", 0.0)
	player.global_position = foe.global_position + Vector2(-24, 0)
	await frames(2)
	foe.call("take_damage", 9999, Vector2.RIGHT, false)
	await frames(3)
	check(get_tree().get_nodes_in_group("fallen").is_empty(), "도화지가 없으면 흐린 자국이 남지 않음")
	GameState.add_consumable("paper", 3)
	foe = get_tree().get_nodes_in_group("enemies")[0]
	foe.set("speed", 0.0)
	foe.set("aggro_range", 0.0)
	var kind := str(foe.get("kind"))
	player.global_position = foe.global_position + Vector2(-24, 0)
	await frames(2)
	foe.call("take_damage", 9999, Vector2.RIGHT, false)
	await frames(3)
	var fallen: Array = get_tree().get_nodes_in_group("fallen")
	check(fallen.size() == 1, "도화지가 있으면 쓰러진 자리에 흐린 자국이 남음")
	player.global_position = (fallen[0] as Node2D).global_position + Vector2(-14, 0)
	await frames(3)
	await shot("life_1_fallen.png")
	check(bool(player.call("try_interact")), "흐린 자국에 F 로 말을 걸 수 있음")
	await frames(3)
	var panel: Control = hud.call("trace_panel")
	check(bool(panel.get("active")) and get_tree().paused, "따라 그리기 화면이 열리고 게임이 멈춤")
	panel.set("strokes", (panel.get("guides") as Array).duplicate())
	await frames(3)
	await shot("life_2_capture_trace.png")
	check(float(panel.call("measure")) > 0.9, "점선을 따라 그리면 점수가 높음 (%.2f)" % float(panel.call("measure")))
	# 확률을 타지 않게 될 때까지 다시 굴린다 (도화지는 한 번에 한 장)
	panel.call("finish")
	await frames(4)
	check(GameState.consumable_count("paper") == 2, "도화지 한 장을 씀")
	while GameState.friends.is_empty() and GameState.consumable_count("paper") > 0:
		GameState.try_capture(kind, 1.0)
	if GameState.friends.is_empty():
		GameState.add_friend(Data.species_of(kind))
	check(GameState.friends.size() == 1 and GameState.companion == 0, "친구가 되고 바로 같이 다님")

	print("[같이 다니는 친구]")
	await frames(5)
	var comp: Node2D = field.get("companion")
	check(comp.visible and not (comp.get("friend") as Dictionary).is_empty(), "친구가 맵에 나타남")
	player.global_position += Vector2(120, 0)
	await frames(90)
	check(comp.global_position.distance_to(player.global_position) < 60.0, "플레이어를 따라옴")
	var target: Node2D = get_tree().get_nodes_in_group("enemies")[0]
	target.set("speed", 0.0)
	target.set("aggro_range", 0.0)
	target.set("max_hp", 9999)
	target.set("hp", 9999)
	player.global_position = target.global_position + Vector2(-40, 0)
	comp.global_position = target.global_position + Vector2(-30, 0)
	await frames(100)
	check(int(target.get("hp")) < 9999, "가까운 적을 스스로 때림 (%d)" % (9999 - int(target.get("hp"))))
	var hp_before := int(target.get("hp"))
	check(bool(comp.call("use_skill")) and hp_before - int(target.get("hp")) >= GameState.friend_attack(GameState.friends[0]) * 3, "G 키 친구 스킬은 공격력의 3배")
	check(not bool(comp.call("use_skill")), "친구 스킬에는 재사용 시간이 있음")
	await shot("life_3_companion.png")
	var lv0 := int(GameState.friends[0]["lv"])
	GameState.add_exp(400)
	check(int(GameState.friends[0]["lv"]) > lv0 and int(GameState.friends[0]["lv"]) <= GameState.level, "친구도 경험치를 나눠 받고, 주인공 레벨을 넘지 않음 (Lv %d)" % int(GameState.friends[0]["lv"]))

	print("[합치기]")
	GameState.friends = []
	GameState.companion = -1
	for i in 3:
		GameState.add_friend("slime")
	check(GameState.merge_same(0) and GameState.friends.size() == 2 and int(GameState.friends[0]["stars"]) == 1, "같은 종 둘을 합치면 별 1개")
	check(GameState.merge_same(0) and GameState.friends.size() == 1 and int(GameState.friends[0]["stars"]) == 2, "별 1 → 2 에는 한 마리가 더 듦")
	check(not GameState.merge_same(0), "같은 종이 없으면 합칠 수 없음")
	var a1 := GameState.friend_attack(GameState.friends[0])
	check(a1 > GameState.friend_attack({"sp": "slime", "lv": int(GameState.friends[0]["lv"]), "stars": 0}), "별이 붙으면 공격력이 오름")
	check(GameState.cross_partner(0) < 0, "짝이 없으면 섞을 수 없음")
	GameState.friends.append({"sp": "grass", "lv": 4, "exp": 0, "stars": 2})
	check(GameState.cross_partner(0) == 1 and GameState.merge_cross(0), "낙서 슬라임 + 풀낙서 (둘 다 별 2) 를 섞음")
	check(GameState.friends.size() == 1 and str(GameState.friends[0]["sp"]) == "grassmallang" and int(GameState.friends[0]["lv"]) == 4, "풀말랑이 태어나고 높은 레벨을 이음")
	for sp in ["slime", "dots", "spider"]:
		GameState.add_friend(sp)
	hud.call("toggle_menu", "friends")
	await frames(3)
	check(bool(hud.call("is_menu_open", "friends")), "친구 창(P)이 열림")
	await shot("life_4_friends.png")
	hud.call("toggle_menu", "friends")
	await frames(2)

	print("[피로도와 시간]")
	GameState.fatigue = 100
	GameState.clock = 480.0
	GameState.day = 1
	check(not GameState.is_night() and GameState.night_amount() == 0.0, "아침 8시는 낮")
	GameState.advance_clock(3600.0)
	check(GameState.clock > 1300.0 and GameState.is_night() and GameState.night_amount() == 1.0, "한 시간 뒤는 밤 (%s)" % GameState.clock_text())
	GameState.fatigue = 10
	GameState.advance_clock(1800.0)
	check(GameState.day == 2 and GameState.fatigue == 100 and not GameState.is_night(), "밤 30분이 지나면 다음 날 아침, 피로가 풀림 (%s)" % GameState.clock_text())
	GameState.clock = 1300.0
	await frames(3)
	await shot("life_5_night.png")
	for i in 3:
		await get_tree().process_frame
	check((hud.get("_night") as ColorRect).color.a > 0.3, "밤에는 화면이 어두워짐")
	GameState.fatigue = 1
	check(not GameState.goto_map("ch1_crossroad", "gate_left"), "피로도가 바닥나면 사냥터에 못 들어감")
	GameState.clock = 600.0

	print("[쓰러짐]")
	GameState.pencil_lead = 50
	GameState.visited = ["ch1"]
	player.set("hp", 1)
	player.call("take_damage", 9999, Vector2.RIGHT)
	await frames(2)
	check(GameState.pencil_lead == 45, "쓰러지면 연필심의 10%를 잃음")
	check(int(player.get("hp")) == int(player.get("max_hp")), "HP 가 가득 찬 채로 다시 일어남")
	field.queue_free()
	await frames(3)

	print("[내 마을: 넓히기]")
	GameState.pencil_lead = 500
	GameState.coins = 3000
	var home: Node2D = HomeScene.instantiate()
	add_child(home)
	await frames(5)
	check(home.get("size") == Vector2(1280, 720) and GameState.home_sheets == 4, "화면 4장(2×2)에서 시작")
	check(GameState.home_expand_cost() == {"lead": 50, "coins": 500}, "첫 넓히기 값은 연필심 50 + 동전 500")
	check(bool(home.call("expand")) and home.get("size") == Vector2(1920, 720) and GameState.home_sheets == 6, "종이를 이어 붙이면 6장(3×2)")
	check(GameState.pencil_lead == 450 and GameState.coins == 2500 and int(GameState.home_expand_cost()["coins"]) == 750, "값을 내고, 다음 값은 1.5배")
	check((home.get("portals")[0] as Node2D).position.x > 1700.0, "포탈이 새 가장자리로 옮겨 감")

	print("[내 마을: 짓기]")
	var hhud: Node = home.get("hud")
	hhud.call("toggle_menu", "build")
	await frames(3)
	check(bool(hhud.call("is_menu_open", "build")), "짓기 창(N)이 열림")
	await shot("life_6_build_menu.png")
	(hhud.call("menu", "build") as Control).call("_choose", "bld_house")
	await frames(3)
	check(str(home.get("placing")) == "bld_house" and not bool(hhud.call("is_menu_open", "build")), "고르면 창이 닫히고 놓을 자리를 고름")
	check(not bool(home.call("can_place", "bld_house", Vector2(10, 300))), "마을 밖에는 놓을 수 없음")
	check(bool(await home.call("place_at", Vector2(800, 420), 0.9)), "내 집을 지음")
	check((home.get("objects") as Array).size() == 1 and bool(GameState.home_objects[0]["fine"]) and GameState.pencil_lead == 445, "잘 따라 그리면 정성 건물, 연필심을 냄")
	check(not bool(home.call("can_place", "bld_shop", Vector2(810, 422))), "다른 건물과 겹치게는 놓을 수 없음")
	home.call("start_placing", "bld_shop")
	check(bool(await home.call("place_at", Vector2(960, 420), 0.4)) and not bool(GameState.home_objects[1]["fine"]), "대충 그려도 지어지지만 정성은 아님")
	home.call("start_placing", "deco_tree_round")
	var coins0 := GameState.coins
	check(bool(await home.call("place_at", Vector2(700, 440))) and bool(await home.call("place_at", Vector2(1060, 440))), "소품은 바로 놓이고 이어서 놓을 수 있음")
	check(GameState.coins == coins0 - 40 and (home.get("objects") as Array).size() == 4, "소품 값을 냄")
	home.call("start_placing", "deco_flower_red")
	for i in 5:
		await home.call("place_at", Vector2(740 + i * 22, 470))
	home.call("stop_placing")
	var hp: Node2D = home.get("player")
	hp.global_position = Vector2(880, 470)
	await frames(30)
	await shot("life_7_village.png")
	check(bool(home.call("remove_at", Vector2(1060, 432))) and (home.get("objects") as Array).size() == 8 and GameState.coins == coins0 - 40 - 25 + 10, "치우면 동전의 절반을 돌려받음")

	print("[내 집에서 자기]")
	GameState.clock = 1300.0
	GameState.fatigue = 12
	var d0 := GameState.day
	hp.set("hp", 5)
	hp.global_position = Vector2(800, 440)
	await frames(4)
	check(bool(hp.call("try_interact")), "내 집에 F 로 들어감")
	await frames(2)
	check(GameState.day == d0 + 1 and GameState.fatigue == 100 and GameState.clock >= 360.0 and GameState.clock < 365.0, "자면 다음 날 아침 6시, 피로가 풀림")
	check(int(hp.get("hp")) == int(hp.get("max_hp")), "HP 가 가득 참")

	print("[저장/불러오기]")
	GameState.friends = [{"sp": "dots", "lv": 3, "exp": 5, "stars": 1}]
	GameState.companion = 0
	check(GameState.save_game(), "저장 성공")
	GameState.friends = []
	GameState.companion = -1
	GameState.home_objects = []
	GameState.home_sheets = 4
	GameState.day = 1
	check(GameState.load_game(), "불러오기 성공")
	check(GameState.friends.size() == 1 and GameState.companion == 0 and int(GameState.friends[0]["stars"]) == 1, "친구가 그대로")
	check(GameState.home_objects.size() == 8 and GameState.home_sheets == 6, "지은 것과 넓힌 마을이 그대로")
	check(GameState.day == d0 + 1 and GameState.fatigue == 100, "날짜와 피로도가 그대로")
	home.queue_free()
	await frames(3)
	home = HomeScene.instantiate()
	add_child(home)
	await frames(5)
	check((home.get("objects") as Array).size() == 8 and home.get("size") == Vector2(1920, 720), "다시 열어도 마을이 그대로")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	print("\n결과: %d 통과 / %d 실패" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
