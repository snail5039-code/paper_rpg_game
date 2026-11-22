extends Node
## 전역 게임 상태 (Autoload: GameState)
## 퀘스트 진행도, 재료, 저장/불러오기, 일시정지(대화·연필 모드·컷신)를 관리한다.

signal changed
signal message(text: String)
signal dialogue_requested(speaker: String, lines: Array, portrait: String)
signal dialogue_finished
signal leveled_up(level: int)

const Items := preload("res://scripts/items.gd")
const Data := preload("res://scripts/game_data.gd")

const SAVE_PATH := "user://save.json"
const BRIDGE_COST := 3
const MAX_LEVEL := 99
const STAT_POINTS_PER_LEVEL := 3
const BASE_WEAPON_ATTACK := 10   # 장비가 생기기 전까지 쓰는 기본 무기 공격력
## 능력치 4종 (세부설정 3). 키는 저장용, 이름은 화면용.
const STAT_KEYS := ["pressure", "grit", "finger", "eye"]
const STAT_NAMES := ["필압", "끈기", "손끝", "눈썰미"]
const STAT_DESCS := ["공격력 +2", "최대 HP +8, 방어 +1", "치명타 확률 +1%", "최대 MP +3"]
## 맵 이름 → 장면. "home" 은 내 마을, "ch1" 은 1장 공책 마을.
const MAP_SCENES := {
	"ch1": "res://scenes/main.tscn",
	"home": "res://scenes/home.tscn",
	"ch1_meadow": "res://scenes/field.tscn",
	"ch1_crossroad": "res://scenes/field.tscn",
	"ch1_gridwoods": "res://scenes/field.tscn",
	"ch1_erasedroad": "res://scenes/field.tscn",
}

## 1페이지(튜토리얼) 진행 순서
enum Quest {
	NOT_STARTED,   # 하루와 이야기하기
	FIND_LEAD,     # 슬라임을 잡아 연필심 모으기 → 다리 그리기
	BRIDGE_BUILT,  # 다리를 건너 빨간 문으로
	CLEAN_DOOR,    # 문의 지우개 자국 닦기
	DOOR_OPEN,     # 열린 문으로 들어가기
	CLEARED,       # 1페이지 끝
}

var save_path: String = SAVE_PATH  # 테스트에서 별도 파일로 바꿔 쓴다
var quest: int = Quest.NOT_STARTED
var pencil_lead: int = 0
var bridge_built: bool = false
var intro_seen: bool = false
var level: int = 1
var exp: int = 0
var materials: Dictionary = {}   # 재료 번호(int) → 개수
var stats: Dictionary = {"pressure": 0, "grit": 0, "finger": 0, "eye": 0}
var stat_points: int = 0
var coins: int = 0
var dust: int = 0                 # 지우개 가루 (강화 재료)
var inventory: Array = []         # 가방 속 장비 (items.gd 의 장비 Dictionary)
var equipped: Dictionary = {}     # 부위 → 장비
var consumables: Dictionary = {}  # 소모품 id → 개수
var skill_points: int = 0
var skill_ranks: Dictionary = {}  # 스킬 id → 단계
var skill_slots: Array = ["", "", ""]   # Q, E, R 칸에 넣은 스킬
const INVENTORY_SIZE := 24        # 처음 가방 칸 수
const BAG_STEP := 6               # 한 번 늘릴 때마다
const BAG_MAX := 60
var bag_size: int = INVENTORY_SIZE
var custom_icons: Dictionary = {} # 소모품 id → 내가 그린 아이콘 이름
var friends: Array = []           # 친구 {"sp": 종, "lv": 레벨, "exp": 경험치, "stars": 별}
var companion: int = -1           # 같이 다니는 친구 (friends 의 번호, -1 없음)
const FRIEND_MAX := 30
const FRIEND_EXP_SHARE := 0.3
var clock: float = 480.0          # 게임 속 시각 (분, 0 ~ 1440). 08:00 에 시작
var day: int = 1
var fatigue: int = 100            # 피로도. 사냥터 화면에 들어갈 때마다 줄고, 아침 6시에 가득 찬다
const FATIGUE_MAX := 100
const FATIGUE_PER_FIELD := 2
const DAY_START := 360.0          # 06:00
const NIGHT_START := 1200.0       # 20:00
var home_sheets: int = 4          # 내 마을 종이 장수 (4 → 16)
var home_objects: Array = []      # 내 마을에 지은 것 {"id", "x", "y", "fine"}
var current_map: String = "ch1"
var visited: Array = ["ch1"]     # 가 본 맵 (지도에 그림으로 나온다)
var spawn_tag: String = ""       # 맵을 옮길 때 어디서 왔는지 (새 맵이 한 번 읽고 지운다)
var home_cells: String = ""      # 내 마을 바닥 칸 (압축 + base64)
var home_doodles: Array = []     # 내 마을 자유 낙서 (선마다 [x0, y0, x1, y1, ...])
var home_intro_seen: bool = false
var has_saved_position: bool = false
var saved_position: Vector2 = Vector2.ZERO

var player_ref: Node2D = null
var dialogue_open: bool = false
var draw_mode: bool = false
var cutscene: bool = false
var menu_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_starting_gear()
	load_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("save_game"):
		if save_game():
			notify("저장했어요.")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("reset_game"):
		reset_game()
		get_viewport().set_input_as_handled()


# ---------- 진행도 ----------

func set_quest(value: int) -> void:
	quest = value
	changed.emit()
	save_game()


func add_lead(amount: int) -> void:
	pencil_lead = max(0, pencil_lead + amount)
	changed.emit()


# ---------- 맵 이동 ----------

func map_scene() -> String:
	return str(MAP_SCENES.get(current_map, MAP_SCENES["ch1"]))


## 다른 맵으로 간다. 게임 맵이 현재 장면일 때만 실제로 옮긴다 (테스트에서는 옮기지 않고 false).
func goto_map(map: String, tag: String = "") -> bool:
	if not MAP_SCENES.has(map):
		return false
	var scene := get_tree().current_scene
	if scene == null or not scene.is_in_group("game_map"):
		return false
	# 사냥터 화면에 들어갈 때마다 피로도가 든다
	if Data.FIELDS.has(map):
		if fatigue < FATIGUE_PER_FIELD:
			notify("너무 피곤해서 더 갈 수 없어요. 내 집에서 자거나 아침을 기다려요.")
			return false
		fatigue -= FATIGUE_PER_FIELD
	current_map = map
	if not visited.has(map):
		visited.append(map)
	spawn_tag = tag
	has_saved_position = false
	player_ref = null   # 옛 맵의 위치는 저장하지 않는다
	dialogue_open = false
	draw_mode = false
	cutscene = false
	menu_open = false
	_update_pause()
	save_game()
	get_tree().change_scene_to_file.call_deferred(map_scene())
	return true


# ---------- 성장 ----------

## 다음 레벨까지 필요한 경험치: 20 × 레벨^1.7
func exp_needed(lv: int = -1) -> int:
	if lv < 0:
		lv = level
	return roundi(20.0 * pow(float(lv), 1.7))


func add_exp(amount: int) -> void:
	_friend_exp(amount)
	if level >= MAX_LEVEL:
		return
	exp += amount
	while level < MAX_LEVEL and exp >= exp_needed():
		exp -= exp_needed()
		level += 1
		stat_points += STAT_POINTS_PER_LEVEL
		skill_points += 1
		leveled_up.emit(level)
		notify("레벨 업!  필력 %d" % level)
	if level >= MAX_LEVEL:
		exp = 0
	changed.emit()


func stat(key: String) -> int:
	return int(stats.get(key, 0))


## 남은 포인트 1점을 능력치에 넣는다
func add_stat(key: String) -> bool:
	if stat_points <= 0 or not stats.has(key):
		return false
	stat_points -= 1
	stats[key] = stat(key) + 1
	changed.emit()
	return true


func max_hp() -> int:
	return 40 + level * 6 + stat("grit") * 8 + gear("hp")


func max_mp() -> int:
	return 20 + level * 2 + stat("eye") * 3 + gear("mp")


## 공격력 = (도구 공격력 + 필압 × 2 + 옵션) × 연필 깎기
func attack_power() -> int:
	var base := (gear("atk") if equipped.has("tool") else 6) + stat("pressure") * 2
	return roundi(base * (1.0 + 0.03 * skill_rank("sharpen")))


func defense() -> int:
	return stat("grit") + gear("def")


func crit_chance() -> float:
	return 0.05 + stat("finger") * 0.01 + gear("crit") * 0.01


func crit_mult() -> float:
	return 1.5 + gear("critdmg") * 0.01


func move_speed_mult() -> float:
	return 1.0 + gear("mspd") * 0.01


func attack_speed_mult() -> float:
	return 1.0 + gear("aspd") * 0.01 + 0.02 * skill_rank("warmup")


# ---------- 장비 ----------

## 새 게임의 기본 장비: 낙서 연필 한 자루
func _starting_gear() -> void:
	inventory = []
	equipped = {"tool": Items.make("tool", 0, 0, 1)}
	consumables = {"bandage": 2}


## 입고 있는 장비에서 오는 능력 합계 (기본 능력 + 무작위 옵션)
func gear(key: String) -> int:
	var total := 0
	for slot in equipped:
		var item: Dictionary = equipped[slot]
		if str(Items.MAIN_STAT[str(item["slot"])]) == key:
			total += Items.main_value(item)
		for o in item["opts"]:
			if str(o[0]) == key:
				total += int(o[1])
	return total


func add_item(item: Dictionary) -> bool:
	if inventory.size() >= bag_size:
		return false
	inventory.append(item)
	changed.emit()
	return true


## 가방의 index 번째 장비를 입는다. 입고 있던 것은 가방으로 돌아온다.
func equip(index: int) -> bool:
	if index < 0 or index >= inventory.size():
		return false
	var item: Dictionary = inventory[index]
	if int(item["level"]) > level:
		notify("필력이 %d 이상이어야 쓸 수 있어요." % int(item["level"]))
		return false
	var slot := str(item["slot"])
	inventory.remove_at(index)
	if equipped.has(slot):
		inventory.append(equipped[slot])
	equipped[slot] = item
	changed.emit()
	return true


func unequip(slot: String) -> bool:
	if not equipped.has(slot) or inventory.size() >= bag_size:
		return false
	inventory.append(equipped[slot])
	equipped.erase(slot)
	changed.emit()
	return true


func sell_item(index: int) -> int:
	if index < 0 or index >= inventory.size():
		return 0
	var price := Items.sell_price(inventory[index])
	inventory.remove_at(index)
	coins += price
	changed.emit()
	return price


## 분해하면 지우개 가루가 나온다
func disassemble(index: int) -> int:
	if index < 0 or index >= inventory.size():
		return 0
	var got := Items.dust_value(inventory[index])
	inventory.remove_at(index)
	dust += got
	changed.emit()
	return got


## 강화. 결과: "ok", "fail"(변화 없음), "down"(한 단계 하락), "broken"(파괴), "saved"(코팅지가 막음), 또는 못 하는 이유.
func enhance(item: Dictionary) -> String:
	if int(item.get("plus", 0)) >= Items.MAX_PLUS:
		return "최고 단계예요."
	var cost: Array = Items.enhance_cost(item)
	if pencil_lead < int(cost[0]) or dust < int(cost[1]):
		return "재료가 부족해요. (연필심 %d, 지우개 가루 %d)" % [int(cost[0]), int(cost[1])]
	pencil_lead -= int(cost[0])
	dust -= int(cost[1])
	var plus := int(item.get("plus", 0))
	var result := "ok"
	if randf() < Items.enhance_rate(item):
		item["plus"] = plus + 1
	elif plus < 6:
		result = "fail"
	elif consumable_count("coating") > 0:
		consumables["coating"] = consumable_count("coating") - 1
		result = "saved"
	elif plus < 9:
		item["plus"] = plus - 1
		result = "down"
	else:
		for slot in equipped.keys():
			if is_same(equipped[slot], item):
				equipped.erase(slot)
		for i in range(inventory.size() - 1, -1, -1):
			if is_same(inventory[i], item):
				inventory.remove_at(i)
		result = "broken"
	changed.emit()
	return result


# ---------- 동전, 소모품, 조합 ----------

func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	changed.emit()


func consumable_count(id: String) -> int:
	return int(consumables.get(id, 0))


func add_consumable(id: String, amount: int = 1) -> void:
	consumables[id] = consumable_count(id) + amount
	changed.emit()


## 문방구에서 사기. entry 는 Items.SHOP 의 한 줄.
func buy(entry: Variant) -> bool:
	if typeof(entry) == TYPE_STRING:
		var price := int(Items.CONSUMABLES[entry][2])
		if coins < price:
			return false
		coins -= price
		add_consumable(str(entry))
		return true
	var arr: Array = entry
	if coins < int(arr[3]) or inventory.size() >= bag_size:
		return false
	coins -= int(arr[3])
	add_item(Items.make(str(arr[0]), int(arr[1]), int(arr[2]), 1))
	return true


func can_craft(recipe: Array) -> bool:
	var mats: Dictionary = recipe[2]
	for id in mats:
		if material_count(int(id)) < int(mats[id]):
			return false
	if pencil_lead < int(recipe[3]):
		return false
	return typeof(recipe[1]) == TYPE_STRING or inventory.size() < bag_size


## 가방 칸 늘리기 값: [동전, 지우개 가루]. 둘 중 하나로 낸다. 늘릴 때마다 두 배.
func bag_expand_cost() -> Array:
	var n := (bag_size - INVENTORY_SIZE) / BAG_STEP
	return [150 * int(pow(2, n)), 12 * int(pow(2, n))]


## with: "coins" 또는 "dust"
func expand_bag(with: String) -> bool:
	if bag_size >= BAG_MAX:
		return false
	var cost := bag_expand_cost()
	if with == "coins":
		if coins < int(cost[0]):
			return false
		coins -= int(cost[0])
	else:
		if dust < int(cost[1]):
			return false
		dust -= int(cost[1])
	bag_size += BAG_STEP
	changed.emit()
	return true


func consumable_icon(id: String) -> String:
	var own := str(custom_icons.get(id, ""))
	return own if own != "" else str(Items.CONSUMABLES[id][1])


## quality: 견본과 얼마나 비슷하게 그렸는지 (0~1). art: 내가 그린 아이콘 이름.
##   장비는 기본 능력이 최대 20% 오르고, 소모품은 0.6 이상이면 2개가 나온다.
func craft(recipe: Array, quality: float = 0.0, art: String = "") -> bool:
	if not can_craft(recipe):
		return false
	var mats: Dictionary = recipe[2]
	for id in mats:
		materials[int(id)] = material_count(int(id)) - int(mats[id])
	pencil_lead -= int(recipe[3])
	if typeof(recipe[1]) == TYPE_STRING:
		add_consumable(str(recipe[1]), 2 if quality >= 0.6 else 1)
		if art != "":
			custom_icons[str(recipe[1])] = art
	else:
		var r: Array = recipe[1]
		var item := Items.make(str(r[0]), int(r[1]), int(r[2]), maxi(1, level))
		item["bonus"] = roundi(clampf(quality, 0.0, 1.0) * 20.0)
		if art != "":
			item["art"] = art
		add_item(item)
	changed.emit()
	return true


# ---------- 친구 (포획, 동행, 합치기) ----------

func has_paper() -> bool:
	return consumable_count("paper") > 0 or consumable_count("paper_thick") > 0


## 다시 그리기 성공률. score: 따라 그린 정확도(0~1). 60%면 40%, 90% 이상이면 80%.
##  많이 지워진 모습은 -15%, 두꺼운 도화지는 +20%.
func capture_chance(score: float, kind: String, thick: bool) -> float:
	var c := 0.0
	if score >= 0.9:
		c = 0.8
	elif score >= 0.6:
		c = lerpf(0.4, 0.8, (score - 0.6) / 0.3)
	else:
		c = 0.4 * score / 0.6
	if kind.ends_with("_erased"):
		c -= 0.15
	if thick:
		c += 0.2
	return clampf(c, 0.02, 0.95)


## 도화지 한 장을 쓰고 다시 그리기를 굴린다. 돌려주는 것: "ok", "fail", "no_paper", "full"
func try_capture(kind: String, score: float) -> String:
	if friends.size() >= FRIEND_MAX:
		return "full"
	var thick := consumable_count("paper") <= 0
	var id := "paper_thick" if thick else "paper"
	if consumable_count(id) <= 0:
		return "no_paper"
	consumables[id] = consumable_count(id) - 1
	var ok := randf() < capture_chance(score, kind, thick)
	if ok:
		add_friend(Data.species_of(kind))
	changed.emit()
	return "ok" if ok else "fail"


func add_friend(sp: String) -> bool:
	if not Data.FRIENDS.has(sp) or friends.size() >= FRIEND_MAX:
		return false
	friends.append({"sp": sp, "lv": 1, "exp": 0, "stars": 0})
	if companion < 0:
		companion = friends.size() - 1
	changed.emit()
	return true


func friend_name(f: Dictionary) -> String:
	return str(Data.FRIENDS[str(f["sp"])]["name"]) + "★".repeat(int(f["stars"]))


## 친구의 공격력: (4 + 레벨 × 2) × 종의 힘 × (1 + 별 × 15%)
func friend_attack(f: Dictionary) -> int:
	return roundi((4 + int(f["lv"]) * 2) * float(Data.FRIENDS[str(f["sp"])]["power"]) * (1.0 + 0.15 * int(f["stars"])))


func companion_friend() -> Dictionary:
	return friends[companion] if companion >= 0 and companion < friends.size() else {}


## 같이 다닐 친구를 고른다. 이미 같이 다니는 친구를 고르면 쉬게 한다.
func set_companion(i: int) -> void:
	companion = -1 if i == companion or i < 0 or i >= friends.size() else i
	changed.emit()


func release_friend(i: int) -> void:
	if i < 0 or i >= friends.size():
		return
	_remove_friends([i])
	changed.emit()


## 친구들을 지우고 동행 번호를 맞춘다
func _remove_friends(idx: Array) -> void:
	var keep: Variant = friends[companion] if companion >= 0 and companion < friends.size() and not idx.has(companion) else null
	idx.sort()
	for k in range(idx.size() - 1, -1, -1):
		friends.remove_at(int(idx[k]))
	companion = -1
	if keep != null:
		for k in friends.size():
			if is_same(friends[k], keep):
				companion = k


## 같은 종 합치기에 드는 마리 수: 별 n개 → n+1개에 n마리 (처음은 1마리)
func merge_need(f: Dictionary) -> int:
	return maxi(1, int(f["stars"]))


## i 번 친구에게 같은 종의 다른 친구들을 합쳐 별을 하나 붙인다 (별이 적은 친구부터 쓴다)
func merge_same(i: int) -> bool:
	if i < 0 or i >= friends.size() or int(friends[i]["stars"]) >= 5:
		return false
	var f: Dictionary = friends[i]
	var others: Array = []
	for k in friends.size():
		if k != i and str(friends[k]["sp"]) == str(f["sp"]):
			others.append(k)
	others.sort_custom(func(a: int, b: int) -> bool: return int(friends[a]["stars"]) < int(friends[b]["stars"]))
	var need := merge_need(f)
	if others.size() < need:
		return false
	f["stars"] = int(f["stars"]) + 1
	_remove_friends(others.slice(0, need))
	changed.emit()
	return true


## i 번 친구와 섞어 새 종을 만들 수 있는 친구의 번호 (없으면 -1). 둘 다 별 2개 이상.
func cross_partner(i: int) -> int:
	if i < 0 or i >= friends.size() or int(friends[i]["stars"]) < 2:
		return -1
	var sp := str(friends[i]["sp"])
	for m in Data.MERGES:
		var other := ""
		if str(m[0]) == sp:
			other = str(m[1])
		elif str(m[1]) == sp:
			other = str(m[0])
		if other == "":
			continue
		for k in friends.size():
			if k != i and str(friends[k]["sp"]) == other and int(friends[k]["stars"]) >= 2:
				return k
	return -1


## 다른 종끼리 합쳐 새 종을 만든다. 레벨은 둘 중 높은 쪽을 잇는다.
func merge_cross(i: int) -> bool:
	var j := cross_partner(i)
	if j < 0:
		return false
	var a := str(friends[i]["sp"])
	var b := str(friends[j]["sp"])
	var born := ""
	for m in Data.MERGES:
		if (str(m[0]) == a and str(m[1]) == b) or (str(m[0]) == b and str(m[1]) == a):
			born = str(m[2])
	var lv := maxi(int(friends[i]["lv"]), int(friends[j]["lv"]))
	var was_companion := companion == i or companion == j
	_remove_friends([i, j])
	friends.append({"sp": born, "lv": lv, "exp": 0, "stars": 0})
	if was_companion:
		companion = friends.size() - 1
	changed.emit()
	return true


## 같이 다니는 친구는 주인공이 얻는 경험치의 30%를 얻는다. 주인공 레벨을 넘지 못한다.
func _friend_exp(amount: int) -> void:
	var f := companion_friend()
	if f.is_empty() or int(f["lv"]) >= level:
		return
	f["exp"] = int(f["exp"]) + maxi(1, roundi(amount * FRIEND_EXP_SHARE))
	while int(f["lv"]) < level and int(f["exp"]) >= roundi(20.0 * pow(int(f["lv"]), 1.7)):
		f["exp"] = int(f["exp"]) - roundi(20.0 * pow(int(f["lv"]), 1.7))
		f["lv"] = int(f["lv"]) + 1
		notify("%s 의 레벨이 올랐어요! (%d)" % [friend_name(f), int(f["lv"])])


# ---------- 시간, 피로도, 쓰러짐 ----------

## 하루는 90분: 낮(06~20시) 60분, 밤(20~06시) 30분. real_sec 만큼 실제 시간이 흘렀다.
func advance_clock(real_sec: float) -> void:
	var night := clock >= NIGHT_START or clock < DAY_START
	var before := clock
	clock += real_sec * ((600.0 / 1800.0) if night else (840.0 / 3600.0))
	if clock >= 1440.0:
		clock -= 1440.0
		before -= 1440.0
	if before < DAY_START and clock >= DAY_START:
		_new_day()


func _new_day() -> void:
	day += 1
	fatigue = FATIGUE_MAX
	notify("아침이 밝았어요. %d일째. 피로가 풀렸어요." % day)
	changed.emit()


func is_night() -> bool:
	return clock >= NIGHT_START or clock < DAY_START


## 밤의 어두운 정도 (0 낮 ~ 1 한밤). 19~21시에 어두워지고 5~7시에 밝아진다.
func night_amount() -> float:
	if clock >= 1140.0:
		return clampf((clock - 1140.0) / 120.0, 0.0, 1.0)
	if clock <= 420.0:
		return clampf((420.0 - clock) / 120.0, 0.0, 1.0)
	return 0.0


func clock_text() -> String:
	return "%s %02d:%02d" % ["밤" if is_night() else "낮", int(clock / 60.0) % 24, int(clock) % 60 / 10 * 10]


## 내 집에서 잔다: 다음 날 아침 6시로 넘어가고 피로가 풀린다
func sleep() -> void:
	clock = DAY_START
	_new_day()
	save_game()


## 쓰러졌다: 연필심의 10%를 잃고, 내 마을이 열려 있으면 내 마을로 돌아간다.
## 돌려주는 것: 내 마을로 옮겨 갔으면 true (false 면 그 맵의 입구에서 다시 시작)
func on_player_death() -> bool:
	var lost := pencil_lead / 10
	pencil_lead -= lost
	notify("쓰러졌다…  연필심 %d개를 잃었어요." % lost if lost > 0 else "쓰러졌다…")
	changed.emit()
	if visited.has("home") and current_map != "home":
		var keep := fatigue
		var moved := goto_map("home", "from_death")
		fatigue = keep
		return moved
	return false


func _process(delta: float) -> void:
	# 대화, 창, 컷신 중에는 시간이 흐르지 않는다
	if not get_tree().paused and is_instance_valid(player_ref):
		advance_clock(delta)


# ---------- 내 마을 짓기 ----------

func can_afford(cost: Dictionary) -> bool:
	return coins >= int(cost.get("coins", 0)) and pencil_lead >= int(cost.get("lead", 0))


func pay(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	coins -= int(cost.get("coins", 0))
	pencil_lead -= int(cost.get("lead", 0))
	changed.emit()
	return true


static func cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	if int(cost.get("lead", 0)) > 0:
		parts.append("연필심 %d" % int(cost["lead"]))
	if int(cost.get("coins", 0)) > 0:
		parts.append("동전 %d" % int(cost["coins"]))
	return ", ".join(parts) if not parts.is_empty() else "공짜"


func home_size() -> Vector2:
	var g: Vector2i = Data.HOME_GRID.get(home_sheets, Vector2i(2, 2))
	return Vector2(g.x * 640.0, g.y * 360.0)


## 다음 넓히기 값. 다 넓혔으면 빈 Dictionary. (5번째 장: 연필심 50 + 동전 500, 한 번마다 1.5배)
func home_expand_cost() -> Dictionary:
	var step := Data.HOME_STEPS.find(home_sheets)
	if step < 0 or step >= Data.HOME_STEPS.size() - 1:
		return {}
	var k := pow(1.5, step)
	return {"lead": roundi(50 * k), "coins": roundi(500 * k)}


func expand_home() -> bool:
	var cost := home_expand_cost()
	if cost.is_empty() or not pay(cost):
		return false
	home_sheets = int(Data.HOME_STEPS[Data.HOME_STEPS.find(home_sheets) + 1])
	changed.emit()
	return true


# ---------- 스킬 ----------

func skill_rank(id: String) -> int:
	return int(skill_ranks.get(id, 0))


## 스킬 포인트 1점으로 스킬을 배우거나 한 단계 올린다
func learn_skill(id: String) -> bool:
	if not Items.SKILLS.has(id) or skill_points <= 0:
		return false
	var info: Dictionary = Items.SKILLS[id]
	if level < int(info["level"]) or skill_rank(id) >= int(info["max"]):
		return false
	skill_points -= 1
	skill_ranks[id] = skill_rank(id) + 1
	# 처음 배운 쓰는 스킬은 빈 칸에 자동으로 넣는다
	if str(info["kind"]) == "active" and not skill_slots.has(id):
		var empty := skill_slots.find("")
		if empty >= 0:
			skill_slots[empty] = id
	changed.emit()
	return true


func set_skill_slot(slot: int, id: String) -> void:
	if slot < 0 or slot >= skill_slots.size():
		return
	if id != "" and (skill_rank(id) <= 0 or str(Items.SKILLS[id]["kind"]) != "active"):
		return
	for i in skill_slots.size():
		if skill_slots[i] == id:
			skill_slots[i] = ""
	skill_slots[slot] = id
	changed.emit()


## 피해 = (공격력 × 스킬 배율 − 방어) × 치명타(1.5배), 최소 1.  [피해, 치명타 여부] 를 돌려준다
func roll_damage(skill_mult: float = 1.0, target_defense: int = 0) -> Array:
	var crit := randf() < crit_chance()
	var dmg := attack_power() * skill_mult - target_defense
	if crit:
		dmg *= crit_mult()
	return [maxi(1, roundi(dmg)), crit]


func add_material(id: int, amount: int = 1) -> void:
	materials[id] = int(materials.get(id, 0)) + amount
	changed.emit()


func material_count(id: int) -> int:
	return int(materials.get(id, 0))


func set_menu_open(on: bool) -> void:
	menu_open = on
	_update_pause()
	changed.emit()


func notify(text: String) -> void:
	message.emit(text)


# ---------- 대화 / 연필 모드 / 컷신 (게임 일시정지) ----------

## portrait: "player", "haru_smile", "haru_surprised" 또는 "" (초상화 없음)
func start_dialogue(speaker: String, lines: Array, portrait: String = "") -> void:
	dialogue_open = true
	_update_pause()
	dialogue_requested.emit(speaker, lines, portrait)


func end_dialogue() -> void:
	dialogue_open = false
	_update_pause()
	dialogue_finished.emit()


## 대화를 띄우고 끝날 때까지 기다린다:  await GameState.say("하루", ["안녕!"], "haru_smile")
func say(speaker: String, lines: Array, portrait: String = "") -> void:
	start_dialogue(speaker, lines, portrait)
	await dialogue_finished


func set_draw_mode(on: bool) -> void:
	draw_mode = on
	_update_pause()
	changed.emit()


func set_cutscene(on: bool) -> void:
	cutscene = on
	_update_pause()
	changed.emit()


func _update_pause() -> void:
	get_tree().paused = dialogue_open or draw_mode or cutscene or menu_open


# ---------- 저장 / 불러오기 ----------

func save_game() -> bool:
	var data := {
		"quest": quest,
		"pencil_lead": pencil_lead,
		"bridge_built": bridge_built,
		"intro_seen": intro_seen,
		"level": level,
		"exp": exp,
		"materials": _materials_for_save(),
		"stats": stats,
		"stat_points": stat_points,
		"coins": coins,
		"dust": dust,
		"inventory": inventory,
		"equipped": equipped,
		"consumables": consumables,
		"skill_points": skill_points,
		"skill_ranks": skill_ranks,
		"skill_slots": skill_slots,
		"bag_size": bag_size,
		"friends": friends,
		"companion": companion,
		"clock": clock,
		"day": day,
		"fatigue": fatigue,
		"home_sheets": home_sheets,
		"home_objects": home_objects,
		"custom_icons": custom_icons,
		"current_map": current_map,
		"visited": visited,
		"home_cells": home_cells,
		"home_doodles": home_doodles,
		"home_intro_seen": home_intro_seen,
	}
	if is_instance_valid(player_ref):
		data["player_x"] = player_ref.global_position.x
		data["player_y"] = player_ref.global_position.y
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("저장 실패: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(data))
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return false
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	quest = clampi(int(data.get("quest", Quest.NOT_STARTED)), 0, Quest.CLEARED)
	pencil_lead = int(data.get("pencil_lead", 0))
	bridge_built = bool(data.get("bridge_built", false))
	intro_seen = bool(data.get("intro_seen", false))
	level = clampi(int(data.get("level", 1)), 1, MAX_LEVEL)
	exp = maxi(0, int(data.get("exp", 0)))
	stat_points = maxi(0, int(data.get("stat_points", 0)))
	var st: Variant = data.get("stats", {})
	for k in STAT_KEYS:
		stats[k] = maxi(0, int(st.get(k, 0))) if typeof(st) == TYPE_DICTIONARY else 0
	coins = maxi(0, int(data.get("coins", 0)))
	dust = maxi(0, int(data.get("dust", 0)))
	skill_points = maxi(0, int(data.get("skill_points", 0)))
	if typeof(data.get("inventory")) == TYPE_ARRAY:
		inventory = data["inventory"]
	if typeof(data.get("equipped")) == TYPE_DICTIONARY:
		equipped = data["equipped"]
	if typeof(data.get("consumables")) == TYPE_DICTIONARY:
		consumables = data["consumables"]
	if typeof(data.get("skill_ranks")) == TYPE_DICTIONARY:
		skill_ranks = data["skill_ranks"]
	bag_size = clampi(int(data.get("bag_size", INVENTORY_SIZE)), INVENTORY_SIZE, BAG_MAX)
	friends = []
	if typeof(data.get("friends")) == TYPE_ARRAY:
		for fr in data["friends"]:
			if typeof(fr) == TYPE_DICTIONARY and Data.FRIENDS.has(str(fr.get("sp", ""))):
				friends.append({"sp": str(fr["sp"]), "lv": int(fr.get("lv", 1)), "exp": int(fr.get("exp", 0)), "stars": int(fr.get("stars", 0))})
	companion = clampi(int(data.get("companion", -1)), -1, friends.size() - 1)
	clock = clampf(float(data.get("clock", 480.0)), 0.0, 1439.0)
	day = maxi(1, int(data.get("day", 1)))
	fatigue = clampi(int(data.get("fatigue", FATIGUE_MAX)), 0, FATIGUE_MAX)
	home_sheets = int(data.get("home_sheets", 4))
	if not Data.HOME_GRID.has(home_sheets):
		home_sheets = 4
	home_objects = []
	if typeof(data.get("home_objects")) == TYPE_ARRAY:
		for o in data["home_objects"]:
			if typeof(o) == TYPE_DICTIONARY and Data.BUILDS.has(str(o.get("id", ""))):
				home_objects.append({"id": str(o["id"]), "x": float(o.get("x", 0)), "y": float(o.get("y", 0)), "fine": bool(o.get("fine", false))})
	if typeof(data.get("custom_icons")) == TYPE_DICTIONARY:
		custom_icons = data["custom_icons"]
	var slots: Variant = data.get("skill_slots", [])
	if typeof(slots) == TYPE_ARRAY and (slots as Array).size() == 3:
		skill_slots = slots
	materials = {}
	var mats: Variant = data.get("materials", {})
	if typeof(mats) == TYPE_DICTIONARY:
		for k in mats:
			materials[int(str(k))] = int(mats[k])
	current_map = str(data.get("current_map", "ch1"))
	if not MAP_SCENES.has(current_map):
		current_map = "ch1"
	var seen: Variant = data.get("visited", [])
	visited = seen if typeof(seen) == TYPE_ARRAY else []
	for m in ["ch1", current_map]:
		if not visited.has(m):
			visited.append(m)
	home_cells = str(data.get("home_cells", ""))
	var doodles: Variant = data.get("home_doodles", [])
	home_doodles = doodles if typeof(doodles) == TYPE_ARRAY else []
	home_intro_seen = bool(data.get("home_intro_seen", false))
	has_saved_position = data.has("player_x") and data.has("player_y")
	if has_saved_position:
		saved_position = Vector2(float(data["player_x"]), float(data["player_y"]))
	return true


func _materials_for_save() -> Dictionary:
	var out := {}
	for k in materials:
		out[str(k)] = materials[k]
	return out


func reset_game() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	quest = Quest.NOT_STARTED
	pencil_lead = 0
	bridge_built = false
	intro_seen = false
	level = 1
	exp = 0
	materials = {}
	stat_points = 0
	for k in STAT_KEYS:
		stats[k] = 0
	coins = 0
	dust = 0
	skill_points = 0
	skill_ranks = {}
	skill_slots = ["", "", ""]
	bag_size = INVENTORY_SIZE
	custom_icons = {}
	friends = []
	companion = -1
	clock = 480.0
	day = 1
	fatigue = FATIGUE_MAX
	home_sheets = 4
	home_objects = []
	_starting_gear()
	menu_open = false
	has_saved_position = false
	dialogue_open = false
	draw_mode = false
	cutscene = false
	home_cells = ""
	home_doodles = []
	home_intro_seen = false
	visited = ["ch1"]
	spawn_tag = ""
	_update_pause()
	var scene := get_tree().current_scene
	if scene != null and scene.is_in_group("game_map") and current_map != "ch1":
		current_map = "ch1"
		get_tree().change_scene_to_file.call_deferred(map_scene())
	else:
		current_map = "ch1"
		get_tree().reload_current_scene()
