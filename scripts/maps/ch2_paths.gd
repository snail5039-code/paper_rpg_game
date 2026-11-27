extends Node
## 2장 친구의 길 기능 (docs/스토리.md 8. 이야기 친구): 같이 다니는 친구만 할 수 있는 일.
##   콩콩이 — 도토리 숲 큰 나무 꼭대기의 종이 과녁(먼 스위치)을 도토리로 맞힌다 → 도토리 바구니가 떨어진다.
##   덩굴이 — 절벽과 덩굴의 끊긴 덩굴을 잇는다 → 덩굴을 타고 절벽 위 둥지에 다녀온다.
## 한 번 하면 GameState.path_done 에 남고, 과녁은 맞은 채로, 덩굴은 이어진 채로 그려진다.
## field.gd 가 ch2_grove, ch2_cliff 에 붙인다.

const Art := preload("res://scripts/core/art.gd")
const SpotScript := preload("res://scripts/actors/story_spot.gd")

## 자리 (bg px): [F 를 누르는 곳, 그림이 걸리는 곳]
const SPOTS := {
	"ch2_grove": {"target": [Vector2(1150, 440), Vector2(1085, 150)]},
	"ch2_cliff": {"vine": [Vector2(1295, 340), Vector2(1295, 215)]},
}
const NEED := {"target": "kongkong", "vine": "vine"}
## 보상: 동전, {재료 번호: 개수}
const REWARD := {
	"target": [150, {13: 5, 21: 2}],
	"vine": [200, {16: 3, 20: 2}],
}

var field: Node2D
var _deco: Sprite2D       # 과녁 또는 이어진 덩굴
var _busy := false


static func here(id: String) -> bool:
	return SPOTS.has(id)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	field = get_parent()
	var id := str(field.get("field_id"))
	var actors: Node2D = field.get("actors")
	for what in SPOTS[id]:
		var at: Array = SPOTS[id][what]
		var s: Node2D = SpotScript.new()
		s.set("what", what)
		s.set("story", self)
		s.position = field.call("bg", at[0])
		actors.add_child(s)
		_deco = Sprite2D.new()
		_deco.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_deco.scale = Art.SCALE
		_deco.position = field.call("bg", at[1])
		_deco.z_index = 1
		field.add_child(_deco)
		_show(what)


func _show(what: String) -> void:
	var done := bool(GameState.path_done.get(what, false))
	if what == "target":
		_deco.texture = Art.tex("path_target_hit" if done else "path_target")
		_deco.rotation = 0.12 if done else 0.0
	else:
		_deco.texture = Art.tex("path_vine")
		_deco.visible = done


## 같이 다니는 친구가 그 일을 할 수 있는지
static func can(what: String) -> bool:
	var f: Dictionary = GameState.companion_friend()
	return not f.is_empty() and str(f["sp"]) == str(NEED[what])


func on_spot(spot: Node2D) -> void:
	if _busy:
		return
	_busy = true
	var what := str(spot.get("what"))
	if bool(GameState.path_done.get(what, false)):
		if what == "target":
			await GameState.say("나", ["과녁 한가운데에 도토리가 박혀 있다. 콩콩이가 쏜 거다."], "player")
		else:
			await GameState.say("나", ["다시 이어진 덩굴. 바람에 새 잎이 흔들린다."], "player")
	elif not can(what):
		if what == "target":
			await GameState.say("나", ["나무 꼭대기에 종이 과녁이 걸려 있다. 너무 높아서 닿지 않는다.", "(멀리 쏠 수 있는 친구가 있으면…)"], "player_sad")
		else:
			await GameState.say("나", ["덩굴이 중간에 끊겨 있다. 색도 빠져서 잡으면 바스러진다.", "(덩굴을 이을 수 있는 친구가 있으면…)"], "player_sad")
	elif what == "target":
		await _shoot(spot)
	else:
		await _grow(spot)
	_busy = false


# ---------- 콩콩이: 먼 스위치 ----------

func _shoot(spot: Node2D) -> void:
	await GameState.say("콩콩이", ["콩! 콩!", "(콩콩이가 모자를 고쳐 쓰고 과녁을 노린다)"], "")
	GameState.set_cutscene(true)
	var acorn := Sprite2D.new()
	acorn.texture = Art.tex("forage_24")
	acorn.scale = Art.SCALE * 0.6
	acorn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	acorn.global_position = spot.global_position + Vector2(0, -10)
	acorn.z_index = 2
	field.add_child(acorn)
	var to := _deco.global_position
	var from := acorn.global_position
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_method(func(t: float):
		acorn.global_position = from.lerp(to, t) + Vector2(0, -40.0 * sin(t * PI))
		acorn.rotation = t * 12.0, 0.0, 1.0, 0.45)
	await tw.finished
	acorn.queue_free()
	GameState.path_done["target"] = true
	_show("target")
	Sound.play("hit")
	# 과녁이 흔들리고, 가지에 걸려 있던 바구니가 떨어진다
	var sw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	sw.tween_property(_deco, "rotation", -0.3, 0.12)
	sw.tween_property(_deco, "rotation", 0.2, 0.18)
	sw.tween_property(_deco, "rotation", 0.12, 0.2)
	var basket := Sprite2D.new()
	basket.texture = Art.tex("path_basket")
	basket.scale = Art.SCALE * 0.8
	basket.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	basket.global_position = to + Vector2(20, 10)
	basket.z_index = 2
	field.add_child(basket)
	var fall := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fall.tween_property(basket, "global_position", spot.global_position + Vector2(14, 0), 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await fall.finished
	GameState.set_cutscene(false)
	await GameState.say("나", ["맞혔다! 나뭇가지에 걸려 있던 바구니가 떨어졌어.", "누가 숨겨 둔 도토리 바구니다."], "player")
	_give("target")
	Sound.play("pickup")
	var gone := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	gone.tween_property(basket, "modulate:a", 0.0, 0.5)
	gone.tween_callback(basket.queue_free)


# ---------- 덩굴이: 끊긴 덩굴 ----------

func _grow(spot: Node2D) -> void:
	await GameState.say("덩굴이", ["스르륵…", "(덩굴이가 끊긴 자리에 제 덩굴을 감는다)"], "")
	GameState.set_cutscene(true)
	_deco.visible = true
	_deco.modulate.a = 0.0
	var full := _deco.scale
	_deco.scale = Vector2(full.x, full.y * 0.1)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel()
	tw.tween_property(_deco, "modulate:a", 1.0, 0.4)
	tw.tween_property(_deco, "scale", full, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	GameState.path_done["vine"] = true
	# 덩굴을 타고 절벽 위에 다녀온다 (화면이 잠깐 어두워진다)
	var p: Node2D = field.get("player")
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 30
	layer.add_child(dim)
	field.add_child(layer)
	var climb := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if p:
		climb.tween_property(p, "global_position", _deco.global_position + Vector2(0, -20), 0.7)
	climb.tween_property(dim, "color:a", 1.0, 0.3)
	await climb.finished
	if p:
		p.global_position = spot.global_position + Vector2(0, 10)
	var back := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	back.tween_property(dim, "color:a", 0.0, 0.4)
	await back.finished
	layer.queue_free()
	GameState.set_cutscene(false)
	await GameState.say("나", ["덩굴을 타고 절벽 위에 올라갔다 왔어.", "꼭대기에 오래된 새 둥지가 있었어. 반짝이는 것들이 모여 있었지."], "player")
	_give("vine")


func _give(what: String) -> void:
	var r: Array = REWARD[what]
	GameState.add_coins(int(r[0]))
	for m in (r[1] as Dictionary):
		GameState.add_material(int(m), int(r[1][m]))
	GameState.notify("동전 %d와 재료를 얻었어요." % int(r[0]))
	GameState.changed.emit()
	GameState.save_game()
