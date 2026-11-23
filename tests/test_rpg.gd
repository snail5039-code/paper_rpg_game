extends Node
## 스킬, 장비, 문방구(사기·팔기·만들기·강화) 테스트 + 화면 캡처.
## 실행: godot --headless --path . res://tests/test_rpg.tscn
##       godot --path . res://tests/test_rpg.tscn -- <캡처 폴더>

const MainScene := preload("res://scenes/main.tscn")
const Items := preload("res://scripts/items.gd")
const Data := preload("res://scripts/game_data.gd")
const Art := preload("res://scripts/art.gd")
const Pixel := preload("res://scripts/doodle_pixel.gd")
const AiPixel := preload("res://scripts/ai_pixel.gd")
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


## 견본이 차지한 자리를 줄마다 가로선으로 덮는 선 (견본을 잘 따라 그린 그림 흉내)
func trace_of(ref: Array) -> Array:
	var out: Array = []
	for y in Pixel.N:
		var x0 := -1
		var x1 := -1
		for x in Pixel.N:
			if ref[y][x]:
				if x0 < 0:
					x0 = x
				x1 = x
		if x0 >= 0:
			out.append(PackedVector2Array([Vector2(x0 + 0.5, y + 0.5) / Pixel.N, Vector2(x1 + 0.5, y + 0.5) / Pixel.N]))
	return out


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else ""
	seed(12345)
	AiPixel.enabled = false   # 테스트에서는 AI 를 부르지 않는다
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
	check(bool(hud.call("is_menu_open", "skills")) and not bool(hud.call("is_menu_open", "bag")), "창이 열린 채로 다른 창의 키를 누르면 그 창으로 바뀜")
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

	print("[직접 그려서 만들기]")
	var ref := Pixel.reference_mask(Art.tex("equip_tool_0"))
	var good := trace_of(ref)
	var q_good := Pixel.similarity(Pixel.silhouette(good), ref)
	var q_bad := Pixel.similarity(Pixel.silhouette([PackedVector2Array([Vector2(0.05, 0.05), Vector2(0.08, 0.05)])]), ref)
	check(q_good > 0.8 and q_bad == 0.0, "견본을 따라 그리면 점수가 높고 딴 데 그리면 0 (%.2f, %.2f)" % [q_good, q_bad])
	var ring: Array = [PackedVector2Array([Vector2(0.3, 0.3), Vector2(0.7, 0.3), Vector2(0.7, 0.7), Vector2(0.3, 0.7), Vector2(0.3, 0.3)])]
	var dot_img := Pixel.pixelize(ring, Pixel.PALETTE[0])
	check(dot_img.get_pixel(16, 16).a > 0.9 and dot_img.get_pixel(16, 16) != Pixel.OUTLINE and dot_img.get_pixel(2, 2).a == 0.0,
		"닫힌 선 안쪽은 색이 칠해지고 바깥은 투명")
	GameState.materials = {2: 4, 0: 2}
	GameState.pencil_lead = 3
	shop.call("_craft", Items.RECIPES[3])
	await frames(3)
	var canvas: Control = shop.get("_canvas")
	check(is_instance_valid(canvas), "만들기에서 그리기 화면이 열림")
	# 아무렇게나 그으면 만들어지지 않고 재료도 그대로다
	canvas.set("strokes", [PackedVector2Array([Vector2(0.05, 0.05), Vector2(0.08, 0.05)])])
	canvas.call("_update")
	var scribble_n := GameState.inventory.size()
	canvas.call("finish")
	await frames(3)
	check(is_instance_valid(canvas) and GameState.inventory.size() == scribble_n and GameState.material_count(2) == 4,
		"견본과 너무 다르게 그리면 만들어지지 않고 재료도 안 듦")
	canvas.set("strokes", good)
	canvas.call("_update")
	await frames(3)
	await shot("rpg_8_craft_draw.png")
	var n_before := GameState.inventory.size()
	canvas.call("finish")
	await frames(3)
	var made: Dictionary = GameState.inventory[GameState.inventory.size() - 1]
	var art := str(made.get("art", ""))
	check(GameState.inventory.size() == n_before + 1 and art.begins_with("drawn_"), "그린 그림으로 장비가 만들어짐")
	check(Items.icon(made) == art and Art.tex(art) != null and FileAccess.file_exists("user://drawn/" + art + ".png"), "내 그림이 아이콘이 되고 파일로 저장됨")
	var plain: Dictionary = made.duplicate(true)
	plain["bonus"] = 0
	check(int(made["bonus"]) >= 16 and Items.main_value(made) > Items.main_value(plain), "잘 그리면 기본 능력이 오름 (+%d%%)" % int(made["bonus"]))
	check(not is_instance_valid(canvas) or canvas.is_queued_for_deletion(), "완성하면 그리기 화면이 닫힘")
	await shot("rpg_9_craft_done.png")
	var band := GameState.consumable_count("bandage")
	check(GameState.craft(Items.RECIPES[0], 0.7, art) and GameState.consumable_count("bandage") == band + 2 and GameState.consumable_icon("bandage") == art,
		"소모품은 잘 그리면 2개가 나오고 내 그림이 아이콘이 됨")
	GameState.custom_icons = {}
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://drawn/" + art + ".png"))
	shop.call("_set_tab", 3)
	await frames(3)
	await shot("rpg_6_shop_enhance.png")
	hud.call("toggle_menu", "shop")
	await frames(3)
	check(not get_tree().paused, "창을 닫으면 다시 움직임")
	await shot("rpg_7_hud.png")

	print("[가방 칸 늘리기]")
	GameState.coins = 1000
	GameState.dust = 24
	check(GameState.bag_size == 24 and GameState.bag_expand_cost() == [150, 12], "처음 24칸, 늘리는 값은 동전 150 또는 가루 12")
	check(GameState.expand_bag("coins") and GameState.bag_size == 32 and GameState.coins == 850, "동전으로 32칸 (8칸씩)")
	check(GameState.expand_bag("dust") and GameState.bag_size == 40 and GameState.dust == 0, "지우개 가루로 40칸 (값은 두 배씩)")
	check(not GameState.expand_bag("dust") and GameState.bag_size == 40, "값이 모자라면 늘지 않음")
	var kept: Array = GameState.inventory.duplicate()
	while GameState.inventory.size() < 40:
		GameState.add_item(Items.make("hat", 0, 0, 1))
	check(GameState.inventory.size() == 40 and not GameState.add_item(Items.make("hat", 0, 0, 1)), "늘어난 칸만큼 담기고 넘치면 못 담음")
	# 소비 가방과 재료 가방: 종류 하나가 한 칸
	check(int(GameState.bag_sizes["use"]) == 24 and int(GameState.bag_sizes["mat"]) == 48, "소비 24칸, 재료 48칸으로 시작")
	var use_kept: Dictionary = GameState.consumables.duplicate()
	GameState.consumables = {}
	var use_ids: Array = Items.CONSUMABLES.keys()
	for ui in 24:
		GameState.add_consumable(str(use_ids[ui]))
	check(GameState.bag_used("use") == 24 and not GameState.add_consumable(str(use_ids[30])), "소비 가방은 24종류까지. 새 종류는 못 넣음")
	check(GameState.add_consumable(str(use_ids[0]), 5) and GameState.consumable_count(str(use_ids[0])) == 6, "이미 가진 종류는 더 넣을 수 있음")
	check(not GameState.buy(str(use_ids[30])), "가득하면 문방구에서도 새 종류를 못 삼")
	check(GameState.add_consumable(str(use_ids[30]), 1, true), "꼭 받아야 하는 보상은 가득해도 들어옴")
	GameState.consumables = {}
	GameState.coins = 150
	check(GameState.expand_bag("coins", "use") and int(GameState.bag_sizes["use"]) == 32 and GameState.bag_size == 40,
		"소비 가방만 따로 32칸으로 늘림")
	GameState.consumables = use_kept
	check(GameState.BAG_MAX == 96, "가방은 96칸까지")

	print("[상세 보기, 못 쓰는 까닭, 레벨 업 효과]")
	hud.call("toggle_menu", "bag")
	await frames(2)
	var bag_menu: Control = hud.get("_menus")["bag"]
	bag_menu.call("show_detail", bag_menu.call("_item_detail", GameState.inventory[0]))
	await frames(2)
	check(bool(bag_menu.call("detail_open")), "장비를 오른쪽 클릭하면 상세 보기가 뜸")
	await shot("rpg_11_detail.png")
	bag_menu.call("hide_detail")
	var use_info: Dictionary = bag_menu.call("_use_detail", "bandage")
	check(str(use_info["title"]) == "반창고" and str(use_info["text"]).contains("HP"), "소모품 상세 보기에 이름과 설명이 나옴")
	check(str((bag_menu.call("_mat_detail", 0) as Dictionary)["text"]).contains("쓰이는 곳"), "재료 상세 보기에 쓰이는 곳이 나옴")
	hud.call("toggle_menu", "bag")
	await frames(2)
	GameState.add_consumable("bandage", 1, true)
	player.set("hp", int(player.get("max_hp")))
	var band_n := GameState.consumable_count("bandage")
	check(not bool(player.call("use_consumable", "bandage")) and str(player.get("use_fail")).contains("가득") and GameState.consumable_count("bandage") == band_n,
		"체력이 가득하면 쓰지 않고 까닭을 알려 줌")
	GameState.leveled_up.emit(GameState.level)
	check(float(player.get("_levelup_t")) > 1.0, "레벨이 오르면 캐릭터에 효과가 보임")
	await frames(20)
	await shot("rpg_12_levelup.png")

	print("[완성 등급 고유 효과와 유일 장비]")
	var eq_kept: Dictionary = GameState.equipped.duplicate(true)
	var done_tool := Items.make("tool", 0, 4, 1)
	check(Items.fx_of(done_tool) == "ink" and Items.fx_of(Items.make("tool", 0, 3, 1)) == "", "완성 등급에만 고유 효과가 붙음")
	check(Items.describe(done_tool).contains("잉크 번짐"), "설명에 고유 효과가 나옴")
	GameState.equipped["hat"] = Items.make("hat", 0, 4, 1)
	GameState.equipped["shoe"] = Items.make("shoe", 0, 4, 1)
	GameState.changed.emit()
	check(GameState.has_fx("brim") and GameState.has_fx("light") and not GameState.has_fx("ink"), "입은 장비의 고유 효과만 켜짐")
	var def_now := GameState.defense()
	player.set("_invuln", 0.0)
	var brim_hp := int(player.get("hp"))
	player.call("take_damage", def_now + 20, Vector2.RIGHT)
	check(brim_hp - int(player.get("hp")) == 18, "단단한 챙: 받는 피해 20 이 18 로 줄어듦")
	player.set("hp", int(player.get("max_hp")))
	var star := Items.make_unique("u_star")
	check(Items.is_unique(star) and Items.item_name(star) == "★ 구깃이의 구겨진 별" and int(star["tier"]) == 4 and (star["opts"] as Array).size() == 3,
		"유일 장비는 이름과 옵션이 정해져 있음")
	check(Items.fx_of(star) == "u_star" and Items.describe(star).contains("구겨진 별"), "유일 장비는 자기만의 효과가 있음")
	check(str(Data.MONSTERS["boss_crumple"]["unique"]) == "u_star" and str(Data.MONSTERS["boss_scribble"]["unique"]) == "u_pen",
		"대장과 필드 보스마다 유일 장비가 하나씩")
	GameState.equipped["tool"] = Items.make_unique("u_pen")
	GameState.changed.emit()
	await frames(2)
	check(GameState.has_fx("u_pen") and GameState.attack_power() > 0, "유일 도구를 입으면 효과가 켜지고 공격력이 계산됨")
	var opt_item := Items.make("acc", 0, 0, 1)
	opt_item["opts"] = [["drop", 20], ["exp", 50]]
	GameState.equipped["acc"] = opt_item
	check(is_equal_approx(GameState.drop_mult(), 1.2), "드롭률 옵션이 실제로 드롭에 반영됨")

	print("[세트 장비]")
	check(Items.SETS.size() == 3, "1장 세트는 세 벌")
	var bosses_with_set := {}
	for sid in Items.SETS:
		bosses_with_set[str(Items.SETS[sid]["boss"])] = true
	check(bosses_with_set.has("boss_bug") and bosses_with_set.has("boss_crumple") and bosses_with_set.has("boss_scribble"), "중간 보스·대장·필드 보스가 한 벌씩")
	var piece := Items.make_set("eraser", "hat", 0, 5)
	check(Items.set_of(piece) == "eraser" and int(piece["tier"]) == Items.SET_MIN_TIER and Items.item_name(piece) == "◆ 지우개 세트 모자", "세트 장비는 색칠 등급부터, 이름에 세트가 붙음")
	check(Items.describe(piece).contains("2부위") and Items.describe(piece).contains("받는 피해 15%"), "설명에 세트 효과가 나옴")
	GameState.equipped = {}
	var hp0 := GameState.gear("hp")
	piece["opts"] = []          # 무작위 옵션은 빼고 세트 효과만 잰다
	GameState.equipped["hat"] = piece
	check(GameState.set_count("eraser") == 1 and GameState.gear("hp") == hp0, "한 부위는 효과 없음")
	GameState.equipped["shoe"] = Items.make_set("eraser", "shoe", 2, 5)
	GameState.equipped["shoe"]["opts"] = []
	check(GameState.gear("hp") == hp0 + 60, "2부위: 최대 HP +60")
	for sl in ["tool", "cloth", "bag", "acc"]:
		GameState.equipped[sl] = Items.make_set("eraser", sl, 2, 5)
		GameState.equipped[sl]["opts"] = []
	var cloth_hp := Items.main_value(GameState.equipped["cloth"])
	check(GameState.set_count("eraser") == 6 and GameState.has_fx("set_eraser") and GameState.gear("hp") == hp0 + cloth_hp + 60 + 120, "6부위: HP +120 더, 받는 피해 15% 감소 효과")
	check(not GameState.has_fx("set_crumple"), "다른 세트 효과는 꺼져 있음")
	GameState.changed.emit()
	await frames(2)
	player.set("_invuln", 0.0)
	player.set("hp", int(player.get("max_hp")))
	var set_hp := int(player.get("hp"))
	player.call("take_damage", GameState.defense() + 100, Vector2.RIGHT)
	check(set_hp - int(player.get("hp")) == 85, "지우개 세트 6부위: 받는 피해 100 이 85 로")
	player.set("hp", int(player.get("max_hp")))
	var dropped := {}
	for i in 60:
		dropped = GameState.roll_set_drop("boss_crumple", "boss", 1)
		if not dropped.is_empty():
			break
	check(Items.set_of(dropped) == "crumple", "대장을 잡으면 구김 세트가 나올 수 있음")
	check(GameState.roll_set_drop("slime_faded", "", 1).is_empty(), "보통 몬스터는 세트를 떨어뜨리지 않음")
	GameState.inventory.append(Items.make_set("scribble", "acc", 3, 1))
	GameState.equipped = eq_kept
	GameState.changed.emit()
	await frames(2)
	check(Items.RECIPES.size() >= 21, "조합법: 스케치·색칠·덧칠 등급을 여섯 부위 모두 만들 수 있음 (%d가지)" % Items.RECIPES.size())
	hud.call("toggle_menu", "bag")
	(hud.get("_menus")["bag"] as Control).call("_turn_page", 1)
	await frames(3)
	await shot("rpg_10_bag_page2.png")
	hud.call("toggle_menu", "bag")
	GameState.inventory = kept
	await frames(2)

	print("[필살기]")
	GameState.level = maxi(GameState.level, 5)
	GameState.skill_points = 1
	check(GameState.learn_skill("ult") and str(GameState.skill_slots.find("ult")) == "-1", "필살기를 배움 (Q·E·R 칸에는 들어가지 않음)")
	player.set("ult", 0.0)
	check(not bool(player.call("use_ultimate")), "게이지가 비어 있으면 쓸 수 없음")
	var big := dummy(Vector2(60, 0))
	await frames(2)
	player.call("_hit", big, 1.0, AIM)
	check(is_equal_approx(float(player.get("ult")), 5.0), "적을 맞히면 게이지가 참")
	player.set("ult", 100.0)
	var big_hp := int(big.get("hp"))
	check(bool(player.call("use_ultimate")), "게이지가 가득 차면 필살기를 씀")
	var ult: Control = hud.call("ultimate")
	await frames(20)
	check(bool(ult.call("is_active")) and get_tree().paused, "컷인이 나오는 동안 게임이 멈춤")
	await shot("rpg_11_ult_cutin.png")
	for i in 200:
		if str(ult.get("phase")) == "trace":
			break
		await frames(1)
	ult.set("strokes", [ult.get("_guide")])
	await frames(2)
	await shot("rpg_12_ult_trace.png")
	check(float(ult.call("measure")) > 0.9, "별을 따라 그리면 점수가 높음 (%.2f)" % float(ult.call("measure")))
	ult.call("finish_trace")
	for i in 200:
		if not bool(ult.call("is_active")):
			break
		await frames(1)
	await frames(4)
	await shot("rpg_13_ult_burst.png")
	check(not get_tree().paused and float(player.get("ult")) < 100.0, "끝나면 다시 움직이고 게이지가 비워짐")
	check(big_hp - int(big.get("hp")) >= GameState.attack_power() * 5, "화면의 적에게 큰 피해 (%d)" % (big_hp - int(big.get("hp"))))
	big.queue_free()

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
	check(GameState.bag_size == 40 and int(GameState.bag_sizes["use"]) == 32, "늘린 가방 칸이 그대로")
	check(GameState.coins == coins and GameState.attack_power() > 0, "동전이 그대로이고 수치 계산이 됨 (공격력 %d)" % GameState.attack_power())

	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	print("\n결과: %d 통과 / %d 실패" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
