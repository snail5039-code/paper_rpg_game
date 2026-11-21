extends SceneTree
## 원본 시트(assets/generated_pixel_art/pixel-v4-*) → 게임용 스프라이트(assets/sprites) 변환기.
## 실행: godot --headless --path . --script tools/import_art.gd [-- base|tutorial] [<디버그 이미지 저장 폴더>]
##   base     : 배경·충돌 마스크·캐릭터·슬라임·소품만
##   tutorial : 튜토리얼용 그림(tutorial_v4 폴더)만
##   (생략)   : 전부
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
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a == "base" or a == "tutorial":
			only = a
		else:
			_debug_dir = a
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if only != "tutorial":
		_background()
		_characters()
		_slime()
		_props()
	if only != "base":
		_tutorial()
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
		# 모든 프레임을 같은 틀로 자른다
		var union := _char_union(img)
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


# ---------------- 튜토리얼 그림 ----------------

const TUT := "res://assets/generated_pixel_art/tutorial_v4/"

func _tutorial() -> void:
	# 1) 지우개 자국 3단계 — 빨간 문을 덮는 크기
	var img := _load(TUT + "01_eraser_smudge_3stages.png")
	_clean_alpha(img, 0.5)
	_row_pieces(img, ["smudge_0", "smudge_1", "smudge_2"], roundi(74.0 * TEX_PER_WORLD), 0)

	# 2) 열린 빨간 문 — 번진 빛(반투명)은 버리고 문만
	img = _load(TUT + "02_open_red_door.png")
	_clean_alpha(img, 0.75)
	_save_piece(img, Rect2i(Vector2i.ZERO, img.get_size()), "door_open", roundi(165.0 * WORLD_PER_BG * TEX_PER_WORLD), 0)

	# 3) 플레이어 공격 4방향 × 3프레임 — 걷기 시트와 같은 배율·같은 세로 틀
	var walk := _load(CHAR_SHEETS["player"])
	_clean_alpha(walk)
	var wu := _char_union(walk)
	var s := CHAR_HEIGHT_WORLD * TEX_PER_WORLD / wu.size.y
	img = _load(TUT + "03_player_attack_4dir_3frames_grid-ready.png")
	_clean_alpha(img)
	var cw := img.get_width() / 3
	var ch := img.get_height() / 4
	var fw := roundi((cw - 20) * s)
	var fh := roundi(wu.size.y * s)
	var sheet := Image.create_empty(fw * 3, fh * 4, false, Image.FORMAT_RGBA8)
	for row in 4:
		for col in 3:
			var r := Rect2i(col * cw + 10, row * ch + wu.position.y, cw - 20, wu.size.y)
			sheet.blit_rect(_box_downsample(img.get_region(r), fw, fh), Rect2i(0, 0, fw, fh), Vector2i(col * fw, row * fh))
	sheet.save_png(OUT + "player_attack.png")
	print("player_attack frame ", fw, "x", fh)

	# 4) 대화창 초상화
	img = _load(TUT + "04_dialogue_portraits.png")
	_clean_alpha(img)
	_row_pieces(img, ["portrait_player", "portrait_haru_smile", "portrait_haru_surprised"], 0, 168)

	# 5) 오프닝 컷, 6) 페이지 넘김 — 그대로 복사
	_load(TUT + "05a_opening_closed_16x9.png").save_png(OUT + "opening_closed.png")
	_load(TUT + "05b_opening_open_16x9.png").save_png(OUT + "opening_open.png")
	_load(TUT + "06_page_turn_4frames_grid-ready.png").save_png(OUT + "page_turn.png")

	# 7) 조작 아이콘 — 칸 사이 선을 피해 안쪽만
	img = _load(TUT + "07_control_icons.png")
	_clean_alpha(img, 0.6)
	var cell := img.get_width() / 4
	var keys := [["key_wasd", "key_mouse_l", "key_mouse_r", "key_space"], ["key_f", "key_tab", "key_enter"]]
	for row in keys.size():
		for col in keys[row].size():
			var r := _used_robust(img, Rect2i(col * cell, row * cell, cell, cell).grow(-14), 8)
			_box_downsample(img.get_region(r), roundi(r.size.x * 0.3), roundi(r.size.y * 0.3)).save_png(OUT + keys[row][col] + ".png")

	# 8) 연필·지우개, 9) 감정 말풍선
	img = _load(TUT + "08_pencil_eraser_icons.png")
	_clean_alpha(img)
	_row_pieces(img, ["tool_pencil", "tool_eraser"], 0, 72)
	img = _load(TUT + "09_haru_emotion_icons.png")
	_clean_alpha(img)
	_row_pieces(img, ["emote_alert", "emote_question", "emote_heart"], roundi(18.0 * TEX_PER_WORLD), 0)

	# 10) 슬라임 사라짐 4프레임 — 흰 배경 제거, 슬라임 스프라이트와 같은 배율, 한 장의 시트로
	img = _load(TUT + "10_slime_vanish_4frames.png")
	_key_white(img)
	_clean_alpha(img)
	var qw := img.get_width() / 4
	var first := _used_robust(img, Rect2i(0, 0, qw, img.get_height()))
	var ss := SLIME_WIDTH_WORLD * TEX_PER_WORLD / first.size.x
	var union := Rect2i()
	for i in 4:
		var u := _used_robust(img, Rect2i(i * qw, 0, qw, img.get_height()).grow_individual(-6, 0, -6, 0), 2)
		u.position.x -= i * qw
		union = u if union.size == Vector2i.ZERO else union.merge(u)
	var vw := roundi(union.size.x * ss)
	var vh := roundi(union.size.y * ss)
	sheet = Image.create_empty(vw * 4, vh, false, Image.FORMAT_RGBA8)
	for i in 4:
		var r := Rect2i(Vector2i(i * qw, 0) + union.position, union.size)
		sheet.blit_rect(_box_downsample(img.get_region(r), vw, vh), Rect2i(0, 0, vw, vh), Vector2i(i * vw, 0))
	sheet.save_png(OUT + "slime_vanish.png")
	print("slime_vanish frame ", vw, "x", vh)

	# 11) 지우개 괴물 — 분홍 잡티 제거
	img = _load(TUT + "11_eraser_monster_silhouette.png")
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.r > 0.7 and c.b > 0.7 and c.g < 0.45:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	_clean_alpha(img, 0.5)
	_save_piece(img, Rect2i(Vector2i.ZERO, img.get_size()), "monster", 0, roundi(64.0 * TEX_PER_WORLD))

	# 12) 지우개 가루 3종 — 흰 배경 제거
	img = _load(TUT + "12_eraser_dust_3variants.png")
	_key_white(img)
	_clean_alpha(img)
	_row_pieces(img, ["dust_0", "dust_1", "dust_2"], 0, 0, 0.14)


## 16칸 걷기 시트에서 그림이 차지하는 공통 틀 (칸 기준 좌표)
func _char_union(img: Image) -> Rect2i:
	var cw := img.get_width() / 4
	var ch := img.get_height() / 4
	var union := Rect2i()
	for row in 4:
		for col in 4:
			var u := _used_robust(img, Rect2i(col * cw, row * ch, cw, ch).grow(-10), 6)
			u.position -= Vector2i(col * cw, row * ch)
			union = u if union.size == Vector2i.ZERO else union.merge(u)
	return union


## 가로로 나란히 놓인 그림들을 같은 폭의 칸으로 나눠 하나씩 저장한다.
func _row_pieces(img: Image, names: Array, tex_w: int, tex_h: int, fixed_scale: float = 0.0) -> void:
	var cw := img.get_width() / names.size()
	for i in names.size():
		_save_piece(img, Rect2i(i * cw, 0, cw, img.get_height()), names[i], tex_w, tex_h, fixed_scale)


## area 안의 그림을 찾아 목표 크기로 줄여 저장. tex_w / tex_h 중 준 쪽에 맞추고 비율 유지.
func _save_piece(img: Image, area: Rect2i, name: String, tex_w: int, tex_h: int, fixed_scale: float = 0.0) -> void:
	var r := _used_robust(img, area)
	var s := fixed_scale
	if tex_w > 0:
		s = float(tex_w) / r.size.x
	elif tex_h > 0:
		s = float(tex_h) / r.size.y
	var w := maxi(1, roundi(r.size.x * s))
	var h := maxi(1, roundi(r.size.y * s))
	_box_downsample(img.get_region(r), w, h).save_png(OUT + name + ".png")
	print(name, " ", w, "x", h)


## 배경이 흰색으로 칠해진 시트: 가장자리에서 이어진 흰 영역만 투명하게 (그림 안쪽 흰색은 남긴다)
func _key_white(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	if img.get_pixel(2, 2).a < 0.5:
		return  # 이미 투명 배경
	var stack := PackedInt32Array()
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	while not stack.is_empty():
		var i := stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		var x := i % w
		var y := i / w
		var c := img.get_pixel(x, y)
		if c.a < 0.5 or c.r < 0.9 or c.g < 0.9 or c.b < 0.9:
			continue
		img.set_pixel(x, y, Color(0, 0, 0, 0))
		if x > 0:
			stack.append(i - 1)
		if x < w - 1:
			stack.append(i + 1)
		if y > 0:
			stack.append(i - w)
		if y < h - 1:
			stack.append(i + w)


# ---------------- 공용 ----------------

func _load(file: String) -> Image:
	var path := file if file.begins_with("res://") else SRC + file
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	return img


## 거의 투명한 픽셀(잡티, 번짐)을 완전히 투명하게
func _clean_alpha(img: Image, threshold: float = 0.3) -> void:
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a < threshold:
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
