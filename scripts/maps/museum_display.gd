extends Node2D
## 박물관 전시 가구 하나 위의 전시물 (scripts/maps/museum.gd 의 DISPLAYS 한 줄).
## 가구 그림의 발이 (0, 0) 이고 그림은 위로 size 만큼 차지한다. 전시 영역은 spec 의 비율 Rect2.
## 기증한 것만 그린다. 물고기는 수조 안을 헤엄치고, 나머지는 칸에 놓인다.
## 가까이 가면 위에 "몬스터 스케치 12/90" 처럼 묶음 이름과 전시 수가 뜬다.

const MuseumScript := preload("res://scripts/data/museum_data.gd")

var museum: Node2D
var spec: Array = []
var size := Vector2(60, 60)
var _t := 0.0
var _seed := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_seed = randf() * 100.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _area() -> Rect2:
	var r: Rect2 = spec[6]
	return Rect2(Vector2(-size.x * 0.5 + r.position.x * size.x, -size.y + r.position.y * size.y), r.size * size)


func _draw() -> void:
	if museum == null:
		return
	var group := str(spec[2])
	var ids: Array = museum.call("group_ids", group)
	var start := int(spec[3])
	var count := int(spec[4])
	var cat := MuseumScript.cat_of(group)
	var area := _area()
	var grid: Vector2i = spec[5]
	var shown := 0
	for i in count:
		var n := start + i
		if n >= ids.size():
			break
		var id := str(ids[n])
		if not GameState.museum_has(cat, id):
			continue
		shown += 1
		var tex: Texture2D = museum.call("exhibit_tex", group, id)
		if tex == null:
			continue
		if group == "fish":
			_draw_fish(tex, area, n)
		else:
			var col := i % grid.x
			var row := i / grid.x
			var cell := Vector2(area.size.x / grid.x, area.size.y / grid.y)
			var c := area.position + cell * Vector2(col + 0.5, row + 0.5)
			var h := minf(cell.x, cell.y) * (0.95 if group != "flower" else 1.6)
			if group == "mon":
				# 작은 흰 액자 안에
				var fr := Rect2(c - Vector2(h, h) * 0.5, Vector2(h, h))
				draw_rect(fr, Color(0.98, 0.96, 0.9))
				draw_rect(fr, Color(0.45, 0.32, 0.22), false, 0.8)
				h *= 0.8
			var w := h * tex.get_width() / float(tex.get_height())
			if w > h * 1.3:
				w = h * 1.3
				h = w * tex.get_height() / float(tex.get_width())
			var bottom := c + Vector2(0, h * 0.5) if group != "flower" else Vector2(c.x, area.end.y)
			draw_texture_rect(tex, Rect2(bottom - Vector2(w * 0.5, h), Vector2(w, h)), false)
	# 가까이 오면 이름과 전시 수
	var p: Node2D = GameState.player_ref
	if is_instance_valid(p) and p.global_position.distance_to(global_position) < 46.0:
		var all_ids: Array = museum.call("group_ids", group)
		var have := 0
		for id in all_ids:
			if GameState.museum_has(cat, str(id)):
				have += 1
		var text := "%s %d/%d  (F 크게 보기)" % [MuseumScript.GROUP_NAMES[group], have, all_ids.size()]
		var font := ThemeDB.fallback_font
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		var at := Vector2(-tw * 0.5, -size.y - 6)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0.15, 0.15, 0.2))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)


## 물고기: 수조 안을 천천히 오가며 위아래로 살짝 흔들린다
func _draw_fish(tex: Texture2D, area: Rect2, n: int) -> void:
	var k := float(n) * 1.7 + _seed
	var speed := 0.12 + fmod(k * 0.37, 0.1)
	var phase := fmod(_t * speed + k * 0.13, 2.0)
	var x01 := phase if phase < 1.0 else 2.0 - phase
	var going_right := phase < 1.0
	var y01 := fmod(k * 0.61, 1.0) * 0.8 + 0.1
	var h := 7.0
	var w := h * tex.get_width() / float(tex.get_height())
	var pos := area.position + Vector2(w * 0.5 + x01 * (area.size.x - w), y01 * area.size.y + sin(_t * 2.0 + k) * 1.2)
	# 그림은 왼쪽을 본다: 오른쪽으로 갈 때는 뒤집는다
	draw_set_transform(pos, 0.0, Vector2(-1.0 if going_right else 1.0, 1.0))
	draw_texture_rect(tex, Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h)), false)
	draw_set_transform(Vector2.ZERO)
