extends SceneTree
## 원본 시트(assets/generated_pixel_art/pixel-v4-*) → 게임용 스프라이트(assets/sprites) 변환기.
## 실행: godot --headless --path . --script tools/import_art.gd [-- <디버그 이미지 저장 폴더>]
##       godot --headless --path . --import
##
## 좌표 규칙
##   - "bg px"  : 배경 원본(1672×941) 픽셀 좌표. 맵 위치는 전부 이 좌표로 적는다.
##   - 월드     : 배경 가로가 640 이 되도록 줄인 좌표 (WORLD_PER_BG).
##   - 스프라이트: 1텍셀 = 1/3 월드 (1280×720 창, 카메라 1.5배에서 화면 1픽셀).

const SRC := "res://assets/generated_pixel_art/"
const OUT := "res://assets/sprites/"

const BG := "pixel-v4-empty-village-background.png"
const WORLD_PER_BG := 640.0 / 1672.0
const TEX_PER_WORLD := 3.0

# 충돌 마스크: 배경을 MASK_BLOCK px 칸으로 나눠 "막힌 칸"을 표시한다
const MASK_BLOCK := 4
const SOLID_RATIO := 0.45
# 직접 지정하는 막힌 영역 (bg px): 집 2채, 집 앞 덤불 줄, 작은 덤불, 빨간 문
const SOLID_RECTS := [
	Rect2i(195, 205, 270, 180),
	Rect2i(525, 245, 215, 145),
	Rect2i(135, 328, 695, 60),
	Rect2i(225, 385, 85, 28),
	Rect2i(1458, 355, 90, 112),
]
# 걸어 다닐 수 있는 안쪽 영역 (bg px). 이 밖은 테두리 나무라 막힌다. 모서리는 CORNER_CUT 만큼 깎는다.
const PLAY_RECT := Rect2i(108, 152, 1452, 650)
const CORNER_CUT := 90
# 다리 자리 (bg px): 마스크에서는 뚫어 두고, 게임에서 다리가 생기기 전까지 따로 막는다
const BRIDGE_RECT := Rect2i(962, 470, 246, 86)

const CHAR_SHEETS := {
	"player": "pixel-v4-player-walk-4x4-grid-ready.png",
	"npc": "pixel-v4-haru-walk-4x4-grid-ready.png",
}
const CHAR_HEIGHT_WORLD := 38.0

const SLIME_SHEET := "pixel-v4-slime-4frames.png"
const SLIME_FRAMES := ["idle", "squash", "jump", "hurt"]
const SLIME_WIDTH_WORLD := 24.0

const PROPS_SHEET := "pixel-v4-light-props.png"
# 이름: [원본 영역, 목표 가로(월드)]
const PROPS := {
	"prop_bridge": [Rect2i(180, 0, 780, 724), 246.0 * WORLD_PER_BG],
	"prop_lead": [Rect2i(1080, 0, 340, 724), 15.0],
	"prop_door": [Rect2i(1500, 0, 560, 724), 150.0 * WORLD_PER_BG],
}

var _debug_dir := ""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_debug_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_background()
	_characters()
	_slime()
	_props()
	print("완료: ", OUT)
	quit()


# ---------------- 배경 + 충돌 마스크 ----------------

func _background() -> void:
	var img := _load(BG)
	img.save_png(OUT + "bg.png")

	var bw := img.get_width() / MASK_BLOCK
	var bh := img.get_height() / MASK_BLOCK
	var solid := Image.create_empty(bw, bh, false, Image.FORMAT_RGBA8)
	var walk := Image.create_empty(bw, bh, false, Image.FORMAT_RGBA8)
	var on := Color(1, 1, 1, 1)
	var off := Color(0, 0, 0, 0)
	for by in bh:
		for bx in bw:
			var hit := 0
			for y in MASK_BLOCK:
				for x in MASK_BLOCK:
					if _is_obstacle(img.get_pixel(bx * MASK_BLOCK + x, by * MASK_BLOCK + y)):
						hit += 1
			solid.set_pixel(bx, by, on if float(hit) / (MASK_BLOCK * MASK_BLOCK) >= SOLID_RATIO else off)
	_despeckle(solid)
	for by in bh:
		for bx in bw:
			var blocked := solid.get_pixel(bx, by).a > 0.5
			var p := Vector2i(bx * MASK_BLOCK, by * MASK_BLOCK)
			if not _in_play_area(p):
				blocked = true
			for r in SOLID_RECTS:
				if (r as Rect2i).has_point(p):
					blocked = true
			if BRIDGE_RECT.has_point(p):
				blocked = false
			solid.set_pixel(bx, by, on if blocked else off)
			walk.set_pixel(bx, by, off if blocked else on)
	solid.save_png(OUT + "mask_solid.png")
	walk.save_png(OUT + "mask_walk.png")
	print("bg ", img.get_size(), "  mask ", bw, "x", bh)

	if _debug_dir != "":
		var dbg := img.duplicate() as Image
		for by in bh:
			for bx in bw:
				if solid.get_pixel(bx, by).a > 0.5:
					for y in MASK_BLOCK:
						for x in MASK_BLOCK:
							var px := Vector2i(bx * MASK_BLOCK + x, by * MASK_BLOCK + y)
							dbg.set_pixelv(px, dbg.get_pixelv(px).lerp(Color(1, 0, 0), 0.45))
		dbg.save_png(_debug_dir.path_join("mask_debug.png"))


## 강물(파랑)인가. 나무 테두리는 색으로 가리기 어려워 PLAY_RECT 로 막는다.
func _is_obstacle(c: Color) -> bool:
	return c.b > 0.6 and c.b - c.r > 0.22


func _in_play_area(p: Vector2i) -> bool:
	if not PLAY_RECT.has_point(p):
		return false
	# 네 모서리를 대각선으로 깎는다 (모서리 나무)
	var dx := mini(p.x - PLAY_RECT.position.x, PLAY_RECT.end.x - p.x)
	var dy := mini(p.y - PLAY_RECT.position.y, PLAY_RECT.end.y - p.y)
	return dx + dy >= CORNER_CUT


## 외딴 막힌 칸(풀 포기 등)을 지운다: 주변 8칸 중 막힌 칸이 2개 이하면 뚫는다. 두 번 반복.
func _despeckle(mask: Image) -> void:
	for pass_i in 2:
		var src := mask.duplicate() as Image
		for y in range(1, mask.get_height() - 1):
			for x in range(1, mask.get_width() - 1):
				if src.get_pixel(x, y).a < 0.5:
					continue
				var n := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if (dx != 0 or dy != 0) and src.get_pixel(x + dx, y + dy).a > 0.5:
							n += 1
				if n <= 2:
					mask.set_pixel(x, y, Color(0, 0, 0, 0))


# ---------------- 캐릭터 (4방향 × 걷기 4프레임) ----------------

func _characters() -> void:
	for key in CHAR_SHEETS:
		var img := _load(CHAR_SHEETS[key])
		_clean_alpha(img)
		var cw := img.get_width() / 4
		var ch := img.get_height() / 4
		# 16칸 전체에서 그림이 차지하는 공통 영역 (칸 기준 좌표) → 모든 프레임을 같은 틀로 자른다
		var union := Rect2i()
		for row in 4:
			for col in 4:
				# 옆 칸 그림이 몇 픽셀 넘어온 것을 피하려고 칸 안쪽만 본다
				var u := _used_robust(img, Rect2i(col * cw, row * ch, cw, ch).grow(-10), 6)
				u.position -= Vector2i(col * cw, row * ch)
				union = u if union.size == Vector2i.ZERO else union.merge(u)
		var s := CHAR_HEIGHT_WORLD * TEX_PER_WORLD / union.size.y
		var fw := roundi(union.size.x * s)
		var fh := roundi(union.size.y * s)
		var sheet := Image.create_empty(fw * 4, fh * 4, false, Image.FORMAT_RGBA8)
		for row in 4:
			for col in 4:
				var r := Rect2i(Vector2i(col * cw, row * ch) + union.position, union.size)
				var f := _box_downsample(img.get_region(r), fw, fh)
				sheet.blit_rect(f, Rect2i(0, 0, fw, fh), Vector2i(col * fw, row * fh))
		sheet.save_png(OUT + key + "_walk.png")
		print(key, "_walk frame ", fw, "x", fh, "  (원본 틀 ", union, ")")


# ---------------- 슬라임 ----------------

func _slime() -> void:
	var img := _load(SLIME_SHEET)
	_clean_alpha(img)
	var cw := img.get_width() / 4
	var idle := _used_robust(img, Rect2i(0, 0, cw, img.get_height()))
	var s := SLIME_WIDTH_WORLD * TEX_PER_WORLD / idle.size.x
	for i in 4:
		var r := _used_robust(img, Rect2i(i * cw, 0, cw, img.get_height()))
		var w := roundi(r.size.x * s)
		var h := roundi(r.size.y * s)
		_box_downsample(img.get_region(r), w, h).save_png(OUT + "slime_" + SLIME_FRAMES[i] + ".png")
		print("slime_", SLIME_FRAMES[i], " ", w, "x", h)


# ---------------- 소품 ----------------

func _props() -> void:
	var img := _load(PROPS_SHEET)
	_clean_alpha(img)
	for key in PROPS:
		var r := _used_robust(img, PROPS[key][0])
		var w := roundi(float(PROPS[key][1]) * TEX_PER_WORLD)
		var h := roundi(w * float(r.size.y) / r.size.x)
		_box_downsample(img.get_region(r), w, h).save_png(OUT + key + ".png")
		print(key, " ", w, "x", h, "  src=", r)


# ---------------- 공용 ----------------

func _load(file: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + file))
	img.convert(Image.FORMAT_RGBA8)
	return img


## 거의 투명한 픽셀(잡티, 번짐)을 완전히 투명하게
func _clean_alpha(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a < 0.3:
				img.set_pixel(x, y, Color(0, 0, 0, 0))


## 영역 안에서 그림이 있는 범위. 점 몇 개짜리 잡티 줄은 무시한다.
func _used_robust(img: Image, area: Rect2i, min_count: int = 4) -> Rect2i:
	var cols := PackedInt32Array()
	cols.resize(area.size.x)
	var rows := PackedInt32Array()
	rows.resize(area.size.y)
	for y in area.size.y:
		for x in area.size.x:
			if img.get_pixel(area.position.x + x, area.position.y + y).a > 0.5:
				cols[x] += 1
				rows[y] += 1
	var l := 0
	while l < area.size.x - 1 and cols[l] < min_count:
		l += 1
	var r := area.size.x - 1
	while r > l and cols[r] < min_count:
		r -= 1
	var t := 0
	while t < area.size.y - 1 and rows[t] < min_count:
		t += 1
	var b := area.size.y - 1
	while b > t and rows[b] < min_count:
		b -= 1
	return Rect2i(area.position + Vector2i(l, t), Vector2i(r - l + 1, b - t + 1))


## 면적 평균 축소. 알파는 부드럽게 유지한다 (크레용 가장자리).
func _box_downsample(src: Image, w: int, h: int) -> Image:
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var sw := src.get_width()
	var sh := src.get_height()
	for ty in h:
		var y0 := int(float(ty) * sh / h)
		var y1 := maxi(y0 + 1, int(float(ty + 1) * sh / h))
		for tx in w:
			var x0 := int(float(tx) * sw / w)
			var x1 := maxi(x0 + 1, int(float(tx + 1) * sw / w))
			var r := 0.0
			var g := 0.0
			var b := 0.0
			var a := 0.0
			var n := 0
			for y in range(y0, y1):
				for x in range(x0, x1):
					var c := src.get_pixel(x, y)
					r += c.r * c.a
					g += c.g * c.a
					b += c.b * c.a
					a += c.a
					n += 1
			if a <= 0.0:
				out.set_pixel(tx, ty, Color(0, 0, 0, 0))
			else:
				out.set_pixel(tx, ty, Color(r / a, g / a, b / a, a / n))
	return out
