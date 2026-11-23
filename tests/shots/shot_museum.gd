extends Node
## 박물관 안 캡처 (눈으로 확인용): 거의 다 기증한 상태로 여기저기 서 본다.
## 실행: godot --path . res://tests/shots/shot_museum.tscn -- <출력폴더>

const MuseumScene := preload("res://scenes/museum.tscn")

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
	GameState.save_path = "user://shot_museum_save.json"
	GameState.clock = 600.0
	GameState.intro_seen = true
	GameState.museum = {}
	var i := 0
	for cat in GameState.MUSEUM_CATS:
		var book := {}
		for id in GameState.museum_entries(cat):
			i += 1
			if i % 7 != 0:      # 거의 다
				book[str(id)] = true
		GameState.museum[cat] = book
	var m: Node2D = MuseumScene.instantiate()
	add_child(m)
	await _frames(20)
	var p: Node2D = m.get("player")
	p.set("_invuln", 999.0)
	var spots := {"m1_door.png": Vector2(480, 470), "m2_desk.png": Vector2(480, 330), "m3_fish.png": Vector2(210, 340),
		"m4_bugs.png": Vector2(715, 330), "m5_mon.png": Vector2(170, 440), "m6_gear.png": Vector2(370, 440), "m7_forage.png": Vector2(700, 440)}
	for f in spots:
		p.global_position = spots[f]
		await _frames(25)
		await _shot(f)
	# 기증 창
	GameState.consumables["fish_3"] = 2
	GameState.consumables["fg_5"] = 1
	GameState.sketches["m07"] = 1
	GameState.museum["fish"].erase("fish_3")
	var hud: Node = m.get("hud")
	hud.call("toggle_menu", "donate")
	await _frames(6)
	await _shot("m8_donate.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	get_tree().quit()
