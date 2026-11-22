extends Node
## 스킬, 장비, 문방구(사기·팔기·만들기·강화) 테스트 + 화면 캡처.
## 실행: godot --headless --path . res://tests/test_rpg.tscn
##       godot --path . res://tests/test_rpg.tscn -- <캡처 폴더>

const MainScene := preload("res://scenes/main.tscn")
const Items := preload("res://scripts/items.gd")
const S := 640.0 / 1672.0
const AIM := Vector2(10, 0)   # 조준 방향 (길이가 1보다 커야 조준으로 친다)

var passed := 0
var failed := 0
var _dir := ""
var world: Node2D
var player: Node2D


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


## 시험용 몬스터를 플레이어 오른쪽에 하나 세운다 (체력이 많아서 잘 죽지 않는다)
func dummy(offset: Vector2, hp: int = 9999) -> Node2D:
	var m: Node2D = preload("res://scenes/enemy.tscn").instantiate()
	m.set("kind", "slime_faded")
	m.position = player.global_position + offset
	world.get("actors").add_child(m)
	m.set("max_hp", hp)
	m.set("hp", hp)
	m.set("speed", 0.0)
	m.set("aggro_range", 0.0)
	return m


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else ""
	seed(12345)
	GameState.save_path = "user://test_rpg_save.json"
	GameState.quest = GameState.Quest.FIND_LEAD
	GameState.intro_seen = true
	GameState.has_saved_position = false
	GameState.level = 1
	GameState.exp = 0
	GameState.coins = 0
	GameState.dust = 0
	GameState.pencil_lead = 0
	GameState.materials = {}
	GameState.skill_points = 0
	GameState.skill_ranks = {}
	GameState.skill_slots = ["", "", ""]
	GameState.call("_starting_gear")
	for k in GameState.STAT_KEYS:
		GameState.stats[k] = 0

	world = MainScene.instantiate()
	add_child(world)
	await frames(5)
	player = world.get("player")
	player.set("_invuln", 9999.0)
	player.global_position = Vector2(500, 560) * S
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await frames(3)

	print("[시작 장비와 수치]")
	check(GameState.equipped.has("tool") and GameState.attack_power() == 10, "낙서 연필을 들고 시작, 공격력 10")
	check(GameState.consumable_count("bandage") == 2, "반창고 2개를 갖고 시작")

	print("[기본 공격 3연타]")
	var foe := dummy(Vector2(22, 0))
	await frames(2)
	var hits: Array = []
	for i in 3:
		var before: int = foe.get("hp")
		player.set("_attack_cd", 0.0)
		player.call("attack", AIM)
		await frames(2)
		hits.append(before - int(foe.get("hp")))
	check(hits[0] == hits[1] and hits[2] > hits[1], "세 번째 타격이 더 강함 (%s)" % str(hits))
	check(int(player.get("combo")) == 0, "세 번 치면 연타가 처음으로 돌아감")
	player.call("attack", AIM)
	await frames(60)
	check(int(player.get("combo")) == 0, "잠깐 쉬면 연타가 끊김")

	print("[스킬]")
	check(not GameState.learn_skill("slash"), "스킬 포인트가 없으면 배울 수 없음")
	GameState.add_exp(GameState.exp_needed())
	check(GameState.level == 2 and GameState.skill_points == 1, "레벨이 오르면 스킬 포인트 1점")
	check(not GameState.learn_skill("circle"), "필력이 모자란 스킬은 배울 수 없음")
	check(GameState.learn_skill("slash") and GameState.skill_rank("slash") == 1, "길게 긋기를 배움")
	check(str(GameState.skill_slots[0]) == "slash", "처음 배운 스킬은 Q 칸에 들어감")
	player.set("mp", 0.0)
	check(not bool(player.call("use_skill_slot", 0, AIM)), "MP 가 없으면 못 씀")
	player.set("mp", 50.0)
	foe.global_position = player.global_position + Vector2(40, 0)
	var far := dummy(Vector2(70, 0))
	await frames(2)
	var hp_a: int = foe.get("hp")
	var hp_b: int = far.get("hp")
	var x0 := player.global_position.x
	check(bool(player.call("use_skill_slot", 0, AIM)), "길게 긋기를 씀")
	await frames(20)
	check(int(foe.get("hp")) < hp_a and int(far.get("hp")) < hp_b, "지나가는 길의 적이 모두 맞음")
	check(player.global_position.x > x0 + 20.0, "앞으로 미끄러짐 (%.0f)" % (player.global_position.x - x0))
	check(float(player.get("mp")) < 50.0, "MP 를 씀 (%.0f)" % float(player.get("mp")))
	check(not bool(player.call("use_skill_slot", 0, AIM)), "재사용 시간 동안에는 못 씀")
	# 나머지 스킬을 한꺼번에 배워서 써 본다
	GameState.level = 20
	GameState.skill_points = 20
	for id in ["circle", "dot", "hatch", "press", "erase", "sharpen", "warmup"]:
		GameState.learn_skill(id)
	check(GameState.skill_rank("erase") == 1 and str(GameState.skill_slots[1]) == "circle", "스킬을 배우면 빈 칸에 차례로 들어감")
	var atk_before := GameState.attack_power()
	GameState.learn_skill("sharpen")
	check(GameState.attack_power() >= atk_before, "연필 깎기는 공격력을 올림 (%d → %d)" % [atk_before, GameState.attack_power()])
	player.set("mp", 999.0)
	player.set("max_mp", 999)
	foe.global_position = player.global_position + Vector2(30, 0)
	far.global_position = player.global_position + Vector2(-30, 10)
	await frames(2)
	hp_a = foe.get("hp")
	hp_b = far.get("hp")
	player.call("use_skill", "circle", AIM)
	await frames(2)
	check(int(foe.get("hp")) < hp_a and int(far.get("hp")) < hp_b, "동그라미: 주변의 적이 모두 맞음")
	await shot("rpg_1_skill.png")
	far.global_position = player.global_position + Vector2(130, 0)
	foe.global_position = player.global_position + Vector2(0, 200)
	await frames(2)
	hp_b = far.get("hp")
	player.call("use_skill", "dot", AIM)
	await frames(2)
	check(int(far.get("hp")) < hp_b, "점 찍기: 멀리 있는 적이 맞음")
	far.global_position = player.global_position + Vector2(26, 0)
	await frames(2)
	hp_b = far.get("hp")
	player.call("use_skill", "hatch", AIM)
	await frames(2)
	var hatch_dmg: int = hp_b - int(far.get("hp"))
	hp_b = far.get("hp")
	far.set("defense", 5)
	player.call("use_skill", "press", AIM)
	await frames(2)
	var press_dmg: int = hp_b - int(far.get("hp"))
	check(hatch_dmg > 0 and press_dmg >= roundi(GameState.attack_power() * 2.5), "빗금과 꾹 눌러 쓰기 (%d, %d)" % [hatch_dmg, press_dmg])
	player.set("_invuln", 0.0)
	player.call("use_skill", "erase", AIM)
	var hp_p: int = player.get("hp")
	player.call("take_damage", 10, Vector2.LEFT)
	check(int(player.get("hp")) == hp_p, "쓱 지우기: 쓰는 동안 맞지 않음")
	player.set("_invuln", 9999.0)
	GameState.set_skill_slot(2, "press")
	check(str(GameState.skill_slots[2]) == "press", "스킬을 R 칸에 넣음")
	foe.queue_free()
	far.queue_free()

	print("[장비]")
	GameState.level = 5
	var hat := Items.make("hat", 2, 2, 3)
	check((hat["opts"] as Array).size() == 2, "색칠 등급 장비에는 무작위 옵션 2줄")
	check(GameState.add_item(hat) and GameState.inventory.size() == 1, "가방에 장비가 들어감")
	var def0 := GameState.defense()
	check(GameState.equip(0) and GameState.equipped.has("hat") and GameState.inventory.is_empty(), "모자를 씀")
	check(GameState.defense() > def0, "방어가 오름 (%d → %d)" % [def0, GameState.defense()])
	var pencil2 := Items.make("tool", 2, 1, 4)
	GameState.add_item(pencil2)
	var atk0 := GameState.attack_power()
	GameState.equip(0)
	check(GameState.attack_power() > atk0 and GameState.inventory.size() == 1, "도구를 바꾸면 공격력이 오르고 옛 도구는 가방으로 (%d → %d)" % [atk0, GameState.attack_power()])
	var high := Items.make("cloth", 0, 1, 30)
	GameState.add_item(high)
	check(not GameState.equip(1), "필력이 모자라면 입을 수 없음")
	await frames(2)
	check(int(player.get("max_hp")) == GameState.max_hp(), "장비를 바꾸면 플레이어 수치에 바로 반영")
	# 떨어진 장비 줍기
	var drop: Node2D = preload("res://scripts/pickup.gd").new()
	drop.set("item", Items.make("shoe", 0, 1, 1))
	world.get("actors").add_child(drop)
	drop.global_position = player.global_position
	await frames(30)
	check(GameState.inventory.size() == 3, "떨어진 장비를 주우면 가방에 들어감")
	check(GameState.disassemble(1) > 0 and GameState.dust > 0, "분해하면 지우개 가루가 나옴 (%d)" % GameState.dust)

	print("[동전과 문방구]")
	var m := dummy(Vector2(22, 0), 1)
	await frames(2)
	player.set("_attack_cd", 0.0)
	player.call("attack", AIM)
	await frames(5)
	check(GameState.coins > 0, "몬스터를 잡으면 동전을 얻음 (%d)" % GameState.coins)
	GameState.coins = 0
	check(not GameState.buy("bandage"), "동전이 없으면 살 수 없음")
	GameState.coins = 100
	check(GameState.buy("bandage") and GameState.consumable_count("bandage") == 3 and GameState.coins == 85, "반창고를 삼 (동전 85)")
	check(GameState.buy(["hat", 2, 0, 30]) and GameState.coins == 55, "장비를 삼 (동전 55)")
	var n_inv := GameState.inventory.size()
	check(GameState.sell_item(n_inv - 1) > 0 and GameState.inventory.size() == n_inv - 1 and GameState.coins > 55, "장비를 팖 (동전 %d)" % GameState.coins)
	player.set("hp", 10)
	check(bool(player.call("use_consumable", "bandage")) and int(player.get("hp")) > 10, "반창고로 HP 회복")
	player.set("hp", player.get("max_hp"))
	check(not bool(player.call("use_consumable", "bandage")), "HP 가 가득하면 쓰지 않음")

	print("[만들기]")
	var recipe: Array = Items.RECIPES[3]   # 스케치 연필
	check(not GameState.can_craft(recipe), "재료가 없으면 만들 수 없음")
	GameState.materials = {2: 4}
	GameState.pencil_lead = 3
	n_inv = GameState.inventory.size()
	check(GameState.craft(recipe) and GameState.inventory.size() == n_inv + 1, "재료와 연필심으로 장비를 만듦")
	check(GameState.material_count(2) == 0 and GameState.pencil_lead == 0, "재료와 연필심이 줄어듦")

	print("[강화]")
	var tool: Dictionary = GameState.equipped["tool"]
	check(GameState.enhance(tool).begins_with("재료가"), "재료가 없으면 강화할 수 없음")
	GameState.pencil_lead = 9999
	GameState.dust = 9999
	var v0 := Items.main_value(tool)
	check(GameState.enhance(tool) == "ok" and int(tool["plus"]) == 1, "+1 강화는 반드시 성공")
	check(Items.main_value(tool) > v0, "강화하면 능력이 오름 (%d → %d)" % [v0, Items.main_value(tool)])
	tool["plus"] = 9
	var broke := false
	for i in 60:
		tool["plus"] = 9
		if GameState.enhance(tool) == "broken":
			broke = true
			break
	check(broke and not GameState.equipped.has("tool"), "+10 강화에 실패하면 장비가 사라짐")
	check(GameState.attack_power() == roundi(6 * (1.0 + 0.03 * GameState.skill_rank("sharpen"))), "도구가 없으면 맨손 공격력")
	GameState.add_item(Items.make("tool", 0, 0, 1))
	GameState.equip(GameState.inventory.size() - 1)
	var t2: Dictionary = GameState.equipped["tool"]
	GameState.add_consumable("coating", 1)
	var saved := false
	for i in 60:
		t2["plus"] = 9
		var r := GameState.enhance(t2)
		if r == "saved":
			saved = true
			break
		if r == "ok":
			continue
	check(saved and GameState.equipped.has("tool") and GameState.consumable_count("coating") == 0, "코팅지가 있으면 파괴를 한 번 막음")

	print("[화면]")
	var hud: Node = world.get("hud")
	hud.call("toggle_menu", "bag")
	await frames(3)
	check(bool(hud.call("is_menu_open", "bag")) and get_tree().paused, "가방 창이 열리고 게임이 멈춤")
	(hud.get("_menus")["bag"] as Control).call("_select", 0)
	await frames(3)
	await shot("rpg_2_bag.png")
	hud.call("toggle_menu", "skills")
	check(not bool(hud.call("is_menu_open", "skills")), "창이 열려 있으면 다른 창은 열리지 않음")
	hud.call("toggle_menu", "bag")
	hud.call("toggle_menu", "skills")
	await frames(3)
	check(bool(hud.call("is_menu_open", "skills")), "스킬 창이 열림")
	await shot("rpg_3_skills.png")
	hud.call("toggle_menu", "skills")
	await frames(2)
	var keeper: Node2D = world.get("shopkeeper")
	keeper.set("_greeted", true)
	player.global_position = keeper.global_position + Vector2(0, 20)
	await frames(3)
	check(bool(player.call("try_interact")), "문방구 할아버지에게 말을 걸 수 있음")
	await frames(3)
	check(bool(hud.call("is_menu_open", "shop")), "문방구 창이 열림")
	await shot("rpg_4_shop_buy.png")
	var shop: Control = hud.get("_menus")["shop"]
	shop.call("_set_tab", 2)
	await frames(3)
	await shot("rpg_5_shop_craft.png")
	shop.call("_set_tab", 3)
	await frames(3)
	await shot("rpg_6_shop_enhance.png")
	hud.call("toggle_menu", "shop")
	await frames(3)
	check(not get_tree().paused, "창을 닫으면 다시 움직임")
	await shot("rpg_7_hud.png")

	print("[저장/불러오기]")
	var inv_n := GameState.inventory.size()
	var rank := GameState.skill_rank("slash")
	var coins := GameState.coins
	check(GameState.save_game(), "저장 성공")
	GameState.inventory = []
	GameState.equipped = {}
	GameState.skill_ranks = {}
	GameState.coins = 0
	GameState.skill_slots = ["", "", ""]
	check(GameState.load_game(), "불러오기 성공")
	check(GameState.inventory.size() == inv_n and GameState.equipped.has("hat"), "장비가 그대로")
	check(GameState.skill_rank("slash") == rank and str(GameState.skill_slots[0]) == "slash", "스킬이 그대로")
	check(GameState.coins == coins and GameState.attack_power() > 0, "동전이 그대로이고 수치 계산이 됨 (공격력 %d)" % GameState.attack_power())

	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	print("\n결과: %d 통과 / %d 실패" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
