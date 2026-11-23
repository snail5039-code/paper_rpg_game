extends RefCounted
## 내가 그린 선을 도트 아이콘으로 바꾼다 (만들기에서 쓴다). 인터넷이 필요 없다.
##   1. 선을 32 × 32 칸에 찍는다 (연필 테두리)
##   2. 선으로 둘러싸인 안쪽을 고른 색으로 칠한다
##   3. 왼쪽 위는 밝게, 오른쪽 아래는 어둡게 음영을 넣는다
## 견본 그림과 얼마나 겹치는지도 잰다 (0~1).

const N := 32                       # 도트 칸 수
const OUT_SCALE := 3                # 저장할 때 키우는 배율 (96 × 96)
const OUTLINE := Color(0.24, 0.2, 0.22)
## 크레용 색 (칠할 색을 고른다)
const PALETTE := [
	Color(0.98, 0.83, 0.42), Color(0.95, 0.56, 0.5), Color(0.6, 0.8, 0.95),
	Color(0.62, 0.85, 0.6), Color(0.8, 0.68, 0.95), Color(0.97, 0.94, 0.86),
]


## strokes: 선마다 PackedVector2Array, 좌표는 0~1 (그림판 안의 위치).
## 돌려주는 것: 선이 지나간 칸이 true 인 N × N 표 (줄 단위 배열)
static func rasterize(strokes: Array) -> Array:
	var grid: Array = []
	for y in N:
		var row: Array = []
		row.resize(N)
		row.fill(false)
		grid.append(row)
	for s in strokes:
		var pts: PackedVector2Array = s
		for i in pts.size():
			var a := pts[i] * N
			var b := pts[mini(i + 1, pts.size() - 1)] * N
			var steps := maxi(1, ceili(a.distance_to(b) * 2.0))
			for k in steps + 1:
				var p := a.lerp(b, float(k) / steps)
				var x := int(floor(p.x))
				var y := int(floor(p.y))
				if x >= 0 and y >= 0 and x < N and y < N:
					grid[y][x] = true
	return grid


## 바깥에서 닿지 않는 빈 칸(= 선으로 둘러싸인 안쪽)을 찾는다
static func interior(lines: Array) -> Array:
	var outside: Array = []
	for y in N:
		var row: Array = []
		row.resize(N)
		row.fill(false)
		outside.append(row)
	var stack: Array = []
	for i in N:
		stack.append(Vector2i(i, 0))
		stack.append(Vector2i(i, N - 1))
		stack.append(Vector2i(0, i))
		stack.append(Vector2i(N - 1, i))
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		if c.x < 0 or c.y < 0 or c.x >= N or c.y >= N or outside[c.y][c.x] or lines[c.y][c.x]:
			continue
		outside[c.y][c.x] = true
		stack.append(c + Vector2i(1, 0))
		stack.append(c + Vector2i(-1, 0))
		stack.append(c + Vector2i(0, 1))
		stack.append(c + Vector2i(0, -1))
	var inside: Array = []
	for y in N:
		var row2: Array = []
		for x in N:
			row2.append(not outside[y][x] and not lines[y][x])
		inside.append(row2)
	return inside


## 선 + 안쪽 = 그림이 차지한 자리
static func silhouette(strokes: Array) -> Array:
	var lines := rasterize(strokes)
	var inside := interior(lines)
	for y in N:
		for x in N:
			inside[y][x] = inside[y][x] or lines[y][x]
	return inside


## 도트 아이콘을 만든다 (N × N)
static func pixelize(strokes: Array, fill: Color) -> Image:
	var lines := rasterize(strokes)
	var inside := interior(lines)
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in N:
		for x in N:
			if lines[y][x]:
				img.set_pixel(x, y, OUTLINE)
			elif inside[y][x]:
				var c := fill
				# 왼쪽 위에 선이 있으면 밝게, 오른쪽 아래에 선이 있으면 어둡게
				if _at(lines, x - 1, y) or _at(lines, x, y - 1):
					c = fill.lightened(0.25)
				elif _at(lines, x + 1, y) or _at(lines, x, y + 1):
					c = fill.darkened(0.18)
				elif (x + y) % 7 == 0:
					c = fill.darkened(0.06)   # 크레용 결
				img.set_pixel(x, y, c)
	return img


static func _at(grid: Array, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < N and y < N and grid[y][x]


## 저장용으로 키운다 (도트가 뭉개지지 않게 가장 가까운 점 방식)
static func upscale(img: Image) -> Image:
	var big: Image = img.duplicate()
	big.resize(N * OUT_SCALE, N * OUT_SCALE, Image.INTERPOLATE_NEAREST)
	return big


## 견본 그림을 그림판 크기(N × N)에 맞춰 놓았을 때 차지하는 자리.
## 가운데에 놓고, 가장자리에 3칸씩 여백을 둔다.
static func reference_mask(tex: Texture2D) -> Array:
	var grid: Array = []
	for y in N:
		var row: Array = []
		row.resize(N)
		row.fill(false)
		grid.append(row)
	if tex == null:
		return grid
	var img := tex.get_image()
	if img == null:
		return grid
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return grid
	img = img.get_region(used)
	var room := N - 6
	var s := float(room) / maxi(used.size.x, used.size.y)
	var w := maxi(1, roundi(used.size.x * s))
	var h := maxi(1, roundi(used.size.y * s))
	img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var ox := (N - w) / 2
	var oy := (N - h) / 2
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.4:
				grid[oy + y][ox + x] = true
	return grid


## 견본이 그림판에서 놓이는 자리 (0~1). 그림판에 견본을 흐리게 보여 줄 때 쓴다.
static func reference_rect(tex: Texture2D) -> Rect2:
	if tex == null:
		return Rect2(0, 0, 1, 1)
	var room := float(N - 6) / N
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var s := room / maxf(w, h)
	return Rect2((1.0 - w * s) / 2.0, (1.0 - h * s) / 2.0, w * s, h * s)


## 두 자리가 겹치는 정도 (겹친 칸 ÷ 둘 중 하나라도 찬 칸) 를 0~1 점수로 바꾼다.
## 손으로 따라 그리면 겹침이 0.5~0.8 쯤 나오므로, 0.25 를 0점, 0.75 를 만점으로 본다.
static func similarity(mine: Array, ref: Array) -> float:
	var both := 0
	var either := 0
	for y in N:
		for x in N:
			if mine[y][x] and ref[y][x]:
				both += 1
			if mine[y][x] or ref[y][x]:
				either += 1
	if either == 0 or both == 0:
		return 0.0
	return clampf((float(both) / either - 0.25) / 0.5, 0.0, 1.0)
