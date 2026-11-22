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
	"ch1_bossroom": "res://scenes/field.tscn",
	"home_room": "res://scenes/room.tscn",
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
var storage: Array = []           # 창고 속 장비
const STORAGE_SIZE := 60
var board_day: int = 0            # 게시판 부탁을 뽑은 날
var board_quests: Array = []      # {"sp", "need", "have", "claimed"}
var gift_days: Dictionary = {}    # 주민 집(자리) → 마지막으로 선물을 받은 날
var tips_seen: Dictionary = {}    # 한 번씩만 띄우는 설명 (id → true)
var settings: Dictionary = {"master": 0.8, "music": 0.6, "sfx": 0.8, "fullscreen": false, "last_slot": 0}
var slot: int = 0                 # 지금 캐릭터 칸 (1 ~ 8). 0 은 칸 없이 save_path 한 파일만 쓴다 (테스트)
const SLOT_COUNT := 8
var save_dir: String = "user://"   # 캐릭터 칸, 공유 자료, 설정 파일이 놓이는 곳 (테스트에서 바꿔 쓴다)
const TITLE_SCENE := "res://scenes/title.tscn"
## 모든 캐릭터가 같이 쓰는 것 (내 마을, 창고, 밭, 가구, 주민). 캐릭터 칸으로 할 때는 shared.json 에 따로 저장한다.
const SHARED_KEYS := ["home_cells", "home_doodles", "home_intro_seen", "home_sheets", "home_objects", "storage",
	"farms", "furniture", "room_items", "villagers", "gift_days", "balloons"]
var buffs: Dictionary = {}        # 요리 효과 (종류 → 남은 초)
var farms: Dictionary = {}        # 밭(자리) → 칸 6개 {"seed", "grown", "watered"}
var foraged: Dictionary = {"day": 0, "taken": []}   # 오늘 채집한 자리
var furniture: Dictionary = {}    # 가진 가구 (id → 개수, 방에 놓은 것은 빼고)
var room_items: Array = []        # 내 집 안에 놓은 가구 {"id", "x", "y"}
var villagers: Dictionary = {}    # 주민 (id → {"q", "name", "house", "aff", "talk_day", "gift_day", "progress", "q_day", "told"})
var balloons: Array = []          # 잡은 풍선이 있던 화면
var difficulty: int = 0           # 사냥터 난이도 단계 (0 흐릿한 ~ 3 빈)
var max_difficulty: int = 0       # 고를 수 있는 가장 높은 단계 (대장을 잡으면 다음 단계가 열린다)
var field_boss: Dictionary = {"day": 0, "map": "", "dead": false}
var bosses_beaten: Dictionary = {}   # 물리친 보스 (종류 → 횟수)
var quick_slots: Array = ["bandage", "milk"]   # 1, 2 번 키에 넣은 소모품
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
	load_settings()
	_migrate_old_save()
	_starting_gear()
	load_game()


# ---------- 설정 ----------

func load_settings() -> void:
	if not FileAccess.file_exists(settings_path()):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(settings_path()))
	if typeof(d) != TYPE_DICTIONARY:
		return
	for k in ["master", "music", "sfx"]:
		settings[k] = clampf(float(d.get(k, settings.get(k, 0.8))), 0.0, 1.0)
	settings["fullscreen"] = bool(d.get("fullscreen", false))
	settings["last_slot"] = clampi(int(d.get("last_slot", 0)), 0, SLOT_COUNT)


func save_settings() -> void:
	var f := FileAccess.open(settings_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))


## 설정을 바꾸고 바로 적용한다. write 를 끄면 파일에는 쓰지 않는다 (테스트).
func set_setting(key: String, value: Variant, write: bool = true) -> void:
	if typeof(value) == TYPE_FLOAT:
		value = snappedf(clampf(float(value), 0.0, 1.0), 0.01)
	settings[key] = value
	Sound.apply_settings()
	if write:
		save_settings()
	changed.emit()


# ---------- 캐릭터 칸 ----------

func slot_path(n: int) -> String:
	return save_dir + "slot_%d.json" % n


func shared_path() -> String:
	return save_dir + "shared.json"


func settings_path() -> String:
	return save_dir + "settings.json"


## 예전의 저장 파일 하나(save.json)를 1번 칸으로 옮긴다
func _migrate_old_save() -> void:
	if FileAccess.file_exists(SAVE_PATH) and not FileAccess.file_exists(slot_path(1)):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(slot_path(1)))


## 칸의 요약 (시작 화면에 보여 준다). 비어 있으면 빈 Dictionary.
func slot_info(n: int) -> Dictionary:
	if n < 1 or n > SLOT_COUNT or not FileAccess.file_exists(slot_path(n)):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(slot_path(n)))
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	return {"level": int(d.get("level", 1)), "day": int(d.get("day", 1)),
		"map": str(Data.MAP_NAMES.get(str(d.get("current_map", "ch1")), "공책 마을")), "job": str(d.get("job", "pencil"))}


## 그 칸의 캐릭터로 게임을 시작한다. 빈 칸이면 새 캐릭터 (프롤로그부터). 마을과 창고는 이어받는다.
func start_slot(n: int) -> void:
	if n < 1 or n > SLOT_COUNT:
		return
	slot = n
	save_path = slot_path(n)
	_reset_state()
	load_game()
	settings["last_slot"] = n
	save_settings()
	save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file(map_scene())


func delete_slot(n: int) -> void:
	if FileAccess.file_exists(slot_path(n)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(n)))
	if int(settings.get("last_slot", 0)) == n:
		settings["last_slot"] = 0
		save_settings()
	changed.emit()


## 저장하고 시작 화면으로 돌아간다
func to_title() -> void:
	save_game()
	player_ref = null
	dialogue_open = false
	draw_mode = false
	cutscene = false
	menu_open = false
	_update_pause()
	get_tree().change_scene_to_file(TITLE_SCENE)


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
		var tired := int(Data.FIELDS[map].get("fatigue", FATIGUE_PER_FIELD))
		if fatigue < tired:
			notify("너무 피곤해서 더 갈 수 없어요. 내 집에서 자거나 아침을 기다려요. (피로도 %d 필요)" % tired)
			return false
		fatigue -= tired
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
	if has_buff("exp"):
		amount = ceili(amount * 1.1)
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
		Sound.play("levelup")
		notify("레벨 업!  필력 %d" % level)
		tip("skillpoint", "스킬 포인트가 생겼어요. K 를 눌러 스킬을 배워 보세요.")
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
	return roundi(base * (1.0 + 0.03 * skill_rank("sharpen")) * (1.1 if has_buff("atk") else 1.0))


func defense() -> int:
	return ceili((stat("grit") + gear("def")) * (1.1 if has_buff("def") else 1.0))


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
## 문방구 값. 내 마을에 정성 문방구가 있으면 10% 싸다.
func price_of(entry: Variant) -> int:
	var base := int(Items.CONSUMABLES[entry][2]) if typeof(entry) == TYPE_STRING else int((entry as Array)[3])
	return maxi(1, roundi(base * 0.9)) if has_fine("bld_shop") else base


func buy(entry: Variant) -> bool:
	var cost := price_of(entry)
	if typeof(entry) == TYPE_STRING:
		if coins < cost:
			return false
		coins -= cost
		add_consumable(str(entry))
		return true
	var arr: Array = entry
	if coins < cost or inventory.size() >= bag_size:
		return false
	coins -= cost
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
	tip("friend", "친구는 옆에서 같이 싸워요. P: 친구 창, G: 친구 스킬")
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
	if not night and is_night():
		tip("night", "밤이 됐어요. 밤에는 몬스터가 더 세지고 큰 물고기가 잘 잡혀요.")


func _new_day() -> void:
	day += 1
	fatigue = FATIGUE_MAX
	_grow_farms()
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


## 내 집에서 잔다: 다음 날 아침 6시로 넘어가고 피로가 풀린다. 정성 집이면 피로도가 10 더 찬다.
func sleep() -> void:
	clock = DAY_START
	_new_day()
	if has_fine("bld_house"):
		fatigue = FATIGUE_MAX + 10
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
		for k in buffs.keys():
			buffs[k] = float(buffs[k]) - delta
			if float(buffs[k]) <= 0.0:
				buffs.erase(k)
				notify("%s 효과가 끝났어요." % Items.BUFF_NAMES[k])


# ---------- 내 마을의 건물 기능 ----------

func has_built(id: String) -> bool:
	for o in home_objects:
		if str(o["id"]) == id:
			return true
	return false


## 정성으로 지은 건물이 있는지. 정성 건물은 기능이 조금 좋다:
##  내 집: 자고 나면 피로도 110 / 문방구: 값 10% 할인 / 조합대: 그려 만들 때 비슷한 정도 +10%
##  창고: 72칸 / 게시판: 보상 +20% / 낚시터: 입질 받는 시간 1초 / 주민 집: 선물 2배
func has_fine(id: String) -> bool:
	for o in home_objects:
		if str(o["id"]) == id and bool(o.get("fine", false)):
			return true
	return false


func storage_size() -> int:
	return STORAGE_SIZE + (12 if has_fine("bld_storage") else 0)


func store_item(i: int) -> bool:
	if i < 0 or i >= inventory.size() or storage.size() >= storage_size():
		return false
	storage.append(inventory[i])
	inventory.remove_at(i)
	changed.emit()
	return true


func take_item(i: int) -> bool:
	if i < 0 or i >= storage.size() or inventory.size() >= bag_size:
		return false
	inventory.append(storage[i])
	storage.remove_at(i)
	changed.emit()
	return true


## 게시판: 날이 바뀌었으면 새 부탁 3개를 뽑는다 (몬스터 종 하나를 3~6마리)
func board_refresh() -> void:
	if board_day == day and board_quests.size() == 3:
		return
	board_day = day
	board_quests = []
	var kinds := ["slime", "squiggle", "dots", "grass", "spider", "bug"]
	kinds.shuffle()
	for i in 3:
		board_quests.append({"sp": kinds[i], "need": 3 + randi() % 4, "have": 0, "claimed": false})
	changed.emit()


func board_reward(q: Dictionary, what: String) -> int:
	var base := int(q["need"]) * (12 if what == "coins" else 6)
	return roundi(base * 1.2) if has_fine("bld_board") else base


## 몬스터를 물리칠 때마다 부른다
func on_kill(kind: String) -> void:
	var sp := Data.species_of(kind)
	for q in board_quests:
		if board_day == day and str(q["sp"]) == sp and not bool(q["claimed"]):
			q["have"] = int(q["have"]) + 1
			changed.emit()


func board_claim(i: int) -> bool:
	if i < 0 or i >= board_quests.size():
		return false
	var q: Dictionary = board_quests[i]
	if bool(q["claimed"]) or int(q["have"]) < int(q["need"]):
		return false
	q["claimed"] = true
	coins += board_reward(q, "coins")
	add_exp(board_reward(q, "exp"))
	changed.emit()
	return true


## 낚시: 그 낚시터(place: "home", "ch1")의 물고기 하나를 가방에 넣고 id 를 돌려준다.
##  낮과 밤에 낚이는 것이 다르고, 12% 로 드문 것(쪽지, 장화, 종이학)이 올라온다.
func catch_fish(place: String = "home") -> String:
	var t: Array = Items.FISH.get(place, Items.FISH["home"])
	var night := is_night()
	var pool: Array = t[3 if night else 2] if randf() < 0.12 else t[1 if night else 0]
	var id := str(pool[randi() % pool.size()])
	add_consumable(id)
	return id


# ---------- 요리 효과 ----------

func has_buff(kind: String) -> bool:
	return float(buffs.get(kind, 0.0)) > 0.0


func add_buff(kind: String, seconds: float) -> void:
	buffs[kind] = maxf(float(buffs.get(kind, 0.0)), seconds)
	changed.emit()


func drop_mult() -> float:
	return 1.1 if has_buff("drop") else 1.0


## 식당에서 요리한다. 정성 식당은 25% 로 하나를 더 만든다.
func can_cook(dish: String) -> bool:
	if not Items.DISHES.has(dish):
		return false
	var need: Dictionary = Items.DISHES[dish]
	for id in need:
		if consumable_count(str(id)) < int(need[id]):
			return false
	return true


func cook(dish: String) -> bool:
	if not can_cook(dish):
		return false
	var need: Dictionary = Items.DISHES[dish]
	for id in need:
		consumables[str(id)] = consumable_count(str(id)) - int(need[id])
	add_consumable(dish, 2 if has_fine("bld_diner") and randf() < 0.25 else 1)
	return true


## 먹거리를 문방구에 판다 (값의 절반)
func sell_goods(id: String) -> int:
	if consumable_count(id) <= 0:
		return 0
	var got := maxi(1, int(Items.CONSUMABLES[id][2]) / 2)
	consumables[id] = consumable_count(id) - 1
	coins += got
	changed.emit()
	return got


# ---------- 농사 ----------

## 밭 하나의 칸들 (없으면 빈 칸 6개를 만든다)
func farm_plots(key: String) -> Array:
	if not farms.has(key):
		var plots: Array = []
		for i in Items.FARM_PLOTS:
			plots.append({"seed": "", "grown": 0, "watered": false})
		farms[key] = plots
	return farms[key]


func plant(key: String, i: int, seed: String) -> bool:
	var plots := farm_plots(key)
	if i < 0 or i >= plots.size() or str(plots[i]["seed"]) != "" or not Items.CROPS.has(seed) or consumable_count(seed) <= 0:
		return false
	consumables[seed] = consumable_count(seed) - 1
	plots[i] = {"seed": seed, "grown": 0, "watered": false}
	changed.emit()
	return true


## 심은 칸 전부에 물을 준다. 돌려주는 것: 물을 준 칸 수
func water(key: String) -> int:
	var n := 0
	for p in farm_plots(key):
		if str(p["seed"]) != "" and not bool(p["watered"]) and not plot_ripe(p):
			p["watered"] = true
			n += 1
	if n > 0:
		changed.emit()
	return n


func plot_ripe(p: Dictionary) -> bool:
	return str(p["seed"]) != "" and int(p["grown"]) >= int(Items.CROPS[str(p["seed"])][1])


## 다 자란 칸을 거둔다. 정성 밭은 하나를 더 준다. 돌려주는 것: 거둔 것의 id ("" 은 못 거둠)
func harvest(key: String, i: int) -> String:
	var plots := farm_plots(key)
	if i < 0 or i >= plots.size() or not plot_ripe(plots[i]):
		return ""
	var crop := str(Items.CROPS[str(plots[i]["seed"])][0])
	plots[i] = {"seed": "", "grown": 0, "watered": false}
	add_consumable(crop, 2 if has_fine("bld_farm") else 1)
	return crop


## 날이 바뀌면 물을 준 칸이 하루만큼 자란다
func _grow_farms() -> void:
	for key in farms:
		for p in farms[key]:
			if str(p["seed"]) != "" and bool(p["watered"]):
				p["grown"] = int(p["grown"]) + 1
			p["watered"] = false


# ---------- 채집 ----------

## 사냥터의 채집 자리 (하루에 한 번). 돌려주는 것: 얻은 것의 id ("" 은 오늘 이미 가져감)
func take_forage(key: String) -> String:
	if int(foraged.get("day", 0)) != day:
		foraged = {"day": day, "taken": []}
	if (foraged["taken"] as Array).has(key):
		return ""
	(foraged["taken"] as Array).append(key)
	var id := str(Items.FORAGE[hash(key) % Items.FORAGE.size()])
	add_consumable(id)
	return id


func forage_left(key: String) -> bool:
	return int(foraged.get("day", 0)) != day or not (foraged["taken"] as Array).has(key)


# ---------- 가구 ----------

func furniture_count(id: String) -> int:
	return int(furniture.get(id, 0))


func add_furniture(id: String) -> void:
	furniture[id] = furniture_count(id) + 1
	changed.emit()


func buy_furniture(id: String) -> bool:
	var cost := int(Items.FURNITURE[id][1])
	if cost <= 0 or coins < cost:
		return false
	coins -= cost
	add_furniture(id)
	return true


# ---------- 주민 ----------

## 주민의 상태. q: 0 아직 부탁을 듣지 않음, 1 부탁을 들음, 2 부탁을 들어줌 (집을 기다림), 3 내 마을에 삶
func villager(id: String) -> Dictionary:
	if not villagers.has(id):
		villagers[id] = {"q": 0, "name": "", "house": "", "aff": 0, "talk_day": 0, "gift_day": 0, "progress": 0, "q_day": 0, "told": 0}
	return villagers[id]


func hearts(id: String) -> int:
	var n := 0
	for need in Data.HEART_NEED:
		if int(villager(id)["aff"]) >= int(need):
			n += 1
	return n


func add_aff(id: String, amount: int) -> void:
	var v := villager(id)
	var before := hearts(id)
	v["aff"] = int(v["aff"]) + amount
	if hearts(id) > before:
		notify("%s 와(과) 더 가까워졌어요. (하트 %d개)" % [villager_name(id), hearts(id)])
		if hearts(id) == 2:
			# 하트 2개: 가구 하나를 선물로 받는다
			var ids: Array = Items.FURNITURE.keys()
			var fid := str(ids[(hash(id) + 3) % ids.size()])
			add_furniture(fid)
			notify("%s 을(를) 선물로 받았어요. (가구)" % Items.FURNITURE[fid][0])
	changed.emit()


func villager_name(id: String) -> String:
	var v := villager(id)
	return str(v["name"]) if str(v["name"]) != "" else str(Data.VILLAGERS[id]["title"])


## 비어 있는 주민 집의 자리 ("" 은 없음)
func free_house() -> String:
	for o in home_objects:
		if str(Data.BUILDS[str(o["id"])].get("use", "")) != "villager":
			continue
		var key := house_key(o)
		if resident_of(key) == "":
			return key
	return ""


static func house_key(o: Dictionary) -> String:
	return "%d_%d" % [roundi(float(o["x"])), roundi(float(o["y"]))]


## 그 집에 사는 주민의 id ("" 은 빈 집)
func resident_of(key: String) -> String:
	for id in villagers:
		if int(villagers[id]["q"]) == 3 and str(villagers[id]["house"]) == key:
			return str(id)
	return ""


## 부탁을 들어준 주민이 이사 온다. 빈 집이 있어야 한다.
func move_in(id: String, new_name: String) -> bool:
	var v := villager(id)
	var key := free_house()
	if int(v["q"]) != 2 or key == "":
		return false
	v["q"] = 3
	v["house"] = key
	v["name"] = new_name.strip_edges().left(8) if new_name.strip_edges() != "" else str(Data.VILLAGERS[id]["title"])
	add_aff(id, 5)   # 부탁을 들어준 몫
	save_game()
	return true


## 하루 한 번 말 걸기 (+1). 오늘 처음이면 true.
func villager_talk(id: String) -> bool:
	var v := villager(id)
	if int(v["talk_day"]) == day:
		return false
	v["talk_day"] = day
	add_aff(id, 1)
	return true


## 좋아하는 것을 선물한다 (+3). 하루에 한 번.
func villager_give(id: String) -> bool:
	var v := villager(id)
	var like := str(Data.VILLAGERS[id]["like"])
	if int(v.get("give_day", 0)) == day or consumable_count(like) <= 0:
		return false
	consumables[like] = consumable_count(like) - 1
	v["give_day"] = day
	add_aff(id, 3)
	return true


## 하트 1개부터 하루 한 번 주는 것. 돌려주는 것: 받은 것의 id ("" 은 없음)
func villager_daily(id: String) -> String:
	var v := villager(id)
	if hearts(id) < 1 or int(v["gift_day"]) == day:
		return ""
	v["gift_day"] = day
	var gift := str(Data.VILLAGERS[id]["gift"])
	add_consumable(gift, 2 if _house_fine(str(v["house"])) else 1)
	return gift


func _house_fine(key: String) -> bool:
	for o in home_objects:
		if house_key(o) == key:
			return bool(o.get("fine", false))
	return false


# ---------- 난이도와 보스 ----------

func diff() -> Dictionary:
	return Data.DIFFICULTY[clampi(difficulty, 0, Data.DIFFICULTY.size() - 1)]


func set_difficulty(d: int) -> bool:
	if d < 0 or d > max_difficulty or d >= Data.DIFFICULTY.size():
		return false
	difficulty = d
	changed.emit()
	return true


## 오늘의 필드 보스가 나오는 화면 (날이 바뀌면 다시 뽑는다)
func field_boss_map() -> String:
	if int(field_boss.get("day", 0)) != day:
		field_boss = {"day": day, "map": str(Data.FIELD_BOSS_MAPS[randi() % Data.FIELD_BOSS_MAPS.size()]), "dead": false}
	return "" if bool(field_boss["dead"]) else str(field_boss["map"])


## 보스를 물리쳤다. 대장을 잡으면 다음 난이도 단계가 열린다.
func on_boss_killed(kind: String) -> void:
	bosses_beaten[kind] = int(bosses_beaten.get(kind, 0)) + 1
	var role := str(Data.MONSTERS[kind].get("boss", ""))
	if role == "field":
		field_boss["dead"] = true
		add_consumable("coating")
		notify("필드 보스를 물리쳤어요! 코팅지를 얻었어요.")
	elif role == "boss" and difficulty == max_difficulty and max_difficulty < Data.DIFFICULTY.size() - 1:
		max_difficulty += 1
		notify("대장을 물리쳤어요! \"%s\" 단계가 열렸어요. (내 마을의 문에서 고른다)" % Data.DIFFICULTY[max_difficulty]["name"])
	changed.emit()


## 주민 집의 주민에게 말을 건다. 하루에 한 번 선물을 준다 (재료 하나 또는 동전). 돌려주는 것: 선물 설명 ("" 은 오늘 이미 받음)
func villager_gift(key: String, fine: bool) -> String:
	if int(gift_days.get(key, 0)) == day:
		return ""
	gift_days[key] = day
	var n := 2 if fine else 1
	if randf() < 0.5:
		add_coins(10 * n)
		return "동전 %d개" % (10 * n)
	var mat := randi() % Data.MATERIALS.size()
	materials[mat] = material_count(mat) + n
	changed.emit()
	return "%s %d개" % [Data.MATERIALS[mat], n]


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
	if id == "ult":
		tip("ult", "필살기: 적을 맞히면 게이지가 차요. 가득 차면 V 키!")
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


## 처음 겪을 때 한 번만 띄우는 설명
func tip(id: String, text: String) -> void:
	if tips_seen.has(id):
		return
	tips_seen[id] = true
	notify(text)


## 1, 2 번 키에 소모품을 넣는다
func set_quick_slot(slot: int, id: String) -> void:
	if slot < 0 or slot >= quick_slots.size() or not Items.CONSUMABLES.has(id):
		return
	var other := 1 - slot
	if str(quick_slots[other]) == id:
		quick_slots[other] = quick_slots[slot]
	quick_slots[slot] = id
	changed.emit()


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
		"storage": storage,
		"board_day": board_day,
		"board_quests": board_quests,
		"gift_days": gift_days,
		"tips_seen": tips_seen,
		"buffs": buffs,
		"farms": farms,
		"foraged": foraged,
		"furniture": furniture,
		"room_items": room_items,
		"villagers": villagers,
		"balloons": balloons,
		"difficulty": difficulty,
		"max_difficulty": max_difficulty,
		"field_boss": field_boss,
		"bosses_beaten": bosses_beaten,
		"quick_slots": quick_slots,
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
	data["job"] = "pencil"
	if slot > 0:
		# 같이 쓰는 것은 따로 저장한다
		var shared := {}
		for k in SHARED_KEYS:
			if data.has(k):
				shared[k] = data[k]
				data.erase(k)
		var sf := FileAccess.open(shared_path(), FileAccess.WRITE)
		if sf:
			sf.store_string(JSON.stringify(shared))
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("저장 실패: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(data))
	return true


func load_game() -> bool:
	var data: Variant = {}
	var found := false
	if FileAccess.file_exists(save_path):
		data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		found = typeof(data) == TYPE_DICTIONARY
		if not found:
			data = {}
	if slot > 0 and FileAccess.file_exists(shared_path()):
		# 같이 쓰는 것 (새 캐릭터도 마을과 창고는 이어받는다)
		var shared: Variant = JSON.parse_string(FileAccess.get_file_as_string(shared_path()))
		if typeof(shared) == TYPE_DICTIONARY:
			for k in shared:
				data[k] = shared[k]
			found = true
	if not found:
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
	fatigue = clampi(int(data.get("fatigue", FATIGUE_MAX)), 0, FATIGUE_MAX + 10)
	storage = data["storage"] if typeof(data.get("storage")) == TYPE_ARRAY else []
	board_day = int(data.get("board_day", 0))
	board_quests = []
	if typeof(data.get("board_quests")) == TYPE_ARRAY:
		for bq in data["board_quests"]:
			if typeof(bq) == TYPE_DICTIONARY and Data.FRIENDS.has(str(bq.get("sp", ""))):
				board_quests.append({"sp": str(bq["sp"]), "need": int(bq.get("need", 3)), "have": int(bq.get("have", 0)), "claimed": bool(bq.get("claimed", false))})
	gift_days = data["gift_days"] if typeof(data.get("gift_days")) == TYPE_DICTIONARY else {}
	tips_seen = data["tips_seen"] if typeof(data.get("tips_seen")) == TYPE_DICTIONARY else {}
	buffs = {}
	if typeof(data.get("buffs")) == TYPE_DICTIONARY:
		for bk in data["buffs"]:
			if Items.BUFF_NAMES.has(str(bk)):
				buffs[str(bk)] = float(data["buffs"][bk])
	farms = {}
	if typeof(data.get("farms")) == TYPE_DICTIONARY:
		for fk in data["farms"]:
			var plots: Array = []
			for pl in data["farms"][fk]:
				var sd := str(pl.get("seed", ""))
				plots.append({"seed": sd if Items.CROPS.has(sd) else "", "grown": int(pl.get("grown", 0)), "watered": bool(pl.get("watered", false))})
			if plots.size() == Items.FARM_PLOTS:
				farms[str(fk)] = plots
	var fg: Variant = data.get("foraged")
	foraged = {"day": int(fg.get("day", 0)), "taken": fg.get("taken", [])} if typeof(fg) == TYPE_DICTIONARY and typeof(fg.get("taken")) == TYPE_ARRAY else {"day": 0, "taken": []}
	furniture = {}
	if typeof(data.get("furniture")) == TYPE_DICTIONARY:
		for uk in data["furniture"]:
			if Items.FURNITURE.has(str(uk)):
				furniture[str(uk)] = int(data["furniture"][uk])
	room_items = []
	if typeof(data.get("room_items")) == TYPE_ARRAY:
		for ri in data["room_items"]:
			if typeof(ri) == TYPE_DICTIONARY and Items.FURNITURE.has(str(ri.get("id", ""))):
				room_items.append({"id": str(ri["id"]), "x": float(ri.get("x", 0)), "y": float(ri.get("y", 0))})
	villagers = {}
	if typeof(data.get("villagers")) == TYPE_DICTIONARY:
		for vk in data["villagers"]:
			if Data.VILLAGERS.has(str(vk)) and typeof(data["villagers"][vk]) == TYPE_DICTIONARY:
				var src: Dictionary = data["villagers"][vk]
				var v := villager(str(vk))
				for field in v.keys():
					if src.has(field):
						v[field] = str(src[field]) if typeof(v[field]) == TYPE_STRING else int(src[field])
				if src.has("give_day"):
					v["give_day"] = int(src["give_day"])
	balloons = data["balloons"] if typeof(data.get("balloons")) == TYPE_ARRAY else []
	max_difficulty = clampi(int(data.get("max_difficulty", 0)), 0, Data.DIFFICULTY.size() - 1)
	difficulty = clampi(int(data.get("difficulty", 0)), 0, max_difficulty)
	var fb: Variant = data.get("field_boss")
	field_boss = {"day": int(fb.get("day", 0)), "map": str(fb.get("map", "")), "dead": bool(fb.get("dead", false))} if typeof(fb) == TYPE_DICTIONARY else {"day": 0, "map": "", "dead": false}
	bosses_beaten = data["bosses_beaten"] if typeof(data.get("bosses_beaten")) == TYPE_DICTIONARY else {}
	var qs: Variant = data.get("quick_slots", [])
	if typeof(qs) == TYPE_ARRAY and (qs as Array).size() == 2 and Items.CONSUMABLES.has(str(qs[0])) and Items.CONSUMABLES.has(str(qs[1])):
		quick_slots = [str(qs[0]), str(qs[1])]
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


## 모든 값을 새 게임 상태로 돌린다 (파일은 건드리지 않는다)
func _reset_state() -> void:
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
	storage = []
	board_day = 0
	board_quests = []
	gift_days = {}
	tips_seen = {}
	quick_slots = ["bandage", "milk"]
	buffs = {}
	farms = {}
	foraged = {"day": 0, "taken": []}
	furniture = {}
	room_items = []
	villagers = {}
	balloons = []
	difficulty = 0
	max_difficulty = 0
	field_boss = {"day": 0, "map": "", "dead": false}
	bosses_beaten = {}
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


func reset_game() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	_reset_state()
	var scene := get_tree().current_scene
	if scene != null and scene.is_in_group("game_map") and current_map != "ch1":
		current_map = "ch1"
		get_tree().change_scene_to_file.call_deferred(map_scene())
	else:
		current_map = "ch1"
		get_tree().reload_current_scene()
