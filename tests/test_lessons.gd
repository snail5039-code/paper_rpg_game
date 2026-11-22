extends Node
## 튜토리얼 장 "연습 페이지" 테스트: 새 캐릭터가 13개 맵에서 선생에게 할 일을 받아 하나씩 끝내고 1장으로 넘어가는지.
## 대화는 테스트가 대신 넘기고, 할 일은 게임의 함수를 직접 불러 채운다.
## 장면이 바뀌어도 남도록 이 노드는 root 로 옮겨 간다.
## 실행: godot --headless --path . res://tests/test_lessons.tscn   (뒤에 "-- <폴더>" 를 주면 맵마다 화면을 찍는다)

const Items := preload("res://scripts/items.gd")
const Data := preload("res://scripts/game_data.gd")
const Tut := preload("res://scripts/tut_data.gd")
const DIR := "user://test_lessons/"
## 나가는 문 바로 밖 (bg px)
const OUT_AT := {"right": Vector2(1662, 470), "left": Vector2(10, 470), "top": Vector2(836, 10), "bottom": Vector2(836, 931)}

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
		await get_tree().process_frame


func shot(file: String) -> void:
	if _dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_dir.path_join(file))


## 열려 있는 대화를 넘기면서 cond 가 참이 될 때까지 기다린다
func until(cond: Callable, limit: int = 900) -> bool:
	for i in limit:
		if GameState.dialogue_open:
			var e := InputEventAction.new()
			e.action = "interact"
			e.pressed = true
			Input.parse_input_event(e)
		elif cond.call():
			return true
		await frames(1)
	return cond.call()


func map() -> Node:
	return get_tree().current_scene


func lesson_is(id: String) -> Callable:
	return func() -> bool: return GameState.lesson == id


func cleared(n: int) -> Callable:
	return func() -> bool: return GameState.tut_cleared >= n


## 선생에게 말을 걸어 첫 할 일을 받는다
func talk(first: String) -> bool:
	(map().get("npc") as Node).call("interact")
	return await until(lesson_is(first))


## 오른쪽 문으로 걸어 나가 다음 맵으로
func go_next(n: int) -> bool:
	var p: Node2D = GameState.player_ref
	p.global_position = OUT_AT[str(map().call("gate_out"))] * float(map().get("WORLD_PER_BG"))
	for i in 200:
		await frames(1)
		if GameState.current_map == "tut_%d" % n and is_instance_valid(map()) and int(map().get("map_no")) == n:
			break
	await frames(15)
	return GameState.current_map == "tut_%d" % n


func wipe() -> void:
	var d := DirAccess.open(DIR)
	if d:
		for f in d.get_files():
			d.remove(f)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else ""
	var tree := get_tree()
	get_parent().remove_child(self)
	tree.root.add_child(self)
	tree.current_scene = null
	wipe()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	GameState.save_dir = DIR
	GameState.settings = {"master": 0.0, "music": 0.0, "sfx": 0.0, "fullscreen": false, "last_slot": 0}

	print("[새 캐릭터는 연습 페이지에서 시작한다]")
	GameState.start_slot(1)
	await frames(10)
	check(GameState.lessons_on and GameState.current_map == "tut_1" and GameState.tut_cleared == 0, "새 캐릭터는 연습 페이지 첫 장에서 시작")
	GameState.intro_seen = true
	tree.reload_current_scene()
	await frames(20)
	GameState.set_cutscene(false)      # 첫 장면이 틀던 오프닝이 남긴 멈춤을 푼다
	await frames(5)
	check(Tut.MAPS.size() == 13, "연습 페이지는 13장")
	var art_ok := true
	for i in Tut.MAPS.size():
		var m: Dictionary = Tut.MAPS[i]
		for tex_name in [str(m["bg"]), str(m["npc"][1]), "portrait_" + str(m["npc"][1]), str(Data.MONSTERS[str(m["monsters"][0][0])]["sprite"])]:
			if not ResourceLoader.exists("res://assets/sprites/%s.png" % tex_name):
				art_ok = false
				print("    그림 없음: %s" % tex_name)
	check(art_ok, "13장 모두 배경, 선생, 선생 얼굴, 몬스터 그림이 있음")
	var names := {}
	var kinds := {}
	for m2 in Tut.MAPS:
		names[str(m2["npc"][0])] = true
		kinds[str(m2["monsters"][0][0])] = true
	check(names.size() == 13 and kinds.size() == 13, "맵마다 선생과 몬스터가 다름")
	var outs := {}
	var joined := true
	var opposite := {"left": "right", "right": "left", "top": "bottom", "bottom": "top"}
	for i in Tut.MAPS.size():
		outs[str(Tut.MAPS[i]["out"])] = true
		if i > 0 and str(Tut.MAPS[i]["in"]) != str(opposite[str(Tut.MAPS[i - 1]["out"])]):
			joined = false
	check(outs.size() == 4, "나가는 문이 오른쪽, 왼쪽, 위, 아래 네 방향 모두 나옴")
	check(joined, "앞 맵에서 나간 방향의 반대쪽으로 다음 맵에 들어옴")

	print("[1 표지 안쪽: 이동, 말 걸기]")
	var hud: Node = map().get("hud")
	check(str(hud.get("quest_text_override")).contains("이름표 아저씨"), "할 일: 선생에게 말 걸기")
	var p: Node2D = GameState.player_ref
	p.global_position = Vector2(1662, 470) * float(map().get("WORLD_PER_BG"))
	await frames(10)
	check(GameState.current_map == "tut_1" and not (map().get("_gate") as CollisionShape2D).disabled, "할 일을 끝내기 전에는 오른쪽 문이 막혀 있어서 나갈 수 없음")
	p.global_position = Vector2(700, 600) * float(map().get("WORLD_PER_BG"))
	(map().get("npc") as Node).call("interact")
	check(await until(cleared(1)), "말을 걸면 첫 장이 끝남")
	await shot("tut_01.png")
	check(await go_next(2), "열린 문으로 나가면 2장으로")

	print("[2 줄 공책 길: 공격]")
	check(await talk("attack"), "선생이 할 일을 줌 (오타 세 마리)")
	for i in 3:
		map().call("_on_monster_died", Vector2(400, 300), "tm2")
	await frames(20)
	await shot("tut_02.png")
	check(await until(cleared(2)), "세 마리를 물리치면 끝")
	check(await go_next(3), "3장으로")

	print("[3 모눈 징검다리: 회피]")
	check(await talk("dodge"), "회피 수업")
	for i in 3:
		GameState.lesson_note("dodge")
	await shot("tut_03.png")
	check(await until(cleared(3)) and await go_next(4), "세 번 피하면 끝, 4장으로")

	print("[4 스티커 언덕: 능력치]")
	check(await talk("stat") and GameState.level >= 2 and GameState.stat_points > 0, "스티커를 받아 필력이 오름")
	GameState.add_stat("pressure")
	await shot("tut_04.png")
	check(await until(cleared(4)) and await go_next(5), "능력치를 올리면 끝, 5장으로")

	print("[5 허수아비 마당: 스킬 체험과 배우기]")
	check(await talk("trial") and GameState.trial and GameState.skill_rank("press") == 1, "체험 중에는 안 배운 스킬도 쓸 수 있음")
	p = GameState.player_ref
	var mp0 := float(p.get("mp"))
	check(bool(p.call("use_skill_slot", 0, Vector2.RIGHT)) and is_equal_approx(float(p.get("mp")), mp0), "체험 중에는 MP 가 줄지 않음")
	var dummy: Node = null
	for e in tree.get_nodes_in_group("enemies"):
		if str(e.get("kind")) == "tm5":
			dummy = e
	dummy.call("take_damage", 50, Vector2.RIGHT)
	check(int(dummy.get("hp")) == int(dummy.get("max_hp")), "허수아비는 쓰러지지 않음")
	await shot("tut_05.png")
	await frames(40)
	p.call("use_skill_slot", 1, Vector2.RIGHT)
	await frames(40)
	p.call("use_skill_slot", 2, Vector2.RIGHT)
	check(await until(lesson_is("learn")) and not GameState.trial and GameState.skill_rank("slash") == 0 and GameState.skill_points >= 1,
		"세 가지를 써 보면 체험이 끝나고, 스킬 포인트를 받아 배우기로")
	check(GameState.learn_skill("slash"), "긋기를 배움")
	GameState.skill_slots[0] = "slash"
	check(await until(cleared(5)) and await go_next(6), "배워서 칸에 넣으면 끝, 6장으로")

	print("[6 별표 광장: 필살기]")
	check(await talk("ult") and GameState.trial, "필살기를 써 볼 수 있게 열림")
	GameState.lesson_skill("ult")
	await shot("tut_06.png")
	check(await until(cleared(6)) and not GameState.trial and await go_next(7), "필살기를 쓰면 끝, 7장으로")

	print("[7 필통 가게: 장비와 소모품]")
	check(await talk("equip"), "모자를 받음")
	var hat_i := -1
	for i in GameState.inventory.size():
		if str(GameState.inventory[i]["slot"]) == "hat":
			hat_i = i
	check(hat_i >= 0 and GameState.equip(hat_i), "모자를 씀")
	check(await until(lesson_is("potion")) and GameState.consumable_count("bandage") >= 2, "반창고를 받음")
	p = GameState.player_ref
	check(int(p.get("hp")) < int(p.get("max_hp")) and bool(p.call("use_consumable", "bandage")), "체력이 깎여 있고 반창고를 씀")
	await shot("tut_07.png")
	check(await until(cleared(7)) and await go_next(8), "끝, 8장으로")

	print("[8 풀칠 작업대: 만들기와 강화]")
	check(await talk("craft") and GameState.material_count(0) >= 2, "재료를 받음")
	(map().get("npc") as Node).call("interact")
	await frames(3)
	check(bool(map().get("hud").call("is_menu_open", "shop")), "할 일을 하는 동안 선생에게 말을 걸면 작업대가 열림")
	map().get("hud").call("toggle_menu", "shop")
	await frames(3)
	check(GameState.craft(Items.RECIPES[0]), "반창고를 만듦")
	check(await until(lesson_is("enhance")), "강화로")
	check(GameState.enhance(GameState.equipped["tool"]) != "" and GameState.lesson_count("enhance") == 1, "장비를 한 번 강화함")
	await shot("tut_08.png")
	check(await until(cleared(8)) and await go_next(9), "끝, 9장으로")

	print("[9 낙서 풀밭: 다시 그리기]")
	check(await talk("capture") and GameState.consumable_count("paper") >= 1, "도화지를 받음")
	var friends_n := GameState.friends.size()
	check(GameState.try_capture("tm9", 0.5) == "practice" and GameState.friends.size() == friends_n, "연습 페이지의 낙서는 다시 그려 줘도 친구가 되지는 않음")
	await shot("tut_09.png")
	check(await until(cleared(9)) and await go_next(10), "끝, 10장으로")

	print("[10 물감 웅덩이: 낚시]")
	check(await talk("fish"), "낚시 수업")
	var has_spot := false
	for n in tree.get_nodes_in_group("interactable"):
		if str(n.get("mode")) == "fish":
			has_spot = true
	check(has_spot, "맵에 낚시 자리가 있음")
	check(GameState.catch_fish("home") != "", "한 마리 낚음")
	await shot("tut_10.png")
	check(await until(cleared(10)) and await go_next(11), "끝, 11장으로")

	print("[11 색종이 텃밭: 채집, 농사, 요리]")
	check(await talk("forage"), "채집 수업")
	check(GameState.take_forage("tut:0") != "", "풀을 주움")
	check(await until(lesson_is("farm")) and GameState.consumable_count("s_radish") >= 1, "씨앗을 받음")
	check(GameState.plant("tut", 0, "s_radish") and GameState.water("tut") == 1, "심고 물을 줌")
	check(await until(lesson_is("cook")) and GameState.consumable_count("c_radish") >= 2, "무를 받음")
	check(GameState.cook("d_radish"), "무 조림을 만듦")
	await shot("tut_11.png")
	check(await until(cleared(11)) and await go_next(12), "끝, 12장으로")

	print("[12 빈 모눈종이: 집 짓기와 잠자기]")
	check(await talk("build") and map().get("lot") != null, "집터가 있음")
	map().set("_built", true)
	(map().get("lot") as Node).call("show_sprite", "bld_house", 70.0)
	map().set("_counts", {"build": 1})
	check(await until(lesson_is("sleep")), "집을 지으면 잠자기로")
	var day0 := GameState.day
	(map().get("lot") as Node).call("interact")
	check(await until(cleared(12)) and GameState.day == day0 + 1, "집 앞에서 자면 하루가 지나고 끝")
	await shot("tut_12.png")
	check(await go_next(13), "13장으로")

	print("[13 마지막 장: 작은 보스]")
	check(await talk("boss"), "시험")
	var boss_there := false
	for e in tree.get_nodes_in_group("boss"):
		if str(e.get("kind")) == "tm13":
			boss_there = true
	check(boss_there, "큰 가위표가 있음")
	await shot("tut_13.png")
	map().call("_on_monster_died", Vector2(400, 300), "tm13")
	check(await until(cleared(13)), "보스를 물리치면 연습 페이지가 끝남")
	check(bool(GameState.settings.get("tutorial_done", false)), "한 번 끝내면 다음 캐릭터는 건너뛸 수 있음")
	p = GameState.player_ref
	p.global_position = Vector2(1662, 470) * float(map().get("WORLD_PER_BG"))
	for i in 200:
		await frames(1)
		if GameState.current_map == "ch1":
			break
	await frames(20)
	GameState.set_cutscene(false)
	check(GameState.current_map == "ch1" and GameState.quest == GameState.Quest.NOT_STARTED, "오른쪽으로 나가면 1장 공책 마을 (하루와 이야기하기 전)")

	print("[1장: 말랑이 → 다리]")
	await frames(10)
	var haru: Node = null
	for n in tree.get_nodes_in_group("interactable"):
		if n.has_method("interact") and str(n.get("npc_name")) == "하루":
			haru = n
	haru.call("interact")
	check(await until(lesson_is("capture")) and GameState.consumable_count("paper") >= 1, "하루가 도화지를 주고 말랑이를 다시 그려 달라고 함")
	check(GameState.try_capture("slime_faded", 0.1) == "ok" and GameState.friends.size() == 1, "1장의 첫 친구는 서툴게 그려도 반드시 됨")
	check(await until(lesson_is("bridge")), "말랑이가 친구가 되면 다리 그리기로")

	print("[저장과 건너뛰기]")
	GameState.save_game()
	GameState.start_slot(1)
	await frames(10)
	GameState.set_cutscene(false)
	check(GameState.tut_cleared == 13 and GameState.lesson == "bridge" and GameState.current_map == "ch1", "진행이 저장됨")
	GameState.start_slot(2, true)
	await frames(10)
	check(not GameState.lessons_on and GameState.quest == GameState.Quest.CLEARED and GameState.current_map == "home",
		"건너뛰면 1장까지 끝낸 것으로 하고 내 마을에서 시작")
	check(GameState.level == 2 and GameState.skill_points >= 1 and GameState.friends.size() == 1, "건너뛰어도 필력 2, 스킬 포인트, 말랑이는 받음")

	wipe()
	GameState.save_dir = "user://"
	print("")
	print("결과: %d 통과 / %d 실패" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
