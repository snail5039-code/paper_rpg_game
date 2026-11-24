extends Node
## 생활 도구 테스트: 낚시·곤충·채집·농사는 맞는 도구를 무기 칸에 들어야 한다. 등급(나무·쇠·금)과 내구도.
## 실행: godot --headless --path . res://tests/test_tools.tscn

const FieldScene := preload("res://scenes/field.tscn")
const Items := preload("res://scripts/data/items.gd")
const Data := preload("res://scripts/data/game_data.gd")
const ArtLib := preload("res://scripts/core/art.gd")

var passed := 0
var failed := 0
var notes: Array = []


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


func held() -> String:
	return str(GameState.life_tool().get("life", ""))


func _run() -> void:
	GameState.save_path = "user://test_tools_save.json"
	GameState.quest = GameState.Quest.CLEARED
	GameState.intro_seen = true
	GameState.current_map = "ch1_meadow"
	GameState.level = 5
	GameState.inventory = []
	GameState.equipped = {"tool": Items.make("tool", 0, 0, 1)}

	print("[도구가 없으면 못 한다]")
	check(not GameState.need_life("rod", true) and not GameState.need_life("net", true) and not GameState.need_life("sickle", true), "생활 도구를 들지 않으면 낚시·곤충·채집을 못 함")
	GameState.farms = {}
	GameState.consumables["s_radish"] = 1
	check(not GameState.plant("tk", 0, "s_radish"), "갈퀴가 없으면 심지 못함")

	print("[문방구에서 사기]")
	var life_rows := Items.SHOP.filter(func(e): return e is Array and str(e[0]) == "life")
	check(life_rows.size() == 6, "문방구가 나무 생활 도구 6종을 팖 (도끼 포함)")
	GameState.coins = 1000
	for e in life_rows:
		GameState.buy(e)
	check(GameState.inventory.filter(func(it): return Items.is_life(it)).size() == 6, "여섯 가지를 사서 가방에 넣음")
	check(not GameState.dex_entries("gear").is_empty() == false or not GameState.dex_has("gear", "tool_0"), "생활 도구는 장비 도감에 적히지 않음")

	print("[들기와 T 바꾸기]")
	var atk0 := GameState.attack_power()
	check(GameState.hold_life("rod") and held() == "rod", "낚싯대를 무기 칸에 듦")
	check(GameState.attack_power() < atk0, "생활 도구를 들면 공격력이 약해짐 (%d → %d)" % [atk0, GameState.attack_power()])
	check(GameState.need_life("rod", true) and not GameState.need_life("net", true), "낚싯대를 들면 낚시는 되고 곤충은 안 됨")
	check(GameState.swap_life() and held() == "" and GameState.attack_power() == atk0, "T: 다시 무기를 듦")
	check(GameState.swap_life() and held() == "rod", "T: 마지막에 든 생활 도구로 돌아감")
	check(Items.describe(GameState.life_tool()).contains("내구도"), "설명에 내구도가 나옴")
	check(GameState.enhance(GameState.life_tool()) != "ok", "생활 도구는 강화하지 않음")

	print("[내구도]")
	var rod: Dictionary = GameState.life_tool()
	var d0 := int(rod["dur"])
	GameState.wear_life("rod")
	check(int(rod["dur"]) == d0 - 1, "쓰면 내구도가 1 줄어듦")
	GameState.wear_life("net")
	check(int(rod["dur"]) == d0 - 1, "들지 않은 도구는 닳지 않음")
	rod["dur"] = 1
	GameState.wear_life("rod")
	check(held() == "" and not GameState.equipped.has("tool"), "내구도가 다 되면 부서져 사라짐")

	print("[등급]")
	check(Items.LIFE_DUR[2] > Items.LIFE_DUR[1] and Items.LIFE_DUR[1] > Items.LIFE_DUR[0], "금 > 쇠 > 나무 순으로 오래 감")
	GameState.hold_life("net")
	check(is_equal_approx(GameState.life_power("net"), 0.0), "나무 잠자리채는 보너스 없음")
	GameState.swap_life()
	var net_i := -1
	for i in GameState.inventory.size():
		if str(GameState.inventory[i].get("life", "")) == "net":
			net_i = i
	GameState.pencil_lead = 100
	GameState.coins = 2000
	check(GameState.upgrade_life(net_i) != "ok", "재료가 없으면 올리지 못함")
	GameState.add_material(7, 3)
	GameState.add_material(11, 1)
	check(GameState.upgrade_life(net_i) == "ok" and int(GameState.inventory[net_i]["grade"]) == 1, "조합대에서 쇠 잠자리채로 올림")
	check(GameState.material_count(7) == 0 and int(GameState.inventory[net_i]["dur"]) == Items.LIFE_DUR[1], "재료를 쓰고 내구도가 새로 참")
	GameState.add_material(19, 3)
	GameState.add_material(21, 2)
	check(GameState.upgrade_life(net_i) == "ok" and Items.item_name(GameState.inventory[net_i]) == "금 잠자리채", "금 잠자리채로 올림")
	check(GameState.upgrade_life(net_i) != "ok", "금이 끝")
	GameState.hold_life("net")
	check(is_equal_approx(GameState.life_power("net"), 0.4), "금 잠자리채는 효과 40%")

	print("[사냥터에서]")
	GameState.fatigue = 100
	GameState.spawn_tag = "gate_right"
	GameState.has_saved_position = false
	GameState.give_life_tools(Items.LIFE_ORDER)
	if held() != "":
		GameState.swap_life()
	var f: Node2D = FieldScene.instantiate()
	f.set("field_id", "ch1_meadow")
	add_child(f)
	await frames(10)
	var p: Node2D = f.get("player")
	p.set("_invuln", 999.0)
	var spot: Node2D = null
	for n in get_tree().get_nodes_in_group("interactable"):
		if str(n.get("mode")) == "forage":
			spot = n
			break
	spot.call("interact")
	await frames(3)
	check(not bool(p.call("is_acting")), "무기를 든 채로는 채집이 안 됨")
	GameState.hold_life("sickle")
	var sick_d := int(GameState.life_tool()["dur"])
	spot.call("interact")
	await frames(40)
	check(not GameState.forage_left(str(spot.get("key"))) and int(GameState.life_tool()["dur"]) == sick_d - 1, "낫을 들면 채집하고 낫이 닳음")
	var fishing: Control = f.get("hud").call("fishing")
	fishing.call("start", false, "pond")
	check(not bool(fishing.call("is_active")), "낫을 든 채로는 낚시가 안 됨")
	GameState.hold_life("rod")
	fishing.call("start", false, "pond")
	check(bool(fishing.call("is_active")), "낚싯대를 들면 낚시가 됨")
	fishing.call("stop")
	await frames(3)

	print("[나무: 흔들기와 베기]")
	var trees := get_tree().get_nodes_in_group("tree")
	check(trees.size() >= 2, "사냥터에 나무가 있음 (%d그루)" % trees.size())
	var ground_ok := true
	for i in 300:
		var g := GameState.roll_forage("plant")
		if Items.TREE_FRUIT.has(g) or Items.FROM_CHOP.has(g):
			ground_ok = false
	check(ground_ok, "땅의 채집 자리에서는 열매·나뭇가지가 나오지 않음")
	var fruit_ok := true
	for i in 100:
		fruit_ok = fruit_ok and Items.TREE_FRUIT.has(GameState.roll_forage("tree"))
	check(fruit_ok, "나무에서는 밤·도토리·사과 같은 열매만 떨어짐")
	var tr: Node2D = trees[0]
	var tkey := str(tr.get("key"))
	p.global_position = tr.global_position + Vector2(-14, 4)
	GameState.swap_life()                  # 무기를 든다
	if not GameState.life_tool().is_empty():
		GameState.swap_life()
	var fruit_before := 0
	for id in Items.TREE_FRUIT:
		fruit_before += GameState.consumable_count(id)
	tr.call("interact")
	await frames(5)
	var fruit_after := 0
	for id in Items.TREE_FRUIT:
		fruit_after += GameState.consumable_count(id)
	check(fruit_after > fruit_before and GameState.tree_done(tkey, "shake"), "맨손으로 흔들면 열매가 떨어져 가방에 들어감 (+%d)" % (fruit_after - fruit_before))
	tr.call("interact")
	await frames(3)
	var fruit_again := 0
	for id in Items.TREE_FRUIT:
		fruit_again += GameState.consumable_count(id)
	check(fruit_again == fruit_after, "하루에 한 번만 흔들 수 있음")
	GameState.hold_life("axe")
	var axe_d := int(GameState.life_tool()["dur"])
	var logs0 := GameState.consumable_count("g_log")
	for i in 3:
		tr.call("interact")
		await frames(30)
	check(GameState.consumable_count("g_log") > logs0 and GameState.consumable_count("g_twig") > 0, "도끼로 세 번 찍으면 통나무와 나뭇가지가 나옴")
	check(int(GameState.life_tool()["dur"]) == axe_d - 1, "나무 하나를 베면 도끼가 1 닳음")
	await frames(60)
	check(bool(tr.call("is_stump")), "벤 나무는 그루터기가 됨")
	GameState.day += 1
	check(not GameState.tree_done(tkey, "chop") and not GameState.tree_done(tkey, "shake"), "다음 날에는 다시 자라고 다시 흔들 수 있음")
	GameState.day -= 1

	print("[보스가 터지며 흩어짐]")
	var BossBurst := load("res://scripts/actors/boss_burst.gd")
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/sprites/monsters/boss_0.png")
	f.add_child(spr)
	var burst: Node2D = BossBurst.spawn(f, spr)
	await frames(20)
	check((burst.get("_bits") as Array).size() >= 18 and (burst.get("_pop") as Array).all(func(t): return t != null), "보스가 번쩍인 뒤 터짐 그림 6장과 종이·잉크 조각으로 터짐")
	await frames(140)
	check(not is_instance_valid(burst), "터진 조각은 잠시 뒤 사라짐")
	var theme_ok := true
	for sp in BossBurst.SPRITE_THEME:
		var th := str(BossBurst.SPRITE_THEME[sp])
		for i in 6:
			if not ArtLib.has("fx_boss_pop_%s_%d" % [th, i]) or not ArtLib.has("boss_debris_%s_%d" % [th, i]):
				theme_ok = false
				print("    그림 없음: %s %d" % [th, i])
	check(theme_ok, "보스 7마리가 저마다 터짐 그림 6장과 조각 6개를 가짐")
	var b2: Node2D = BossBurst.spawn(f, spr, "boss_3")
	check(str(b2.get("theme")) == "oak", "큰나무 할아범은 잎·도토리로 터짐")
	b2.queue_free()
	spr.queue_free()
	f.queue_free()
	await frames(3)

	print("[불러오기 화면]")
	var LoadScene := load("res://scenes/loading.tscn")
	var ld: Control = LoadScene.instantiate()
	ld.set("target", "res://scenes/home.tscn")
	add_child(ld)
	await frames(5)
	check(ld.get_node_or_null(".") != null and (ld.get("_tip") as Label).text.begins_with("팁:"), "불러오기 화면에 팁 한 줄이 나옴")
	var prog := 0.0
	for i in 400:
		await frames(1)
		prog = float(ld.call("progress"))
		if prog >= 1.0:
			break
	check(prog >= 1.0, "다음 장면을 뒤에서 다 불러옴")
	ld.set("_done", true)              # 테스트에서는 장면을 바꾸지 않는다
	ld.queue_free()
	await frames(2)

	print("[예전 저장]")
	GameState.inventory = []
	GameState.equipped = {"tool": Items.make("tool", 0, 0, 1)}
	GameState.save_game()
	var raw := FileAccess.get_file_as_string(GameState.save_path)
	var data: Dictionary = JSON.parse_string(raw)
	data.erase("life_given")
	var fa := FileAccess.open(GameState.save_path, FileAccess.WRITE)
	fa.store_string(JSON.stringify(data))
	fa.close()
	GameState.load_game()
	check(GameState.inventory.filter(func(it): return Items.is_life(it)).size() == 6, "생활 도구 전의 저장을 불러오면 나무 도구 한 벌(도끼까지)을 받음")
	GameState.save_game()
	GameState.load_game()
	check(GameState.inventory.filter(func(it): return Items.is_life(it)).size() == 6, "두 번 받지는 않음")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	print("\n결과: %d 통과 / %d 실패" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
