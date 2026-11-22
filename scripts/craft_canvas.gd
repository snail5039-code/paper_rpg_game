extends Control
## 직접 그려서 만들기. 문방구의 "만들기" 탭에서 조합법을 고르면 열린다.
## 흐리게 보이는 견본 위에 마우스로 그리면, 그 그림이 도트로 바뀌어 아이템의 아이콘이 된다.
## 견본과 비슷할수록 좋은 물건이 나온다 (장비: 기본 능력 최대 +20%, 소모품: 60% 이상이면 2개).
##   왼쪽 드래그: 그리기 / 오른쪽 클릭: 마지막 획 지우기 / Enter: 완성 / Esc: 그만두기

signal done(message: String)   ## 만들었거나 그만뒀다 (그만두면 빈 글)

const Art := preload("res://scripts/art.gd")
const UI := preload("res://scripts/ui_kit.gd")
const Items := preload("res://scripts/items.gd")
const Pixel := preload("res://scripts/doodle_pixel.gd")
const AiPixel := preload("res://scripts/ai_pixel.gd")

const BOARD := Rect2(70, 46, 156, 156)     # 그림판 (창 안의 자리)

const MIN_QUALITY := 0.3    # 견본과 적어도 이만큼은 비슷해야 만들어진다 (아무렇게나 그으면 안 만들어진다)

var recipe: Array
var strokes: Array = []                    # 선마다 PackedVector2Array (0~1)
var fill := 0                              # 고른 크레용 색 번호
var quality := 0.0
var busy := false                          # AI 를 기다리는 중

var _win: Control
var _board: Control
var _preview: TextureRect
var _score: Label
var _info: Label
var _current := PackedVector2Array()
var _ref: Array = []
var _ref_name := ""
var _swatches: Array = []
var _buttons: Array = []


func setup(r: Array) -> void:
	recipe = r
	if typeof(recipe[1]) == TYPE_STRING:
		_ref_name = str(Items.CONSUMABLES[recipe[1]][1])
	else:
		_ref_name = "equip_%s_%d" % [recipe[1][0], int(recipe[1][1])]
	_ref = Pixel.reference_mask(Art.tex(_ref_name))


func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_win = UI.icon(self, "ui_window", Vector2(110, 46), Vector2(420, 268), Color.WHITE, false)
	var title := UI.label(_win, "직접 그려서 만들기: %s" % recipe[0], Vector2(0, 14), Vector2(420, 20), 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.icon(_win, "ui_board", BOARD.position - Vector2(8, 8), BOARD.size + Vector2(16, 16), Color.WHITE, false)
	_board = Control.new()
	_board.position = BOARD.position
	_board.size = BOARD.size
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_board.mouse_default_cursor_shape = Control.CURSOR_CROSS
	_board.draw.connect(_draw_board)
	_board.gui_input.connect(_board_input)
	_win.add_child(_board)

	var x := 246.0
	UI.label(_win, "견본", Vector2(x, 44), Vector2(50, 12), 9)
	UI.icon(_win, "ui_slot", Vector2(x, 56), Vector2(40, 40))
	UI.icon(_win, _ref_name, Vector2(x + 6, 62), Vector2(28, 28))
	UI.label(_win, "내 도트", Vector2(x + 58, 44), Vector2(60, 12), 9)
	UI.icon(_win, "ui_slot", Vector2(x + 56, 56), Vector2(40, 40))
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.position = Vector2(x + 60, 60)
	_preview.size = Vector2(32, 32)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win.add_child(_preview)
	_score = UI.label(_win, "", Vector2(x, 100), Vector2(120, 14), 10)

	UI.label(_win, "칠할 색", Vector2(x, 118), Vector2(60, 12), 9)
	for i in Pixel.PALETTE.size():
		var sw := ColorRect.new()
		sw.color = Pixel.PALETTE[i]
		sw.position = Vector2(x + i * 19, 132)
		sw.size = Vector2(16, 16)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_win.add_child(sw)
		_swatches.append(sw)
		UI.button(_win, "", sw.position - Vector2(1, 1), Vector2(18, 18), set_fill.bind(i), "plain")
	_buttons = [
		UI.button(_win, "완성", Vector2(x, 160), Vector2(52, 20), finish),
		UI.button(_win, "다시", Vector2(x + 56, 160), Vector2(52, 20), clear),
		UI.button(_win, "그만두기", Vector2(x, 184), Vector2(108, 20), cancel),
	]
	_info = UI.label(_win, "", Vector2(112, 212), Vector2(250, 30), 9)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_color_override("font_color", UI.INK_SOFT)
	_info.text = "흐린 견본을 따라 그려 보세요. 비슷할수록 좋은 물건이 나와요.\n오른쪽 클릭: 마지막 획 지우기" \
		+ ("   (AI 도트 변환 켜짐)" if AiPixel.api_key() != "" else "")
	set_fill(recipe_default_fill())
	_update()


## 부위에 어울리는 색을 처음에 골라 둔다
func recipe_default_fill() -> int:
	if typeof(recipe[1]) == TYPE_STRING:
		return 5
	return {"tool": 0, "hat": 1, "cloth": 2, "shoe": 3, "bag": 4, "acc": 0}.get(str(recipe[1][0]), 0)


func set_fill(i: int) -> void:
	fill = i
	for k in _swatches.size():
		(_swatches[k] as ColorRect).scale = Vector2(1.15, 1.15) if k == i else Vector2(0.8, 0.8)
		(_swatches[k] as ColorRect).pivot_offset = Vector2(8, 8)
	_update()


func clear() -> void:
	if busy:
		return
	strokes.clear()
	_current = PackedVector2Array()
	_update()


func cancel() -> void:
	if busy:
		return
	done.emit("")
	queue_free()


func _board_input(event: InputEvent) -> void:
	if busy:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_current = PackedVector2Array([_norm(mb.position)])
			elif _current.size() > 0:
				strokes.append(_current)
				_current = PackedVector2Array()
				_update()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and not strokes.is_empty():
			strokes.pop_back()
			_update()
	elif event is InputEventMouseMotion and _current.size() > 0:
		var p := _norm((event as InputEventMouseMotion).position)
		if p.distance_to(_current[_current.size() - 1]) > 0.01:
			_current.append(p)
			_board.queue_redraw()


func _norm(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x / BOARD.size.x, 0.0, 0.999), clampf(p.y / BOARD.size.y, 0.0, 0.999))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			cancel()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER:
			finish()
			get_viewport().set_input_as_handled()


## 도트 미리보기와 점수를 다시 계산한다
func _update() -> void:
	quality = Pixel.similarity(Pixel.silhouette(strokes), _ref) if not strokes.is_empty() else 0.0
	if _preview:
		_preview.texture = ImageTexture.create_from_image(Pixel.pixelize(strokes, Pixel.PALETTE[fill]))
		_score.text = "비슷한 정도 %d%%" % roundi(quality * 100.0)
		_board.queue_redraw()


func _draw_board() -> void:
	var cell := BOARD.size.x / Pixel.N
	# 견본 (흐리게)
	for y in Pixel.N:
		for x in Pixel.N:
			if _ref[y][x]:
				_board.draw_rect(Rect2(x * cell, y * cell, cell, cell), Color(0.45, 0.6, 0.85, 0.22))
	for s in strokes + [_current]:
		var pts: PackedVector2Array = s
		if pts.size() == 1:
			_board.draw_circle(pts[0] * BOARD.size, 1.5, Pixel.OUTLINE)
		elif pts.size() > 1:
			var scaled := PackedVector2Array()
			for p in pts:
				scaled.append(p * BOARD.size)
			_board.draw_polyline(scaled, Pixel.OUTLINE, 2.5, true)


## 완성: 도트로 바꾸고(키가 있으면 AI 가 다시 그리고) 물건을 만든다
func finish() -> void:
	if busy:
		return
	if strokes.is_empty():
		_info.text = "아직 아무것도 그리지 않았어요."
		return
	if not GameState.can_craft(recipe):
		_info.text = "재료가 모자라요."
		return
	if quality < MIN_QUALITY:
		# 견본과 너무 다르다: 만들지 않고 재료도 쓰지 않는다. 고쳐 그릴 수 있다.
		Sound.play("fail")
		_info.text = "견본과 너무 달라요. (비슷한 정도 %d%%, %d%% 는 넘어야 해요) 흐린 견본을 따라 그려 보세요." % [roundi(quality * 100.0), roundi(MIN_QUALITY * 100.0)]
		return
	var img := Pixel.pixelize(strokes, Pixel.PALETTE[fill])
	if AiPixel.api_key() != "":
		busy = true
		for b in _buttons:
			(b as Button).disabled = true
		_info.text = "AI 가 내 그림을 도트로 다시 그리는 중이에요… (최대 1분)"
		var ai: Node = AiPixel.new()
		add_child(ai)
		ai.call("request", img, str(recipe[0]))
		var better: Variant = await ai.finished
		ai.queue_free()
		busy = false
		if better is Image:
			img = better
	var art := Art.save_drawn(Pixel.upscale(img))
	# 조합대의 단계: 3단계 기준으로 한 단계마다 3%. 정성 조합대: +10%
	var q := clampf(quality + (GameState.build_lv("bld_craft") - 3) * 0.03 + (0.1 if GameState.has_fine("bld_craft") else 0.0), 0.0, 1.0)
	GameState.craft(recipe, q, art)
	Sound.play("craft")
	var msg := "%s 을(를) 만들었어요. (비슷한 정도 %d%%" % [recipe[0], roundi(q * 100.0)]
	if typeof(recipe[1]) == TYPE_STRING:
		msg += ", 2개 완성!)" if q >= 0.6 else ")"
	else:
		msg += ", 기본 능력 +%d%%)" % roundi(q * 20.0)
	done.emit(msg)
	queue_free()
