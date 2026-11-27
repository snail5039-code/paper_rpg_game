extends Node
## 1장 뒷이야기 "흰 집" 장면마다 캡처: 대사 한 줄, 그림책 한 쪽, 따라 그리기마다 한 장.
## 실행: godot --headless --path . res://tests/test_ch1.tscn
##       godot --path . res://tests/test_ch1.tscn -- <캡처 폴더>
## 대화와 그림책은 저절로 넘기고, 따라 그리기는 점선대로 그린 것으로 친다.

const FieldScene := preload("res://scenes/field.tscn")
const VillageScene := preload("res://scenes/main.tscn")
const Data := preload("res://scripts/data/game_data.gd")
const Ch1Story := preload("res://scripts/maps/ch1_story.gd")
const ArtLib := preload("res://scripts/core/art.gd")

var passed := 0
var failed := 0
var _dir := ""
var dialogs: Array = []     # [말한 사람, 모든 줄]
var books := 0              # 펼친 그림책 수
var hud: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_cmdline_user_args().size() > 0:      # 캡처 창이 키 입력을 받지 않게
		get_window().set_flag(Window.FLAG_NO_FOCUS, true)
	GameState.dialogue_requested.connect(func(sp, lines, _p): dialogs.append([str(sp), "\n".join(lines)]))
	_run.call_deferred()


var _n := 0            # 사진 번호
var _wait := 0         # 다음 사진까지 남은 프레임
var _busy := false     # 사진을 찍는 중
var _trace_age := 0


func _process(_d: float) -> void:
	if _busy:
		return
	if _wait > 0:
		_wait -= 1
		return
	_busy = true
	await _step()
	_busy = false


## 찍고 나서 넘긴다 (찍기 전에 넘기면 다음 줄이 찍힌다)
func _step() -> void:
	# 대사: 줄마다 한 장씩
	if GameState.dialogue_open and hud and is_instance_valid(hud):
		await _snap("dlg")
		var lines: Array = hud.get("_lines")
		var idx := int(hud.get("_line_idx"))
		if idx + 1 < lines.size():
			hud.set("_line_idx", idx + 1)
			hud.call("_show_line")
		else:
			GameState.end_dialogue()
		_wait = 3
		return
	# 그림책: 다 떠오르고 글이 다 나온 뒤 한 장
	for b in get_tree().get_nodes_in_group("story_book"):
		if not b.has_meta("seen"):
			b.set_meta("seen", true)
			books += 1
		if not bool(b.get("_waiting")) or (b.get("_root") as Control).modulate.a < 0.99 or (b.get("_pic") as Control).modulate.a < 0.99:
			continue
		var t: Label = b.get("_text")
		if t.visible_ratio < 1.0:
			t.visible_ratio = 1.0
			_wait = 3
			return
		await _snap("book")
		b.call("advance")
		_wait = 3
		return
	# 따라 그리기: 점선이 뜬 화면 한 장
	if hud and is_instance_valid(hud):
		var panel: Control = hud.call("trace_panel")
		if bool(panel.get("active")):
			_trace_age += 1
			if _trace_age == 20:
				await _snap("trace")
				panel.set("strokes", (panel.get("guides") as Array).duplicate())
				panel.call("finish")
				_trace_age = 0
				_wait = 6


func _snap(tag: String) -> void:
	_n += 1
	await shot("%03d_%s.png" % [_n, tag])


func check(ok: bool, text: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", text])


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func until(cond: Callable, limit: int = 600) -> bool:
	for i in limit:
		if cond.call():
			return true
		await frames(1)
	return cond.call()


func shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_dir.path_join(file))


func open_field(id: String) -> Node2D:
	GameState.current_map = id
	GameState.spawn_tag = "gate_" + str((Data.FIELDS[id]["gates"] as Dictionary).keys()[0])
	GameState.has_saved_position = false
	var f: Node2D = FieldScene.instantiate()
	f.set("field_id", id)
	add_child(f)
	await frames(8)
	hud = f.get("hud")
	(f.get("player") as Node2D).set("_invuln", 9999.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.set("aggro_range", 0.0)
	return f


func open_village() -> Node2D:
	GameState.current_map = "ch1"
	GameState.spawn_tag = "from_home"
	GameState.has_saved_position = false
	var v: Node2D = VillageScene.instantiate()
	add_child(v)
	await frames(10)
	hud = v.get("hud")
	(v.get("player") as Node2D).set("_invuln", 9999.0)
	return v


func close(f: Node2D) -> void:
	f.queue_free()
	await frames(3)


func spot_of(f: Node2D, what: String) -> Node2D:
	for n in f.get("actors").get_children():
		if str(n.get("what")) == what and not n.is_queued_for_deletion():
			return n
	return null


func talk_to(f: Node2D, n: Node2D) -> void:
	var p: Node2D = f.get("player")
	p.global_position = n.global_position + Vector2(-16, 4)
	await frames(3)
	await n.call("interact")
	await frames(3)


func said(who: String, part: String) -> bool:
	for d in dialogs:
		if str(d[0]) == who and str(d[1]).contains(part):
			return true
	return false


func kill(kind: String) -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		if str(e.get("kind")) == kind:
			e.call("take_damage", 99999999, Vector2.RIGHT, false)
			return true
	return false


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else ""
	GameState.save_path = "user://test_ch1_save.json"
	GameState.quest = GameState.Quest.CLEARED
	GameState.bridge_built = true
	GameState.intro_seen = true
	GameState.clock = 600.0
	GameState.fatigue = 100
	GameState.difficulty = 0
	GameState.ch1_step = 0
	GameState.ch1_scraps = []
	GameState.bosses_beaten = {}
	GameState.field_boss = {"day": GameState.day, "map": "", "dead": true, "map_ch2": "", "dead_ch2": true}

	print("[그림]")
	var missing: Array = []
	for n in ["npc_heosu", "npc_signpost", "npc_mailbox", "portrait_heosu", "portrait_signpost", "portrait_mailbox", "portrait_crumple",
			"story_scrap", "story_letter", "ch1_page_0", "ch1_page_1", "ch1_page_2", "ch1_page_3"]:
		if not ArtLib.has(n):
			missing.append(n)
	check(missing.is_empty(), "1장 뒷이야기 그림이 다 있음 %s" % str(missing))

	print("[0 → 1: 흰 집]")
	var v := await open_village()
	check(v.get_node_or_null("Ch1Story") != null, "빨간 문을 지난 뒤 1장 마을에 이야기가 붙음")
	check(await until(func(): return GameState.ch1_step == 1), "돌아오자마자 흰 집 장면 (그림책 + 하루 + 할아버지)")
	check(books >= 1 and said("지팡이 할아버지", "편지를 날라"), "할아버지가 편지를 날라 주던 사람 이야기를 함")
	check(str(hud.get("quest_text_override")).contains("들판"), "할 일: 들판에 가 보기")
	await _place()
	await close(v)

	print("[1 → 2 → 3: 들판, 허수와 편지 조각]")
	var f := await open_field("ch1_meadow")
	var heosu := spot_of(f, "heosu")
	check(heosu != null, "들판에 허수가 있음")
	await _place()
	await talk_to(f, heosu)
	check(GameState.ch1_step == 2 and said("허수", "노란 가방"), "허수: 노란 가방, 흩어진 편지 → 줍기 시작")
	var scraps := 0
	for i in 3:
		if spot_of(f, "scrap%d" % i) != null:
			scraps += 1
	check(scraps == 3, "편지 조각 3장이 들판에 놓임")
	check(str(hud.get("quest_text_override")).contains("0/3"), "할 일에 0/3")
	for i in 3:
		var sc := spot_of(f, "scrap%d" % i)
		if sc:
			await talk_to(f, sc)
		await frames(4)
	check(GameState.ch1_step == 3 and GameState.ch1_scraps.size() == 3, "세 장을 다 주우면 갈림길로")
	check(said("하루", "어디서 많이 본"), "하루가 편지 글자를 알아본 듯함")
	await close(f)

	print("[3 → 4: 갈림길, 이정표 아저씨]")
	f = await open_field("ch1_crossroad")
	await _place()
	var sign := spot_of(f, "signpost")
	check(sign != null, "갈림길에 이정표 아저씨가 있음")
	var b0 := books
	await talk_to(f, sign)
	check(await until(func(): return GameState.ch1_step == 4), "지워진 팻말을 다시 그리면 기억이 돌아옴")
	check(books > b0, "기억 한 장면을 그림책으로 보여 줌")
	await close(f)

	print("[4 → 5: 모눈 숲, 왕 지우개똥 벌레]")
	f = await open_field("ch1_gridwoods")
	await frames(30)
	await until(func(): return not GameState.cutscene and not GameState.dialogue_open and get_viewport().get_camera_2d().offset == Vector2.ZERO)
	await _place()
	check(said("하루", "노란 가방"), "숲에 들어가면 하루가 벌레가 문 가방을 봄")
	check(kill("boss_bug"), "왕 지우개똥 벌레가 숲에 있음")
	await _place()
	await _place()
	check(await until(func(): return GameState.ch1_step == 5), "벌레를 쓰러뜨리면 빈 가방과 우표 → 우편함으로")
	await close(f)

	print("[5 → 6: 지워진 길, 빈 우편함]")
	f = await open_field("ch1_erasedroad")
	await _place()
	var p: Node2D = f.get("player")
	p.global_position = f.call("bg", Vector2(836, 930))
	await frames(6)
	check(GameState.current_map == "ch1_erasedroad", "우편함 이야기 전에는 구깃이의 방이 막혀 있음")
	var mb := spot_of(f, "mailbox")
	check(mb != null, "길 끝에 빈 우편함이 있음")
	await talk_to(f, mb)
	check(GameState.ch1_step == 6 and said("빈 우편함", "구깃이"), "구겨진 편지들이 구깃이가 됐다는 이야기")
	await close(f)

	print("[6 → 7: 구깃이를 펴 주기]")
	f = await open_field("ch1_bossroom")
	await frames(30)
	check(said("구깃이", "답장"), "구깃이가 편지 조각으로 말함")
	await _place()
	b0 = books
	check(kill("boss_crumple"), "구깃이가 방에 있음")
	await _place()
	await _place()
	check(await until(func(): return GameState.ch1_step == 7, 900), "쓰러뜨린 뒤 구겨진 편지를 펴면 하루의 편지")
	check(books > b0 and said("하루", "내 글씨"), "편지 그림책과 하루의 말")
	await close(f)

	print("[7 → 8: 다시 흰 집]")
	v = await open_village()
	await _place()
	var wh := spot_of(v, "whitehouse")
	check(wh != null, "흰 집 자리에 편지를 넣을 곳이 있음")
	b0 = books
	if wh:
		await talk_to(v, wh)
	check(await until(func(): return GameState.ch1_step == 8), "편지를 넣으면 1장 뒷이야기가 끝남")
	check(books > b0 and said("지팡이 할아버지", "한 통은 도착"), "마지막 그림책과 할아버지의 말")
	await _place()
	await close(v)

	print("[저장]")
	GameState.save_game()
	GameState.ch1_step = 0
	GameState.load_game()
	check(GameState.ch1_step == 8 and GameState.ch1_scraps.size() == 3, "단계와 편지 조각이 저장됨")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	print("\n결과: %d 통과 / %d 실패" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _place() -> void:
	await frames(20)
	_n += 1
	await shot("%03d_place.png" % _n)
