extends Node
## MVP 자동 테스트 — 핵심 루프를 실제 게임 씬 위에서 처음부터 끝까지 돌려 본다.
## 실행: godot --headless --path . res://tests/test_mvp.tscn

const MainScene := preload("res://scenes/main.tscn")
const Validator := preload("res://scripts/blueprint_validator.gd")
const S := 640.0 / 1672.0  # bg px → 월드

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


## 배경 원본 픽셀 좌표 → 월드 좌표
func bg(x: float, y: float) -> Vector2:
	return Vector2(x, y) * S


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
	GameState.intro_seen = true  # 오프닝 컷신은 건너뛴다


## 열려 있는 대화를 끝까지 넘긴다 (여러 사람이 이어서 말하는 대화 포함)
func skip_dialogue(max_presses: int = 40) -> void:
	for i in max_presses:
		await frames(2)
		if not GameState.dialogue_open and not GameState.cutscene:
			await frames(4)
			if not GameState.dialogue_open and not GameState.cutscene:
				return
		if GameState.dialogue_open:
			await press_action("interact")


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
	var drawing: Node2D = world.get("drawing")

	print("[이동/충돌]")
	player.global_position = bg(400, 620)
	var x0 := player.global_position.x
	await hold("move_right", 30)
	check(player.global_position.x > x0 + 20, "D 키로 오른쪽 이동 (%.1f → %.1f)" % [x0, player.global_position.x])
	player.global_position = bg(200, 640)
	await hold("move_left", 80)
	check(player.global_position.x > bg(90, 0).x, "왼쪽 나무 테두리 통과 안 함 (bg x=%.0f)" % (player.global_position.x / S))
	player.global_position = bg(490, 450)
	await hold("move_up", 80)
	check(player.global_position.y > bg(0, 380).y, "집·덤불 통과 안 함 (bg y=%.0f)" % (player.global_position.y / S))
	player.global_position = bg(860, 660)
	await hold("move_right", 120)
	check(player.global_position.x < bg(990, 0).x, "강물 통과 안 함 (bg x=%.0f)" % (player.global_position.x / S))
	player.global_position = bg(900, 512)
	await hold("move_right", 120)
	check(player.global_position.x < bg(1000, 0).x, "다리 없을 땐 다리 자리도 못 지나감 (bg x=%.0f)" % (player.global_position.x / S))

	print("[회피]")
	player.global_position = bg(300, 700)
	player.set("facing", Vector2.RIGHT)
	x0 = player.global_position.x
	Input.action_press("dodge")
	await frames(2)
	Input.action_release("dodge")
	check(player.call("is_dodging"), "Space 회피 발동")
	await frames(12)
	check(player.global_position.x > x0 + 20, "회피로 빠르게 이동 (%.1f px)" % (player.global_position.x - x0))

	print("[NPC 대화/퀘스트]")
	player.global_position = bg(880, 490)
	await frames(2)
	await press_action("interact")
	check(GameState.dialogue_open, "F 키로 대화 시작")
	check(get_tree().paused, "대화 중 게임 일시정지")
	await skip_dialogue()
	check(GameState.quest == GameState.Quest.FIND_LEAD, "대화를 끝까지 들으면 퀘스트 수락")
	check(not GameState.dialogue_open and not get_tree().paused, "대화가 끝나면 닫히고 재개")

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
		player.global_position = slime.global_position + Vector2(-20, 0)
		await frames(1)
		player.call("attack", slime.global_position - player.global_position)
		await frames(1)
		if round == 0:
			check(not is_instance_valid(slime) or int(slime.get("hp")) < hp_before, "공격하면 슬라임 HP 감소")
		for hit in 14:
			if not is_instance_valid(slime):
				break
			player.global_position = slime.global_position + Vector2(-20, 0)
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

	print("[성장: 경험치·레벨·재료·가방]")
	check(GameState.exp > 0 or GameState.level > 1, "몬스터를 잡으면 경험치를 얻음 (필력 %d, %d)" % [GameState.level, GameState.exp])
	var lv_before := GameState.level
	GameState.add_exp(GameState.exp_needed() - GameState.exp)
	check(GameState.level == lv_before + 1 and GameState.exp == 0, "경험치가 차면 레벨 업")
	GameState.add_exp(1000)
	check(GameState.level > 5 and GameState.level <= GameState.MAX_LEVEL, "한 번에 여러 레벨이 오름 (필력 %d)" % GameState.level)
	check(int(player.get("max_hp")) == GameState.max_hp() and int(player.get("hp")) == GameState.max_hp(),
		"레벨 업하면 최대 HP 가 늘고 전부 회복 (%d)" % GameState.max_hp())
	check(GameState.attack_power() > 1, "레벨이 오르면 공격력이 오름 (%d)" % GameState.attack_power())
	GameState.level = 1
	GameState.exp = 0
	player.set("max_hp", GameState.max_hp())
	player.set("hp", GameState.max_hp())
	var mat_drop: Node2D = preload("res://scripts/pickup.gd").new()
	mat_drop.set("mat_id", 2)
	world.get("actors").add_child(mat_drop)
	mat_drop.global_position = player.global_position
	await frames(30)
	check(GameState.material_count(2) == 1, "재료를 주우면 가방에 들어감")
	var hud0: Node = world.get("hud")
	hud0.call("toggle_bag")
	await frames(2)
	check(bool(hud0.call("is_bag_open")) and get_tree().paused, "가방을 열면 게임이 멈춤")
	hud0.call("toggle_bag")
	await frames(2)
	check(not bool(hud0.call("is_bag_open")) and not get_tree().paused, "가방을 닫으면 다시 움직임")
	var kinds := {}
	for e in get_tree().get_nodes_in_group("enemies"):
		kinds[str(e.get("kind"))] = true
	check(kinds.size() >= 8, "마을에 몬스터가 여러 종류 있음 (%d종)" % kinds.size())
	player.set("hp", player.get("max_hp"))

	print("[슬라임 AI: 일정 거리 안에서만 공격]")
	var s2: Node2D = null
	# 앞선 전투에서 전부 처치됐을 수 있으니, 다시 나타날 때까지(8초) 기다린다
	player.global_position = bg(1400, 700)
	for i in 700:
		for e in get_tree().get_nodes_in_group("enemies"):
			s2 = e
			break
		if s2:
			break
		await frames(1)
	check(s2 != null, "처치한 슬라임이 시간이 지나면 다시 나타남")
	if s2:
		var SState: Dictionary = s2.get("State")
		# 1) 멀리 있으면 쫓아오지 않는다
		player.set("_invuln", 0.0)
		var far := float(s2.get("aggro_range")) + 40.0
		# 앞선 전투에서 쉬는 중일 수 있으니, 계속 멀리 떨어진 채로 충분히 기다린다
		for i in 150:
			player.global_position = s2.global_position + Vector2(far, 0)
			await frames(1)
		check(int(s2.get("state")) == SState.WANDER, "멀리 있으면 쫓아오지 않음")
		# 2) 닿아 있어도 박치기 중이 아니면 피해 없음 (예고 동작이 먼저)
		var hp0: int = player.get("hp")
		player.global_position = s2.global_position + Vector2(8, 0)
		await frames(10)
		check(int(player.get("hp")) == hp0, "닿자마자 바로 피해를 주지 않음")
		check(int(s2.get("state")) == SState.WINDUP, "가까이 오면 공격 준비(예고) 동작")
		# 3) 예고 뒤 박치기에 맞으면 피해
		for i in 60:
			player.global_position = s2.global_position + Vector2(8, 0)
			await frames(1)
			if int(player.get("hp")) < hp0:
				break
		check(int(player.get("hp")) == hp0 - 1, "예고 뒤 박치기에 맞으면 HP 1 감소")
		# 4) 박치기 뒤에는 쉰다 (연속 피해 없음)
		player.set("_invuln", 0.0)
		for i in 30:
			player.global_position = s2.global_position + Vector2(8, 0)
			await frames(1)
		check(int(player.get("hp")) == hp0 - 1, "박치기 직후에는 쉬느라 연속 피해 없음")
		# 5) 멀리 도망가면 포기
		player.global_position = s2.global_position + Vector2(float(s2.get("lose_range")) + 60.0, 0)
		await frames(120)
		check(int(s2.get("state")) == SState.WANDER, "멀리 도망가면 포기하고 돌아감")
	player.global_position = bg(860, 512)
	await frames(1)

	print("[연필 모드: 다리 그리기]")
	await press_action("toggle_draw")
	var guides: Array = drawing.get("guides")
	# 1) 엉뚱한 곳에 낙서 → 실패
	drawing.set("strokes", [PackedVector2Array([Vector2(100, 150), Vector2(200, 170), Vector2(150, 250)])])
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
	await frames(2)
	check((world.get("bridge_sprite") as Sprite2D).visible, "다리 그림이 맵에 나타남")
	check(world.get("bridge_blocker") == null, "다리 자리 통행 차단이 풀림")

	print("[다리 건너기 → 빨간 문]")
	var goal: Node2D = world.get("goal")
	player.global_position = bg(900, 512)
	await hold("move_right", 130)
	check(player.global_position.x > bg(1230, 0).x, "다리를 건너감 (bg x=%.0f)" % (player.global_position.x / S))

	print("[문의 지우개 자국 닦기]")
	check(not goal.call("is_clean"), "처음에는 문이 지우개 자국에 덮여 있음")
	# 다리를 건너기 전 단계에서는 닦이지 않는지: 이미 BRIDGE_BUILT 이므로 먼 곳을 문질러 본다
	goal.call("wipe", goal.global_position + Vector2(200, 0))
	check(float(goal.get("wipe_progress")) == 0.0, "문에서 먼 곳을 문지르면 닦이지 않음")
	player.global_position = goal.global_position + Vector2(-40, 6)
	await hold("move_right", 30)
	await skip_dialogue()
	check(GameState.quest == GameState.Quest.CLEAN_DOOR, "문 앞에 가면 자국을 발견 (퀘스트: 문 닦기)")
	await press_action("toggle_draw")
	check(drawing.get("active"), "연필 모드 진입")
	var door_center: Vector2 = goal.global_position + Vector2(0, -28)
	for i in 20:
		drawing.call("_erase_at", door_center + Vector2(sin(i) * 10.0, cos(i) * 8.0))
	check(float(goal.get("wipe_progress")) > 0.3 and not goal.call("is_clean"), "지우개로 문지르면 조금씩 닦임 (%.0f%%)" % (float(goal.get("wipe_progress")) * 100.0))
	for i in 40:
		drawing.call("_erase_at", door_center + Vector2(sin(i) * 10.0, cos(i) * 8.0))
	check(goal.call("is_clean"), "끝까지 문지르면 자국이 사라짐")
	check(GameState.quest == GameState.Quest.DOOR_OPEN, "문이 열림 (퀘스트: 문으로 들어가기)")
	await skip_dialogue(80)
	check(not drawing.get("active") and not get_tree().paused, "괴물 등장 장면이 끝나면 다시 조작 가능")

	print("[페이지 넘김]")
	player.global_position = goal.global_position + Vector2(-40, 6)
	await hold("move_right", 30)
	await frames(90)
	check(GameState.quest == GameState.Quest.CLEARED, "열린 문으로 들어가면 1페이지 클리어")
	check(GameState.cutscene, "페이지 넘김 화면이 떠 있음")
	await press_action("interact")
	await frames(60)
	check(not GameState.cutscene and not get_tree().paused, "화면을 넘기면 마을로 돌아옴")

	print("[저장/불러오기]")
	check(GameState.save_game(), "저장 성공")
	GameState.quest = 0
	GameState.bridge_built = false
	GameState.pencil_lead = 99
	GameState.intro_seen = false
	check(GameState.load_game(), "불러오기 성공")
	check(GameState.bridge_built and GameState.quest == GameState.Quest.CLEARED and GameState.intro_seen, "다리·퀘스트 상태 복원")
	var saved_pos := GameState.saved_position
	await _load_world()
	player = world.get("player")
	check((world.get("bridge_sprite") as Sprite2D).visible and world.get("bridge_blocker") == null, "재시작 후에도 다리 유지")
	check((world.get("goal") as Node2D).call("is_clean"), "재시작 후에도 문이 열려 있음")
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
