extends Node
## 화면 캡처 도구: 튜토리얼의 주요 장면을 PNG로 저장한다 (눈으로 확인용).
## 실행: godot --path . res://tests/screenshot.tscn -- <출력폴더>

const S := 640.0 / 1672.0

var _dir := ""
var world: Node2D
var player: Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_dir.path_join(file))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await _frames(2)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await _frames(2)


func _skip_dialogue() -> void:
	for i in 60:
		await _frames(3)
		if not GameState.dialogue_open and not GameState.cutscene:
			await _frames(6)
			if not GameState.dialogue_open and not GameState.cutscene:
				return
		if GameState.dialogue_open:
			await _press("interact")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	GameState.save_path = "user://shot_save.json"
	GameState.quest = 0
	GameState.pencil_lead = 0
	GameState.bridge_built = false
	GameState.has_saved_position = false
	GameState.intro_seen = false
	world = preload("res://scenes/main.tscn").instantiate()
	add_child(world)
	player = world.get("player")
	var drawing: Node2D = world.get("drawing")
	var goal: Node2D = world.get("goal")

	# 1) 오프닝
	await _frames(20)
	await _shot("1_opening_closed.png")
	await _press("interact")
	await _press("interact")
	await _frames(60)
	await _shot("2_opening_open.png")
	for i in 30:
		if not GameState.cutscene:
			break
		await _press("interact")
		await _frames(12)
	await _frames(12)
	await _shot("3_monologue.png")
	await _skip_dialogue()
	await _frames(10)
	await _shot("4_hint_move.png")

	# 2) 하루와 대화
	player.global_position = Vector2(880, 492) * S
	await _frames(30)
	player.call("try_interact")
	await _frames(8)
	await _shot("5_haru_surprised.png")
	await _press("interact")
	await _frames(8)
	await _shot("6_haru_smile.png")
	await _skip_dialogue()

	# 3) 공격 모션 + 슬라임 사라짐
	var slime: Node2D = get_tree().get_nodes_in_group("enemies")[0]
	player.global_position = slime.global_position + Vector2(-22, 0)
	await _frames(3)
	player.call("attack", Vector2.RIGHT)
	await _frames(7)
	await _shot("7_attack.png")
	slime.call("take_damage", 5, Vector2.RIGHT)
	await _frames(9)
	await _shot("8_slime_vanish.png")

	# 4) 다리를 만든 뒤 문 앞
	GameState.pencil_lead = 3
	drawing.call("set_active", true)
	drawing.set("strokes", (drawing.get("guides") as Array).duplicate())
	await _press("draw_confirm")
	await _frames(40)
	player.global_position = goal.global_position + Vector2(-34, 8)
	await _frames(40)
	GameState.end_dialogue() if GameState.dialogue_open else null
	await _skip_dialogue()
	await _shot("9_door_smudged.png")

	# 5) 문 닦는 중
	drawing.call("set_active", true)
	var c: Vector2 = goal.global_position + Vector2(0, -28)
	for i in 25:
		drawing.call("_erase_at", c + Vector2(sin(i) * 9.0, cos(i) * 7.0))
	await _frames(6)
	await _shot("10_wiping.png")
	for i in 40:
		drawing.call("_erase_at", c + Vector2(sin(i) * 9.0, cos(i) * 7.0))
	await _frames(75)
	await _shot("11_monster.png")
	await _skip_dialogue()
	await _frames(10)
	await _shot("12_door_open.png")

	# 6) 페이지 넘김
	player.global_position = goal.global_position + Vector2(-8, 6)
	await _frames(20)
	await _shot("13_page_turn.png")
	await _frames(70)
	await _shot("14_page_end.png")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	get_tree().quit()
