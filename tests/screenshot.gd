extends Node
## 화면 캡처 도구: 일반 화면 / 대화 / 연필 모드를 PNG로 저장한다.
## 실행: godot --path . res://tests/screenshot.tscn -- <출력폴더>

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name))

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else OS.get_user_data_dir()
	GameState.save_path = "user://shot_save.json"
	GameState.quest = 0
	GameState.pencil_lead = 3
	GameState.bridge_built = false
	GameState.has_saved_position = false
	var world: Node2D = preload("res://scenes/main.tscn").instantiate()
	add_child(world)
	var player: Node2D = world.get("player")
	player.global_position = Vector2(20 * 16 + 4, 10 * 16 + 8)
	for i in 40: await get_tree().process_frame
	await _shot(dir, "1_village.png")
	player.call("try_interact")
	for i in 5: await get_tree().process_frame
	await _shot(dir, "2_dialogue.png")
	GameState.end_dialogue()
	var drawing: Node2D = world.get("drawing")
	drawing.call("set_active", true)
	var g: Array = drawing.get("guides")
	drawing.set("strokes", [PackedVector2Array([g[0][0] + Vector2(0, 2), (g[0][0] + g[0][1]) / 2.0 + Vector2(0, -2)])])
	for i in 5: await get_tree().process_frame
	await _shot(dir, "3_draw_mode.png")
	drawing.set("strokes", g.duplicate())
	Input.action_press("draw_confirm")
	var ev := InputEventAction.new(); ev.action = "draw_confirm"; ev.pressed = true
	Input.parse_input_event(ev); Input.flush_buffered_events()
	for i in 10: await get_tree().process_frame
	await _shot(dir, "4_bridge_built.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	get_tree().quit()
