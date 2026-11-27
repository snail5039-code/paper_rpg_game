extends Node
## 쓰러짐·일어남·몬스터 죽음 캡처 (눈으로 확인용).
## 실행: godot --path . res://tests/shots/shot_fall.tscn -- <출력폴더>
## 파일: fall_0~4 (쓰러짐), wake_field_0~3 (그 자리에서 일어남), wake_home_0~4 (마을 침대), die_<모양>_0~3 (몬스터)

var _dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().set_flag(Window.FLAG_NO_FOCUS, true)
	get_window().gui_disable_input = true
	GameState.save_dir = OS.get_user_data_dir().path_join("shot_tmp/")
	DirAccess.make_dir_recursive_absolute(GameState.save_dir)
	_run.call_deferred()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _shot(file: String, zoom: Rect2i = Rect2i()) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if zoom.size != Vector2i.ZERO:
		img = img.get_region(zoom)
	img.save_png(_dir.path_join(file))


func _crop_around(p: Node2D, half := Vector2i(110, 80)) -> Rect2i:
	var vp := get_viewport()
	var s := Vector2(vp.get_texture().get_size()) / vp.get_visible_rect().size
	var c := Vector2i(p.get_global_transform_with_canvas().origin * s)
	return Rect2i(c - half, half * 2).intersection(Rect2i(Vector2i.ZERO, Vector2i(vp.get_texture().get_size())))


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	var tree := get_tree()
	get_parent().remove_child(self)
	tree.root.add_child(self)
	tree.current_scene = null
	GameState.save_path = "user://shot_fall_save.json"
	GameState.quest = GameState.Quest.CLEARED
	GameState.intro_seen = true
	GameState.clock = 600.0
	GameState.current_map = "ch1_erasedroad"
	GameState.visited = []
	GameState.spawn_tag = "gate_top"
	GameState.has_saved_position = false
	get_tree().change_scene_to_file("res://scenes/field.tscn")
	await _wait(0.6)
	var field := get_tree().current_scene
	var p: Node2D = field.get("player")
	p.global_position = Vector2(320, 200)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.3)
	# 몬스터 죽음 세 가지
	for kind in ["slime", "mon_bug", "mon_dots", "slime_erased", "mon_grass"]:
		var m: Node2D = load("res://scenes/enemy.tscn").instantiate()
		m.set("kind", kind)
		m.position = Vector2(400, 200)
		field.get("actors").add_child(m)
		m.set_physics_process(false)
		await _wait(0.2)
		var st: String = load("res://scripts/actors/monster_death.gd").style_of(kind)
		var crop := Rect2i()
		m.call("take_damage", 9999, Vector2.RIGHT, false)
		for i in 4:
			await _wait(0.2 if i == 0 else 0.2)
			await _shot("die_%s_%s_%d.png" % [kind, st, i], crop)
		await _wait(0.6)
	# 쓰러짐
	p.set("_invuln", 0.0)
	p.set("hp", 1)
	p.call("take_damage", 99, Vector2.RIGHT)
	var marks := [0.1, 0.4, 0.8, 1.2, 1.7, 2.1]
	var t0 := Time.get_ticks_msec()
	for i in marks.size():
		while float(Time.get_ticks_msec() - t0) / 1000.0 < marks[i]:
			await get_tree().process_frame
		await _shot("fall_%d.png" % i, Rect2i())
	await _wait(0.7)
	var wm := [0.4, 1.2, 2.0, 2.6, 3.2, 3.6]
	t0 = Time.get_ticks_msec()
	for i in wm.size():
		while float(Time.get_ticks_msec() - t0) / 1000.0 < wm[i]:
			await get_tree().process_frame
		await _shot("wake_field_%d.png" % i, Rect2i())
	await _wait(1.0)
	# 마을 침대에서 일어남
	GameState.visited = ["home"]
	GameState.spawn_tag = "from_death"
	GameState.current_map = "home"
	GameState.has_saved_position = false
	get_tree().change_scene_to_file("res://scenes/home.tscn")
	await _wait(0.2)
	var home := get_tree().current_scene
	var hp_: Node2D = home.get("player")
	t0 = Time.get_ticks_msec()
	for i in wm.size():
		while float(Time.get_ticks_msec() - t0) / 1000.0 < wm[i]:
			await get_tree().process_frame
		await _shot("wake_home_%d.png" % i, Rect2i())
	get_tree().quit()
