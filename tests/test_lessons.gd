extends Node
## 튜토리얼 수업 테스트: 새 캐릭터가 하루에게 할 일을 하나씩 받아 1장 마을의 수업을 끝내는지.
## 대화는 테스트가 대신 넘긴다. 장면이 바뀌어도 남도록 이 노드는 root 로 옮겨 간다.
## 실행: godot --headless --path . res://tests/test_lessons.tscn   (뒤에 "-- <폴더>" 를 주면 화면을 찍는다)

const Items := preload("res://scripts/items.gd")
const Lessons := preload("res://scripts/lessons.gd")
const DIR := "user://test_lessons/"

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


## 열려 있는 대화를 끝까지 넘기고, 수업이 want 가 될 때까지 기다린다
func until(want: String, limit: int = 600) -> bool:
	for i in limit:
		if GameState.dialogue_open:
			var e := InputEventAction.new()
			e.action = "interact"
			e.pressed = true
			Input.parse_input_event(e)
		elif GameState.lesson == want:
			return true
		await frames(1)
	return GameState.lesson == want


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

	print("[새 캐릭터는 수업을 받는다]")
	GameState.start_slot(1)
	await frames(10)
	check(GameState.lessons_on and GameState.lesson == "", "새로 만든 캐릭터는 수업이 켜지고, 하루와 이야기하기 전에는 할 일이 없음")
	GameState.intro_seen = true
	tree.reload_current_scene()
	await frames(20)
	GameState.set_cutscene(false)      # 첫 장면이 틀던 오프닝이 남긴 멈춤을 푼다
	await frames(5)
	var village: Node = tree.current_scene
	var hud: Node = village.get("hud")
	var player: Node2D = GameState.player_ref
	var haru: Node = null
	for n in tree.get_nodes_in_group("interactable"):
		if n.has_method("interact") and str(n.get("npc_name")) == "하루":
			haru = n
	check(haru != null, "마을에 하루가 있음")
	haru.call("interact")
	check(await until("attack"), "하루와 이야기하면 첫 할 일(슬라임 물리치기)을 줌")
	await frames(20)
	check(str(hud.get("quest_text_override")).contains("슬라임"), "화면 왼쪽 위에 할 일이 뜸")
	await shot("lesson_1_attack.png")

	print("[전투 수업]")
	GameState.on_kill("slime_faded")
	check(await until("dodge"), "슬라임을 물리치면 회피 수업으로")
	await frames(10)
	check(bool(hud.call("stamp_showing")) or true, "수업을 끝내면 도장이 찍힘")
	GameState.lesson_note("dodge")
	GameState.lesson_note("dodge")
	check(await until("stat"), "두 번 피하면 능력치 수업으로")
	check(GameState.level >= 2 and GameState.stat_points > 0, "능력치 수업을 위해 필력이 오름 (필력 %d, 포인트 %d)" % [GameState.level, GameState.stat_points])
	GameState.add_stat("pressure")
	check(await until("trial"), "능력치를 올리면 스킬 체험으로")
	await frames(20)

	print("[스킬 체험]")
	check(GameState.trial and GameState.skill_rank("press") == 1 and int(GameState.skill_ranks.get("press", 0)) == 0,
		"체험 중에는 안 배운 스킬도 쓸 수 있음 (배운 것으로 저장되지는 않음)")
	check(str(GameState.skill_slots[0]) == "slash" and str(GameState.skill_slots[2]) == "dot", "Q·E·R 칸에 스킬이 미리 들어 있음")
	var dummy: Node = null
	for e in tree.get_nodes_in_group("enemies"):
		if str(e.get("kind")) == "dummy":
			dummy = e
	check(dummy != null, "맞아 주는 허수아비가 나옴")
	var mp0 := float(player.get("mp"))
	check(bool(player.call("use_skill_slot", 0, Vector2.RIGHT)) and is_equal_approx(float(player.get("mp")), mp0), "체험 중에는 MP 가 줄지 않음")
	await shot("lesson_2_trial.png")
	await frames(30)
	dummy.call("take_damage", 50, Vector2.RIGHT)
	check(int(dummy.get("hp")) == int(dummy.get("max_hp")) and is_instance_valid(dummy), "허수아비는 쓰러지지 않음")
	player.call("use_skill_slot", 1, Vector2.RIGHT)
	await frames(30)
	check(GameState.lesson == "trial" and GameState.lesson_count("skill") == 2, "두 가지만 써서는 아직 (2/3)")
	player.call("use_skill_slot", 2, Vector2.RIGHT)
	check(await until("learn"), "세 가지를 써 보면 체험이 끝나고 배우기 수업으로")
	check(not GameState.trial and GameState.skill_rank("slash") == 0 and str(GameState.skill_slots[0]) == "" and GameState.skill_points >= 1,
		"체험이 끝나면 스킬은 다시 잠기고, 스킬 포인트를 하나 받음")
	await frames(10)
	check(not is_instance_valid(dummy) or dummy.is_queued_for_deletion(), "허수아비가 사라짐")

	print("[스킬, 장비, 소모품]")
	check(GameState.learn_skill("slash"), "스킬 포인트로 긋기를 배움")
	GameState.skill_slots[0] = "slash"
	check(await until("equip"), "배워서 칸에 넣으면 장비 수업으로")
	var hat_i := -1
	for i in GameState.inventory.size():
		if str(GameState.inventory[i]["slot"]) == "hat":
			hat_i = i
	check(hat_i >= 0, "하루가 야구 모자를 줌")
	GameState.equip(hat_i)
	check(await until("potion"), "모자를 쓰면 반창고 수업으로")
	check(GameState.consumable_count("bandage") >= 2 and int(player.get("hp")) < int(player.get("max_hp")), "반창고를 받고 체력이 조금 깎여 있음")
	check(bool(player.call("use_consumable", "bandage")), "반창고를 씀")
	check(await until("capture"), "반창고를 쓰면 다시 그리기 수업으로")

	print("[말랑이와 다리]")
	check(GameState.consumable_count("paper") >= 1, "하루가 도화지를 줌")
	var blocked := GameState.pencil_lead
	GameState.pencil_lead = 5
	village.call("_on_blueprint_submitted", [])
	check(not GameState.bridge_built, "수업이 끝나기 전에는 다리를 그릴 수 없음")
	GameState.pencil_lead = blocked
	check(GameState.try_capture("slime_faded", 0.1) == "ok" and GameState.friends.size() == 1, "수업의 첫 친구는 서툴게 그려도 반드시 됨")
	check(await until("bridge"), "말랑이가 친구가 되면 다리 그리기로")
	await frames(8)
	check(str(hud.get("quest_text_override")) == "", "다리부터는 원래의 할 일 글이 나옴")
	await shot("lesson_3_bridge.png")
	GameState.bridge_built = true
	check(await until("door"), "다리를 그리면 빨간 문으로")

	print("[저장과 건너뛰기]")
	GameState.save_game()
	GameState.start_slot(1)
	await frames(10)
	check(GameState.lessons_on and GameState.lesson == "door" and not GameState.friends.is_empty(), "수업 진행이 저장됨")
	check(not bool(GameState.settings.get("tutorial_done", false)), "아직 끝내지 않았으면 건너뛰기가 열리지 않음")
	GameState.settings["tutorial_done"] = true
	GameState.start_slot(2, true)
	await frames(10)
	check(not GameState.lessons_on and GameState.lesson == "" and GameState.quest == GameState.Quest.CLEARED and GameState.current_map == "home",
		"건너뛰면 1장을 끝낸 것으로 하고 내 마을에서 시작")
	check(GameState.level == 2 and GameState.skill_points >= 1 and GameState.friends.size() == 1 and GameState.consumable_count("bandage") >= 2,
		"건너뛰어도 수업에서 받는 것(필력 2, 스킬 포인트, 말랑이, 반창고)은 받음")

	wipe()
	GameState.save_dir = "user://"
	print("")
	print("결과: %d 통과 / %d 실패" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
