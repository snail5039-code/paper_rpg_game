extends Node
## 1페이지(튜토리얼) 연출 담당.
##  - 오프닝: 책상 위 공책 → 펼쳐짐 → 마을로 들어감 → 독백
##  - 단계별 조작 안내 (HUD 아래쪽 키 아이콘)
##  - 빨간 문: 자국 발견 → 닦기 → 문 열림 → 지우개 괴물 등장 → 페이지 넘김
## 게임이 일시정지(대화·컷신)된 동안에도 움직여야 하므로 PROCESS_MODE_ALWAYS.

signal _advance

const Art := preload("res://scripts/art.gd")
const PAPER := Color(0.99, 0.96, 0.87)

var village: Node2D   # village.gd 가 넣어 준다
var hud: CanvasLayer
var goal: Node2D
var drawing: Node2D

var _waiting_advance := false
var _busy := false
var _spawn_pos := Vector2.ZERO
var _moved := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	goal.connect("found_smudged", _on_found_smudged)
	goal.connect("cleaned", _on_door_cleaned)
	goal.connect("entered", _on_door_entered)
	drawing.connect("erased_at", func(p: Vector2) -> void: goal.call("wipe", p))
	if is_instance_valid(GameState.player_ref):
		_spawn_pos = GameState.player_ref.global_position
	if GameState.quest >= GameState.Quest.DOOR_OPEN:
		_scatter_dust()
	if not GameState.intro_seen:
		_play_opening.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not _waiting_advance:
		return
	var pressed: bool = event.is_action_pressed("interact") or event.is_action_pressed("dodge") \
		or event.is_action_pressed("draw_confirm") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if pressed:
		get_viewport().set_input_as_handled()
		_waiting_advance = false
		_advance.emit()


func _wait_advance() -> void:
	_waiting_advance = true
	await _advance


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


# ---------- 단계별 조작 안내 ----------

func _process(_delta: float) -> void:
	if hud == null:
		return
	var p := GameState.player_ref
	if not _moved and is_instance_valid(p) and p.global_position.distance_to(_spawn_pos) > 24.0:
		_moved = true
	hud.call("set_hints", _current_hints())


func _current_hints() -> Array:
	var Q := GameState.Quest
	var q := GameState.quest
	if GameState.draw_mode:
		if q == Q.CLEAN_DOOR or (q == Q.BRIDGE_BUILT and GameState.bridge_built):
			return [["key_mouse_r", "문 위를 문질러 자국 닦기"], ["key_tab", "닫기"]]
		if q == Q.FIND_LEAD:
			return [["key_mouse_l", "점선을 따라 그리기"], ["key_mouse_r", "지우기"], ["key_enter", "완성"], ["key_tab", "닫기"]]
		return [["key_mouse_l", "그리기"], ["key_mouse_r", "지우기"], ["key_tab", "닫기"]]
	if q == Q.NOT_STARTED:
		if not _moved:
			return [["key_wasd", "움직여 보자"]]
		return [["key_wasd", "이동"], ["key_f", "하루에게 말 걸기"]]
	if q == Q.FIND_LEAD:
		if GameState.pencil_lead < GameState.BRIDGE_COST:
			return [["key_mouse_l", "공격"], ["key_space", "회피"]]
		return [["key_tab", "강가에서 연필 꺼내기"]]
	if q == Q.BRIDGE_BUILT:
		return [["key_wasd", "다리를 건너 빨간 문으로"]]
	if q == Q.CLEAN_DOOR:
		return [["key_tab", "연필 모드에서 지우개 쓰기"]]
	if q == Q.DOOR_OPEN:
		return [["key_wasd", "열린 문으로 들어가기"]]
	return []


# ---------- 오프닝 ----------

func _play_opening() -> void:
	_busy = true
	GameState.set_cutscene(true)
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var back := ColorRect.new()
	back.color = Color(0.16, 0.11, 0.08)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(back)
	var closed := _full_image(layer, "opening_closed")
	var opened := _full_image(layer, "opening_open")
	opened.modulate.a = 0.0
	var caption := _caption_label(layer)

	caption.text = "오랜만에 서랍에서 어릴 적 공책을 꺼냈다.   ▼"
	await _wait_advance()
	caption.text = "그때 뭘 그렸더라… 한번 펼쳐 볼까.   ▼"
	await _wait_advance()
	caption.text = ""
	var tw := create_tween()
	tw.tween_property(opened, "modulate:a", 1.0, 0.7)
	await tw.finished
	closed.visible = false
	caption.text = "…어? 그림이 움직이고 있어!   ▼"
	await _wait_advance()
	caption.text = ""

	# 공책 속으로 빨려 들어간다
	opened.pivot_offset = Vector2(320, 190)
	tw = create_tween().set_parallel(true)
	tw.tween_property(opened, "scale", Vector2(2.4, 2.4), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(back, "color", PAPER, 0.9)
	tw.chain().tween_property(layer, "offset:y", 0.0, 0.01)
	await tw.finished
	var fade := ColorRect.new()
	fade.color = PAPER
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	opened.visible = false
	back.visible = false
	tw = create_tween()
	tw.tween_property(fade, "modulate:a", 0.0, 0.6)
	await tw.finished
	layer.queue_free()
	GameState.set_cutscene(false)

	await GameState.say("나", [
		"여긴… 내가 그렸던 마을이잖아!",
		"손에는 연필이 들려 있다. 일단 주변을 둘러보자.",
	], "player")
	GameState.intro_seen = true
	GameState.save_game()
	_busy = false


func _full_image(layer: CanvasLayer, tex_name: String) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = Art.tex(tex_name)
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tr)
	return tr


func _caption_label(layer: CanvasLayer, y: float = 300.0, font_size: int = 17) -> Label:
	var l := Label.new()
	l.position = Vector2(0, y)
	l.size = Vector2(640, 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.12, 0.1))
	l.add_theme_constant_override("outline_size", 6)
	layer.add_child(l)
	return l


# ---------- 빨간 문 ----------

func _on_found_smudged() -> void:
	if _busy:
		return
	_busy = true
	await GameState.say("나", [
		"다음 페이지로 가는 문인데… 뿌옇게 지워져 있어.",
		"지우개로 문지르면 자국이 닦일지도 몰라.",
	], "player")
	GameState.set_quest(GameState.Quest.CLEAN_DOOR)
	_busy = false


func _on_door_cleaned() -> void:
	_busy = true
	drawing.call("set_active", false)
	GameState.set_quest(GameState.Quest.DOOR_OPEN)
	GameState.notify("문이 열렸다!")

	# 지우개 괴물이 잠깐 모습을 드러낸다
	GameState.set_cutscene(true)
	var monster: Sprite2D = null
	var mt := Art.tex("monster")
	if mt:
		monster = Art.make_sprite(village, mt, goal.position + Vector2(-58, 4))
		monster.z_index = 20
		monster.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.5)
		tw.tween_property(monster, "modulate:a", 0.92, 0.5)
		await tw.finished
	GameState.set_cutscene(false)
	await GameState.say("???", [
		"히히… 지워 놨더니 또 그려 놨네?",
		"재밌다! 어디 한번 따라와 봐, 그린이.",
		"다음 페이지에서 기다릴게!",
	])
	if monster:
		GameState.set_cutscene(true)
		var tw2 := create_tween().set_parallel(true)
		tw2.tween_property(monster, "modulate:a", 0.0, 0.5)
		tw2.tween_property(monster, "position:y", monster.position.y - 14.0, 0.5)
		await tw2.finished
		monster.queue_free()
		GameState.set_cutscene(false)
	_scatter_dust()
	await GameState.say("나", [
		"방금 그건… 지우개 괴물?",
		"마을을 지운 게 저 녀석이구나. 문으로 들어가서 쫓아가자!",
	], "player")
	_busy = false


## 괴물이 지나간 자리에 지우개 가루를 남긴다
func _scatter_dust() -> void:
	var spots := [Vector2(-66, 8), Vector2(-46, 15), Vector2(-80, 17)]
	for i in spots.size():
		var t := Art.tex("dust_%d" % i)
		if t:
			var s := Art.make_sprite(village, t, goal.position + spots[i])
			s.z_index = -4


func _on_door_entered() -> void:
	if _busy:
		return
	_busy = true
	GameState.set_cutscene(true)
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)

	# 페이지가 넘어간다
	var paper := ColorRect.new()
	paper.color = PAPER
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.modulate.a = 0.0
	layer.add_child(paper)
	var sheet := Art.tex("page_turn")
	if sheet:
		var frame_h := sheet.get_height() / 4.0
		var at := AtlasTexture.new()
		at.atlas = sheet
		var page := TextureRect.new()
		page.texture = at
		page.set_anchors_preset(Control.PRESET_FULL_RECT)
		page.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		page.stretch_mode = TextureRect.STRETCH_SCALE
		page.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(page)
		for i in 4:
			at.region = Rect2(0, i * frame_h, sheet.get_width(), frame_h)
			if i == 1:
				paper.modulate.a = 1.0
			await _wait(0.17)
		page.queue_free()
	paper.modulate.a = 1.0

	var title := _caption_label(layer, 130.0, 30)
	title.add_theme_color_override("font_color", Color(0.3, 0.25, 0.25))
	title.add_theme_constant_override("outline_size", 0)
	title.text = "1페이지 끝"
	var sub := _caption_label(layer, 178.0, 16)
	sub.add_theme_color_override("font_color", Color(0.45, 0.4, 0.4))
	sub.add_theme_constant_override("outline_size", 0)
	sub.text = "지우개 괴물을 쫓아 2페이지로… (준비 중)"
	var foot := _caption_label(layer, 300.0, 12)
	foot.add_theme_color_override("font_color", Color(0.55, 0.5, 0.5))
	foot.add_theme_constant_override("outline_size", 0)
	foot.text = "클릭하면 마을로 돌아갑니다  ·  F9 처음부터 다시"

	if GameState.quest != GameState.Quest.CLEARED:
		GameState.set_quest(GameState.Quest.CLEARED)
	await _wait(0.4)
	await _wait_advance()
	var tw := create_tween()
	tw.tween_property(layer, "offset:y", 0.0, 0.01)
	for c in layer.get_children():
		tw.parallel().tween_property(c, "modulate:a", 0.0, 0.4)
	await tw.finished
	layer.queue_free()
	GameState.set_cutscene(false)
	_busy = false
