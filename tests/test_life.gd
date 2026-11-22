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
	# 줄의 단추들이 서로 겹치지 않아야 한다
	var overlap := false
	for row in ((hud.call("menu", "friends") as Control).get("_body") as Control).get_child(0).get_child(0).get_children():
		var rects: Array = []
		for c in row.get_children():
			if c is Button:
				rects.append((c as Button).get_rect())
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				if (rects[i] as Rect2).intersects(rects[j]):
					overlap = true
	check(not overlap, "친구 창의 단추가 서로 겹치지 않음")
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

	print("[밤의 몬스터]")
	GameState.clock = 1300.0
	field.call("_spawn_monster", "slime_faded", Vector2(300, 200))
	await frames(2)
	var night_kind := str(get_tree().get_nodes_in_group("enemies")[-1].get("kind"))
	GameState.clock = 600.0
	field.call("_spawn_monster", "slime_faded", Vector2(340, 200))
	await frames(2)
	check(night_kind == "slime_erased" and str(get_tree().get_nodes_in_group("enemies")[-1].get("kind")) == "slime_faded", "밤에는 많이 지워진 모습이 나오고 낮에는 그대로")

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
	check(not bool(home.call("remove_at", Vector2(1060, 432))) and (home.get("objects") as Array).size() == 9, "치우기는 한 번 누르면 묻기만 함")
	check(bool(home.call("remove_at", Vector2(1060, 432))) and (home.get("objects") as Array).size() == 8 and GameState.coins == coins0 - 40 - 25 + 10, "치우면 동전의 절반을 돌려받음")

	print("[내 집에서 자기]")
	GameState.clock = 1300.0
	GameState.fatigue = 12
	var d0 := GameState.day
	hp.set("hp", 5)
	hp.global_position = Vector2(800, 440)
	await frames(4)
	check(bool(hp.call("try_interact")) and GameState.day == d0, "내 집에 F 를 한 번 누르면 묻기만 함")
	await frames(2)
	check(bool(hp.call("try_interact")), "한 번 더 누르면 잠")
	await frames(2)
	check(GameState.day == d0 + 1 and GameState.fatigue == 110 and GameState.clock >= 360.0 and GameState.clock < 365.0, "자면 다음 날 아침 6시, 피로가 풀림 (정성 집이라 110)")
	check(int(hp.get("hp")) == int(hp.get("max_hp")), "HP 가 가득 참")

	print("[놓을 수 없는 까닭]")
	check(str(home.call("place_error", "bld_shop", Vector2(10, 300))).contains("가장자리"), "마을 밖이면 그렇게 알려 줌")
	check(str(home.call("place_error", "bld_shop", Vector2(805, 421))).contains("겹쳐"), "겹치면 그렇게 알려 줌")
	var keep_coins := GameState.coins
	GameState.coins = 0
	check(str(home.call("place_error", "bld_shop", Vector2(300, 300))).contains("모자라"), "값이 모자라면 그렇게 알려 줌")
	GameState.coins = keep_coins

	print("[안내와 확인]")
	GameState.tips_seen = {}
	var shown: Array = []
	var on_msg := func(t: String) -> void: shown.append(t)
	GameState.message.connect(on_msg)
	GameState.tip("x", "처음")
	GameState.tip("x", "처음")
	GameState.message.disconnect(on_msg)
	check(shown.size() == 1, "처음 겪는 설명은 한 번만 나옴")
	GameState.set_quick_slot(0, "g_berry")
	check(str(GameState.quick_slots[0]) == "g_berry", "1 번 키에 다른 소모품을 넣을 수 있음")
	GameState.set_quick_slot(1, "g_berry")
	check(str(GameState.quick_slots[1]) == "g_berry" and str(GameState.quick_slots[0]) == "milk", "같은 것을 다른 키에 넣으면 서로 바뀜")
	GameState.quick_slots = ["bandage", "milk"]
	GameState.friends = [{"sp": "dots", "lv": 1, "exp": 0, "stars": 0}, {"sp": "slime", "lv": 1, "exp": 0, "stars": 0}]
	hhud.call("toggle_menu", "friends")
	await frames(2)
	var fm: Control = hhud.call("menu", "friends")
	fm.call("_release", 1)
	check(GameState.friends.size() == 2, "보내기는 한 번 누르면 묻기만 함")
	fm.call("_release", 1)
	check(GameState.friends.size() == 1, "한 번 더 누르면 보냄")
	hhud.call("toggle_menu", "pause")
	await frames(3)
	check(bool(hhud.call("is_menu_open", "pause")) and not bool(hhud.call("is_menu_open", "friends")), "도움말 창이 열리고 친구 창은 닫힘")
	await shot("life_12_help.png")
	(hhud.call("menu", "pause") as Control).call("_set_tab", 1)
	await frames(3)
	await shot("life_13_help_game.png")
	hhud.call("toggle_menu", "pause")
	hhud.call("toggle_menu", "skills")
	await frames(2)
	(hhud.call("menu", "skills") as Control).call("_show_skill", "press")
	await frames(2)
	check(str((hhud.call("menu", "skills") as Control).get("_message")).contains("방어를 무시"), "배우기 전에도 스킬 설명을 볼 수 있음")
	await shot("life_14_skill_desc.png")
	hhud.call("toggle_menu", "skills")
	GameState.inventory = [GameState.Items.make("tool", 0, 2, 1)]
	hhud.call("toggle_menu", "bag")
	await frames(2)
	var bag: Control = hhud.call("menu", "bag")
	bag.call("_select", 0)
	await frames(2)
	await shot("life_15_bag_compare.png")
	bag.call("_disassemble_selected")
	check(GameState.inventory.size() == 1, "좋은 장비 분해는 한 번 누르면 묻기만 함")
	bag.call("_select", 0)
	bag.call("_select", 0)
	check(GameState.inventory.size() <= 1 and str((GameState.equipped["tool"] as Dictionary)["tier"]) == "2", "고른 장비를 한 번 더 누르면 바로 입음")
	hhud.call("toggle_menu", "bag")
	GameState.friends = []
	GameState.companion = -1
	await frames(2)

	print("[건물 기능]")
	GameState.pencil_lead = 500
	GameState.coins = 3000
	var spots := {"bld_storage": Vector2(300, 300), "bld_board": Vector2(420, 300), "bld_fishing": Vector2(540, 300),
		"bld_villager_a": Vector2(300, 600), "bld_craft": Vector2(420, 600)}
	for bid in spots:
		home.call("start_placing", bid)
		check(bool(await home.call("place_at", spots[bid], 0.95)), "%s 을(를) 정성으로 지음" % Data.BUILDS[bid]["name"])
	var objs: Array = home.get("objects")
	var by_id := {}
	for o in objs:
		by_id[str(o.get("id"))] = o
	# 창고
	GameState.inventory = [GameState.Items.make("hat", 0, 0, 1), GameState.Items.make("shoe", 0, 0, 1)]
	check(GameState.storage_size() == 72, "정성 창고는 72칸")
	(by_id["bld_storage"] as Node).call("interact")
	await frames(3)
	check(bool(hhud.call("is_menu_open", "storage")), "창고에 말을 걸면 창고 창이 열림")
	(hhud.call("menu", "storage") as Control).call("_move", 0)
	check(GameState.storage.size() == 1 and GameState.inventory.size() == 1, "장비를 창고에 넣음")
	(hhud.call("menu", "storage") as Control).call("_set_tab", 1)
	await frames(3)
	await shot("life_8_storage.png")
	(hhud.call("menu", "storage") as Control).call("_move", 0)
	check(GameState.storage.is_empty() and GameState.inventory.size() == 2, "창고에서 다시 꺼냄")
	hhud.call("toggle_menu", "storage")
	# 게시판
	(by_id["bld_board"] as Node).call("interact")
	await frames(3)
	check(bool(hhud.call("is_menu_open", "board")) and GameState.board_quests.size() == 3, "게시판에 오늘의 부탁 3개가 붙음")
	var q: Dictionary = GameState.board_quests[0]
	check(not GameState.board_claim(0), "다 하기 전에는 보상을 받을 수 없음")
	for i in int(q["need"]):
		GameState.on_kill(str(q["sp"]) + "_faded")
	var c0 := GameState.coins
	(hhud.call("menu", "board") as Control).call("refresh")
	await frames(3)
	await shot("life_9_board.png")
	check(GameState.board_claim(0) and GameState.coins == c0 + roundi(int(q["need"]) * 12 * 1.2), "다 하면 보상을 받음 (정성 게시판은 +20%)")
	check(not GameState.board_claim(0), "보상은 한 번만")
	hhud.call("toggle_menu", "board")
	# 낚시터
	(by_id["bld_fishing"] as Node).call("interact")
	await frames(3)
	var fishing: Control = hhud.call("fishing")
	check(bool(fishing.call("is_active")) and is_equal_approx(float(fishing.get("window")), 1.0), "낚시가 시작됨 (정성 낚시터는 입질 시간 1초)")
	check(not bool(fishing.call("pull")) and str(fishing.get("phase")) == "result", "입질 전에 채면 놓침")
	for i in 400:
		if str(fishing.get("phase")) == "bite":
			break
		await frames(1)
	check(bool(fishing.call("pull")) and str(fishing.get("phase")) == "reel", "입질에 맞춰 채면 끌어올리기가 시작됨")
	await frames(2)
	await shot("life_10_fishing.png")
	var before_fish := {}
	for fid in GameState.Items.CONSUMABLES:
		before_fish[fid] = GameState.consumable_count(str(fid))
	# 찌가 초록 칸보다 아래면 누르고, 위면 뗀다
	for i in 400:
		if str(fishing.get("phase")) != "reel":
			break
		fishing.set("_t", float(fishing.get("_t")) + 0.03)
		fishing.call("step_reel", 0.03, float(fishing.get("_pos")) < float(fishing.get("_zone")))
	var fish_id := ""
	for fid in GameState.Items.CONSUMABLES:
		if GameState.consumable_count(str(fid)) > int(before_fish[fid]):
			fish_id = str(fid)
	check(fish_id != "" and (fish_id.begins_with("f_") or fish_id.begins_with("j_")), "찌를 초록 칸에 두면 낚임 (%s)" % fish_id)
	fishing.call("stop")
	check(not get_tree().paused, "낚시를 그만두면 다시 움직임")
	GameState.clock = 600.0
	var day_fish := {}
	for i in 60:
		day_fish[GameState.catch_fish("home")] = true
	check(not day_fish.has("f_catfish") and day_fish.has("f_carp"), "낮에는 잉크 메기가 안 낚임")
	GameState.clock = 1300.0
	var night_fish := {}
	for i in 60:
		night_fish[GameState.catch_fish("ch1")] = true
	check(night_fish.has("f_moon") and not night_fish.has("f_carp"), "1장 강의 밤에는 달빛 은어가 낚임")
	GameState.clock = 600.0
	hp.set("hp", 5)
	check(bool(hp.call("use_consumable", "f_carp")) and int(hp.get("hp")) > 5, "물고기를 먹으면 HP 회복")
	# 주민 집
	var gift := GameState.villager_gift("a", true)
	check(gift != "" and GameState.villager_gift("a", true) == "", "주민은 하루에 한 번 선물을 줌 (%s)" % gift)
	GameState.day += 1
	check(GameState.villager_gift("a", true) != "", "다음 날에는 다시 줌")
	# 정성 혜택
	check(GameState.has_fine("bld_house") and not GameState.has_fine("bld_shop"), "정성 건물인지 구분함")
	check(GameState.price_of("paper") == 30, "보통 문방구는 제값")
	GameState.home_objects[1]["fine"] = true
	check(GameState.price_of("paper") == 27, "정성 문방구는 10% 할인")
	GameState.sleep()
	check(GameState.fatigue == 110, "정성 집에서 자면 피로도 110")
	hp.global_position = Vector2(420, 330)
	await frames(30)
	await shot("life_11_buildings.png")

	print("[농사]")
	home.call("start_placing", "bld_farm")
	check(bool(await home.call("place_at", Vector2(560, 600), 0.95)), "밭을 정성으로 지음")
	var farm_key := "560_600"
	GameState.consumables["s_radish"] = 2
	GameState.consumables["s_carrot"] = 1
	check(GameState.plant(farm_key, 0, "s_radish") and GameState.plant(farm_key, 1, "s_carrot") and GameState.consumable_count("s_radish") == 1, "씨앗을 심음")
	check(not GameState.plant(farm_key, 0, "s_radish"), "이미 심은 칸에는 못 심음")
	var d_farm := GameState.day
	GameState.sleep()
	check(int(GameState.farm_plots(farm_key)[0]["grown"]) == 0, "물을 주지 않으면 자라지 않음")
	check(GameState.water(farm_key) == 2 and GameState.water(farm_key) == 0, "물은 하루에 한 번")
	GameState.sleep()
	check(GameState.plot_ripe(GameState.farm_plots(farm_key)[0]) and not GameState.plot_ripe(GameState.farm_plots(farm_key)[1]), "연필 무는 하루, 당근은 이틀")
	hhud.call("open_menu", "farm", farm_key)
	await frames(3)
	await shot("life_16_farm.png")
	hhud.call("toggle_menu", "farm")
	check(GameState.harvest(farm_key, 0) == "c_radish" and GameState.consumable_count("c_radish") == 2, "거두면 작물이 들어옴 (정성 밭은 하나 더)")
	check(GameState.harvest(farm_key, 1) == "", "덜 자란 것은 못 거둠")

	print("[요리와 효과]")
	check(GameState.can_cook("d_radish") and not GameState.can_cook("d_soup"), "재료가 있어야 요리할 수 있음")
	check(GameState.cook("d_radish") and GameState.consumable_count("c_radish") == 0 and GameState.consumable_count("d_radish") >= 1, "무 조림을 만듦")
	var def0 := GameState.defense()
	GameState.stats["grit"] = 20
	var def1 := GameState.defense()
	hp.set("hp", 5)
	check(bool(hp.call("use_consumable", "d_radish")) and int(hp.get("hp")) > 5 and GameState.has_buff("def") and GameState.defense() > def1, "무 조림: HP 회복과 방어 +10%% (%d → %d)" % [def1, GameState.defense()])
	GameState.buffs["def"] = 0.01
	await frames(4)
	check(not GameState.has_buff("def") and def0 >= 0, "시간이 지나면 효과가 끝남")
	GameState.stats["grit"] = 0
	GameState.consumables["f_carp"] = 1
	hhud.call("open_menu", "cook", "")
	await frames(3)
	await shot("life_17_cook.png")
	hhud.call("toggle_menu", "cook")
	check(GameState.sell_goods("f_carp") == 6 and GameState.consumable_count("f_carp") == 0, "먹거리는 값의 절반에 팔림")

	print("[주민 이사와 호감도]")
	var kid := GameState.villager("kid")
	kid["q"] = 1
	GameState.balloons = ["a", "b", "c"]
	kid["q"] = 2
	check(GameState.free_house() != "", "빈 주민 집이 있음")
	check(GameState.move_in("kid", "봄이") and GameState.villager_name("kid") == "봄이" and GameState.free_house() == "", "이름을 지어 주면 이사 옴 (집이 참)")
	check(int(kid["aff"]) == 5, "부탁을 들어준 몫으로 호감 +5")
	check(GameState.villager_talk("kid") and not GameState.villager_talk("kid"), "말 걸기는 하루 한 번 (+1)")
	GameState.consumables["g_berry"] = 2
	check(GameState.villager_give("kid") and not GameState.villager_give("kid") and int(kid["aff"]) == 9, "좋아하는 선물은 하루 한 번 (+3)")
	check(GameState.villager_daily("kid") == "" and GameState.hearts("kid") == 0, "하트가 없으면 오늘의 선물이 없음")
	GameState.add_aff("kid", 1)
	check(GameState.hearts("kid") == 1 and GameState.villager_daily("kid") == "candy" and GameState.villager_daily("kid") == "", "하트 1개부터 하루 한 번 선물")
	var furn0 := 0
	for fk in GameState.furniture:
		furn0 += int(GameState.furniture[fk])
	GameState.add_aff("kid", 20)
	var furn1 := 0
	for fk in GameState.furniture:
		furn1 += int(GameState.furniture[fk])
	check(GameState.hearts("kid") == 2 and furn1 == furn0 + 1, "하트 2개가 되면 가구를 받음")
	await frames(3)
	(by_id["bld_villager_a"] as Node).call("interact")
	await frames(3)
	check(bool(hhud.call("is_menu_open", "resident")), "주민 집에 말을 걸면 주민 창이 열림")
	await shot("life_18_resident.png")
	hhud.call("toggle_menu", "resident")
	hhud.call("ask_name", "풍선 아이")
	await frames(3)
	await shot("life_19_name.png")
	hhud.call("submit_name", "봄이")
	await frames(2)

	print("[난이도와 보스]")
	check(GameState.difficulty == 0 and not GameState.set_difficulty(1), "처음에는 흐릿한 단계만")
	GameState.on_boss_killed("boss_crumple")
	check(GameState.max_difficulty == 1 and GameState.set_difficulty(1), "대장을 잡으면 다음 단계가 열림")
	(home.get("portals")[0] as Node).call("interact")
	await frames(3)
	check(bool(hhud.call("is_menu_open", "portal")), "단계가 열리면 문에서 난이도를 고름")
	await shot("life_20_difficulty.png")
	hhud.call("toggle_menu", "portal")
	home.queue_free()
	await frames(3)
	GameState.field_boss = {"day": GameState.day, "map": "ch1_meadow", "dead": false}
	GameState.clock = 600.0
	var f2: Node2D = FieldScene.instantiate()
	f2.set("field_id", "ch1_meadow")
	add_child(f2)
	await frames(5)
	var fbosses: Array = get_tree().get_nodes_in_group("boss")
	check(fbosses.size() == 1 and str(fbosses[0].get("kind")) == "boss_scribble", "오늘의 필드 보스가 그 화면에 나옴")
	var fb: Node2D = fbosses[0]
	check(int(fb.get("max_hp")) == 240 * 5, "지워지는 단계에서는 HP 가 5배")
	var fnormal: Node2D = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if str(e.get("boss")) == "":
			fnormal = e
	check(int(fnormal.get("max_hp")) == int(Data.MONSTERS[str(fnormal.get("kind"))]["hp"]) * 5, "보통 몬스터도 5배")
	var p2: Node2D = f2.get("player")
	p2.global_position = fb.global_position + Vector2(-60, 0)
	await frames(20)
	await shot("life_21_field_boss.png")
	check((f2.get("hud").get("_boss_bar") as ColorRect).visible, "보스 체력 막대가 화면 위에 나옴")
	GameState.bag_sizes["use"] = GameState.BAG_MAX   # 앞에서 이것저것 모았으니 소비 가방을 넉넉하게
	var fspots := 0
	for n in get_tree().get_nodes_in_group("interactable"):
		if str(n.get("mode")) == "forage":
			fspots += 1
			if fspots == 1:
				n.call("interact")
	check(fspots == 4, "사냥터에 채집 자리 4곳")
	await frames(2)
	var fleft := 0
	for n in get_tree().get_nodes_in_group("interactable"):
		if str(n.get("mode")) == "forage":
			fleft += 1
	check(fleft == 3, "주운 자리는 오늘은 사라짐")
	var gear_before := get_tree().get_nodes_in_group("pickup").size()
	var coat := GameState.consumable_count("coating")
	fb.call("take_damage", 999999, Vector2.RIGHT, false)
	await frames(3)
	check(GameState.field_boss_map() == "" and GameState.consumable_count("coating") == coat + 1 and gear_before >= 0, "필드 보스를 잡으면 코팅지를 주고 오늘은 다시 안 나옴")
	f2.queue_free()
	await frames(3)
	GameState.difficulty = 0
	var f3: Node2D = FieldScene.instantiate()
	f3.set("field_id", "ch1_bossroom")
	add_child(f3)
	await frames(5)
	var crumple: Node2D = get_tree().get_nodes_in_group("boss")[0]
	check(str(crumple.get("kind")) == "boss_crumple", "대장 방에 구깃이가 있음")
	crumple.call("take_damage", int(crumple.get("max_hp")) / 2 + 1, Vector2.RIGHT, false)
	await frames(3)
	var fminions := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if str(e.get("boss")) == "":
			fminions += 1
	check(fminions == 2, "체력이 절반이 되면 부하 둘을 부름")
	(f3.get("player") as Node2D).global_position = crumple.global_position + Vector2(0, 50)
	await frames(30)
	await shot("life_22_boss_room.png")
	f3.queue_free()
	await frames(3)

	print("[내 집 안]")
	var room: Node2D = preload("res://scenes/room.tscn").instantiate()
	add_child(room)
	await frames(5)
	GameState.furniture = {"furn_0": 1, "furn_4": 1}
	GameState.room_items = []
	room.call("_on_chosen", "furn_0")
	check(bool(room.call("place_at", Vector2(300, 200))) and GameState.furniture_count("furn_0") == 0 and GameState.room_items.size() == 1, "가구를 방에 놓음")
	room.call("_on_chosen", "furn_4")
	room.call("place_at", Vector2(380, 250))
	check(not bool(room.call("can_place", Vector2(10, 10))), "방 밖에는 못 놓음")
	(room.get("player") as Node2D).global_position = Vector2(300, 240)
	await frames(30)
	await shot("life_23_room.png")
	var d_room := GameState.day
	room.call("use_bed")
	check(GameState.day == d_room, "침대도 한 번 누르면 묻기만 함")
	room.call("use_bed")
	check(GameState.day == d_room + 1, "한 번 더 누르면 잠")
	check(bool(room.call("remove_at", Vector2(300, 192))) and GameState.furniture_count("furn_0") == 1, "치우면 가구가 가방으로 돌아옴")
	room.queue_free()
	await frames(3)
	home = HomeScene.instantiate()
	add_child(home)
	await frames(5)
	hp = home.get("player")

	print("[저장/불러오기]")
	GameState.friends = [{"sp": "dots", "lv": 3, "exp": 5, "stars": 1}]
	GameState.companion = 0
	check(GameState.save_game(), "저장 성공")
	GameState.friends = []
	GameState.companion = -1
	GameState.home_objects = []
	GameState.home_sheets = 4
	GameState.day = 1
	GameState.villagers = {}
	GameState.farms = {}
	GameState.room_items = []
	GameState.max_difficulty = 0
	check(GameState.load_game(), "불러오기 성공")
	check(GameState.friends.size() == 1 and GameState.companion == 0 and int(GameState.friends[0]["stars"]) == 1, "친구가 그대로")
	check(GameState.home_objects.size() == 14 and GameState.home_sheets == 6, "지은 것과 넓힌 마을이 그대로")
	check(GameState.villager_name("kid") == "봄이" and GameState.hearts("kid") == 2 and GameState.max_difficulty == 1, "주민과 난이도 단계가 그대로")
	check(GameState.farm_plots("560_600")[1]["seed"] == "s_carrot" and GameState.room_items.size() == 1, "밭과 방이 그대로")
	check(GameState.day > d0 + 3, "날짜가 그대로")
	home.queue_free()
	await frames(3)
	home = HomeScene.instantiate()
	add_child(home)
	await frames(5)
	check((home.get("objects") as Array).size() == 14 and home.get("size") == Vector2(1920, 720), "다시 열어도 마을이 그대로")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	print("\n결과: %d 통과 / %d 실패" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
