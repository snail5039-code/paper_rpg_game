extends Node
## MVP 자동 테스트 — 핵심 루프를 실제 게임 씬 위에서 처음부터 끝까지 돌려 본다.
## 실행: godot --headless --path . res://tests/test_mvp.tscn

const MainScene := preload("res://scenes/main.tscn")
const Validator := preload("res://scripts/blueprint_validator.gd")
const Tiles := preload("res://scripts/placeholder_tiles.gd")
const TILE := 16

var passed := 0
var failed := 0
var world: Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
		print("  PASS  ", label)
	else:
		failed += 1
		print("  FAIL  ", label)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func cell_center(x: int, y: int) -> Vector2:
	return Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)


func hold(action: String, n: int) -> void:
	Input.action_press(action)
	await frames(n)
	Input.action_release(action)
	await frames(1)


func press_action(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await frames(1)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await frames(1)


func _fresh_state() -> void:
	GameState.save_path = "user://test_save.json"
	if FileAccess.file_exists(GameState.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	GameState.quest = GameState.Quest.NOT_STARTED
	GameState.pencil_lead = 0
	GameState.bridge_built = false
	GameState.has_saved_position = false


func _load_world() -> void:
	if world:
		world.queue_free()
		await frames(2)
	world = MainScene.instantiate()
	add_child(world)
	await frames(3)


func _run() -> void:
	_test_validator()
	_fresh_state()
	await _load_world()
	var player: CharacterBody2D = world.get("player")
	var ground: TileMapLayer = world.get("ground")
	var drawing: Node2D = world.get("drawing")

	print("[이동/충돌]")
	player.global_position = cell_center(5, 12)
	var x0 := player.global_position.x
	await hold("move_right", 30)
	check(player.global_position.x > x0 + 20, "D 키로 오른쪽 이동 (%.1f → %.1f)" % [x0, player.global_position.x])
	player.global_position = cell_center(1, 12)
	await hold("move_left", 40)
	check(player.global_position.x >= TILE + 3, "왼쪽 나무 벽 통과 안 함 (x=%.1f)" % player.global_position.x)
	player.global_position = cell_center(22, 5)
	await hold("move_right", 80)
	check(player.global_position.x < 24 * TILE, "강물 통과 안 함 (x=%.1f)" % player.global_position.x)
	player.global_position = cell_center(22, 10)
	await hold("move_right", 60)
	check(player.global_position.x < 24 * TILE, "다리 없을 땐 다리 자리도 못 지나감 (x=%.1f)" % player.global_position.x)

	print("[회피]")
	player.global_position = cell_center(8, 18)
	player.set("facing", Vector2.RIGHT)
	x0 = player.global_position.x
	Input.action_press("dodge")
	await frames(2)
	Input.action_release("dodge")
	check(player.call("is_dodging"), "Space 회피 발동")
	await frames(12)
	check(player.global_position.x > x0 + 20, "회피로 빠르게 이동 (%.1f px)" % (player.global_position.x - x0))

	print("[NPC 대화/퀘스트]")
	player.global_position = cell_center(21, 10)
	await frames(2)
	await press_action("interact")
	check(GameState.dialogue_open, "F 키로 대화 시작")
	check(get_tree().paused, "대화 중 게임 일시정지")
	check(GameState.quest == GameState.Quest.FIND_LEAD, "퀘스트 수락됨")
	for i in 6:
		if GameState.dialogue_open:
			await press_action("interact")
	check(not GameState.dialogue_open and not get_tree().paused, "대화 끝까지 넘기면 닫히고 재개")

	print("[미완성 상태로 그리기]")
	await press_action("toggle_draw")
	check(drawing.get("active") and get_tree().paused, "Tab 으로 연필 모드 진입 + 일시정지")
	drawing.set("strokes", drawing.get("guides").duplicate())
	await press_action("draw_confirm")
	check(not GameState.bridge_built, "연필심 0개면 정답이어도 다리 안 생김")
	await press_action("toggle_draw")
	check(not drawing.get("active") and not get_tree().paused, "Tab 으로 연필 모드 종료")

	print("[실시간 전투]")
	var kills := 0
	for round in 3:
		var slime: Node2D = null
		for e in get_tree().get_nodes_in_group("enemies"):
			slime = e
			break
		if slime == null:
			break
		var hp_before: int = slime.get("hp")
		player.global_position = slime.global_position + Vector2(-12, 0)
		await frames(1)
		player.call("attack", slime.global_position - player.global_position)
		await frames(1)
		if round == 0:
			check(not is_instance_valid(slime) or int(slime.get("hp")) < hp_before, "공격하면 슬라임 HP 감소")
		for hit in 6:
			if not is_instance_valid(slime):
				break
			player.global_position = slime.global_position + Vector2(-12, 0)
			await frames(20)
			if is_instance_valid(slime):
				player.call("attack", slime.global_position - player.global_position)
			await frames(1)
		if not is_instance_valid(slime):
			kills += 1
		# 드롭된 연필심 줍기
		await frames(20)
		for c in world.get("actors").get_children():
			if c.get_script() == preload("res://scripts/pickup.gd"):
				player.global_position = c.global_position
				await frames(5)
	check(kills == 3, "슬라임 3마리 처치 (%d)" % kills)
	check(GameState.pencil_lead >= 3, "연필심 3개 이상 획득 (%d)" % GameState.pencil_lead)
	player.set("hp", player.get("max_hp"))

	print("[슬라임 접촉 피해]")
	var s2: Node2D = null
	for e in get_tree().get_nodes_in_group("enemies"):
		s2 = e
		break
	if s2:
		player.set("_invuln", 0.0)  # 전투 중 맞아서 생긴 무적 시간 제거
		var hp0: int = player.get("hp")
		player.global_position = s2.global_position
		await frames(3)
		check(int(player.get("hp")) < hp0, "슬라임에 닿으면 HP 감소")
	player.global_position = cell_center(20, 10)
	await frames(1)

	print("[연필 모드: 다리 그리기]")
	await press_action("toggle_draw")
	var guides: Array = drawing.get("guides")
	# 1) 엉뚱한 곳에 낙서 → 실패
	drawing.set("strokes", [PackedVector2Array([Vector2(100, 100), Vector2(200, 120), Vector2(150, 200)])])
	await press_action("draw_confirm")
	check(not GameState.bridge_built, "엉뚱한 낙서는 실패")
	# 2) 지우개
	var line := PackedVector2Array()
	for i in 21:
		line.append(Vector2(100 + i * 3, 300))
	drawing.set("strokes", [line])
	drawing.call("_erase_at", Vector2(130, 300))
	var after: Array = drawing.get("strokes")
	check(after.size() == 2, "지우개로 선 가운데를 지우면 두 조각 (%d)" % after.size())
	await press_action("draw_clear")
	check((drawing.get("strokes") as Array).is_empty(), "Backspace 로 전체 지우기")
	# 3) 안내선을 손으로 따라 그린 것처럼 (살짝 흔들림)
	var hand: Array = []
	for g in guides:
		var pl: PackedVector2Array = g
		var s := PackedVector2Array()
		var n := int(pl[0].distance_to(pl[1]) / 3.0)
		for k in n + 1:
			s.append(pl[0].lerp(pl[1], float(k) / n) + Vector2(0, sin(k * 0.7) * 3.0).rotated(pl[0].angle_to_point(pl[1])))
		hand.append(s)
	drawing.set("strokes", hand)
	await press_action("draw_confirm")
	check(GameState.bridge_built, "안내선을 따라 그리면 다리 완성")
	check(GameState.quest == GameState.Quest.BRIDGE_BUILT, "퀘스트 단계: 다리 완성")
	check(GameState.pencil_lead >= 0 and GameState.pencil_lead < 3, "연필심 3개 소모 (남은 %d)" % GameState.pencil_lead)
	check(not drawing.get("active") and not get_tree().paused, "완성 후 연필 모드 자동 종료")
	var bridge_cells: Array = world.get("bridge_cells")
	check(ground.get_cell_atlas_coords(bridge_cells[0]) == Vector2i(Tiles.T.BRIDGE, 0), "다리 타일이 맵에 생김")

	print("[다리 건너기 → 도리이]")
	player.global_position = cell_center(22, 10) + Vector2(0, 6)
	await hold("move_right", 150)
	check(player.global_position.x > 28 * TILE, "다리를 건너감 (x=%.1f)" % player.global_position.x)
	check(GameState.quest == GameState.Quest.CLEARED, "도리이 도착 → MVP 클리어")
	for i in 4:
		if GameState.dialogue_open:
			await press_action("interact")

	print("[저장/불러오기]")
	check(GameState.save_game(), "저장 성공")
	GameState.quest = 0
	GameState.bridge_built = false
	GameState.pencil_lead = 99
	check(GameState.load_game(), "불러오기 성공")
	check(GameState.bridge_built and GameState.quest == GameState.Quest.CLEARED, "다리·퀘스트 상태 복원")
	var saved_pos := GameState.saved_position
	await _load_world()
	player = world.get("player")
	ground = world.get("ground")
	check(ground.get_cell_atlas_coords(bridge_cells[0]) == Vector2i(Tiles.T.BRIDGE, 0), "재시작 후에도 다리 유지")
	check(player.global_position.distance_to(saved_pos) < 1.0, "재시작 후 플레이어 위치 복원")

	# 정리
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	print("\n결과: %d 통과 / %d 실패" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _test_validator() -> void:
	print("[설계도 판정기]")
	var g := [PackedVector2Array([Vector2(0, 0), Vector2(100, 0)])]
	check(not Validator.evaluate(g, []).success, "빈 그림은 실패")
	var exact := [PackedVector2Array([Vector2(0, 2), Vector2(50, -3), Vector2(100, 1)])]
	check(Validator.evaluate(g, exact).success, "안내선 근처로 끝까지 그리면 성공")
	var half := [PackedVector2Array([Vector2(0, 0), Vector2(50, 0)])]
	check(not Validator.evaluate(g, half).success, "절반만 그리면 실패")
	var scribble := [PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 60), Vector2(0, 60), Vector2(0, 0)])]
	check(not Validator.evaluate(g, scribble).success, "넓게 마구 칠하면 실패")
