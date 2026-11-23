extends Control
## 박물관 전시대를 가까이서 보는 화면 (전시대 앞에서 F).
## 수조는 물속처럼(물고기가 크게 헤엄치고 거품이 올라간다), 표본장·액자·진열장은 그 안을 들여다보는 것처럼 그린다.
## 기증한 것을 누르면 아래에 설명이 나온다. 바깥을 누르거나 X·Esc 로 닫는다.
## 내용은 menus.gd 의 "exhibit" 창이 정한다 (setup 으로 전시대 번호와 설명을 넘긴다).

const Art := preload("res://scripts/core/art.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const Items := preload("res://scripts/data/items.gd")
const Data := preload("res://scripts/data/game_data.gd")
const MuseumScript := preload("res://scripts/data/museum_data.gd")

const VIEW := Rect2(40, 12, 560, 336)        # 화면에서 차지하는 곳 (640×360 기준)
const FRAME := Rect2(0, 24, 560, 240)        # 전시대 (이 안이 확대된 모습)
const CAPTION := Rect2(0, 270, 560, 66)      # 설명 쪽지
const INK := Color(0.3, 0.25, 0.22)

var menus: Control                 # 그림(_exhibit_tex)과 고르기(_exhibit_pick)를 맡은 창
var display := 0
var group := "fish"
var ids: Array = []                # 이 전시대에 놓이는 것들 (기증 안 한 것 포함)
var selected := ""
var _t := 0.0
var _hits: Array = []              # [Rect2, id] (그릴 때마다 새로)
var _title: Label
var _caption: Label
var _seed := 0.0


func _ready() -> void:
	position = VIEW.position
	size = VIEW.size
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_title = Label.new()
	_title.position = Vector2(180, 0)
	_title.size = Vector2(200, 20)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 13)
	_title.add_theme_color_override("font_color", Color.WHITE)
	_title.add_theme_color_override("font_outline_color", Color(0.15, 0.12, 0.12))
	_title.add_theme_constant_override("outline_size", 4)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_caption = Label.new()
	_caption.position = CAPTION.position + Vector2(14, 8)
	_caption.size = CAPTION.size - Vector2(28, 14)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_size_override("font_size", 10)
	_caption.add_theme_color_override("font_color", INK)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	UI.icon_button(self, "ui_close", Vector2(394, 0), Vector2(21, 21), func() -> void:
		if menus:
			menus.emit_signal("close_requested"))


## 전시대 번호와 아래 설명을 정한다
func setup(index: int, message: String, pick: String) -> void:
	var d: Array = MuseumScript.DISPLAYS[clampi(index, 0, MuseumScript.DISPLAYS.size() - 1)]
	if index != display or ids.is_empty():
		_seed = float(index) * 3.1
	display = index
	group = str(d[2])
	var all: Array = MuseumScript.groups()[group]
	ids = all.slice(int(d[3]), int(d[3]) + int(d[4]))
	selected = pick
	_title.text = str(MuseumScript.GROUP_NAMES[group])
	var cat := MuseumScript.cat_of(group)
	var have := 0
	for id in ids:
		have += 1 if GameState.museum_has(cat, str(id)) else 0
	if message == "":
		message = "이 전시대 %d / %d   (전시실 전체 %d / %d)\n%s 바깥을 누르거나 Esc 로 닫아요." % [
			have, ids.size(), GameState.museum_count(cat), GameState.museum_entries(cat).size(),
			"헤엄치는 물고기를 누르면 설명이 나와요." if group == "fish" else "하나를 누르면 설명이 나와요. 빈 자리는 아직 기증하지 않은 것이에요."]
	_caption.text = message
	queue_redraw()


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		var at: Vector2 = (event as InputEventMouseButton).position
		for i in range(_hits.size() - 1, -1, -1):      # 위에 그려진 것부터
			if (_hits[i][0] as Rect2).has_point(at):
				if menus:
					menus.call("_exhibit_pick", group, str(_hits[i][1]))
				return


func _has(id: String) -> bool:
	return GameState.museum_has(MuseumScript.cat_of(group), id)


func _tex(id: String) -> Texture2D:
	return menus.call("_exhibit_tex", group, id) if menus else null


## 이름표에 쓸 짧은 이름
func _name(id: String) -> String:
	match group:
		"mon":
			return str(Data.FRIENDS.get(id, {}).get("name", id))
		"gear":
			var p := id.split("_")
			return str(Items.SHAPES[p[0]][int(p[1])])
	return str(Items.CONSUMABLES[id][0]) if Items.CONSUMABLES.has(id) else id


# ---------- 그리기 ----------

func _draw() -> void:
	_hits.clear()
	# 설명 쪽지
	draw_rect(CAPTION, Color(0.99, 0.97, 0.9))
	draw_rect(CAPTION, Color(0.45, 0.35, 0.28), false, 1.5)
	# 제목 띠
	draw_rect(Rect2(170, 1, 220, 20), Color(0.42, 0.3, 0.22))
	match group:
		"fish": _draw_tank()
		"bug": _draw_case(Color(0.93, 0.9, 0.78), Color(0.52, 0.36, 0.22), 3, 2, true)
		"flower": _draw_planter()
		"thing": _draw_table()
		"mon": _draw_board()
		"gear": _draw_case(Color(0.45, 0.14, 0.18), Color(0.3, 0.22, 0.2), 5, 3, true)


func _inner() -> Rect2:
	return FRAME.grow(-10)


func _frame(wood: Color) -> void:
	draw_rect(FRAME, wood.darkened(0.35))
	draw_rect(FRAME.grow(-3), wood)
	for i in 6:      # 나뭇결
		var y := FRAME.position.y + 4 + i * (FRAME.size.y - 8) / 6.0
		draw_line(Vector2(FRAME.position.x + 3, y), Vector2(FRAME.position.x + 9, y + 9), wood.darkened(0.15), 1.0)
		draw_line(Vector2(FRAME.end.x - 9, y), Vector2(FRAME.end.x - 3, y + 9), wood.darkened(0.15), 1.0)


func _glass(r: Rect2) -> void:
	for k in 2:
		var x := r.position.x + r.size.x * (0.12 + k * 0.1)
		var w := 22.0 - k * 12.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, r.position.y), Vector2(x + w, r.position.y),
			Vector2(x + w - 60, r.end.y), Vector2(x - 60, r.end.y)]), Color(1, 1, 1, 0.07))


## 전시대마다 같은 모양이 나오는 0~1 값 (돌, 물풀, 코르크 점 자리)
func _r01(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + _seed * 78.233) * 43758.5453, 1.0)


## 수조 속: 물, 빛줄기, 모래, 물풀, 거품, 헤엄치는 물고기
func _draw_tank() -> void:
	_frame(Color(0.36, 0.42, 0.48))
	var r := _inner()
	var top := Color(0.62, 0.86, 0.95)
	var bot := Color(0.12, 0.36, 0.62)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bot, bot]))
	# 물결 무늬 (위)
	for x in range(int(r.position.x), int(r.end.x), 6):
		var y := r.position.y + 3 + sin(_t * 1.6 + x * 0.08) * 1.5
		draw_line(Vector2(x, y), Vector2(x + 4, y), Color(1, 1, 1, 0.35), 1.0)
	# 빛줄기
	for k in 4:
		var x := r.position.x + r.size.x * (0.15 + k * 0.23) + sin(_t * 0.3 + k) * 10.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, r.position.y), Vector2(x + 26, r.position.y),
			Vector2(x + 70, r.end.y - 30), Vector2(x + 20, r.end.y - 30)]), Color(1, 1, 0.9, 0.06))
	# 모래와 돌
	var sand_y := r.end.y - 26.0
	var sand := PackedVector2Array([Vector2(r.position.x, r.end.y)])
	for i in 15:
		var x := r.position.x + r.size.x * i / 14.0
		sand.append(Vector2(x, sand_y + sin(i * 1.3 + _seed) * 4.0))
	sand.append(r.end)
	draw_colored_polygon(sand, Color(0.86, 0.78, 0.56))
	for i in 28:
		var p := Vector2(r.position.x + _r01(i) * r.size.x, sand_y + 8 + _r01(i + 40) * 14.0)
		draw_circle(p, 1.0 + _r01(i + 80) * 2.5, Color(0.6, 0.55, 0.45).lerp(Color(0.75, 0.7, 0.6), _r01(i + 9)))
	# 물풀
	for k in 7:
		var bx := r.position.x + 20 + _r01(k + 200) * (r.size.x - 40)
		var hgt := 50.0 + _r01(k + 210) * 80.0
		var pts := PackedVector2Array()
		for s in 9:
			var f := s / 8.0
			pts.append(Vector2(bx + sin(_t * 1.3 + k + f * 3.0) * 8.0 * f, sand_y + 4 - hgt * f))
		draw_polyline(pts, Color(0.2, 0.55, 0.3, 0.9), 4.0, true)
		draw_polyline(pts, Color(0.35, 0.7, 0.4, 0.9), 1.5, true)
	# 거품
	for b in 14:
		var bx := r.position.x + r.size.x * (0.1 + 0.8 * _r01(b + 300))
		var sp := 18.0 + _r01(b + 310) * 20.0
		var life := fmod(_t * sp + _r01(b + 320) * 400.0, r.size.y - 20.0)
		var p := Vector2(bx + sin(_t * 3.0 + b) * 3.0, sand_y - life)
		draw_arc(p, 1.5 + _r01(b + 330) * 2.0, 0, TAU, 10, Color(1, 1, 1, 0.55), 1.0)
	# 물고기 (기증한 것만)
	for n in ids.size():
		var id := str(ids[n])
		if not _has(id):
			continue
		var tex := _tex(id)
		if tex == null:
			continue
		var k := float(n) * 1.7 + _seed
		var speed := 0.05 + fmod(k * 0.37, 0.05)
		var phase := fmod(_t * speed + k * 0.13, 2.0)
		var x01 := phase if phase < 1.0 else 2.0 - phase
		var going_right := phase < 1.0
		var rarity := int(Items.FISH_INFO.get(id, ["", "", 0])[2])
		var h := 22.0 + rarity * 5.0
		var w := h * tex.get_width() / float(tex.get_height())
		var y01 := fmod(k * 0.61, 1.0) * 0.75 + 0.08
		var pos := r.position + Vector2(w * 0.5 + 6 + x01 * (r.size.x - w - 12), 14 + y01 * (sand_y - r.position.y - 40) + sin(_t * 1.5 + k) * 3.0)
		var rect := Rect2(pos - Vector2(w, h) * 0.5, Vector2(w, h))
		if id == selected:
			draw_circle(pos, maxf(w, h) * 0.62, Color(1, 1, 0.7, 0.25))
		draw_set_transform(pos, 0.0, Vector2(-1.0 if going_right else 1.0, 1.0))
		draw_texture_rect(tex, Rect2(-Vector2(w, h) * 0.5, Vector2(w, h)), false)
		draw_set_transform(Vector2.ZERO)
		_hits.append([rect.grow(4), id])
	_glass(r)


## 칸이 나뉜 진열장 (곤충 표본장, 장비 진열장): 칸마다 핀이나 받침 위에 하나씩, 아래 이름표
func _draw_case(back: Color, wood: Color, cols: int, rows: int, glass: bool) -> void:
	_frame(wood)
	var r := _inner()
	draw_rect(r, back)
	# 천 결
	for i in range(0, int(r.size.y), 4):
		draw_line(Vector2(r.position.x, r.position.y + i), Vector2(r.end.x, r.position.y + i), back.darkened(0.04), 1.0)
	var cell := Vector2(r.size.x / cols, r.size.y / rows)
	for i in ids.size():
		var id := str(ids[i])
		var c := r.position + cell * Vector2(i % cols + 0.5, i / cols + 0.5)
		var box := Rect2(c - cell * 0.5, cell).grow(-5)
		draw_rect(box, back.darkened(0.12), false, 1.0)
		var tag := Rect2(Vector2(c.x - cell.x * 0.4, box.end.y - 14), Vector2(cell.x * 0.8, 12))
		if group == "gear":       # 작은 받침대
			draw_rect(Rect2(Vector2(c.x - cell.x * 0.25, box.end.y - 24), Vector2(cell.x * 0.5, 8)), Color(0.85, 0.78, 0.6))
			draw_rect(Rect2(Vector2(c.x - cell.x * 0.25, box.end.y - 24), Vector2(cell.x * 0.5, 8)), Color(0.5, 0.4, 0.28), false, 1.0)
		var bottom := tag.position.y - (12.0 if group == "gear" else 4.0)    # 장비는 받침대 위에
		_item(id, Rect2(box.position + Vector2(6, 4), Vector2(box.size.x - 12, bottom - box.position.y - 4)), tag, back.get_luminance() < 0.4)
		if group == "bug" and _has(id):
			draw_circle(Vector2(c.x, box.position.y + 8), 2.2, Color(0.85, 0.2, 0.2))   # 핀
	if glass:
		_glass(r)


## 그림 한 칸: 기증했으면 그림과 이름표, 아니면 빈 자리와 ?
func _item(id: String, area: Rect2, tag: Rect2, dark_back: bool) -> void:
	var font := get_theme_default_font()
	var ink := Color(0.96, 0.92, 0.85) if dark_back else INK
	if not _has(id):
		var c := area.get_center()
		draw_dashed_line(area.position + Vector2(area.size.x * 0.25, area.size.y * 0.15), Vector2(area.position.x + area.size.x * 0.75, area.position.y + area.size.y * 0.15), Color(ink, 0.35), 1.0, 3.0)
		draw_string(font, c + Vector2(-4, 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(ink, 0.4))
		_hits.append([area, id])
		return
	var tex := _tex(id)
	if tex:
		var h := area.size.y
		var w := h * tex.get_width() / float(tex.get_height())
		if w > area.size.x:
			w = area.size.x
			h = w * tex.get_height() / float(tex.get_width())
		var rect := Rect2(area.get_center() - Vector2(w, h) * 0.5, Vector2(w, h))
		if id == selected:
			draw_rect(rect.grow(3), Color(1, 0.95, 0.5, 0.35))
		draw_texture_rect(tex, rect, false)
	draw_rect(tag, Color(0.99, 0.97, 0.9) if not dark_back else Color(0.2, 0.08, 0.1))
	var name := _name(id)
	var fs := 8
	var tw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(tag.get_center().x - minf(tw, tag.size.x) * 0.5, tag.end.y - 3), name, HORIZONTAL_ALIGNMENT_LEFT, tag.size.x, fs, ink)
	_hits.append([area.merge(tag), id])


## 몬스터 스케치: 코르크 판에 흰 액자를 압정으로
func _draw_board() -> void:
	_frame(Color(0.5, 0.34, 0.2))
	var r := _inner()
	draw_rect(r, Color(0.8, 0.64, 0.44))
	for i in 160:
		draw_circle(r.position + Vector2(_r01(i) * r.size.x, _r01(i + 500) * r.size.y), 0.8, Color(0.62, 0.46, 0.3))
	var cols := 5
	var rows := 3
	var cell := Vector2(r.size.x / cols, r.size.y / rows)
	for i in ids.size():
		var id := str(ids[i])
		var c := r.position + cell * Vector2(i % cols + 0.5, i / cols + 0.5)
		var tilt := (_r01(i + 700) - 0.5) * 0.06
		var fr := Rect2(c - Vector2(cell.x * 0.36, cell.y * 0.42), Vector2(cell.x * 0.72, cell.y * 0.84))
		draw_set_transform(c, tilt, Vector2.ONE)
		var local := Rect2(fr.position - c, fr.size)
		draw_rect(Rect2(local.position + Vector2(2, 2), local.size), Color(0, 0, 0, 0.18))
		draw_rect(local, Color(0.98, 0.96, 0.9) if _has(id) else Color(0.9, 0.86, 0.78, 0.6))
		draw_rect(local, Color(0.45, 0.32, 0.22), false, 1.0)
		draw_set_transform(Vector2.ZERO)
		var tag := Rect2(Vector2(fr.position.x + 4, fr.end.y - 13), Vector2(fr.size.x - 8, 11))
		_item(id, Rect2(fr.position + Vector2(6, 8), Vector2(fr.size.x - 12, tag.position.y - fr.position.y - 10)), tag, false)
		draw_circle(Vector2(c.x, fr.position.y + 3), 2.5, Color(0.25, 0.45, 0.85))     # 압정


## 꽃밭: 벽 앞 화단에 꽃이 살랑인다
func _draw_planter() -> void:
	_frame(Color(0.55, 0.4, 0.26))
	var r := _inner()
	draw_rect(r, Color(0.93, 0.95, 0.88))
	for i in range(0, int(r.size.x), 24):     # 벽지 줄
		draw_line(Vector2(r.position.x + i, r.position.y), Vector2(r.position.x + i, r.end.y), Color(0.85, 0.9, 0.8), 2.0)
	var soil := Rect2(Vector2(r.position.x, r.end.y - 50), Vector2(r.size.x, 50))
	draw_rect(soil, Color(0.45, 0.3, 0.2))
	draw_rect(Rect2(soil.position, Vector2(soil.size.x, 8)), Color(0.6, 0.42, 0.28))
	for i in 40:
		draw_circle(soil.position + Vector2(_r01(i + 900) * soil.size.x, 12 + _r01(i + 950) * 34.0), 1.2, Color(0.35, 0.22, 0.15))
	var n := ids.size()
	var cw := r.size.x / n
	var font := get_theme_default_font()
	for i in n:
		var id := str(ids[i])
		var base := Vector2(r.position.x + cw * (i + 0.5), soil.position.y + 10)
		var tag := Rect2(Vector2(base.x - cw * 0.4, soil.end.y - 16), Vector2(cw * 0.8, 12))
		if not _has(id):
			draw_line(base, base + Vector2(0, -26), Color(0.55, 0.4, 0.28), 2.0)       # 빈 팻말
			draw_rect(Rect2(base + Vector2(-12, -40), Vector2(24, 16)), Color(0.96, 0.92, 0.82))
			draw_string(font, base + Vector2(-3, -28), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(INK, 0.5))
			_hits.append([Rect2(base + Vector2(-cw * 0.4, -120), Vector2(cw * 0.8, 130)), id])
			continue
		var tex := _tex(id)
		if tex:
			var h := 120.0
			var w := h * tex.get_width() / float(tex.get_height())
			if w > cw * 0.95:
				w = cw * 0.95
				h = w * tex.get_height() / float(tex.get_width())
			var sway := sin(_t * 1.4 + i * 0.9) * 0.05
			if id == selected:
				draw_circle(base + Vector2(0, -h * 0.5), maxf(w, h) * 0.5, Color(1, 1, 0.7, 0.3))
			draw_set_transform(base, sway, Vector2.ONE)
			draw_texture_rect(tex, Rect2(Vector2(-w * 0.5, -h), Vector2(w, h)), false)
			draw_set_transform(Vector2.ZERO)
			_hits.append([Rect2(base + Vector2(-w * 0.5, -h), Vector2(w, h)), id])
		draw_rect(tag, Color(0.99, 0.97, 0.9))
		var name := _name(id)
		var tw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(font, Vector2(tag.get_center().x - minf(tw, tag.size.x) * 0.5, tag.end.y - 3), name, HORIZONTAL_ALIGNMENT_LEFT, tag.size.x, 8, INK)


## 채집물 진열대: 체크무늬 식탁보 위 작은 접시에 하나씩
func _draw_table() -> void:
	_frame(Color(0.6, 0.44, 0.28))
	var r := _inner()
	var a := Color(0.98, 0.95, 0.88)
	var b := Color(0.93, 0.78, 0.72)
	var sq := 20.0
	for yy in range(0, ceili(r.size.y / sq)):
		for xx in range(0, ceili(r.size.x / sq)):
			var cell := Rect2(r.position + Vector2(xx, yy) * sq, Vector2(sq, sq)).intersection(r)
			draw_rect(cell, a if (xx + yy) % 2 == 0 else b)
	var cols := 5
	var rows := 2
	var cell := Vector2(r.size.x / cols, r.size.y / rows)
	for i in ids.size():
		var id := str(ids[i])
		var c := r.position + cell * Vector2(i % cols + 0.5, i / cols + 0.5)
		var plate := Rect2(c + Vector2(-cell.x * 0.36, cell.y * 0.12), Vector2(cell.x * 0.72, cell.y * 0.2))
		draw_set_transform(plate.get_center(), 0.0, Vector2(1.0, plate.size.y / plate.size.x))
		draw_circle(Vector2.ZERO, plate.size.x * 0.5, Color(1, 1, 1))
		draw_arc(Vector2.ZERO, plate.size.x * 0.5, 0, TAU, 32, Color(0.6, 0.55, 0.5), 2.0)
		draw_set_transform(Vector2.ZERO)
		var tag := Rect2(Vector2(c.x - cell.x * 0.4, c.y + cell.y * 0.5 - 16), Vector2(cell.x * 0.8, 12))
		_item(id, Rect2(c - Vector2(cell.x * 0.32, cell.y * 0.42), Vector2(cell.x * 0.64, cell.y * 0.62)), tag, false)
