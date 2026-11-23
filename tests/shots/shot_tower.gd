extends Node
## 끝없는 탑 층마다 나오는 몬스터 캡처 (눈으로 확인용): 1층, 7층(2장), 13층(3장) … 46층(섞임).
## 실행: godot --path . res://tests/shots/shot_tower.tscn -- <출력폴더>

const TowerScene := preload("res://scenes/tower.tscn")

var _dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	GameState.save_path = "user://shot_tower_save.json"
	GameState.clock = 600.0
	GameState.intro_seen = true
	for f in [2, 7, 13, 18, 23, 28, 33, 38, 43, 47]:
		GameState.tower_floor = f
		GameState.spawn_tag = "gate_bottom"
		GameState.has_saved_position = false
		var t: Node2D = TowerScene.instantiate()
		add_child(t)
		await _frames(30)
		(t.get("player") as Node2D).set("_invuln", 999.0)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_dir.path_join("tower_%02d.png" % f))
		t.queue_free()
		await _frames(5)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	get_tree().quit()
