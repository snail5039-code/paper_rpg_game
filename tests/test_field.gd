extends Node
## 사냥터 화면(1장 넓히기) 테스트 + 화면 캡처.
## 실행: godot --headless --path . res://tests/test_field.tscn
##       godot --path . res://tests/test_field.tscn -- <캡처 폴더>

const FieldScene := preload("res://scenes/field.tscn")
const MainScene := preload("res://scenes/main.tscn")
const Data := preload("res://scripts/data/game_data.gd")
const S := 640.0 / 1672.0

var passed := 0
var failed := 0
var _dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(ok: bool, text: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", text])


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func shot(file: String) -> void:
	if _dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_dir.path_join(file))


func walk(action: String, n: int) -> void:
	Input.action_press(action)
	await frames(n)
	Input.action_release(action)
	await frames(2)


func open_field(id: String, tag: String) -> Node2D:
	GameState.spawn_tag = tag
	GameState.has_saved_position = false
	var f: Node2D = FieldScene.instantiate()
	f.set("field_id", id)
	add_child(f)
	await frames(5)
	(f.get("player") as Node2D).set("_invuln", 999.0)
	return f


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else ""
	GameState.save_path = "user://test_field_save.json"
	GameState.clock = 480.0
	GameState.fatigue = 100
	GameState.difficulty = 0
	GameState.field_boss = {"day": GameState.day, "map": "", "dead": true, "map_ch2": "", "dead_ch2": true}   # 필드 보스는 따로 시험한다
	GameState.quest = GameState.Quest.FIND_LEAD
	GameState.intro_seen = true

	print("[화면 표]")
	check(Data.CH1_LAYOUT.size() == 6, "1장은 마을 + 사냥터 4장 + 대장 방")
	var ch2_fields := (Data.CH2_LAYOUT.keys() as Array).filter(func(k): return Data.FIELDS.has(k) and not Data.FIELDS[k].has("town") and k != "ch2_bossroom")
	check(Data.CH2_LAYOUT.size() == 8 and ch2_fields.size() == 6, "2장은 숲 입구 마을 + 사냥터 6장 + 대장 방")
	# 몬스터가 막힌 곳 안에 서 있지 않다, 모든 화면에 배경 그림이 있다
	var stuck: Array = []
	for id in Data.FIELDS:
		if not preload("res://scripts/core/art.gd").has(str(Data.FIELDS[id]["bg"])):
			stuck.append("%s 배경 없음" % id)
		for m in Data.FIELDS[id]["monsters"]:
			for r in Data.FIELDS[id]["solids"]:
				if (r as Rect2).has_point(m[1]):
					stuck.append("%s %s" % [id, m[0]])
	check(stuck.is_empty(), "몬스터가 막힌 곳 안에 있지 않고 모든 화면에 배경이 있음 (%s)" % str(stuck))
	var ok_links := true
	var opposite := {"top": "bottom", "bottom": "top", "left": "right", "right": "left"}
	for id in Data.FIELDS:
		var gates: Dictionary = Data.FIELDS[id]["gates"]
		for side in gates:
			var other := str(gates[side])
			if other == "ch1":
				continue
			if not Data.FIELDS.has(other) or str(Data.FIELDS[other]["gates"].get(opposite[side], "")) != id:
				ok_links = false
	check(ok_links, "문은 양쪽에서 서로 이어져 있음")
	for id in Data.FIELDS:
		check(GameState.MAP_SCENES.has(id), "%s 화면이 맵으로 등록됨" % Data.MAP_NAMES[id])

	print("[갈림길]")
	var f: Node2D = await open_field("ch1_crossroad", "gate_top")
	var p: Node2D = f.get("player")
	check(p.global_position.distance_to(Vector2(836, 160) * S) < 2.0, "위쪽 문으로 들어오면 위쪽 문 앞에 섬")
	check(get_tree().get_nodes_in_group("enemies").size() == (Data.FIELDS["ch1_crossroad"]["monsters"] as Array).size(), "몬스터가 표대로 나옴")
	await shot("field_1_crossroad.png")
	# 위쪽 문으로 다시 나가기
	await walk("move_up", 60)
	check(str(f.get("last_exit")) == "top", "문으로 걸어 나가면 넘어가려 함 (위쪽)")
	# 문이 아닌 테두리는 막힌다
	p.global_position = Vector2(300, 200) * S
	await walk("move_up", 70)
	check(p.global_position.y > 108.0 * S, "나무 테두리는 지나갈 수 없음 (y=%.0f)" % (p.global_position.y / S))
	# 우물은 막힌다
	p.global_position = Vector2(985, 520) * S
	await walk("move_up", 80)
	check(p.global_position.y > 425.0 * S, "우물은 지나갈 수 없음 (y=%.0f)" % (p.global_position.y / S))
	# 왼쪽 문
	p.global_position = Vector2(200, 470) * S
	f.set("last_exit", "")
	await walk("move_left", 80)
	check(str(f.get("last_exit")) == "left", "왼쪽 문으로 나감")
	var hud: Node = f.get("hud")
	hud.call("toggle_map")
	await frames(3)
	check(bool(hud.call("is_map_open")) and get_tree().paused, "M 지도를 열면 게임이 멈춤")
	hud.call("toggle_map")
	await frames(2)
	GameState.current_map = "ch1_crossroad"
	GameState.visited = ["ch1", "ch1_crossroad", "ch1_meadow"]
	hud.call("toggle_map")
	await frames(3)
	check(GameState.visited.has("ch1_meadow") and not GameState.visited.has("ch1_gridwoods"), "가 본 화면만 지도에 그림으로 나옴")
	await shot("field_2_map.png")
	hud.call("toggle_map")
	await frames(3)
	check(not get_tree().paused, "지도를 닫으면 다시 움직임")
	# 오른쪽 아래 메뉴 단추: 누르면 단축키와 같은 창이 열리고, 다시 누르면 닫힘
	var btn_ok := true
	for id in ["bag", "skills", "friends", "dex", "pause"]:
		hud.call("press_menu_button", id)
		await frames(2)
		if not bool(hud.call("is_menu_open", id)):
			btn_ok = false
		hud.call("press_menu_button", id)
		await frames(2)
		if bool(hud.call("is_menu_open", id)):
			btn_ok = false
	hud.call("press_menu_button", "map")
	await frames(2)
	btn_ok = btn_ok and bool(hud.call("is_map_open"))
	hud.call("press_menu_button", "map")
	await frames(2)
	check(btn_ok and not get_tree().paused, "메뉴 단추로 가방·스킬·친구·도감·설정·지도 창이 열리고 닫힘")
	f.queue_free()
	await frames(3)

	print("[들판, 모눈 숲, 지워진 길]")
	f = await open_field("ch1_meadow", "gate_right")
	p = f.get("player")
	check(p.global_position.distance_to(Vector2(1512, 470) * S) < 2.0, "들판: 오른쪽 문 앞에 섬")
	p.global_position = Vector2(310, 480) * S
	await walk("move_up", 80)
	check(p.global_position.y > 380.0 * S, "들판: 연못은 지나갈 수 없음 (y=%.0f)" % (p.global_position.y / S))
	p.global_position = Vector2(700, 480) * S
	await frames(20)
	await shot("field_3_meadow.png")
	f.queue_free()
	await frames(3)

	f = await open_field("ch1_gridwoods", "gate_left")
	p = f.get("player")
	p.global_position = Vector2(800, 470) * S
	await walk("move_up", 90)
	check(p.global_position.y > 336.0 * S, "모눈 숲: 줄지어 선 나무는 지나갈 수 없음 (y=%.0f)" % (p.global_position.y / S))
	await shot("field_4_gridwoods.png")
	f.queue_free()
	await frames(3)

	f = await open_field("ch1_erasedroad", "gate_top")
	p = f.get("player")
	p.global_position = Vector2(836, 760) * S
	await walk("move_down", 90)
	check(str(f.get("last_exit")) == "bottom", "지워진 길: 아래쪽 문은 대장 방으로 이어짐")
	p.global_position = Vector2(836, 560) * S
	await frames(20)
	await shot("field_5_erasedroad.png")
	f.queue_free()
	await frames(3)

	print("[마을 아래쪽 문]")
	GameState.quest = GameState.Quest.NOT_STARTED
	GameState.spawn_tag = "gate_bottom"
	GameState.has_saved_position = false
	var v: Node2D = MainScene.instantiate()
	add_child(v)
	await frames(5)
	p = v.get("player")
	p.set("_invuln", 999.0)
	check(p.global_position.distance_to(Vector2(805, 800) * S) < 2.0, "갈림길에서 올라오면 마을 아래쪽 문 앞에 섬")
	await shot("field_6_village_gate.png")
	await walk("move_down", 120)
	check(str(v.get("last_exit")) == "", "하루와 이야기하기 전에는 마을 밖으로 못 나감")
	GameState.quest = GameState.Quest.FIND_LEAD
	await walk("move_down", 120)
	check(str(v.get("last_exit")) == "bottom", "이야기를 들은 뒤에는 아래쪽 문으로 나감")
	# 문 옆의 나무는 여전히 막힌다
	p.global_position = Vector2(600, 760) * S
	v.set("last_exit", "")
	await walk("move_down", 120)
	check(str(v.get("last_exit")) == "" and p.global_position.y < 830.0 * S, "문이 아닌 곳의 나무는 막혀 있음 (y=%.0f)" % (p.global_position.y / S))

	v.queue_free()
	await frames(3)

	print("[2장 색연필 숲]")
	check(Data.chapter_of("ch2_gray") == "ch2" and Data.chapter_of("ch1_meadow") == "ch1" and Data.chapter_of("home") == "", "화면이 몇 장인지 앎")
	var shot_n := 0
	for id in ["ch2", "ch2_path", "ch2_grove", "ch2_cliff", "ch2_gray", "ch2_mushroom", "ch2_bigtree", "ch2_bossroom"]:
		var gates: Dictionary = Data.FIELDS[id]["gates"]
		f = await open_field(id, "gate_" + str(gates.keys()[0]))
		p = f.get("player")
		var want := (Data.FIELDS[id]["monsters"] as Array).size()
		check(get_tree().get_nodes_in_group("enemies").size() == want, "%s: 몬스터 %d마리가 표대로 나옴" % [Data.MAP_NAMES[id], want])
		check(str(f.get("hud").get("quest_text_override")).begins_with("2장 · "), "%s: 화면 이름에 2장이 붙음" % Data.MAP_NAMES[id])
		p.global_position = Vector2(836, 470) * S
		await frames(15)
		shot_n += 1
		await shot("field_ch2_%d_%s.png" % [shot_n, id])
		f.queue_free()
		await frames(3)
	check(int(Data.FIELDS["ch2"].get("fatigue", 2)) == 0, "숲 입구 마을은 피로도가 들지 않음")
	GameState.current_map = "ch2_gray"
	for id in ["ch2", "ch2_path", "ch2_gray", "ch2_grove"]:
		if not GameState.visited.has(id):
			GameState.visited.append(id)
	f = await open_field("ch2_gray", "gate_top")
	var hud2: Node = f.get("hud")
	hud2.call("toggle_map")
	await frames(5)
	check(str(hud2.get("_map_title").text).contains("2장 색연필 숲") and str(hud2.get("_map_view").get("chapter")) == "ch2", "2장에서 지도를 열면 2장 지도가 나옴")
	await shot("field_ch2_9_map.png")
	hud2.call("toggle_map")
	f.queue_free()
	await frames(3)

	print("[2장으로 가는 길]")
	GameState.bosses_beaten = {}
	f = await open_field("ch1_bossroom", "gate_top")
	var door := false
	for n in f.get("actors").get_children():
		if str(n.get("target_map")) == "ch2":
			door = true
	check(not door, "구깃이를 잡기 전에는 구깃이의 방에 2장 문이 없음")
	f.queue_free()
	await frames(3)
	GameState.bosses_beaten = {"boss_crumple": 1}
	f = await open_field("ch1_bossroom", "gate_top")
	door = false
	for n in f.get("actors").get_children():
		if str(n.get("target_map")) == "ch2":
			door = true
	check(door, "구깃이를 잡은 뒤에는 구깃이의 방에 2장으로 가는 문이 생김")
	f.queue_free()
	await frames(3)

	print("[장마다 필드 보스]")
	GameState.field_boss = {"day": GameState.day - 1}
	var m1 := GameState.field_boss_map("ch1")
	var m2 := GameState.field_boss_map("ch2")
	check((Data.CHAPTERS["ch1"]["field_maps"] as Array).has(m1) and (Data.CHAPTERS["ch2"]["field_maps"] as Array).has(m2), "1장과 2장에 오늘의 필드 보스가 하나씩 (%s, %s)" % [m1, m2])
	GameState.current_map = m2
	GameState.on_boss_killed("boss_colorworm")
	check(GameState.field_boss_map("ch2") == "" and GameState.field_boss_map("ch1") == m1, "2장 필드 보스를 잡아도 1장 필드 보스는 남음")
	f = await open_field(m1, "gate_top")
	var fb := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if str(e.get("kind")) == "boss_scribble":
			fb = true
	check(fb, "1장 필드 보스는 그대로 나옴")
	f.queue_free()
	await frames(3)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	print("\n결과: %d 통과 / %d 실패" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
