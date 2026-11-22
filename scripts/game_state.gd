extends Node
## 전역 게임 상태 (Autoload: GameState)
## 퀘스트 진행도, 재료, 저장/불러오기, 일시정지(대화·연필 모드·컷신)를 관리한다.

signal changed
signal message(text: String)
signal dialogue_requested(speaker: String, lines: Array, portrait: String)
signal dialogue_finished
signal leveled_up(level: int)

const Items := preload("res://scripts/items.gd")

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
const INVENTORY_SIZE := 24
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
	if inventory.size() >= INVENTORY_SIZE:
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
	if not equipped.has(slot) or inventory.size() >= INVENTORY_SIZE:
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
	if coins < int(arr[3]) or inventory.size() >= INVENTORY_SIZE:
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
	return typeof(recipe[1]) == TYPE_STRING or inventory.size() < INVENTORY_SIZE


func craft(recipe: Array) -> bool:
	if not can_craft(recipe):
		return false
	var mats: Dictionary = recipe[2]
	for id in mats:
		materials[int(id)] = material_count(int(id)) - int(mats[id])
	pencil_lead -= int(recipe[3])
	if typeof(recipe[1]) == TYPE_STRING:
		add_consumable(str(recipe[1]))
	else:
		var r: Array = recipe[1]
		add_item(Items.make(str(r[0]), int(r[1]), int(r[2]), maxi(1, level)))
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
