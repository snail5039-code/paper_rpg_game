extends Node
## 화면 캡처 도구 (1장 새 그림 확인용): 프롤로그, 마을의 흰 자국·주민·몬스터, HUD, 가방.
## 실행: godot --path . res://tests/shot_ch1.tscn -- <출력폴더>

const S := 640.0 / 1672.0

var _dir := ""


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
	for down in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = down
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await _frames(2)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	GameState.save_path = "user://shot_save.json"
	GameState.quest = 0
	GameState.pencil_lead = 2
	GameState.level = 1
	GameState.exp = 0
	GameState.materials = {}
	GameState.bridge_built = false
	GameState.has_saved_position = false
	GameState.intro_seen = false
	var world: Node2D = preload("res://scenes/main.tscn").instantiate()
	add_child(world)
	var player: Node2D = world.get("player")
	var hud: Node = world.get("hud")

	# 프롤로그 3컷
	for i in 3:
		await _frames(45)
		await _shot("a%d_prologue.png" % i)
		await _press("interact")
		await _press("interact")
	for i in 60:
		if not GameState.cutscene:
			break
		await _press("interact")
		await _frames(12)
	await _frames(12)
	await _shot("b_monologue.png")
	for i in 20:
		if not GameState.dialogue_open:
			break
		await _press("interact")
		await _frames(4)

	# 마을 여기저기
	GameState.quest = GameState.Quest.FIND_LEAD
	GameState.add_exp(5)
	var spots := {"c_start": Vector2(330, 500), "d_villagers": Vector2(600, 500), "e_field": Vector2(560, 690),
		"f_field2": Vector2(800, 640), "g_west": Vector2(220, 680)}
	for k in spots:
		player.global_position = spots[k] * S
		player.set("_invuln", 99.0)
		await _frames(50)
		await _shot(k + ".png")
	GameState.bridge_built = true
	for k2 in ["h_east", "i_east2"]:
		player.global_position = (Vector2(1340, 330) if k2 == "h_east" else Vector2(1340, 640)) * S
		await _frames(50)
		await _shot(k2 + ".png")

	# 주민 대화
	player.global_position = Vector2(400, 470) * S
	await _frames(20)
	player.call("try_interact")
	await _frames(8)
	await _shot("j_villager_talk.png")
	for i in 10:
		if not GameState.dialogue_open:
			break
		await _press("interact")
		await _frames(4)

	# 가방
	for id in [0, 0, 0, 1, 2, 4, 6, 8, 10, 11]:
		GameState.add_material(id)
	hud.call("toggle_bag")
	await _frames(6)
	await _shot("k_bag.png")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	get_tree().quit()
