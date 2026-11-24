extends Node
## 2장 색연필 숲 이야기 테스트 + 화면 캡처 (scripts/maps/ch2_story.gd).
## 실행: godot --headless --path . res://tests/test_ch2.tscn
##       godot --path . res://tests/test_ch2.tscn -- <캡처 폴더>
## 대화는 저절로 넘기고, 따라 그리기는 점선대로 그린 것으로 친다.

const FieldScene := preload("res://scenes/field.tscn")
const Data := preload("res://scripts/data/game_data.gd")
const Villager := preload("res://scripts/actors/villager.gd")
const S := 640.0 / 1672.0

var passed := 0
var failed := 0
var _dir := ""
var auto := true
var dialogs: Array = []     # 지나간 대화 (말한 사람, 첫 줄)
var hud: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.dialogue_requested.connect(func(sp, lines, _p): dialogs.append([str(sp), str(lines[0]) if not lines.is_empty() else "", "\n".join(lines)]))
	_run.call_deferred()


func _process(_d: float) -> void:
	if not auto:
		return
	if GameState.dialogue_open:
		GameState.end_dialogue()
	if hud and is_instance_valid(hud):
		var panel: Control = hud.call("trace_panel")
		if bool(panel.get("active")):
			panel.set("strokes", (panel.get("guides") as Array).duplicate())
			panel.call("finish")


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


func open_field(id: String) -> Node2D:
	GameState.current_map = id
	GameState.spawn_tag = "gate_" + str((Data.FIELDS[id]["gates"] as Dictionary).keys()[0])
	GameState.has_saved_position = false
	var f: Node2D = FieldScene.instantiate()
	f.set("field_id", id)
	add_child(f)
	await frames(8)
	hud = f.get("hud")
	(f.get("player") as Node2D).set("_invuln", 9999.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.set("aggro_range", 0.0)
	return f


func close(f: Node2D) -> void:
	f.queue_free()
	await frames(3)


func spot_of(f: Node2D, what: String) -> Node2D:
	for n in f.get("actors").get_children():
		if str(n.get("what")) == what:
			return n
	return null


func talk_to(f: Node2D, n: Node2D) -> void:
	var p: Node2D = f.get("player")
	p.global_position = n.global_position + Vector2(-16, 4)
	await frames(3)
	await n.call("interact")
	await frames(3)


func quest_text(f: Node2D) -> String:
	return str(f.get("hud").get("quest_text_override"))


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else ""
	GameState.save_path = "user://test_ch2_save.json"
	GameState.quest = GameState.Quest.CLEARED
	GameState.intro_seen = true
	GameState.clock = 480.0
	GameState.fatigue = 100
	GameState.difficulty = 0
	GameState.ch2_step = 0
	GameState.ch2_echo = 0
	GameState.stickers = 0
	GameState.friends = []
	GameState.companion = -1
	GameState.field_boss = {"day": GameState.day, "map": "", "dead": true, "map_ch2": "", "dead_ch2": true}

	print("[2장 재료와 합치기]")
	check(Data.MATERIALS.size() == 22, "재료가 22종 (1장 12 + 2장 10)")
	var no_icon: Array = []
	for i in range(12, 22):
		if not preload("res://scripts/core/art.gd").has("mat_%d" % i):
			no_icon.append(i)
	check(no_icon.is_empty(), "2장 재료 10종에 아이콘이 있음 (%s)" % str(no_icon))
	var no_drop: Array = []
	for k in Data.MONSTERS:
		if int(Data.MONSTERS[k].get("chapter", 0)) == 2 and (Data.MONSTERS[k]["drops"] as Array).is_empty():
			no_drop.append(k)
	check(no_drop.is_empty(), "2장 몬스터가 모두 재료를 떨어뜨림 (%s)" % str(no_drop))
	var m2 := 0
	var no_art: Array = []
	for mg in Data.MERGES:
		if str(mg[0]).begins_with("m"):
			m2 += 1
			if not preload("res://scripts/core/art.gd").has("mon_friend_" + str(mg[2])):
				no_art.append(mg[2])
	check(m2 == 3 and no_art.is_empty(), "2장 합치기 조합 3개, 모두 전용 그림 (%s)" % str(no_art))
	for sp in ["kongkong", "vine"]:
		check(Data.FRIENDS.has(sp) and preload("res://scripts/core/art.gd").has("mon_friend_" + sp), "이야기 친구 %s 의 그림이 있음" % Data.FRIENDS[sp]["name"])

	print("[숲 입구 마을]")
	dialogs.clear()
	var f := await open_field("ch2")
	await frames(40)
	check(GameState.ch2_step == 1, "처음 오면 2장 이야기가 시작됨")
	check(dialogs.size() >= 2 and str(dialogs[0][0]) == "하루", "하루가 색이 빠지는 숲 이야기를 함")
	check(quest_text(f).contains("숲길"), "할 일: 숲길로 가 보기 (%s)" % quest_text(f))
	var vils: Array = []
	for n in f.get("actors").get_children():
		if n is Villager:
			vils.append(n)
	check(vils.size() == 3, "숲 마을 주민 셋")
	var echo: Node2D = null
	for v in vils:
		if bool(v.get("echo")):
			echo = v
	dialogs.clear()
	await talk_to(f, echo)
	await talk_to(f, echo)
	await talk_to(f, echo)
	check(dialogs.size() == 3 and str(dialogs[1][1]).length() < str(dialogs[0][1]).length() and str(dialogs[2][1]).length() < str(dialogs[1][1]).length(), "되풀이 주민의 말이 만날 때마다 한 글자씩 짧아짐 (%s)" % str(dialogs.map(func(d): return d[1])))
	check(Villager.echo_text(99, 1) == "(입만 벙긋거린다)" and Villager.echo_text(0, 6) == "(입만 벙긋거린다)", "다 줄거나 2장을 끝내면 입만 벙긋거림")
	await shot("ch2_1_village.png")
	# 덩굴 할머니 부탁: 덩굴 선 세 개
	var weaver: Node2D = null
	for v in vils:
		if str(v.get("vid")) == "weaver":
			weaver = v
	await talk_to(f, weaver)
	check(int(GameState.villager("weaver")["q"]) == 1, "덩굴 할머니가 덩굴 선을 부탁함")
	GameState.add_material(16, 3)
	await talk_to(f, weaver)
	check(int(GameState.villager("weaver")["q"]) == 2 and GameState.material_count(16) == 0, "덩굴 선 세 개를 주면 부탁이 끝남")
	var painter: Node2D = null
	for v in vils:
		if str(v.get("vid")) == "painter":
			painter = v
	await talk_to(f, painter)
	await talk_to(f, painter)
	check(int(GameState.villager("painter")["q"]) == 2, "곰 아저씨의 지붕을 따라 그려 칠해 줌")
	await close(f)

	print("[귀퉁이와 사냥 시합]")
	f = await open_field("ch2_path")
	var gt := spot_of(f, "gutungi")
	check(gt != null, "숲길에 귀퉁이가 있음")
	await shot("ch2_2_gutungi.png")
	dialogs.clear()
	await talk_to(f, gt)
	check(GameState.ch2_step == 2 and dialogs.any(func(d): return str(d[0]) == "귀퉁이"), "귀퉁이가 시합을 걺")
	check(quest_text(f).contains("귀퉁이보다 먼저"), "할 일에 시합이 나옴 (%s)" % quest_text(f))
	GameState.on_kill("slime_faded")
	check(int(GameState.ch2_race["kills"]) == 0, "1장 몬스터는 세지 않음")
	for i in 10:
		GameState.on_kill("m11_faded")
	check(str(GameState.ch2_race["result"]) == "win", "2장 몬스터 10마리를 먼저 잡으면 이김")
	var coins := GameState.coins
	dialogs.clear()
	await talk_to(f, gt)
	check(GameState.ch2_step == 3 and GameState.coins == coins + 150, "이기면 동전 150, 다음 단계로")
	check(dialogs.any(func(d): return str(d[1]) == "정 주지 마."), "귀퉁이가 말랑이를 보고 \"정 주지 마.\"")
	await frames(3)
	check(spot_of(f, "gutungi") == null or spot_of(f, "gutungi").is_queued_for_deletion(), "귀퉁이는 떠남")
	await close(f)
	# 지는 경우: 귀퉁이도 시간이 지나면 잡는다
	GameState.ch2_step = 2
	GameState.ch2_race = {"kills": 0, "rival": 9.0, "result": ""}
	f = await open_field("ch2_grove")
	var story: Node = f.get_node("Ch2Story")
	story.set("_rival_t", 13.9)
	await frames(10)
	check(str(GameState.ch2_race["result"]) == "lose", "귀퉁이가 먼저 10마리를 채우면 짐")
	GameState.ch2_step = 3
	await close(f)

	print("[콩콩이와 덩굴이]")
	f = await open_field("ch2_grove")
	var kong := spot_of(f, "kongkong")
	check(kong != null, "도토리 숲에 모자 잃은 도토리가 있음")
	await shot("ch2_3_kongkong.png")
	await talk_to(f, kong)
	check(GameState.ch2_step == 4 and GameState.friends.any(func(fr): return str(fr["sp"]) == "kongkong"), "모자를 다시 그려 주면 콩콩이가 친구가 됨")
	await close(f)
	f = await open_field("ch2_bigtree")
	var p: Node2D = f.get("player")
	p.global_position = Vector2(836, 760) * S
	Input.action_press("move_down")
	await frames(60)
	Input.action_release("move_down")
	await frames(3)
	check(str(f.get("last_exit")) == "", "덩굴이를 만나기 전에는 큰나무 뿌리로 못 감")
	await close(f)
	f = await open_field("ch2_cliff")
	var vine := spot_of(f, "vine")
	check(vine != null, "절벽에 끊어진 덩굴이 있음")
	await talk_to(f, vine)
	check(GameState.ch2_step == 5 and GameState.friends.any(func(fr): return str(fr["sp"]) == "vine"), "덩굴을 이어 주면 덩굴이가 친구가 되고 대장 길이 열림")
	await frames(10)
	await shot("ch2_4_cliff_drain.png")
	check(f.get("drain") != null, "색이 빠지는 경계가 있음")
	var x0: float = f.get("_drain_x")
	await frames(30)
	check(float(f.get("_drain_x")) < x0, "경계가 조금씩 다가옴")
	await close(f)
	f = await open_field("ch2_bigtree")
	p = f.get("player")
	p.global_position = Vector2(836, 760) * S
	Input.action_press("move_down")
	await frames(60)
	Input.action_release("move_down")
	await frames(3)
	check(str(f.get("last_exit")) == "bottom", "덩굴이를 만난 뒤에는 큰나무 뿌리로 감")
	await close(f)

	print("[큰나무 할아범]")
	dialogs.clear()
	f = await open_field("ch2_bossroom")
	await frames(60)
	check(dialogs.any(func(d): return str(d[0]) == "큰나무 할아범"), "들어가면 큰나무 할아범이 말을 함")
	await shot("ch2_5_oak.png")
	var oak: Node2D = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if str(e.get("kind")) == "boss_oak":
			oak = e
	check(oak != null, "대장 큰나무 할아범이 있음")
	dialogs.clear()
	oak.call("take_damage", 99999, Vector2.RIGHT, false)
	await frames(120)
	check(GameState.ch2_step == 6 and GameState.stickers == 1, "쓰러뜨리고 뿌리를 그려 주면 첫 스티커 (2장 끝)")
	check(dialogs.any(func(d): return str(d[2]).contains("하나도 생각나지 않는구나")), "할아범은 살지만 옛일을 기억하지 못함")
	check(not dialogs.any(func(d): return str(d[0]) == "큰나무 할아범" and str(d[2]).contains("고맙")), "할아범은 고맙다고 하지 않음")
	check(quest_text(f).contains("2장을 끝냈다"), "할 일: 2장 끝")
	await close(f)

	print("[저장]")
	GameState.save_game()
	GameState.ch2_step = 0
	GameState.stickers = 0
	GameState.load_game()
	check(GameState.ch2_step == 6 and GameState.stickers == 1 and GameState.ch2_echo == 3, "2장 이야기 진행이 저장됨")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	print("\n결과: %d 통과 / %d 실패" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
