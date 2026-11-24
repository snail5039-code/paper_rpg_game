extends Node
## 몬스터 공격 효과 캡처 (눈으로 확인용): 예고 느낌표, 박치기 시작·맞힘 효과, 보스 내리치기.
## 실행: godot --path . res://tests/shots/shot_monfx.tscn -- <출력폴더>

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
	var tree := get_tree()
	get_parent().remove_child(self)     # 장면을 바꿔도 이 노드는 남게
	tree.root.add_child(self)
	tree.current_scene = null
	GameState.save_path = "user://shot_monfx_save.json"
	GameState.quest = GameState.Quest.CLEARED
	GameState.intro_seen = true
	GameState.clock = 600.0
	GameState.has_saved_position = false
	GameState.current_map = "ch1_meadow"
	GameState.spawn_tag = "gate_right"
	get_tree().change_scene_to_file("res://scenes/field.tscn")
	await _frames(30)
	var field := get_tree().current_scene
	var p: Node2D = field.get("player")
	p.set("_invuln", 9999.0)
	p.global_position = Vector2(330, 220)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(20)
	var actors: Node2D = field.get("actors")
	var foes := {}
	var spots := {"squiggle_faded": Vector2(-60, -30), "slime_faded": Vector2(60, -30), "dots_faded": Vector2(-60, 40), "m10_faded": Vector2(60, 40)}
	for k in spots:
		var m: Node2D = load("res://scenes/enemy.tscn").instantiate()
		m.set("kind", k)
		m.position = p.global_position + (spots[k] as Vector2)
		actors.add_child(m)
		m.set_physics_process(false)
		foes[k] = m
	await _frames(10)
	# 1. 예고
	for k in foes:
		var m: Node2D = foes[k]
		m.set("_lunge_dir", (p.global_position - m.global_position).normalized())
		m.call("_set_state", 2)
		m.set_physics_process(true)
	await _frames(4)
	for k in foes:
		(foes[k] as Node).set_physics_process(false)
	await _shot("x1_windup.png")
	# 2. 박치기 시작 + 맞힘
	for k in foes:
		var m: Node2D = foes[k]
		m.call("_set_state", 3)
		m.call("_hit_fx", p)
	await _frames(5)
	await _shot("x2_lunge_hit.png")
	await _frames(30)
	# 3. 보스 내리치기 예고와 충격
	var boss: Node2D = load("res://scenes/enemy.tscn").instantiate()
	boss.set("kind", "boss_crumple")
	boss.position = p.global_position + Vector2(90, -10)
	actors.add_child(boss)
	boss.set_physics_process(false)
	for k in foes:
		(foes[k] as Node).queue_free()
	await _frames(5)
	boss.set("_slam_pos", p.global_position + Vector2(-10, 8))
	boss.call("_show_target")
	await _frames(35)
	await _shot("x3_slam_warn.png")
	boss.call("_slam_fx")
	await _frames(5)
	await _shot("x4_slam_hit.png")
	# 5. 몬스터마다 다른 맞힘 효과 (4×3, 맞는 자리에 빈 표시)
	await _frames(30)
	boss.queue_free()
	var kinds := ["slime_faded", "spider_faded", "m15_faded", "m23_faded", "m37_faded", "m45_faded",
		"m50_faded", "m60_faded", "m66_faded", "m75_faded", "m85_faded", "m90_faded"]
	var sheets := [kinds.slice(0, 12)]
	for i in kinds.size():
		var m: Node2D = load("res://scenes/enemy.tscn").instantiate()
		m.set("kind", kinds[i])
		m.position = Vector2(-500, -500)
		actors.add_child(m)
		m.set_physics_process(false)
		var target := Node2D.new()
		target.global_position = p.global_position + Vector2(-150 + (i % 4) * 100, -50 + (i / 4) * 60)
		actors.add_child(target)
		m.set("_lunge_dir", Vector2.RIGHT)
		m.call("_hit_fx", target)
	await _frames(7)
	await _shot("x5_each_monster.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	get_tree().quit()
