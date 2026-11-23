extends Node
## 수집 늘리기 흐름 테스트 (실제 장면을 오간다): 내 마을에 박물관 짓기 → 들어가기 → 데스크에서 기증 → 전시 →
## 저장·불러오기 → 나오기 → 들판: 곤충 잡기, 연못 낚시, 채집 자리.
## 실행: godot --headless --path . res://tests/test_collect.tscn

const Items := preload("res://scripts/data/items.gd")

var passed := 0
var failed := 0


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


func scene_name() -> String:
	var s := get_tree().current_scene
	return str(s.name) if s else ""


func _run() -> void:
	var tree := get_tree()
	get_parent().remove_child(self)
	tree.root.add_child(self)
	tree.current_scene = null
	GameState.save_path = "user://test_collect_save.json"
	GameState.quest = GameState.Quest.CLEARED
	GameState.bridge_built = true
	GameState.intro_seen = true
	GameState.home_intro_seen = true
	GameState.has_saved_position = false
	GameState.current_map = "home"
	GameState.clock = 600.0
	GameState.fatigue = 100
	GameState.pencil_lead = 500
	GameState.coins = 5000
	GameState.museum = {}

	print("[박물관 짓고 들어가기]")
	tree.change_scene_to_file("res://scenes/home.tscn")
	await frames(30)
	check(scene_name() == "Home", "내 마을이 열림 (%s)" % scene_name())
	var home := tree.current_scene
	home.call("start_placing", "bld_museum")
	check(bool(await home.call("place_at", Vector2(700, 520), 0.9)), "박물관을 지음")
	await frames(5)
	var museum_obj: Node2D = null
	for n in tree.get_nodes_in_group("home_object"):
		if str(n.get("id")) == "bld_museum":
			museum_obj = n
	var player: Node2D = home.get("player")
	player.global_position = museum_obj.global_position + Vector2(0, 18)
	await frames(5)
	museum_obj.call("interact")
	await frames(30)
	check(scene_name() == "Museum" and GameState.current_map == "museum", "박물관에 F: 박물관 안으로 들어감 (%s)" % scene_name())
	var mus := tree.current_scene
	var mp: Node2D = mus.get("player")
	check(is_instance_valid(mp) and mp.global_position.y > 480.0, "문 앞에서 시작함 (y=%.0f)" % (mp.global_position.y if mp else -1.0))
	check(tree.get_nodes_in_group("interactable").size() >= 2, "데스크와 문에 F 를 쓸 수 있음")

	print("[데스크에서 기증]")
	GameState.consumables["f_carp"] = 1
	GameState.consumables["fg_0"] = 2
	GameState.sketches = {"m07": 1}
	mp.global_position = Vector2(480, 332)
	await frames(5)
	check(bool(mp.call("try_interact")), "데스크 앞에서 F")
	await frames(3)
	var hud: Node = mus.get("hud")
	check(bool(hud.call("is_menu_open", "donate")), "기증 창이 열림")
	var dn: Control = hud.call("menu", "donate")
	dn.call("_donate", "fish", "f_carp")
	dn.call("_donate", "forage", "fg_0")
	dn.call("_donate", "mon", "m07")
	check(GameState.museum_has("fish", "f_carp") and GameState.museum_has("forage", "fg_0") and GameState.museum_has("mon", "m07"), "물고기·채집물·몬스터 스케치를 기증함")
	check(GameState.consumable_count("f_carp") == 0 and GameState.consumable_count("fg_0") == 1 and not GameState.sketches.has("m07"), "기증한 만큼 가방에서 빠짐")
	hud.call("toggle_menu", "donate")
	await frames(3)
	check(not tree.paused, "기증 창을 닫으면 다시 움직임")
	check(str(hud.get("quest_text_override")).contains("전시 3"), "위에 전시 수가 보임 (%s)" % str(hud.get("quest_text_override")))
	var shown := false
	for d in mus.get_node("Actors").get_children():
		for c in d.get_children():
			if c.has_method("_area") and str((c.get("spec") as Array)[2]) == "fish" and int((c.get("spec") as Array)[3]) == 0:
				shown = true
	check(shown, "수조에 전시물 그리기가 붙어 있음")

	print("[전시대 크게 보기]")
	mp.global_position = Vector2(150, 318)      # 첫 수조 앞
	await frames(5)
	check(bool(mp.call("try_interact")) and bool(hud.call("is_menu_open", "exhibit")), "수조 앞에서 F: 전시대를 크게 보는 창이 열림")
	var ex: Control = hud.call("menu", "exhibit")
	check(str(ex.get("ctx")) == "0", "앞에 선 전시대(첫 수조)가 열림")
	ex.call("_exhibit_pick", "fish", "f_carp")
	check(str(ex.get("_message")).begins_with("연필 붕어") and str(ex.get("_message")).contains("내 마을 물"), "누르면 이름과 사는 곳·때·희귀도 설명")
	ex.call("_exhibit_pick", "fish", "f_minnow")
	check(str(ex.get("_message")).begins_with("???"), "기증하지 않은 것은 이름을 가림")
	hud.call("toggle_menu", "exhibit")
	await frames(3)

	print("[박물관에서 저장·불러오기]")
	GameState.save_game()
	GameState.museum = {}
	GameState.current_map = "home"
	check(GameState.load_game() and GameState.current_map == "museum" and GameState.museum_has("fish", "f_carp"), "박물관 안에서 저장하면 박물관에서 이어하고, 기증한 것도 남음")

	print("[나오기]")
	mp.global_position = Vector2(480, 506)
	await frames(5)
	check(bool(mp.call("try_interact")), "문 앞에서 F")
	await frames(30)
	check(scene_name() == "Home", "내 마을로 나옴 (%s)" % scene_name())
	var hp: Node2D = tree.current_scene.get("player")
	check(hp.global_position.distance_to(Vector2(700, 520)) < 60.0, "박물관 앞에 섬 (%.0f)" % hp.global_position.distance_to(Vector2(700, 520)))

	print("[들판: 곤충, 연못 낚시, 채집]")
	check(GameState.goto_map("ch1_meadow", "gate_right"), "들판으로 이동")
	await frames(30)
	var field := tree.current_scene
	var fp: Node2D = field.get("player")
	fp.set("_invuln", 999.0)
	var pond: Node2D = null
	var forage_spots := 0
	for n in field.get("actors").get_children():
		if str(n.get("mode")) == "fish" and str(n.get("key")) == "pond":
			pond = n
		if str(n.get("mode")) == "forage":
			forage_spots += 1
	check(pond != null and forage_spots == 4, "연못 낚시 자리와 채집 자리 넷이 있음")
	# 곤충: 없으면 하나 놓는다 (나올지 말지는 70%)
	var bugs := tree.get_nodes_in_group("bug")
	if bugs.is_empty():
		var b: Node2D = load("res://scripts/actors/bug.gd").new()
		b.set("id", "fg_30")
		b.position = fp.global_position + Vector2(60, 0)
		field.get("actors").add_child(b)
		bugs = [b]
	var bug: Node2D = bugs[0]
	var bug_id := str(bug.get("id"))
	check(str(Items.FORAGE_INFO[bug_id][0]) == "bug", "사냥터에 곤충이 돌아다님 (%s)" % Items.CONSUMABLES[bug_id][0])
	var before := GameState.consumable_count(bug_id)
	bug.set("area", Rect2(bug.global_position, Vector2(1, 1)))    # 시험 동안 가만히
	fp.global_position = bug.global_position + Vector2(-16, 0)
	await frames(30)     # 멈춰 서서 기다린다
	check(float(bug.call("catch_chance")) >= 0.9, "멈춰 서 있으면 잘 잡힘 (%.2f)" % float(bug.call("catch_chance")))
	var caught := false
	for t in 6:
		if not is_instance_valid(bug) or bug.is_queued_for_deletion():
			break
		bug.call("_swing", 1.0)
		await frames(2)
	caught = GameState.consumable_count(bug_id) == before + 1
	check(caught and GameState.dex_has("forage", bug_id), "잠자리채로 잡으면 가방과 도감에 들어감")
	# 실제로 F: 잠자리채를 휘두르고, 휘두르기가 끝나면 잡힌다 (멈춰 있으면 95%, 몇 번 해 본다)
	var net_ok := false
	for tries in 4:
		var b2: Node2D = load("res://scripts/actors/bug.gd").new()
		b2.set("id", "fg_31")
		b2.position = fp.global_position + Vector2(18, 0)
		b2.set("area", Rect2(b2.position, Vector2(1, 1)))
		field.get("actors").add_child(b2)
		await frames(30)
		var c0 := GameState.consumable_count("fg_31")
		var acted := bool(fp.call("try_interact")) and bool(fp.call("is_acting"))
		await frames(40)
		if acted and GameState.consumable_count("fg_31") == c0 + 1:
			net_ok = (fp.get("_act") as Dictionary).is_empty()
			break
	check(net_ok, "곤충 앞에서 F: 잠자리채를 휘둘러 잡고, 동작이 끝남")
	# 연못 낚시
	fp.global_position = pond.global_position + Vector2(0, 10)
	await frames(5)
	pond.call("interact")
	await frames(3)
	var fishing: Control = field.get("hud").call("fishing")
	check(bool(fishing.call("is_active")) and str(fishing.get("place")) == "pond", "연못 표지판에서 F: 연못 낚시가 시작됨")
	for i in 400:
		if str(fishing.get("phase")) == "bite":
			break
		await frames(1)
	fishing.call("pull")
	var hooked := str(fishing.get("hooked"))
	check(hooked != "" and (not Items.FISH_INFO.has(hooked) or str(Items.FISH_INFO[hooked][0]) == "pond"), "연못에서는 연못 물고기(또는 잡동사니)가 묾 (%s)" % hooked)
	var got_before := GameState.consumable_count(hooked)
	for i in 800:
		if str(fishing.get("phase")) != "reel":
			break
		fishing.set("_t", float(fishing.get("_t")) + 0.02)
		fishing.call("step_reel", 0.02, float(fishing.get("_pos")) < float(fishing.get("_zone")))
	check(GameState.consumable_count(hooked) == got_before + 1, "끌어올려 낚음 (%s)" % Items.CONSUMABLES[hooked][0])
	fishing.call("stop")

	print()
	print("결과: %d 통과 / %d 실패" % [passed, failed])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	tree.quit(1 if failed > 0 else 0)
