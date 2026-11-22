extends RefCounted
## 창에 쓰는 부품 (단추, 글, 아이콘, 목록 줄, 스크롤 막대). 모두 도트 그림으로 그린다.
## 그림: assets/sprites/ui_*.png (없으면 종이색 네모로 대신한다)

const Art := preload("res://scripts/art.gd")
const INK := Color(0.3, 0.25, 0.22)
const INK_SOFT := Color(0.5, 0.42, 0.38)

static var _tex: Dictionary = {}     # 그림은 계속 쥐고 있어야 한다 (놓으면 하얗게 나온다)
static var _boxes: Dictionary = {}


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = Art.tex(name)
	return _tex[name]


## 그림 한 장을 통째로 늘려 그리는 상자
static func box(name: String, tint: Color = Color.WHITE) -> StyleBox:
	var key := "%s/%s" % [name, tint.to_html()]
	if _boxes.has(key):
		return _boxes[key]
	var t := tex(name)
	var sb: StyleBox
	if t:
		var st := StyleBoxTexture.new()
		st.texture = t
		st.modulate_color = tint
		sb = st
	else:
		var sf := StyleBoxFlat.new()
		sf.bg_color = Color(0.99, 0.95, 0.84) * tint
		sf.border_color = Color(0.5, 0.38, 0.3)
		sf.set_border_width_all(1)
		sf.set_corner_radius_all(3)
		sb = sf
	sb.set_content_margin_all(1)
	_boxes[key] = sb
	return sb


## kind: "auto" (모양에 따라 네모 단추 또는 긴 단추), "tab" (탭), "plain" (그림 없음: 칸 위에 얹는 투명 단추)
static func button(parent: Control, text: String, pos: Vector2, size: Vector2, on_press: Callable, kind: String = "auto") -> Button:
	var b := Button.new()
	b.text = text
	b.clip_text = true     # 크기보다 먼저: 글자 폭 때문에 단추가 제멋대로 넓어지지 않게
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	b.add_theme_font_size_override("font_size", 9)
	if kind == "plain":
		for state in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	else:
		var off := "ui_tab"
		var on := "ui_tab_on"
		if kind != "tab":
			var square := size.x / maxf(1.0, size.y) < 1.6
			off = "ui_btn_sq" if square else "ui_button"
			on = "ui_btn_sq_on" if square else "ui_button_on"
		b.add_theme_stylebox_override("normal", box(off))
		b.add_theme_stylebox_override("hover", box(off, Color(1.0, 0.93, 0.8)))
		b.add_theme_stylebox_override("pressed", box(on))
		# 탭은 고른 탭이 "누를 수 없는" 상태다: 빨간 테두리로 보여 준다
		b.add_theme_stylebox_override("disabled", box(on) if kind == "tab" else box(off, Color(1, 1, 1, 0.45)))
	for col in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(col, INK)
	b.add_theme_color_override("font_disabled_color", INK if kind == "tab" else Color(INK_SOFT, 0.7))
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


## 그림만 있는 단추 (닫기, 화살표)
static func icon_button(parent: Control, tex_name: String, pos: Vector2, size: Vector2, on_press: Callable) -> Button:
	var b := button(parent, "", pos, size, on_press, "plain")
	b.add_theme_stylebox_override("normal", box(tex_name))
	b.add_theme_stylebox_override("hover", box(tex_name, Color(1.0, 0.9, 0.75)))
	b.add_theme_stylebox_override("pressed", box(tex_name, Color(0.85, 0.75, 0.65)))
	b.add_theme_stylebox_override("disabled", box(tex_name, Color(1, 1, 1, 0.35)))
	return b


## 글자가 다 보이는 단추 폭
static func text_width(text: String, font_size: int = 9) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


static func label(parent: Control, text: String, pos: Vector2, size: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", INK)
	parent.add_child(l)
	return l


static func icon(parent: Control, tex_name: String, pos: Vector2, size: Vector2, tint: Color = Color.WHITE, keep_aspect: bool = true) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex(tex_name) if not tex_name.begins_with("drawn_") else Art.tex(tex_name)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if keep_aspect else TextureRect.STRETCH_SCALE
	# 내가 그린 도트는 또렷하게, 나머지 그림은 부드럽게 줄인다
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if tex_name.begins_with("drawn_") else CanvasItem.TEXTURE_FILTER_LINEAR
	tr.position = pos
	tr.size = size
	tr.modulate = tint
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr


## 세로 스크롤 상자. 막대는 지우개 모양이다. 돌려주는 것은 줄을 넣을 상자.
static func scroll_list(parent: Control, size: Vector2) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.position = Vector2.ZERO
	sc.size = size
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var bar := sc.get_v_scroll_bar()
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bar.custom_minimum_size.x = 9
	bar.add_theme_stylebox_override("scroll", box("ui_scroll_track"))
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, box("ui_scroll_knob"))
	parent.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	sc.add_child(list)
	return list
