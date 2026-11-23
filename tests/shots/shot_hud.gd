extends Node
## HUD 배치 확인용 화면 캡처 (눈으로 확인용).
## 실행: godot --path . res://tests/shots/shot_hud.tscn -- <출력폴더>

const FieldScene := preload("res://scenes/field.tscn")

var _dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_dir.path_join(file))


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	GameState.save_path = "user://shot_hud_save.json"
	GameState.clock = 600.0
	GameState.intro_seen = true
	GameState.quest = GameState.Quest.FIND_LEAD
	GameState.level = 7
	GameState.stat_points = 2
	GameState.coins = 1234
	GameState.pencil_lead = 12
	GameState.field_boss = {"day": GameState.day, "map": "", "dead": true}
	GameState.spawn_tag = "gate_top"
	GameState.has_saved_position = false
	var f: Node2D = FieldScene.instantiate()
	f.set("field_id", "ch1_crossroad")
	add_child(f)
	await _frames(20)
	var p: Node2D = f.get("player")
	p.set("_invuln", 999.0)
	p.set("hp", 61)
	GameState.buffs = {"atk": 125.0, "exp": 300.0}
	GameState.notify("연필심 3개를 주웠다!")
	await _frames(10)
	await _shot("hud_1_field.png")
	# 보스 막대
	var e: Node = get_tree().get_nodes_in_group("enemies")[0]
	e.add_to_group("boss")
	e.set("display_name", "지우개 벌레")
	await _frames(6)
	var hud: Node = f.get("hud")
	hud.call("_show_menu_tip", (hud.get("_menu_btns") as Array)[0], "가방 (I)")
	await _frames(2)
	await _shot("hud_2_boss.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	get_tree().quit()
