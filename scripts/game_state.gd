extends Node
## 전역 게임 상태 (Autoload: GameState)
## 퀘스트 진행도, 재료, 저장/불러오기, 일시정지(대화·연필 모드·컷신)를 관리한다.

signal changed
signal message(text: String)
signal dialogue_requested(speaker: String, lines: Array, portrait: String)
signal dialogue_finished
signal leveled_up(level: int)

const SAVE_PATH := "user://save.json"
const BRIDGE_COST := 3
const MAX_LEVEL := 20
## 맵 이름 → 장면. "home" 은 내 마을, "ch1" 은 1장 공책 마을.
const MAP_SCENES := {
	"ch1": "res://scenes/main.tscn",
	"home": "res://scenes/home.tscn",
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
var current_map: String = "ch1"
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

## 다음 레벨까지 필요한 경험치
func exp_needed(lv: int = -1) -> int:
	if lv < 0:
		lv = level
	return 8 + 6 * (lv - 1)


func add_exp(amount: int) -> void:
	if level >= MAX_LEVEL:
		return
	exp += amount
	while level < MAX_LEVEL and exp >= exp_needed():
		exp -= exp_needed()
		level += 1
		leveled_up.emit(level)
		notify("레벨 업!  필력 %d" % level)
	if level >= MAX_LEVEL:
		exp = 0
	changed.emit()


## 레벨에 따른 최대 HP 와 공격력 (능력치 배분은 아직 없음)
func max_hp() -> int:
	return 5 + (level - 1) / 2


func attack_power() -> int:
	return 1 + (level - 1) / 3


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
		"current_map": current_map,
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
	materials = {}
	var mats: Variant = data.get("materials", {})
	if typeof(mats) == TYPE_DICTIONARY:
		for k in mats:
			materials[int(str(k))] = int(mats[k])
	current_map = str(data.get("current_map", "ch1"))
	if not MAP_SCENES.has(current_map):
		current_map = "ch1"
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
	menu_open = false
	has_saved_position = false
	dialogue_open = false
	draw_mode = false
	cutscene = false
	home_cells = ""
	home_doodles = []
	home_intro_seen = false
	spawn_tag = ""
	_update_pause()
	var scene := get_tree().current_scene
	if scene != null and scene.is_in_group("game_map") and current_map != "ch1":
		current_map = "ch1"
		get_tree().change_scene_to_file.call_deferred(map_scene())
	else:
		current_map = "ch1"
		get_tree().reload_current_scene()
