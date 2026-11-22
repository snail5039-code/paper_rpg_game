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

	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	print("\n결과: %d 통과 / %d 실패" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
