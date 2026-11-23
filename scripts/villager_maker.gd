extends Control
## 직접 그려 만드는 주민. 내 마을의 빈 주민 집에 F 를 두 번 누르면 열린다.
##  1. 몸·옷·얼굴 부품을 고른다 (화살표). 부품 그림이 없는 종류는 건너뛴다.
##  2. 성격을 고른다: 좋아하는 선물, 하루 선물, 들려주는 이야기가 달라진다.
##  3. 이름을 적는다.
##  4. (골라도 되고 안 해도 된다) "덧그리기": 고른 모습 위에 크레용으로 더 그린다.
##  5. "이사 오기": 그 집에 산다. 최대 Data.CUSTOM_MAX 명.

signal done(id: String)   ## 만든 주민의 id. 그만두면 빈 글

const Art := preload("res://scripts/art.gd")
const UI := preload("res://scripts/ui_kit.gd")
const Data := preload("res://scripts/game_data.gd")
const DoodleCanvas := preload("res://scripts/doodle_canvas.gd")

const SIZE := 96               # 합친 그림의 크기 (px)

var house := ""                # 이사 올 집의 자리
var pick := {"body": 0, "cloth": 0, "face": 0}
var persona := "glutton"
var drawn := ""                # 덧그린 그림 ("" 은 덧그리지 않음)

var _win: Control
var _preview: TextureRect
var _name: LineEdit
var _info: Label
var _persona_buttons := {}
var _part_labels := {}
var _canvas: Control


func setup(key: String) -> void:
	house = key


## 그 종류에서 고를 수 있는 그림들 (그림이 있는 것만). 몸은 그림이 하나도 없으면 있는 주민 그림을 쓴다.
static func parts(kind: String) -> Array:
	var out: Array = []
	for n in Data.CUSTOM_PARTS[kind]:
		if Art.tex(str(n)):
			out.append(str(n))
	if out.is_empty() and kind == "body":
		for n in Data.CUSTOM_BODY_FALLBACK:
			if Art.tex(str(n)):
				out.append(str(n))
	return out


## 고른 부품을 겹친 그림 (몸 → 옷 → 얼굴, 아래 가운데 맞춤)
func compose() -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for kind in ["body", "cloth", "face"]:
		var list := parts(kind)
		if list.is_empty():
			continue
		var tex := Art.tex(str(list[int(pick[kind]) % list.size()]))
		var layer := tex.get_image()
		if layer.is_compressed():
			layer.decompress()
		layer = layer.duplicate()
		layer.convert(Image.FORMAT_RGBA8)
		var k := minf(float(SIZE) / layer.get_width(), float(SIZE) / layer.get_height())
		layer.resize(maxi(1, roundi(layer.get_width() * k)), maxi(1, roundi(layer.get_height() * k)), Image.INTERPOLATE_BILINEAR)
		img.blend_rect(layer, Rect2i(Vector2i.ZERO, layer.get_size()), Vector2i((SIZE - layer.get_width()) / 2, SIZE - layer.get_height()))
	return img


func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.08, 0.4)
	dim.size = size
	add_child(dim)
	_win = UI.icon(self, "ui_window", Vector2(110, 46), Vector2(420, 268), Color.WHITE, false)
	var tl := UI.label(_win, "새 주민 그리기", Vector2(0, 14), Vector2(420, 20), 14)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.icon(_win, "ui_board", Vector2(62, 40), Vector2(116, 116), Color.WHITE, false)
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.position = Vector2(70, 48)
	_preview.size = Vector2(100, 100)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win.add_child(_preview)
	# 부품 고르기
	var y := 44.0
	for kind in ["body", "cloth", "face"]:
		UI.label(_win, {"body": "몸", "cloth": "옷", "face": "얼굴"}[kind], Vector2(196, y + 3), Vector2(40, 14), 10)
		UI.button(_win, "◀", Vector2(232, y), Vector2(22, 20), _step.bind(kind, -1))
		_part_labels[kind] = UI.label(_win, "", Vector2(256, y + 3), Vector2(50, 14), 10)
		(_part_labels[kind] as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UI.button(_win, "▶", Vector2(306, y), Vector2(22, 20), _step.bind(kind, 1))
		y += 24.0
	# 성격
	UI.label(_win, "성격", Vector2(196, 118), Vector2(40, 14), 10)
	var i := 0
	for p in Data.PERSONAS:
		_persona_buttons[p] = UI.button(_win, str(Data.PERSONAS[p]["name"]), Vector2(232 + (i % 2) * 64, 114 + (i / 2) * 22), Vector2(60, 20), _set_persona.bind(str(p)))
		i += 1
	# 이름
	_name = LineEdit.new()
	_name.position = Vector2(62, 164)
	_name.size = Vector2(116, 22)
	_name.max_length = 8
	_name.placeholder_text = "이름 (8자까지)"
	_name.add_theme_font_size_override("font_size", 10)
	for st in ["normal", "focus"]:
		_name.add_theme_stylebox_override(st, UI.box("ui_row"))
	_name.add_theme_color_override("font_color", UI.INK)
	_name.add_theme_color_override("font_placeholder_color", UI.INK_SOFT)
	_name.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_win.add_child(_name)
	UI.button(_win, "덧그리기", Vector2(196, 166), Vector2(64, 20), redraw)
	UI.button(_win, "이사 오기", Vector2(264, 166), Vector2(64, 20), finish)
	UI.button(_win, "그만두기", Vector2(332, 166), Vector2(58, 20), cancel)
	_info = UI.label(_win, "", Vector2(62, 194), Vector2(330, 40), 9)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_color_override("font_color", UI.INK_SOFT)
	_set_persona(persona)


func _step(kind: String, d: int) -> void:
	var list := parts(kind)
	if list.is_empty():
		return
	pick[kind] = posmod(int(pick[kind]) + d, list.size())
	drawn = ""            # 모습을 바꾸면 덧그린 것은 지운다
	_update()


func _set_persona(p: String) -> void:
	persona = p
	for k in _persona_buttons:
		(_persona_buttons[k] as Button).disabled = k == p
	_update()


func _update() -> void:
	_preview.texture = Art.tex(drawn) if drawn != "" else ImageTexture.create_from_image(compose())
	for kind in _part_labels:
		var list := parts(kind)
		(_part_labels[kind] as Label).text = "%d / %d" % [int(pick[kind]) % maxi(1, list.size()) + 1, list.size()] if not list.is_empty() else "없음"
	var info: Dictionary = Data.PERSONAS[persona]
	_info.text = "%s: 좋아하는 것 %s, 하루 선물 %s.\n덧그리기: 고른 모습 위에 크레용으로 더 그려요. (만든 주민 %d / %d)" % [
		info["name"], GameState.Items.CONSUMABLES[str(info["like"])][0], GameState.Items.CONSUMABLES[str(info["gift"])][0],
		GameState.custom_villagers.size(), Data.CUSTOM_MAX]


## 고른 모습 위에 덧그린다 (그림판의 밑그림으로 넣는다)
func redraw() -> void:
	if is_instance_valid(_canvas):
		return
	var base := ImageTexture.create_from_image(compose())
	_canvas = DoodleCanvas.new()
	_canvas.call("setup", "주민 덧그리기", "고른 모습 위에 모자, 무늬, 표정을 더 그려 보세요.", base, false)
	add_child(_canvas)
	_canvas.connect("done", func(art: String) -> void:
		if art != "":
			drawn = art
		_update())


func cancel() -> void:
	done.emit("")
	queue_free()


func finish() -> void:
	if GameState.custom_villagers.size() >= Data.CUSTOM_MAX:
		_info.text = "직접 만든 주민은 %d명까지예요." % Data.CUSTOM_MAX
		return
	var art := drawn
	if art == "":
		art = Art.save_drawn(compose())
	var id := GameState.create_villager(_name.text, persona, art, house)
	if id == "":
		_info.text = "이 집에는 이사 올 수 없어요."
		return
	Sound.play("craft")
	done.emit(id)
	queue_free()


func _input(event: InputEvent) -> void:
	if is_instance_valid(_canvas):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		cancel()
		get_viewport().set_input_as_handled()
