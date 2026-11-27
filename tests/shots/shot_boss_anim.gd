extends Node
## 보스 7마리의 움직임 캡처 (눈으로 확인용). 보스마다 6장: 가만히, 걷기 둘, 예고, 공격, 맞음.
## 실행: godot --path . res://tests/shots/shot_boss_anim.tscn -- <출력폴더> [보스 종류...]

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
	GameState.save_path = "user://shot_boss_anim_save.json"
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
	for kind in only:
		for e in get_tree().get_nodes_in_group("enemies"):
			e.queue_free()
		await _frames(3)
		var m: Node2D = load("res://scenes/enemy.tscn").instantiate()
		m.set("kind", kind)
		m.position = Vector2(320, 190)
		actors.add_child(m)
		m.set_physics_process(false)
		p.global_position = Vector2(200, 260)
		await _frames(6)
		var poses := [["idle", 0, Vector2.ZERO, 0.0], ["walk1", 1, Vector2(30, 0), 0.1], ["walk2", 1, Vector2(30, 0), 0.5],
			["windup", 2, Vector2.ZERO, 0.4], ["attack", 3, Vector2.ZERO, 0.2], ["hurt", 0, Vector2.ZERO, 0.0]]
		for i in poses.size():
			var po: Array = poses[i]
			m.set("_flash", 0.2 if po[0] == "hurt" else 0.0)
			m.set("_lunge_dir", Vector2.RIGHT)
			m.set("state", int(po[1]))
			m.set("_state_t", float(po[3]))
			m.set("_t", float(po[3]) * 2.0)
			m.call("_boss_pose", 0.0, po[2])
			await _frames(2)
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var at := m.get_global_transform_with_canvas().origin * Vector2(img.get_size()) / get_viewport().get_visible_rect().size
			var r := Rect2i(Vector2i(at) - Vector2i(150, 200), Vector2i(300, 260)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
			img.get_region(r).save_png(_dir.path_join("anim_%s_%d.png" % [kind, i]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	get_tree().quit()
