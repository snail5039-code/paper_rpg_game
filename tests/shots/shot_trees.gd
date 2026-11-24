extends Node
## 나무·보스 터짐·불러오기 화면 캡처 (눈으로 확인용).
## 실행: godot --path . res://tests/shots/shot_trees.tscn -- <출력폴더>

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


func _field(map: String) -> Node:
	GameState.current_map = map
	GameState.spawn_tag = "gate_right" if map == "ch1_meadow" else "gate_top"
	GameState.has_saved_position = false
	get_tree().change_scene_to_file("res://scenes/field.tscn")
	await _frames(30)
	return get_tree().current_scene


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	var tree := get_tree()
	get_parent().remove_child(self)
	tree.root.add_child(self)
	tree.current_scene = null
	GameState.save_path = "user://shot_trees_save.json"
	GameState.quest = GameState.Quest.CLEARED
	GameState.intro_seen = true
	GameState.clock = 600.0
	GameState.level = 10
	GameState.give_life_tools(GameState.Items.LIFE_ORDER)
	for m in ["ch1_meadow", "ch2_grove"]:
		var field: Node = await _field(m)
		for e in get_tree().get_nodes_in_group("enemies"):
			e.queue_free()
		var trees := get_tree().get_nodes_in_group("tree")
		var p: Node2D = field.get("player")
		p.set("_invuln", 9999.0)
		var t0: Node2D = trees[0]
		p.global_position = t0.global_position + Vector2(-18, 6)
		await _frames(20)
		await _shot("tree_%s_1.png" % m)
		# 도끼로 찍는 모습, 흔드는 모습
		GameState.hold_life("axe")
		await _frames(2)
		t0.call("interact")
		await _frames(8)
		await _shot("tree_%s_2_chop.png" % m)
		await _frames(30)
		if trees.size() > 1:
			var t1: Node2D = trees[1]
			GameState.swap_life()
			p.global_position = t1.global_position + Vector2(-18, 6)
			await _frames(15)
			t1.call("interact")
			await _frames(14)
			await _shot("tree_%s_3_shake.png" % m)
		for i in 2:
			t0.call("interact")
			await _frames(30)
		await _frames(10)
		await _shot("tree_%s_4_fell.png" % m)
		await _frames(40)
		await _shot("tree_%s_5_stump.png" % m)
	# 보스가 터짐
	var field2: Node = await _field("ch1_bossroom")
	var p2: Node2D = field2.get("player")
	p2.set("_invuln", 9999.0)
	await _frames(20)
	var boss: Node2D = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if str(e.get("boss")) == "boss":
			boss = e
	if boss:
		p2.global_position = boss.global_position + Vector2(-60, 30)
		await _frames(5)
		boss.call("take_damage", 999999, Vector2.RIGHT, true)
		await _frames(5)
		await _shot("boss_burst_1.png")
		await _frames(8)
		await _shot("boss_burst_2.png")
		await _frames(8)
		await _shot("boss_burst_3.png")
		await _frames(25)
		await _shot("boss_burst_4.png")
		await _frames(40)
		await _shot("boss_burst_5.png")
	# 불러오기 화면
	GameState.loading_screen = true
	GameState.open_with_loading("res://scenes/home.tscn")
	await _frames(30)
	await _shot("loading_1.png")
	await _frames(15)
	await _shot("loading_2.png")
	await _frames(15)
	await _shot("loading_3.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	get_tree().quit()
