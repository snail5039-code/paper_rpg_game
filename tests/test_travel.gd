extends Node
## 맵 이동 테스트: 시작 장면 → 1장 → (문) → 내 마을 → (포탈) → 1장.
## 장면이 바뀌어도 남아 있도록 이 노드는 스스로 root 로 옮겨 간다.
## 실행: godot --headless --path . res://tests/test_travel.tscn

var passed := 0
var failed := 0


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


func scene_name() -> String:
	var s := get_tree().current_scene
	return str(s.name) if s else ""


func _run() -> void:
	var tree := get_tree()
	get_parent().remove_child(self)
	tree.root.add_child(self)
	tree.current_scene = null   # 장면이 바뀔 때 이 노드가 같이 지워지지 않게
	GameState.save_path = "user://test_travel_save.json"
	GameState.quest = GameState.Quest.CLEARED
	GameState.ch1_step = 8          # 1장 뒷이야기는 끝낸 것으로 (마을에 들어가면 그림책 장면이 나와 멈춘다)
	GameState.bridge_built = true
	GameState.intro_seen = true
	GameState.home_intro_seen = true
	GameState.has_saved_position = false
	GameState.current_map = "ch1"
	GameState.home_cells = ""
	GameState.home_doodles = []

	print("[맵 이동]")
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await frames(30)
	check(scene_name() == "Village", "시작하면 저장된 맵(1장)이 열림 (%s)" % scene_name())
	check(get_tree().current_scene.is_in_group("game_map"), "1장이 게임 맵으로 등록됨")

	check(GameState.goto_map("home", "from_ch1"), "내 마을로 이동 요청")
	await frames(30)
	check(scene_name() == "Home" and GameState.current_map == "home", "내 마을이 열림 (%s)" % scene_name())
	var home := get_tree().current_scene
	var player: Node2D = home.get("player")
	var portal: Node2D = (home.get("portals") as Array)[0]
	check(player.global_position.distance_to(portal.global_position) < 80.0, "1장에서 오면 1장 포탈 앞에 섬")

	GameState.save_game()
	GameState.current_map = "ch1"
	check(GameState.load_game() and GameState.current_map == "home", "지금 있는 맵이 저장됨")

	player.global_position = portal.global_position + Vector2(-20, 6)
	await frames(5)
	check(bool(player.call("try_interact")), "포탈에 F 로 들어가기")
	await frames(30)
	check(scene_name() == "Village" and GameState.current_map == "ch1", "1장으로 돌아옴 (%s)" % scene_name())
	var village := get_tree().current_scene
	var p2: Node2D = village.get("player")
	var goal: Node2D = village.get("goal")
	var d := p2.global_position.distance_to(goal.global_position)
	check(d > 30.0 and d < 90.0, "빨간 문 앞에서 시작하고, 바로 다시 빨려 들어가지 않음 (거리 %.0f)" % d)
	await frames(40)
	check(scene_name() == "Village" and not GameState.cutscene, "가만히 있으면 1장에 머무름")

	print("[1장 화면 사이 이동]")
	GameState.quest = GameState.Quest.FIND_LEAD
	p2.set("_invuln", 999.0)
	p2.global_position = Vector2(805, 880) * (640.0 / 1672.0)
	Input.action_press("move_down")
	await frames(12)
	Input.action_release("move_down")
	await frames(30)
	check(scene_name() == "Field" and GameState.current_map == "ch1_crossroad", "마을 아래쪽 문으로 나가면 갈림길 (%s)" % GameState.current_map)
	var field := get_tree().current_scene
	var p3: Node2D = field.get("player")
	p3.set("_invuln", 999.0)
	check(p3.global_position.y < 200.0 * (640.0 / 1672.0), "갈림길의 위쪽 문 앞에 섬")
	p3.global_position = Vector2(1600, 470) * (640.0 / 1672.0)
	Input.action_press("move_right")
	await frames(30)
	Input.action_release("move_right")
	await frames(30)
	check(GameState.current_map == "ch1_gridwoods", "갈림길 오른쪽 문으로 나가면 모눈 숲 (%s)" % GameState.current_map)
	var p4: Node2D = get_tree().current_scene.get("player")
	check(p4.global_position.x < 600.0 * (640.0 / 1672.0), "모눈 숲의 왼쪽 문 쪽에서 시작")
	GameState.save_game()
	GameState.current_map = "ch1"
	check(GameState.load_game() and GameState.current_map == "ch1_gridwoods", "사냥터 화면에서도 지금 있는 맵이 저장됨")

	print("[끝없는 탑]")
	check(GameState.goto_map("home", ""), "내 마을로")
	await frames(30)
	var home2 := get_tree().current_scene
	var tower_portal: Node2D = null
	for pt in home2.get("portals"):
		if str(pt.get("target_map")) == "tower":
			tower_portal = pt
	check(tower_portal != null and not bool(tower_portal.get("locked")), "내 마을에 탑 문이 있음")
	GameState.tower_best = 0
	var fat0 := GameState.fatigue
	tower_portal.call("interact")
	await frames(30)
	var tower := get_tree().current_scene
	check(scene_name() == "Tower" and GameState.current_map == "tower" and int(tower.get("floor_no")) == 1, "탑 문으로 들어가면 1층 (%s)" % scene_name())
	check(GameState.fatigue == fat0, "탑은 피로도가 들지 않음")
	var n1 := int(tower.get("remaining"))
	check(n1 >= 4 and not bool(tower.get("cleared")), "1층에 몬스터 %d마리, 위쪽 문은 닫힘" % n1)
	var tp: Node2D = tower.get("player")
	tp.set("_invuln", 999.0)
	var c_t := GameState.coins
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_method("take_damage"):
			e.call("take_damage", 999999, Vector2.RIGHT, false)
	await frames(20)
	check(bool(tower.get("cleared")) and GameState.tower_best == 1 and GameState.coins >= c_t + 20, "다 물리치면 층을 끝내고 보상 (첫 기록은 두 배)")
	tp.global_position = Vector2(836, 150) * (640.0 / 1672.0)
	Input.action_press("move_up")
	await frames(30)
	Input.action_release("move_up")
	await frames(30)
	var tower2 := get_tree().current_scene
	check(GameState.current_map == "tower" and int(tower2.get("floor_no")) == 2 and GameState.tower_floor == 2, "위쪽 문으로 나가면 2층")
	check(float(tower2.get("remaining")) > n1 - 1, "층이 오르면 몬스터가 같거나 많음")
	var k5: Vector2 = tower2.call("floor_mult", 5)
	check(k5.x > 1.5 and tower2.call("is_boss_floor", 5) and str(tower2.call("floor_monsters", 5)[0][0]) == "boss_bug", "5층: 대장(지우개똥 벌레)과 더 센 몬스터")
	var r5: Dictionary = GameState.tower_reward(5, false)
	check(int(r5["coating"]) == 1 and int(r5["gear"]) == 1, "5층마다 코팅지와 장비")
	var tp2: Node2D = tower2.get("player")
	tp2.set("_invuln", 999.0)
	tp2.global_position = Vector2(836, 830) * (640.0 / 1672.0)
	Input.action_press("move_down")
	await frames(30)
	Input.action_release("move_down")
	await frames(30)
	check(GameState.current_map == "home" and GameState.tower_floor == 0 and GameState.tower_best == 1, "아래쪽 문으로 나가면 내 마을, 기록은 남음")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	print("\n결과: %d 통과 / %d 실패" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
