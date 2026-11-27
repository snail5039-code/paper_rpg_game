extends Node
## 보스 등장 장면과 전용 기술 캡처 (눈으로 확인용). 보스마다: 등장 5장(0.5초 간격), 기술마다 2장(1페이즈), 2페이즈 기술마다 1장.
## 실행: godot --path . res://tests/shots/shot_boss_skill.tscn -- <출력폴더> [보스 종류...]

const BOSSES := ["tm13", "boss_bug", "boss_crumple", "boss_scribble", "boss_oak", "boss_mushking", "boss_colorworm"]
var _dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 캡처 창이 키보드·마우스를 받지 않게 (다른 창에서 치던 글자가 들어가 설정이 바뀌는 일이 있었다)
	get_window().set_flag(Window.FLAG_NO_FOCUS, true)
	get_window().gui_disable_input = true
	GameState.save_dir = OS.get_user_data_dir().path_join("shot_tmp/")
	DirAccess.make_dir_recursive_absolute(GameState.save_dir)
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
	var only: Array = args.slice(1) if args.size() > 1 else BOSSES
	var tree := get_tree()
	get_parent().remove_child(self)
	tree.root.add_child(self)
	tree.current_scene = null
	GameState.save_path = "user://shot_boss_skill_save.json"
	GameState.quest = GameState.Quest.CLEARED
	GameState.intro_seen = true
	GameState.clock = 600.0
	GameState.current_map = "ch1_erasedroad"
	GameState.spawn_tag = "gate_top"
	GameState.has_saved_position = false
	get_tree().change_scene_to_file("res://scenes/field.tscn")
	await _frames(30)
	var field := get_tree().current_scene
	var p: Node2D = field.get("player")
	p.set("_invuln", 9999.0)
	var actors: Node2D = field.get("actors")
	const BossData := preload("res://scripts/data/boss_data.gd")
	for kind in only:
		for e in get_tree().get_nodes_in_group("enemies"):
			e.queue_free()
		await _frames(3)
		GameState.bosses_met = {}
		p.global_position = Vector2(250, 230)
		var m: Node2D = load("res://scenes/enemy.tscn").instantiate()
		m.set("kind", kind)
		m.position = Vector2(340, 200)
		actors.add_child(m)
		var waited := 0
		while not GameState.cutscene and waited < 200:
			await _frames(1)
			waited += 1
		for i in 8:
			await _frames(30)
			await _shot("skill_%s_intro_%d.png" % [kind, i])
		while GameState.cutscene:
			await _frames(1)
		var br: Node = m.get("brain")
		for ph in [1, 2]:
			for sk in BossData.BOSSES[kind]["skills"]:
				if not is_instance_valid(m):
					break
				p.global_position = m.global_position + Vector2(-80, 20)
				await _frames(20)
				br.set("phase", ph)
				m.set("enraged", ph == 2)
				br.call("use", sk)
				for j in 2:
					await _frames(33)
					await _shot("skill_%s_%d_%s_%d.png" % [kind, ph, sk, j])
				while str(br.call("current")) != "":
					await _frames(1)
				await _frames(30)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	get_tree().quit()
