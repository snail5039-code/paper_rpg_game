extends Control
## 불러오기 화면: 게임에 들어갈 때(시작 화면에서 칸을 고른 뒤) 잠깐 나온다.
## 책상 위의 공책 그림(bg_loading)에서 오른쪽 장이 넘어가고, 아래에 연필이 선을 그으며 차오르는 막대와 팁 한 줄.
## 다음 맵 장면은 뒤에서 미리 불러 두고(ResourceLoader.load_threaded_request), 다 되면 넘어간다.
## 쓰는 법: GameState.open_with_loading(장면 경로)

const UI := preload("res://scripts/ui/ui_kit.gd")
const Art := preload("res://scripts/core/art.gd")
const Data := preload("res://scripts/data/game_data.gd")
const MIN_SEC := 1.4            # 너무 빨리 지나가면 깜빡이기만 하니 이만큼은 보여 준다
const FLIP_SEC := 1.25          # 장 하나가 넘어가는 시간
const FLIP_REST := 0.35         # 한 장을 넘긴 뒤 쉬는 시간
# 공책 그림(bg_loading, 1280×720) 안의 자리: 등(고리 가운데)의 x, 고리 폭의 반, 장의 바깥 x, 장의 위·아래 y
const SPINE := 649.0
const RING := 29.0              # 고리가 있는 곳은 넘어가는 장에 넣지 않는다
const PAGE_OUT := 1072.0
const PAGE_Y0 := 54.0
const PAGE_Y1 := 488.0
const STRIPS := 30              # 넘어가는 장을 세로 띠로 잘라 휘게 한다
const BAR := Rect2(150, 312, 340, 6)

const TIPS := [
	"T 를 누르면 무기와 생활 도구를 바꿔 들어요.",
	"사냥터의 나무는 맨손으로 흔들면 열매가, 도끼로 베면 통나무가 나와요.",
	"밤에는 몬스터가 세지지만 큰 물고기가 잘 잡혀요.",
	"도화지가 있으면 쓰러진 몬스터를 다시 그려 친구로 만들 수 있어요.",
	"생활 도구는 쓸수록 닳아요. 조합대에서 쇠·금으로 올리면 오래 가요.",
	"내 집에서 자면 피로도가 가득 차요.",
	"Space 로 구르면 잠깐 공격을 피할 수 있어요.",
	"주민에게 좋아하는 것을 선물하면 하트가 올라가요.",
	"채집 자리와 나무는 날이 바뀌면 다시 열려요.",
	"필드 보스는 하루에 한 번, 장마다 한 마리가 나와요.",
	"박물관에 물고기·곤충·화석을 기증하면 전시돼요.",
	"M 을 누르면 지도를 볼 수 있어요.",
	"강화가 실패해도 장비가 사라지지는 않아요… 대부분은요.",
	"따라 그리기를 꼼꼼하게 하면 '정성' 건물이 돼요.",
]

var target := ""
var _t := 0.0
var _shown := 0.0               # 막대에 보이는 값 (천천히 따라간다)
var _done := false
var _bg: TextureRect
var _pen: Texture2D            # 그리는 텍스처는 붙잡아 둬야 한다 (지역 변수만이면 그리기 전에 풀려 하얗게 나온다)
var _tip: Label
var _title: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if target == "":
		target = GameState.loading_target
	var back := ColorRect.new()
	back.color = Color(0.55, 0.36, 0.22)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	_bg = TextureRect.new()
	_bg.texture = Art.tex("bg_loading")
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_bg)
	var flip := Control.new()        # 넘어가는 장은 그림 위, 글씨 아래
	flip.set_anchors_preset(Control.PRESET_FULL_RECT)
	flip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flip.draw.connect(_draw_flip.bind(flip))
	add_child(flip)
	set_meta("flip", flip)
	var bar := Control.new()          # 연필 막대
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(_draw_bar.bind(bar))
	add_child(bar)
	set_meta("bar", bar)
	_title = UI.label(self, "%s 펼치는 중…" % Data.MAP_NAMES.get(GameState.current_map, "공책"), Vector2(BAR.position.x, BAR.position.y - 20), Vector2(BAR.size.x, 14), 10)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip = UI.label(self, "팁: " + str(TIPS[randi() % TIPS.size()]), Vector2(70, BAR.end.y + 12), Vector2(500, 14), 9)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
	_title.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))
	for l in [_title, _tip]:
		(l as Label).add_theme_color_override("font_outline_color", Color(0.3, 0.18, 0.1))
		(l as Label).add_theme_constant_override("outline_size", 4)
	if target != "":
		ResourceLoader.load_threaded_request(target)


## 지금까지 불러온 정도 (0~1)
func progress() -> float:
	if target == "":
		return 1.0
	var arr := []
	var st := ResourceLoader.load_threaded_get_status(target, arr)
	if st == ResourceLoader.THREAD_LOAD_LOADED:
		return 1.0
	if st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		return 1.0
	return float(arr[0]) if not arr.is_empty() else 0.0


func _process(delta: float) -> void:
	_t += delta
	# 막대는 불러온 정도와 보여 준 시간 중 느린 쪽을 따라간다
	var goal := minf(progress(), _t / MIN_SEC)
	_shown = move_toward(_shown, goal, delta * 1.6)
	(get_meta("flip") as Control).queue_redraw()
	(get_meta("bar") as Control).queue_redraw()
	if not _done and _shown >= 0.999:
		_done = true
		_finish.call_deferred()


func _finish() -> void:
	var scene: PackedScene = null
	if target != "":
		scene = ResourceLoader.load_threaded_get(target) as PackedScene
	GameState.loading_target = ""
	if scene:
		get_tree().change_scene_to_packed(scene)
	elif target != "":
		get_tree().change_scene_to_file(target)


## 오른쪽 장이 고리를 축으로 넘어간다. 장은 그림 속 진짜 장(오른쪽 장)을 띠로 잘라 휘어 그리고,
## 뒷면은 왼쪽 장 그림을 쓴다: 그래서 넘기기 시작할 때와 다 넘겼을 때 그림과 똑같이 맞아 떨어진다.
func _draw_flip(c: Control) -> void:
	var tex := _bg.texture
	if tex == null:
		return
	var ts := Vector2(tex.get_width(), tex.get_height())
	var s := c.size.x / ts.x                           # 그림 → 화면 배율 (16:9 그대로)
	var off := (c.size - ts * s) * 0.5
	var k := clampf(fmod(_t, FLIP_SEC + FLIP_REST) / FLIP_SEC, 0.0, 1.0)
	if k <= 0.0 or k >= 1.0:
		return
	var e := k * k * (3.0 - 2.0 * k)                  # 처음과 끝은 천천히
	var th := e * PI
	var w := PAGE_OUT - SPINE - RING
	var cy := (PAGE_Y0 + PAGE_Y1) * 0.5
	# 띠마다 꺾이는 각: 바깥쪽이 조금 앞서 넘어가 장이 휜다. 고리 폭만큼은 축에서 곧게 나온다
	var a_in := clampf(th, 0.0, PI)
	var pts_x: Array = [SPINE + RING * cos(a_in)]
	var pts_z: Array = [RING * sin(a_in)]
	var angs: Array = []
	for j in STRIPS:
		var d := (j + 0.5) / STRIPS
		var a := clampf(th + sin(th) * 0.75 * d * d, 0.0, PI)
		angs.append(a)
		pts_x.append(float(pts_x[j]) + w / STRIPS * cos(a))
		pts_z.append(float(pts_z[j]) + w / STRIPS * sin(a))
	# 들린 장 밑의 그림자 (오른쪽 장 위)
	var lift := sin(th)
	if lift > 0.01:
		var sh_w := w * (1.0 - absf(cos(th))) * 0.55 + 8.0
		var sx := SPINE + RING if th < PI * 0.5 else SPINE - RING - sh_w
		var sh := PackedVector2Array([Vector2(sx, PAGE_Y0), Vector2(sx + sh_w, PAGE_Y0), Vector2(sx + sh_w, PAGE_Y1), Vector2(sx, PAGE_Y1)])
		for i in sh.size():
			sh[i] = off + sh[i] * s
		var cols := PackedColorArray()
		var dark := Color(0.25, 0.14, 0.06, 0.28 * lift)
		var clear := Color(0.25, 0.14, 0.06, 0.0)
		if th < PI * 0.5:
			cols = PackedColorArray([dark, clear, clear, dark])
		else:
			cols = PackedColorArray([clear, dark, dark, clear])
		c.draw_polygon(sh, cols)
	# 장: 띠마다 앞면(오른쪽 장) 또는 뒷면(왼쪽 장을 거울로)
	for j in STRIPS:
		var a := float(angs[j])
		var front := a < PI * 0.5
		var u0 := float(j) / STRIPS
		var u1 := float(j + 1) / STRIPS
		var quad := PackedVector2Array()
		for q in [[j, PAGE_Y0], [j + 1, PAGE_Y0], [j + 1, PAGE_Y1], [j, PAGE_Y1]]:
			var x := float(pts_x[q[0]])
			var z := float(pts_z[q[0]])
			var y := cy + (float(q[1]) - cy) * (1.0 + z * 0.0008) - z * 0.16     # 들릴수록 조금 커지고 위로
			quad.append(off + Vector2(x, y) * s)
		var tx0 := SPINE + RING + u0 * w if front else SPINE - RING - u0 * w
		var tx1 := SPINE + RING + u1 * w if front else SPINE - RING - u1 * w
		var uvs := PackedVector2Array([Vector2(tx0, PAGE_Y0) / ts, Vector2(tx1, PAGE_Y0) / ts, Vector2(tx1, PAGE_Y1) / ts, Vector2(tx0, PAGE_Y1) / ts])
		# 빛: 램프가 왼쪽 위에 있다. 세워질수록, 뒷면일수록 어둡다
		var lit := 0.78 + 0.22 * absf(cos(a))
		if not front:
			lit *= 0.94
		var col := Color(lit, lit * 0.985, lit * 0.96, clampf(minf(k, 1.0 - k) / 0.05, 0.0, 1.0))
		c.draw_polygon(quad, PackedColorArray([col, col, col, col]), uvs, tex)
	# 바깥 가장자리 선
	var ex := float(pts_x[STRIPS])
	var ez := float(pts_z[STRIPS])
	var top := off + Vector2(ex, cy + (PAGE_Y0 - cy) * (1.0 + ez * 0.0008) - ez * 0.16) * s
	var bot := off + Vector2(ex, cy + (PAGE_Y1 - cy) * (1.0 + ez * 0.0008) - ez * 0.16) * s
	c.draw_line(top, bot, Color(0.35, 0.22, 0.14, 0.55), 1.2)


## 연필이 줄을 그으며 차오르는 막대
func _draw_bar(cv: Control) -> void:
	var s := cv.size.x / 640.0
	var r := Rect2(BAR.position * s, BAR.size * s)
	# 공책 종이 띠 (그림자, 종이, 테두리, 파란 줄)
	var strip := r.grow_individual(6 * s, 5 * s, 6 * s, 5 * s)
	cv.draw_rect(Rect2(strip.position + Vector2(2, 3) * s, strip.size), Color(0.25, 0.14, 0.06, 0.3))
	cv.draw_rect(strip, Color(0.99, 0.96, 0.88))
	cv.draw_rect(strip, Color(0.4, 0.26, 0.16), false, 1.2 * s)
	cv.draw_line(Vector2(strip.position.x + 2 * s, r.get_center().y + 3 * s), Vector2(strip.end.x - 2 * s, r.get_center().y + 3 * s), Color(0.55, 0.68, 0.9, 0.6), 1.0 * s)
	cv.draw_line(Vector2(strip.position.x + 14 * s, strip.position.y), Vector2(strip.position.x + 14 * s, strip.end.y), Color(0.9, 0.45, 0.45, 0.55), 1.0 * s)
	# 연필로 그은 선: 살짝 흔들리는 흑연 줄
	var w := r.size.x * _shown
	if w > 1.0:
		var line := PackedVector2Array()
		var x := r.position.x
		while x < r.position.x + w:
			line.append(Vector2(x, r.get_center().y + sin(x * 0.37) * 0.5 * s + sin(x * 0.11) * 0.4 * s))
			x += 2.0 * s
		line.append(Vector2(r.position.x + w, r.get_center().y))
		cv.draw_polyline(line, Color(0.25, 0.24, 0.28, 0.9), 2.6 * s)
		cv.draw_polyline(line, Color(0.45, 0.44, 0.5, 0.5), 1.0 * s)
	# 연필 (게임의 연필 그림, 끝이 선 끝에 닿아 있다)
	if _pen == null:
		_pen = Art.tex("tool_pencil")            # 촉이 왼쪽 아래인 연필 그림
	var pen := _pen
	if pen:
		var tip := Vector2(r.position.x + w, r.get_center().y + sin(_t * 30.0) * 0.6 * s)
		var ph := 34.0 * s
		var pw := ph * pen.get_width() / float(pen.get_height())
		cv.draw_texture_rect(pen, Rect2(tip - Vector2(pw * 0.07, ph * 0.93), Vector2(pw, ph)), false)
