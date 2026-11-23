extends Control
## 지도 그림: 공책에 연필과 크레용으로 그린 것처럼 보이는 1장 지도.
##  - 가 본 화면은 그 화면의 배경을 작게 줄인 그림에 삐뚤빼뚤한 연필 테두리를 두른다.
##  - 아직 안 가 본 화면은 연필 밑그림과 물음표만.
##  - 화면 사이는 연필 점선 길로 잇고, 지금 있는 곳에는 빨간 크레용 동그라미를 친다.

const Art := preload("res://scripts/core/art.gd")
const Data := preload("res://scripts/data/game_data.gd")

const THUMB := Vector2(76, 43)
const GAP := Vector2(30, 20)
const PENCIL := Color(0.28, 0.25, 0.27)
const PENCIL_SOFT := Color(0.28, 0.25, 0.27, 0.55)
const CRAYON_RED := Color(0.88, 0.3, 0.28)
const LINKS := [["ch1", "ch1_crossroad"], ["ch1_meadow", "ch1_crossroad"],
	["ch1_crossroad", "ch1_gridwoods"], ["ch1_crossroad", "ch1_erasedroad"]]
const BG_NAMES := {
	"ch1": "bg_ch1_village", "ch1_meadow": "bg_ch1_meadow", "ch1_crossroad": "bg_ch1_crossroad",
	"ch1_gridwoods": "bg_ch1_gridwoods", "ch1_erasedroad": "bg_ch1_erasedroad",
}

## _draw 에서 쓰는 텍스처는 여기서 잡고 있어야 한다 (지역 변수로만 두면 그리기 전에 해제된다)
var _tex: Dictionary = {}
var _labels: Dictionary = {}
var _here: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for id in BG_NAMES:
		_tex[id] = Art.tex(str(BG_NAMES[id]))
		var l := Label.new()
		l.size = Vector2(THUMB.x + 20, 14)
		l.position = _center(id) + Vector2(-(THUMB.x + 20) * 0.5, THUMB.y * 0.5 + 3.0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_size_override("font_size", 9)
		l.add_theme_color_override("font_color", PENCIL)
		l.rotation = _tilt(id)
		add_child(l)
		_labels[id] = l
	_here = Label.new()
	_here.text = "여기!"
	_here.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_here.add_theme_font_size_override("font_size", 11)
	_here.add_theme_color_override("font_color", CRAYON_RED)
	add_child(_here)
	refresh()


func refresh() -> void:
	for id in _labels:
		(_labels[id] as Label).text = str(Data.MAP_NAMES[id]) if _visited(id) else "?"
	var cur := GameState.current_map
	_here.visible = Data.CH1_LAYOUT.has(cur)
	if _here.visible:
		_here.position = _center(cur) + Vector2(THUMB.x * 0.5 + 2, -THUMB.y * 0.5 - 15)
	queue_redraw()


func _visited(id: String) -> bool:
	return id == GameState.current_map or GameState.visited.has(id)


func _center(id: String) -> Vector2:
	var cell: Vector2i = Data.CH1_LAYOUT[id]
	return Vector2(cell) * (THUMB + GAP) + THUMB * 0.5 + Vector2(12, 4)


## 화면마다 조금씩 다르게 기울인다 (손으로 붙인 느낌)
func _tilt(id: String) -> float:
	return deg_to_rad(float((hash(id) % 7) - 3) * 0.9)


## 손으로 그은 것처럼 조금씩 떨리는 선. seed_n 이 같으면 항상 같은 모양이다.
func _wobbly(a: Vector2, b: Vector2, seed_n: int, amount: float = 1.1) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := maxi(2, int(a.distance_to(b) / 7.0))
	var normal := (b - a).orthogonal().normalized()
	for i in n + 1:
		var t := float(i) / n
		var h := sin(float(seed_n) * 12.9898 + float(i) * 78.233) * 43758.5453
		var jitter := (h - floorf(h) - 0.5) * 2.0 * amount
		pts.append(a.lerp(b, t) + normal * (0.0 if i == 0 or i == n else jitter))
	return pts


func _pencil_line(a: Vector2, b: Vector2, seed_n: int, width: float = 1.3, col: Color = PENCIL) -> void:
	draw_polyline(_wobbly(a, b, seed_n), col, width, true)


func _draw() -> void:
	# 길: 연필 점선
	var n := 0
	for pair in LINKS:
		n += 1
		var a := _center(pair[0])
		var b := _center(pair[1])
		var both: bool = _visited(pair[0]) and _visited(pair[1])
		var line := _wobbly(a, b, 100 + n, 1.4)
		for i in range(0, line.size() - 1, 2):
			draw_line(line[i], line[i + 1], PENCIL if both else PENCIL_SOFT, 2.0, true)

	# 화면 그림
	n = 0
	for id in BG_NAMES:
		n += 1
		var c := _center(id)
		var rot := _tilt(id)
		draw_set_transform(c, rot, Vector2.ONE)
		var r := Rect2(-THUMB * 0.5, THUMB)
		if _visited(id):
			draw_rect(r.grow(2.5), Color(1.0, 0.99, 0.95))   # 흰 종이 여백 (붙인 그림처럼)
			var tex: Texture2D = _tex[id]
			if tex:
				draw_texture_rect(tex, r, false)
			else:
				draw_rect(r, Color(0.8, 0.88, 0.65))
		else:
			draw_rect(r, Color(1.0, 0.99, 0.95, 0.5))
			# 빗금 밑그림
			for k in 5:
				var x := r.position.x + 8.0 + k * 12.0
				_pencil_line(Vector2(x, r.end.y - 6), Vector2(x + 10, r.position.y + 6), 300 + n * 10 + k, 1.0, PENCIL_SOFT)
		# 삐뚤빼뚤한 연필 테두리 (두 번 그어 겹친 느낌)
		var g := r.grow(2.5)
		var corners := [g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)]
		for pass_i in 2:
			for k in 4:
				var off := Vector2(0.6, -0.5) * pass_i
				_pencil_line(corners[k] + off, corners[(k + 1) % 4] - off, n * 20 + k + pass_i * 7, 1.2,
					PENCIL if pass_i == 0 else PENCIL_SOFT)
		draw_set_transform(Vector2.ZERO)

	# 지금 있는 곳: 빨간 크레용 동그라미 (두 바퀴)
	var cur := GameState.current_map
	if Data.CH1_LAYOUT.has(cur):
		var cc := _center(cur)
		for loop in 2:
			var ring := PackedVector2Array()
			for i in 41:
				var ang := TAU * i / 40.0 + loop * 0.5
				var wob := 1.0 + sin(ang * 3.0 + loop * 2.0) * 0.04
				ring.append(cc + Vector2(cos(ang) * (THUMB.x * 0.6 + loop * 1.5), sin(ang) * (THUMB.y * 0.72 + loop)) * wob)
			draw_polyline(ring, CRAYON_RED if loop == 0 else Color(CRAYON_RED, 0.6), 2.2, true)
