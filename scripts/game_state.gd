extends Node
## 전역 게임 상태 (Autoload: GameState)
## 퀘스트 진행도, 재료, 저장/불러오기, 일시정지(대화·연필 모드·컷신)를 관리한다.

signal changed
signal message(text: String)
signal dialogue_requested(speaker: String, lines: Array, portrait: String)
signal dialogue_finished

const SAVE_PATH := "user://save.json"
const BRIDGE_COST := 3

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
var has_saved_position: bool = false
var saved_position: Vector2 = Vector2.ZERO

var player_ref: Node2D = null
var dialogue_open: bool = false
var draw_mode: bool = false
var cutscene: bool = false


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
	get_tree().paused = dialogue_open or draw_mode or cutscene


# ---------- 저장 / 불러오기 ----------

func save_game() -> bool:
	var data := {
		"quest": quest,
		"pencil_lead": pencil_lead,
		"bridge_built": bridge_built,
		"intro_seen": intro_seen,
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
	has_saved_position = data.has("player_x") and data.has("player_y")
	if has_saved_position:
		saved_position = Vector2(float(data["player_x"]), float(data["player_y"]))
	return true


func reset_game() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	quest = Quest.NOT_STARTED
	pencil_lead = 0
	bridge_built = false
	intro_seen = false
	has_saved_position = false
	dialogue_open = false
	draw_mode = false
	cutscene = false
	_update_pause()
	get_tree().reload_current_scene()
