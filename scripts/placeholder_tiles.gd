extends RefCounted
## 임시 도트 타일 생성기.
## 실제 도트 타일셋이 준비되면 village.gd 에서 Tiles.build() 대신
## 직접 만든 TileSet(.tres)을 쓰면 된다. 아틀라스 순서(T)만 맞추면 맵은 그대로 동작한다.

enum T { GRASS, PATH, TREE, HOUSE, DOOR, WATER, BRIDGE, ROOF }

const SOLID := [T.TREE, T.HOUSE, T.DOOR, T.WATER, T.ROOF]
const COUNT := 8


static func build(tile: int = 16) -> TileSet:
	var img := Image.create_empty(tile * COUNT, tile, false, Image.FORMAT_RGBA8)
	for i in COUNT:
		_paint(img, i, tile)

	var ts := TileSet.new()
	ts.tile_size = Vector2i(tile, tile)
	ts.add_physics_layer()

	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(tile, tile)
	ts.add_source(src, 0)

	var h := tile / 2.0
	var poly := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	for i in COUNT:
		var coords := Vector2i(i, 0)
		src.create_tile(coords)
		if i in SOLID:
			var td: TileData = src.get_tile_data(coords, 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, poly)
	return ts


static func _paint(img: Image, index: int, s: int) -> void:
	var ox := index * s
	var pencil := Color(0.25, 0.25, 0.3)
	match index:
		T.GRASS:
			_rect(img, ox, 0, s, s, Color(0.78, 0.88, 0.66))
			for p in [Vector2i(3, 4), Vector2i(10, 2), Vector2i(7, 11), Vector2i(13, 9), Vector2i(2, 13)]:
				img.set_pixel(ox + p.x, p.y, Color(0.6, 0.76, 0.5))
		T.PATH:
			_rect(img, ox, 0, s, s, Color(0.92, 0.85, 0.7))
			for p in [Vector2i(4, 5), Vector2i(11, 3), Vector2i(8, 12), Vector2i(2, 9)]:
				img.set_pixel(ox + p.x, p.y, Color(0.8, 0.72, 0.58))
		T.TREE:
			_rect(img, ox, 0, s, s, Color(0.78, 0.88, 0.66))
			_rect(img, ox + 7, 10, 2, 5, Color(0.5, 0.36, 0.25))
			_circle(img, ox + 8, 7, 6, Color(0.38, 0.6, 0.4))
			_circle(img, ox + 6, 6, 2, Color(0.48, 0.7, 0.48))
		T.HOUSE:
			_rect(img, ox, 0, s, s, Color(0.96, 0.92, 0.82))
			_rect(img, ox, 0, s, 1, pencil)
			_rect(img, ox, 7, s, 1, Color(0.55, 0.4, 0.3))
			_rect(img, ox + 4, 3, 3, 3, Color(0.7, 0.8, 0.9))
			_rect(img, ox + 10, 3, 3, 3, Color(0.7, 0.8, 0.9))
		T.DOOR:
			_rect(img, ox, 0, s, s, Color(0.96, 0.92, 0.82))
			_rect(img, ox + 3, 4, 10, 12, Color(0.45, 0.32, 0.25))
			_rect(img, ox + 3, 4, 10, 4, Color(0.3, 0.38, 0.6))  # 노렌(가게 천)
		T.WATER:
			_rect(img, ox, 0, s, s, Color(0.58, 0.77, 0.93))
			_rect(img, ox + 2, 4, 5, 1, Color(0.8, 0.9, 1.0))
			_rect(img, ox + 9, 11, 5, 1, Color(0.8, 0.9, 1.0))
		T.BRIDGE:
			_rect(img, ox, 0, s, s, Color(0.58, 0.77, 0.93))
			for y in range(0, s, 4):
				_rect(img, ox, y, s, 3, Color(0.72, 0.52, 0.34))
			_rect(img, ox, 0, s, 1, pencil)
			_rect(img, ox, s - 1, s, 1, pencil)
		T.ROOF:
			_rect(img, ox, 0, s, s, Color(0.4, 0.44, 0.58))
			for y in range(3, s, 4):
				_rect(img, ox, y, s, 1, Color(0.3, 0.33, 0.45))
			_rect(img, ox, s - 1, s, 1, pencil)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)


static func _circle(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if Vector2(x - cx, y - cy).length() <= r + 0.3:
				if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
					img.set_pixel(x, y, c)
