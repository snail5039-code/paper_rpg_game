extends Node
const Art := preload("res://scripts/core/art.gd")
## 포획·친구·합치기, 내 마을 짓기·넓히기, 쓰러짐·낮밤·피로도 테스트 + 화면 캡처.
## 실행: godot --headless --path . res://tests/test_life.tscn
##       godot --path . res://tests/test_life.tscn -- <캡처 폴더>

const FieldScene := preload("res://scenes/field.tscn")
const HomeScene := preload("res://scenes/home.tscn")
const Data := preload("res://scripts/data/game_data.gd")
const AiPixel := preload("res://scripts/drawing/ai_pixel.gd")
const Items_ := preload("res://scripts/data/items.gd")

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


## 방금 지은 건물은 1단계(초가집)다. 기능의 기준값을 재는 시험에서는 3단계로 맞추고, 지을 때 받은 효과도 지운다.
func lv3() -> void:
	for o in GameState.home_objects:
		o["lv"] = 3
	GameState.buffs = {}


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
	lv3()
	check((home.get("objects") as Array).size() == 1 and bool(GameState.home_objects[0]["fine"]) and GameState.pencil_lead == 445, "잘 따라 그리면 정성 건물, 연필심을 냄")
	check(not bool(home.call("can_place", "bld_shop", Vector2(810, 422))), "다른 건물과 겹치게는 놓을 수 없음")
	home.call("start_placing", "bld_shop")
	var lead_before := GameState.pencil_lead
	var coins_before := GameState.coins
	check(not bool(await home.call("place_at", Vector2(960, 420), 0.3)) and GameState.home_objects.size() == 1
		and GameState.pencil_lead == lead_before and GameState.coins == coins_before, "점선을 제대로 안 따라 그리면 지어지지 않고 값도 안 듦")
	home.call("start_placing", str(home.get("placing")) if str(home.get("placing")) != "" else "bld_shop")
	check(bool(await home.call("place_at", Vector2(960, 420), 0.6)) and not bool(GameState.home_objects[1]["fine"]), "절반 넘게 따라 그리면 지어지지만 정성은 아님")
	lv3()
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
	GameState.friends = [{"sp": "dots", "lv": 1, "exp": 0, "stars": 0}, {"sp": "slime", "lv": 1, "exp": 0, "stars": 0},
		{"sp": "dots", "lv": 1, "exp": 0, "stars": 0}]
	GameState.companion = 0

	print("[친구 우리]")
	check(GameState.friend_cap() == 30, "친구 우리가 없으면 친구 30")
	hhud.call("toggle_menu", "friends")
	await frames(2)
	var fm: Control = hhud.call("menu", "friends")
	var outside_buttons := 0
	for row in (fm.get("_body") as Control).get_child(0).get_child(0).get_children():
		for c in row.get_children():
			if c is Button:
				outside_buttons += 1
	check(outside_buttons == 3, "우리 밖(P)에서는 동행 단추만 (%d개)" % outside_buttons)
	fm.call("_merge", 0, false)
	check(GameState.friends.size() == 3, "우리 밖에서는 합칠 수 없음")
	hhud.call("toggle_menu", "friends")
	GameState.pencil_lead = maxi(GameState.pencil_lead, 100)
	GameState.coins = maxi(GameState.coins, 1000)
	home.call("start_placing", "bld_pen")
	check(bool(await home.call("place_at", Vector2(700, 600), 0.9)), "친구 우리를 지음")
	check(GameState.friend_cap() == 36, "우리 1단계: 친구 36칸")
	var pen: Node2D = null
	for n in get_tree().get_nodes_in_group("home_object"):
		if str(n.get("id")) == "bld_pen":
			pen = n
	await frames(30)
	check((pen.get("_extra") as Array).size() == 2, "같이 다니지 않는 친구 둘이 우리 안을 돌아다님")
	hp.global_position = pen.global_position + Vector2(0, 20)
	await frames(20)
	await shot("life_4a_pen.png")
	pen.call("interact")
	await frames(3)
	check(bool(hhud.call("is_menu_open", "friends")) and str(fm.get("ctx")) == "pen", "우리에 F: 친구 창이 우리 모드로 열림")
	fm.call("_merge", 0, false)
	check(GameState.friends.size() == 2 and int(GameState.friends[0]["stars"]) == 1, "우리 안에서는 합칠 수 있음")
	await shot("life_4b_pen_menu.png")
	GameState.friends = [{"sp": "dots", "lv": 1, "exp": 0, "stars": 0}, {"sp": "slime", "lv": 1, "exp": 0, "stars": 0}]
	fm.call("refresh")
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

	print("[건물 단계]")
	GameState.pencil_lead = 5000
	GameState.coins = 50000
	var up_i := 0
	for oi in GameState.home_objects.size():
		if str(GameState.home_objects[oi]["id"]) == "bld_house":
			up_i = oi
	GameState.home_objects[up_i]["lv"] = 1
	GameState.buffs = {}
	check(Data.build_sprite("bld_house", 1) == "bld_house_l1" and Data.build_sprite("bld_house", 3) == "bld_house" and Data.build_sprite("bld_house", 5) == "bld_house_l5",
		"단계마다 건물 그림이 다름 (초가집, 나무집, 저택)")
	var art_all := true
	for bid2 in ["bld_house", "bld_shop", "bld_craft", "bld_storage", "bld_board", "bld_fishing", "bld_villager_a", "bld_villager_b", "bld_farm", "bld_diner"]:
		for blv in [1, 2, 4, 5]:
			if not Art.has("%s_l%d" % [bid2, blv]):
				art_all = false
				print("    그림 없음: %s_l%d" % [bid2, blv])
	check(art_all, "건물 10종 모두 1·2·4·5단계 그림이 있음")
	GameState.sleep()
	check(GameState.fatigue == 90 + (10 if bool(GameState.home_objects[up_i]["fine"]) else 0), "초가집에서 자면 피로가 덜 풀림 (%d)" % GameState.fatigue)
	var cost1: Dictionary = Data.upgrade_cost("bld_house", 1)
	var lead0 := GameState.pencil_lead
	check(not bool(await home.call("upgrade_at", up_i, 0.3)) and int(GameState.home_objects[up_i]["lv"]) == 1 and GameState.pencil_lead == lead0,
		"점선을 제대로 안 따라 그리면 올라가지 않고 값도 안 듦")
	check(bool(await home.call("upgrade_at", up_i, 0.75)) and int(GameState.home_objects[up_i]["lv"]) == 2 and GameState.pencil_lead == lead0 - int(cost1["lead"]),
		"따라 그리면 2단계 흙집이 되고 값을 냄")
	check(not bool(GameState.home_objects[up_i]["fine"]) and GameState.has_buff("def") and float(GameState.buffs["def"]) <= 300.0,
		"70% 넘게 그리면 5분 동안 효과를 받음 (정성은 아님)")
	check(int((home.get("objects")[up_i] as Node).get("lv")) == 2, "마을의 건물 그림도 새 단계로 바뀜")
	GameState.buffs = {}
	for step in 3:
		await home.call("upgrade_at", up_i, 0.95)
	check(int(GameState.home_objects[up_i]["lv"]) == 5 and bool(GameState.home_objects[up_i]["fine"]) and float(GameState.buffs.get("def", 0.0)) > 500.0,
		"5단계 저택까지 올림. 잘 그리면 정성 건물이 되고 10분 동안 효과")
	check(not bool(await home.call("upgrade_at", up_i, 0.95)) and int(GameState.home_objects[up_i]["lv"]) == 5, "5단계가 끝")
	GameState.sleep()
	check(GameState.fatigue == 120, "정성 저택에서 자면 피로도 120")
	var big: Node = (home.get("objects")[up_i] as Node)
	check(big.get("_sprite") != null and float(big.get("_height")) > 70.0, "저택은 그림이 더 큼")
	# 방: 단계에 따라 넓어지고 가구를 더 놓는다
	var room_scene: PackedScene = load("res://scenes/room.tscn")
	GameState.home_objects[up_i]["lv"] = 1
	GameState.room_ctx = {"key": GameState.house_key(GameState.home_objects[up_i]), "id": "bld_house"}
	var small_room: Node2D = room_scene.instantiate()
	add_child(small_room)
	await frames(3)
	check(int(small_room.call("furn_cap")) == 3 and float(small_room.get("k")) < 0.7 and (small_room.get("FLOOR") as Rect2).size.x < 340.0,
		"초가집의 방은 좁고 가구를 3개까지")
	await shot("life_30_room_lv1.png")
	small_room.queue_free()
	await frames(2)
	GameState.home_objects[up_i]["lv"] = 5
	var big_room: Node2D = room_scene.instantiate()
	add_child(big_room)
	await frames(3)
	check(int(big_room.call("furn_cap")) == 16 and is_equal_approx(float(big_room.get("k")), 1.0), "저택의 방은 넓고 가구를 16개까지")
	await shot("life_31_room_lv5.png")
	big_room.queue_free()
	await frames(2)
	# 다른 건물 안: 문방구에는 계산대가 있고 거기서 가게 창이 열린다
	GameState.room_ctx = {"key": "", "id": "bld_shop"}
	var shop_room: Node2D = room_scene.instantiate()
	add_child(shop_room)
	await frames(3)
	check(str(shop_room.get("use")) == "shop" and str(shop_room.get("bld_id")) == "bld_shop", "문방구 안으로 들어감")
	shop_room.call("use_fixture")
	await frames(3)
	check(bool((shop_room.get("hud") as Node).call("is_menu_open", "shop")), "계산대에서 가게 창이 열림")
	(shop_room.get("hud") as Node).call("toggle_menu", "shop")
	await frames(2)
	check(not bool(shop_room.call("can_place", shop_room.get("FIX_POS") + Vector2(0, -40))), "계산대 위에는 가구를 놓을 수 없음")
	GameState.furniture["furn_0"] = 1
	shop_room.call("_on_chosen", "furn_0")
	check(bool(shop_room.call("place_at", Vector2(200, 260))) and (GameState.rooms.get("", []) as Array).size() == 1 and GameState.room_items.size() == 0,
		"문방구 안에 놓은 가구는 내 집과 따로 저장됨")
	await shot("life_32_room_shop.png")
	shop_room.call("remove_at", Vector2(200, 252))
	shop_room.queue_free()
	await frames(2)
	GameState.rooms = {}
	GameState.room_ctx = {}
	GameState.player_ref = home.get("player")     # 방을 띄우면서 바뀐 주인공을 내 마을의 주인공으로 되돌린다
	GameState.buffs = {}
	lv3()
	GameState.pencil_lead = 500
	GameState.coins = 3000

	print("[건물 기능]")
	GameState.pencil_lead = 500
	GameState.coins = 3000
	var spots := {"bld_storage": Vector2(300, 300), "bld_board": Vector2(420, 300), "bld_fishing": Vector2(540, 300),
		"bld_villager_a": Vector2(300, 600), "bld_craft": Vector2(420, 600)}
	for bid in spots:
		home.call("start_placing", bid)
		check(bool(await home.call("place_at", spots[bid], 0.95)), "%s 을(를) 정성으로 지음" % Data.BUILDS[bid]["name"])
		lv3()
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
	var angler: Node2D = GameState.player_ref
	check(bool(angler.call("is_acting")) and not get_tree().paused, "낚시 창 없이 캐릭터가 낚싯대를 들고, 게임은 멈추지 않음")
	check((angler.get("_tool") as Sprite2D).texture == preload("res://scripts/core/art.gd").tex("life_rod"), "손에 낚싯대가 보임")
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
	check(fish_id != "" and (fish_id.begins_with("f_") or fish_id.begins_with("fish_") or fish_id.begins_with("j_")), "찌를 초록 칸에 두면 낚임 (%s)" % fish_id)
	fishing.call("stop")
	check(not get_tree().paused and not bool(angler.call("is_acting")), "낚시를 그만두면 다시 움직임")
	# 밭일 동작: 갈퀴를 휘두르고 끝나면 알려 준다
	var act_done := [false]
	angler.call("act", "life_rake", Vector2.RIGHT, 0.2, false, func() -> void: act_done[0] = true)
	check(bool(angler.call("is_acting")), "생활 동작을 하는 동안에는 다른 동작을 못 함")
	for ai in 60:
		if not bool(angler.call("is_acting")):
			break
		await get_tree().physics_frame
	check(act_done[0] and not bool(angler.call("is_acting")), "동작이 끝나면 다시 움직일 수 있음")
	GameState.clock = 600.0
	var day_fish := {}
	for i in 400:
		day_fish[GameState.roll_fish("home")] = true
	check(not day_fish.has("f_catfish") and day_fish.has("f_carp") and not day_fish.has("fish_20"), "낮에는 잉크 메기가 안 낚이고, 다른 낚시터 물고기도 안 나옴")
	GameState.clock = 1300.0
	var night_fish := {}
	for i in 600:
		night_fish[GameState.roll_fish("ch1")] = true
	check(night_fish.has("f_moon") and not night_fish.has("f_carp") and not night_fish.has("fish_14"), "1장 강의 밤에는 달빛 은어가 낚이고 낮 물고기는 안 나옴")
	var pond_fish := {}
	for i in 400:
		pond_fish[GameState.roll_fish("pond")] = true
	var common := 0
	var legend := 0
	for i in 2000:
		var r := GameState.fish_rarity(GameState.roll_fish("pond"))
		common += 1 if r == 0 else 0
		legend += 1 if r == 3 else 0
	check(pond_fish.has("fish_30") and not pond_fish.has("f_carp") and common > legend * 5, "들판 연못에는 연못 물고기만, 흔한 것이 전설보다 훨씬 많이 낚임 (%d / %d)" % [common, legend])
	check(Items_.FISH_INFO.size() == 50 and GameState.dex_entries("fish").size() == 50, "물고기는 50종")
	GameState.clock = 600.0
	hp.set("hp", 5)
	GameState.consumables["f_carp"] = GameState.consumable_count("f_carp") + 1
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
	lv3()
	var farm_key := "560_600"
	GameState.consumables["s_radish"] = 2
	GameState.consumables["s_carrot"] = 1
	check(GameState.plant(farm_key, 0, "s_radish") and GameState.plant(farm_key, 1, "s_carrot") and GameState.consumable_count("s_radish") == 1, "씨앗을 심음")
	check(not GameState.plant(farm_key, 0, "s_radish"), "이미 심은 칸에는 못 심음")
	var d_farm := GameState.day
	GameState.sleep()
	check(int(GameState.farm_plots(farm_key)[0]["grown"]) == 0, "물을 주지 않으면 자라지 않음")
	# 물뿌리개: 물이 필요한 칸 앞에 서서 F
	var farm_obj: Node2D = null
	for n in get_tree().get_nodes_in_group("home_object"):
		if str(n.get("id")) == "bld_farm":
			farm_obj = n
	hp.global_position = farm_obj.global_position + (farm_obj.call("plot_pos", 0) as Vector2)
	check(int(farm_obj.call("thirsty_plot_near", hp.global_position)) == 0, "칸 앞에 서면 그 칸을 고름")
	farm_obj.call("interact")
	await frames(2)
	var plots_now := GameState.farm_plots(farm_key)
	check(bool(plots_now[0]["watered"]) and not bool(plots_now[1]["watered"]) and not bool(hhud.call("is_menu_open", "farm")), "물뿌리개로 F: 그 칸에만 물을 줌 (창은 열리지 않음)")
	await shot("life_16a_water.png")
	check(GameState.water_plot(farm_key, 1) and not GameState.water_plot(farm_key, 1) and GameState.water(farm_key) == 0, "칸마다 하루 한 번")
	hp.global_position = farm_obj.global_position + Vector2(0, 40)
	farm_obj.call("interact")
	await frames(2)
	check(bool(hhud.call("is_menu_open", "farm")), "물 줄 칸이 없으면 밭 창이 열림")
	hhud.call("toggle_menu", "farm")
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
	await frames(12)
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
	# 게시판 부탁에는 내 마을 주민의 이름이 붙고, 끝내면 그 주민과 가까워진다
	GameState.board_day = 0
	GameState.board_refresh()
	var bq: Dictionary = GameState.board_quests[0]
	check(str(bq["who"]) == "kid", "게시판 부탁에 주민 이름이 붙음")
	var aff_b := int(kid["aff"])
	for i in int(bq["need"]):
		GameState.board_note(str(bq["sp"]))
	check(GameState.board_claim(0) and int(kid["aff"]) == aff_b + GameState.BOARD_AFF, "부탁을 끝내면 그 주민 호감 +2")
	GameState.board_quests[2] = {"sp": "fish", "need": 1, "have": 0, "claimed": false, "who": ""}
	check(GameState.catch_fish("home") != "" and int(GameState.board_quests[2]["have"]) == 1, "물고기를 낚으면 낚기 부탁이 나아감")
	check(GameState.board_text(GameState.board_quests[2]) == "물고기 낚기", "낚기 부탁의 이름")
	# 하트 4개: 전용 조합법, 하트 5개: 전용 장신구
	var aff_keep := int(kid["aff"])
	var n_recipes := GameState.known_recipes().size()
	GameState.add_aff("kid", 100 - int(kid["aff"]))
	check(GameState.hearts("kid") == 4 and GameState.known_recipes().size() == n_recipes + 1, "하트 4개: 전용 조합법(풍선껌)을 배움")
	var inv0 := GameState.inventory.size()
	GameState.add_aff("kid", 50)
	check(GameState.hearts("kid") == 5 and GameState.inventory.size() == inv0 + 1 and bool(kid["acc"]), "하트 5개: 전용 장신구를 받음")
	check(not GameState.give_villager_acc("kid"), "장신구는 한 번만")
	var badge: Dictionary = GameState.inventory[GameState.inventory.size() - 1]
	check(str(badge.get("unique", "")) == "v_badge" and int(badge["level"]) == 10, "풍선 배지 (필요 필력 10)")
	var ms0 := GameState.move_speed_mult()
	var lv_keep := GameState.level
	GameState.level = 10
	GameState.equip(GameState.inventory.size() - 1)
	check(GameState.has_fx("v_badge") and GameState.move_speed_mult() > ms0 + 0.15, "배지를 차면 이동 속도가 빨라짐 (옵션 8% + 효과 10%)")
	hhud.call("open_menu", "resident", "kid")
	await frames(3)
	await shot("life_18a_resident_hearts.png")
	hhud.call("toggle_menu", "resident")
	GameState.unequip("acc")
	GameState.inventory.pop_back()
	GameState.level = lv_keep
	kid["aff"] = aff_keep
	kid["acc"] = 0

	print("[직접 그려 만드는 주민]")
	GameState.pencil_lead = maxi(GameState.pencil_lead, 100)
	GameState.coins = maxi(GameState.coins, 1000)
	home.call("start_placing", "bld_villager_b")
	check(bool(await home.call("place_at", Vector2(860, 600), 0.9)), "주민 집을 하나 더 지음")
	var cv_key := "860_600"
	var cv_house: Node = null
	for n in get_tree().get_nodes_in_group("home_object"):
		if str(n.get("id")) == "bld_villager_b":
			cv_house = n
	cv_house.call("interact")
	check(not is_instance_valid(hhud.get("maker")), "빈 집에 F: 처음에는 알리기만")
	cv_house.call("interact")
	await frames(3)
	var maker: Control = hhud.get("maker")
	check(is_instance_valid(maker) and GameState.menu_open, "한 번 더 F: 새 주민 그리기 화면이 열림")
	maker.call("_step", "body", 1)
	maker.call("_set_persona", "angler")
	(maker.get("_name") as LineEdit).text = "낚시왕"
	await frames(2)
	await shot("life_18b_maker.png")
	maker.call("redraw")
	await frames(2)
	var mcanvas: Control = maker.get("_canvas")
	mcanvas.set("strokes", [{"pts": PackedVector2Array([Vector2(0.3, 0.1), Vector2(0.7, 0.1), Vector2(0.5, 0.0)]), "c": 2}])
	mcanvas.call("finish")
	await frames(2)
	check(str(maker.get("drawn")).begins_with("drawn_"), "덧그리면 덧그린 그림이 주민 그림이 됨")
	maker.call("finish")
	await frames(3)
	var cv_id := GameState.resident_of(cv_key)
	check(cv_id.begins_with("cv") and GameState.villager_name(cv_id) == "낚시왕" and not is_instance_valid(hhud.get("maker")), "이사 오기: 그 집에 내 주민이 삶")
	check(str(GameState.villager_info(cv_id)["sprite"]).begins_with("drawn_") and str(GameState.villager_info(cv_id)["like"]) == "f_catfish", "성격(낚시꾼)에 따라 좋아하는 것이 정해짐")
	check(bool(hhud.call("is_menu_open", "resident")), "다 만들면 주민 창이 열림")
	await shot("life_18c_custom_resident.png")
	hhud.call("toggle_menu", "resident")
	GameState.add_aff(cv_id, 10)
	check(GameState.villager_daily(cv_id) == "f_minnow", "하트 1개: 성격에 맞는 하루 선물")
	check(GameState.residents().has(cv_id), "게시판 부탁을 줄 수 있는 주민이 됨")
	await frames(10)
	await shot("life_18d_custom_house.png")

	print("[도감과 박물관]")
	GameState.dex = {}
	GameState.museum_claimed = {}
	GameState.on_kill("slime_faded")
	GameState.add_material(0)
	check(GameState.dex_has("mon", "slime_faded") and GameState.dex_has("mat", "0") and not GameState.dex_has("mon", "slime_erased"), "물리친 몬스터와 얻은 재료가 도감에 적힘")
	var mon_n := 15 + Data.Book.SPECIES.size() * 2
	check(GameState.dex_entries("mon").size() == mon_n and GameState.dex_entries("gear").size() == 60 and GameState.dex_entries("crop").size() == 8, "도감 묶음의 크기")
	var atk_d0 := GameState.gear("atk")
	for k in GameState.dex_entries("mon"):
		GameState.dex_add("mon", str(k))
	check(GameState.dex_count("mon") == mon_n and GameState.gear("atk") == atk_d0 + 3, "몬스터 묶음을 다 채우면 공격력 +3")
	check(not GameState.museum_ready("mon", 25), "박물관이 없으면 보상을 못 받음")
	hhud.call("toggle_menu", "dex")
	await frames(3)
	check(bool(hhud.call("is_menu_open", "dex")), "도감 창이 열림")
	await shot("life_24_dex.png")
	hhud.call("toggle_menu", "dex")
	home.call("start_placing", "bld_museum")
	check(bool(await home.call("place_at", Vector2(1000, 600), 0.9)), "박물관을 지음")
	var museum: Node = null
	for n in get_tree().get_nodes_in_group("home_object"):
		if str(n.get("id")) == "bld_museum":
			museum = n
	museum.call("interact")
	await frames(3)
	check(bool(hhud.call("is_menu_open", "donate")), "박물관에 F: (맵을 옮길 수 없는 테스트에서는) 기증 창이 열림")
	hhud.call("toggle_menu", "donate")
	await frames(2)
	check(GameState.museum_entries("fish").size() == 50 and GameState.museum_entries("forage").size() == 50
		and GameState.museum_entries("mon").size() == 90 and GameState.museum_entries("gear").size() == 60, "박물관 묶음: 물고기 50, 채집물 50, 몬스터 90, 장비 60")
	var MuseumScript := load("res://scripts/data/museum_data.gd")
	var mg: Dictionary = MuseumScript.groups()
	check((mg["bug"] as Array).size() == 18 and (mg["flower"] as Array).size() == 12 and (mg["thing"] as Array).size() == 20, "채집물 전시: 곤충 18, 꽃 12, 그 밖의 것 20")
	GameState.museum = {}
	GameState.consumables["f_carp"] = 1
	GameState.consumables.erase("f_minnow")
	check(GameState.can_donate("fish", "f_carp") and not GameState.can_donate("fish", "f_minnow"), "가방에 있는 것만 기증할 수 있음")
	check(GameState.donate("fish", "f_carp") and GameState.consumable_count("f_carp") == 0 and GameState.museum_has("fish", "f_carp"), "기증하면 가방에서 빠지고 전시됨")
	GameState.consumables["f_carp"] = 1
	check(not GameState.donate("fish", "f_carp"), "같은 것은 한 번만 기증")
	GameState.sketches = {"slime": 1}
	check(GameState.donate("mon", "slime") and not GameState.sketches.has("slime"), "몬스터 스케치를 기증함")
	GameState.inventory.append(Items_.make("hat", 3, 1, 1))
	check(GameState.donatable("gear").has("hat_3") and GameState.donate("gear", "hat_3") and GameState.museum_has("gear", "hat_3"), "장비를 기증함 (그 모양이 전시됨)")
	var dn: Control = hhud.call("menu", "donate")
	GameState.consumables["fg_5"] = 1
	hhud.call("toggle_menu", "donate")
	dn.call("_set_tab", 1)
	await frames(3)
	await shot("life_24a_donate.png")
	dn.call("_donate", "forage", "fg_5")
	check(GameState.museum_has("forage", "fg_5"), "기증 창의 단추로 기증함")
	for id in GameState.museum_entries("mon"):
		GameState.museum["mon"][str(id)] = true
	var c_m := GameState.coins
	var coat_m := GameState.consumable_count("coating")
	for pct in [25, 50, 75, 100]:
		dn.call("_museum_claim", "mon", pct)
	check(GameState.coins > c_m and GameState.consumable_count("coating") == coat_m + 1, "몬스터 전시실 25~100%% 보상을 받음 (동전 +%d)" % (GameState.coins - c_m))
	check(not GameState.museum_claim("mon", 100), "같은 보상은 한 번만")
	check(not GameState.museum_ready("fish", 25), "덜 채운 묶음은 받을 수 없음")
	hhud.call("toggle_menu", "donate")
	await frames(3)
	var sk0 := GameState.sketches.size()
	for i in 400:
		GameState.on_kill("dots_faded")
	check(int(GameState.sketches.get("dots", 0)) > 0 and GameState.sketches.size() == sk0 + 1, "몬스터를 물리치면 가끔 몬스터 스케치가 나옴 (%d장)" % int(GameState.sketches.get("dots", 0)))
	print("[채집 50종과 곤충]")
	check(Items_.FORAGE_INFO.size() == 50 and GameState.dex_entries("forage").size() == 50, "채집물은 50종")
	var bug_ok := true
	var plant_ok := true
	for i in 300:
		bug_ok = bug_ok and str(Items_.FORAGE_INFO[GameState.roll_forage("bug")][0]) == "bug"
		plant_ok = plant_ok and str(Items_.FORAGE_INFO[GameState.roll_forage("plant")][0]) != "bug"
	check(bug_ok and plant_ok, "곤충 자리에는 곤충만, 줍는 자리에는 곤충이 아닌 것만")
	check(GameState.forage_item("x:1") == GameState.forage_item("x:1"), "채집 자리의 물건은 같은 때에는 늘 같음")
	GameState.clock = 600.0
	var day_bugs := {}
	for i in 600:
		day_bugs[GameState.roll_forage("bug")] = true
	check(not day_bugs.has("fg_33") and day_bugs.has("fg_28"), "반딧불이는 밤에만, 종이 나비는 낮에 나옴")
	GameState.consumables.erase("fg_28")
	check(GameState.catch_bug("fg_28") and GameState.consumable_count("fg_28") == 1 and GameState.dex_has("forage", "fg_28"), "잠자리채로 잡으면 가방과 도감에 들어감")

	print("[강화소]")
	check(GameState.forge_bonus() == 0.0, "강화소가 없으면 보너스 없음")
	GameState.pencil_lead = maxi(GameState.pencil_lead, 300)
	GameState.coins = maxi(GameState.coins, 1000)
	home.call("start_placing", "bld_forge")
	check(bool(await home.call("place_at", Vector2(1140, 600), 0.9)), "강화소를 지음")
	var forge_obj: Node = null
	for n in get_tree().get_nodes_in_group("home_object"):
		if str(n.get("id")) == "bld_forge":
			forge_obj = n
	check(is_equal_approx(GameState.forge_bonus(), 0.05), "강화소 1단계 정성: 성공률 +5%% (%.2f)" % GameState.forge_bonus())
	var risky := Items_.make("hat", 0, 2, 1)
	risky["plus"] = 9
	check(is_equal_approx(GameState.enhance_chance(risky, GameState.forge_bonus()), 0.35), "+9 → +10: 30% 가 35% 로")
	GameState.inventory.append(risky)
	GameState.dust = 500
	forge_obj.call("interact")
	await frames(3)
	var fp: Control = hhud.get("forge")
	check(is_instance_valid(fp) and GameState.menu_open, "강화소에 F: 강화 화면이 열림")
	fp.call("select", risky)
	await frames(2)
	await shot("life_25_forge.png")
	check(str((fp.get("_risk") as Label).text).contains("지워져요"), "+9 는 실패하면 지워진다고 알려 줌")
	GameState.consumables["coating"] = 1
	fp.set("use_coating", false)
	var lead_f := GameState.pencil_lead
	fp.set("result_hold", 1.2)
	fp.call("hit")
	await get_tree().create_timer(0.5, true).timeout
	await shot("life_25a_forge_hammer.png")
	check(fp.get("_stage") != null and bool(fp.get("busy")), "두드리면 가운데에서 망치질 연출이 나옴")
	await get_tree().create_timer(0.9, true).timeout
	await shot("life_25b_forge_result.png")
	var r_f := str(fp.get("last_result"))
	check(r_f in ["ok", "broken"] and GameState.pencil_lead < lead_f, "결과를 크게 보여 줌 (%s)" % r_f)
	while bool(fp.get("busy")):
		await frames(2)
	check(fp.get("_stage") == null, "결과 화면은 잠시 뒤 닫힘")
	check(GameState.consumable_count("coating") == 1, "코팅지 쓰기를 끄면 코팅지를 쓰지 않음")
	# 성공 연출: 반드시 성공하는 +1 → +2 → +3
	var shiny := Items_.make("tool", 0, 2, 1)
	shiny["plus"] = 1
	GameState.inventory.append(shiny)
	fp.call("select", shiny)
	fp.call("hit")
	while bool(fp.get("busy")):
		await frames(2)
	fp.call("hit")
	await get_tree().create_timer(1.25, true).timeout
	await shot("life_25c_forge_success.png")
	while bool(fp.get("busy")):
		await frames(2)
	check(int(shiny["plus"]) == 3 and str(fp.get("last_result")) == "ok", "+1 → +3 성공")
	fp.call("close")
	await frames(2)
	check(not is_instance_valid(hhud.get("forge")) and not GameState.menu_open, "닫으면 원래대로")
	# 강화 겉모습: +4 이상을 입으면 발밑에 오라
	var keep_tool: Dictionary = GameState.equipped.get("tool", {})
	shiny["plus"] = 4
	GameState.equipped["tool"] = shiny
	GameState.changed.emit()
	await frames(4)
	var aura: Sprite2D = hp.get("_aura")
	check(aura != null and aura.visible and int(hp.get("aura_plus")) == 4, "+4 를 입으면 오라가 생김")
	shiny["plus"] = 10
	GameState.changed.emit()
	await frames(20)
	check(aura.modulate.r > 0.9 and aura.modulate.b < 0.5, "+10 은 금빛 오라")
	hp.global_position = forge_obj.global_position + Vector2(0, 40)
	await frames(10)
	await shot("life_25d_aura.png")
	GameState.equipped["tool"] = keep_tool
	GameState.inventory.erase(shiny)
	GameState.changed.emit()
	await frames(4)
	check(not aura.visible, "벗으면 오라가 사라짐")
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
	# 보스 다시 도전: 보스마다, 단계마다 하루 한 번 보너스
	var c_b := GameState.coins
	var coat0 := GameState.consumable_count("coating")
	var dust0 := GameState.dust
	GameState.on_boss_killed("boss_bug")
	check(GameState.consumable_count("coating") == coat0 + 1 and GameState.coins == c_b + 80 and GameState.dust == dust0 + 4,
		"중간 보스, 지워지는 단계: 코팅지 1, 동전 80, 지우개 가루 4")
	var c_b2 := GameState.coins
	GameState.on_boss_killed("boss_bug")
	check(GameState.coins == c_b2 and not GameState.boss_bonus_ready("boss_bug"), "같은 날 같은 단계는 한 번만")
	check(not GameState.boss_bonus_ready("boss_crumple", 0) and GameState.boss_bonus_ready("boss_bug", 0) and GameState.boss_bonus_ready("boss_scribble"), "보스마다, 단계마다 따로 받음")
	var rb: Dictionary = GameState.boss_bonus_reward("boss", 3)
	check(int(rb["coating"]) == 2 and int(rb["coins"]) == 320, "대장의 빈 단계 보너스는 더 많음")
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
	p2.set("_invuln", 30.0)                          # 옆의 필드 보스에게 맞으면 채집이 끊기므로 잠깐 무적
	var fspots := 0
	for n in get_tree().get_nodes_in_group("interactable"):
		if str(n.get("mode")) == "forage":
			fspots += 1
			if fspots == 1:
				n.call("interact")
	check(fspots == 4, "사냥터에 채집 자리 4곳")
	check(bool(p2.call("is_acting")), "채집하면 캐릭터가 낫을 휘두름")
	for fi in 60:
		if not bool(p2.call("is_acting")):
			break
		await get_tree().physics_frame
	await frames(2)
	p2.set("_invuln", 0.0)
	var fleft := 0
	for n in get_tree().get_nodes_in_group("interactable"):
		if str(n.get("mode")) == "forage":
			fleft += 1
	check(fleft == 3, "주운 자리는 오늘은 사라짐")
	var gear_before := get_tree().get_nodes_in_group("pickup").size()
	var coat := GameState.consumable_count("coating")
	fb.call("take_damage", 999999, Vector2.RIGHT, false)
	await frames(3)
	check(GameState.field_boss_map() == "" and GameState.consumable_count("coating") == coat + 2 and gear_before >= 0, "필드 보스를 잡으면 코팅지(+ 오늘의 보스 보너스)를 주고 오늘은 다시 안 나옴")
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
	# 액자: 앞에서 F 로 그림판을 열고, 그린 것이 액자 안에 걸린다
	GameState.furniture["furn_6"] = 1
	room.call("_on_chosen", "furn_6")
	check(bool(room.call("place_at", Vector2(460, 200))), "액자를 놓음")
	var fi := GameState.room_items.size() - 1
	var fnode: Node2D = (room.get("items") as Array)[fi]
	var fspot: Node = null
	for c in fnode.get_children():
		if str(c.get("mode")) == "frame":
			fspot = c
	check(fspot != null, "액자 앞에 F 자리가 있음")
	(room.get("player") as Node2D).global_position = fnode.global_position + Vector2(0, 14)
	await frames(2)
	fspot.call("interact")
	await frames(2)
	var canvas: Control = room.get("_canvas")
	check(is_instance_valid(canvas) and GameState.menu_open, "F 를 누르면 그림판이 열림")
	canvas.set("strokes", [{"pts": PackedVector2Array([Vector2(0.2, 0.2), Vector2(0.8, 0.8)]), "c": 2},
		{"pts": PackedVector2Array([Vector2(0.8, 0.2), Vector2(0.2, 0.8)]), "c": 7}])
	canvas.call("_update")
	await frames(2)
	await shot("life_23a_frame_draw.png")
	canvas.call("finish")
	await frames(3)
	var hung := str(GameState.room_items[fi].get("art", ""))
	check(hung.begins_with("drawn_") and fnode.get_node_or_null("Picture") != null and not GameState.menu_open, "완성하면 그림이 액자에 걸림")
	await frames(10)
	await shot("life_23b_frame.png")
	check(GameState._furn_entry(GameState.room_items[fi]).get("art", "") == hung, "건 그림은 저장됨")
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
	check(GameState.home_objects.size() == 18 and GameState.home_sheets == 6, "지은 것과 넓힌 마을이 그대로")
	check(GameState.villager_name("kid") == "봄이" and GameState.hearts("kid") == 2 and GameState.max_difficulty == 1, "주민과 난이도 단계가 그대로")
	check(GameState.farm_plots("560_600")[1]["seed"] == "s_carrot" and GameState.room_items.size() == 2, "밭과 방이 그대로")
	check(str(GameState.room_items[1].get("art", "")).begins_with("drawn_"), "액자에 건 그림도 그대로")
	check(GameState.day > d0 + 3, "날짜가 그대로")
	home.queue_free()
	await frames(3)
	home = HomeScene.instantiate()
	add_child(home)
	await frames(5)
	check((home.get("objects") as Array).size() == 18 and home.get("size") == Vector2(1920, 720), "다시 열어도 마을이 그대로")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	print("\n결과: %d 통과 / %d 실패" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
