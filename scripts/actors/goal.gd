extends Node2D
## 강 건너편 빨간 문(다음 페이지로 가는 문).
## 문 그림은 배경에 있고, 그 위를 지우개 자국(smudge)이 덮고 있다.
## 연필 모드의 지우개로 자국을 문지르면(wipe) 닦이고, 다 닦으면 열린 문 그림으로 바뀐다.
## 이야기 진행(대사, 괴물 등장, 페이지 넘김)은 tutorial.gd 가 이 신호들을 받아 처리한다.

signal found_smudged   ## 다리를 건너 처음 문 앞에 왔다 (자국 발견)
signal cleaned         ## 자국을 다 닦았다
signal entered         ## 열린 문으로 들어갔다

const Art := preload("res://scripts/core/art.gd")
const DOOR_CENTER := Vector2(0, -28)   # 문 가운데 (이 노드는 문 바로 아래 발치에 놓인다)
const DOOR_FOOT := Vector2(-3, -5)
const REACH := 22.0
const WIPE_RADIUS := 34.0
const WIPE_PER_RUB := 0.022            # 문지르기 한 번에 닦이는 양 (약 45번 문지르면 끝)

var wipe_progress := 0.0
var _inside := false
var _smudge: Sprite2D
var _open: Sprite2D
var _stage := -1


func _ready() -> void:
	var t := Art.tex("smudge_0")
	if t:
		_smudge = Sprite2D.new()
		_smudge.scale = Art.SCALE
		_smudge.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_smudge.position = DOOR_CENTER
		add_child(_smudge)
	var o := Art.tex("door_open")
	if o:
		_open = Art.make_sprite(self, o, DOOR_FOOT)
	if GameState.quest >= GameState.Quest.DOOR_OPEN:
		wipe_progress = 1.0
	_update_look()


func is_clean() -> bool:
	return wipe_progress >= 1.0


## 지우개가 월드 좌표 p 를 문질렀다. 자국 위였으면 조금 닦인다.
func wipe(p: Vector2) -> void:
	if is_clean():
		return
	var q := GameState.quest
	if q != GameState.Quest.BRIDGE_BUILT and q != GameState.Quest.CLEAN_DOOR:
		return
	if p.distance_to(global_position + DOOR_CENTER) > WIPE_RADIUS:
		return
	wipe_progress = minf(1.0, wipe_progress + WIPE_PER_RUB)
	_update_look()
	if is_clean():
		cleaned.emit()


func _update_look() -> void:
	var stage := 3 if is_clean() else (0 if wipe_progress < 0.35 else (1 if wipe_progress < 0.7 else 2))
	if stage == _stage:
		return
	_stage = stage
	if _smudge:
		_smudge.visible = stage < 3
		if stage < 3:
			_smudge.texture = Art.tex("smudge_%d" % stage)
	if _open:
		_open.visible = stage == 3
	queue_redraw()


func _physics_process(_delta: float) -> void:
	var p := GameState.player_ref
	if not is_instance_valid(p):
		return
	var inside := p.global_position.distance_to(global_position) < REACH
	if inside and not _inside:
		var Q := GameState.Quest
		if GameState.quest == Q.BRIDGE_BUILT:
			found_smudged.emit()
		elif GameState.quest >= Q.DOOR_OPEN:
			entered.emit()
	_inside = inside


func _draw() -> void:
	# 스프라이트가 없을 때의 임시 표시
	if _smudge == null and not is_clean():
		draw_circle(DOOR_CENTER, 26, Color(0.8, 0.8, 0.82, 0.8 - wipe_progress * 0.6))
