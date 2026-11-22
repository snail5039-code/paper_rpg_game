extends Control
## 낚시 (내 마을의 낚시터, 1장 마을의 강가에서 F). 창을 띄우지 않고 캐릭터가 직접 낚싯대를 던진다.
##   1. 낚싯대를 휘둘러 찌를 물에 던지고 기다린다 (1.2 ~ 3초). 이때 F 를 누르면 너무 일러서 놓친다.
##   2. 찌가 쑥 들어가며 "!" 가 뜨면 0.7초 안에 F 를 누른다 (정성 낚시터는 1초).
##   3. 끌어올리기: F 를 누르고 있으면 찌가 올라가고 떼면 내려간다. 찌를 초록 칸 안에 두면 게이지가 찬다.
##      게이지가 다 차면 낚는다. 7초 안에 못 채우면 놓친다.
##   잡은 것은 가방의 소모품에 들어간다. 낮과 밤, 낚시터마다 낚이는 것이 다르다.
## Esc 로 그만둔다. 게임은 멈추지 않는다 (맞으면 낚시가 끊긴다).
## 이 노드는 HUD 위에서 찌, 낚싯줄, 게이지를 그린다 (월드 좌표를 화면 좌표로 바꿔서).

const UI := preload("res://scripts/ui_kit.gd")
const Items := preload("res://scripts/items.gd")

const REEL_TIME := 7.0
const FILL_TIME := 2.0       # 초록 칸 안에 이만큼 머물면 낚는다
const CAST_TIME := 0.3       # 낚싯대를 휘두르는 시간
const CAST_REACH := 52.0     # 물의 자리를 모를 때 찌가 떨어지는 거리
const BAR_SIZE := Vector2(8, 54)

var phase := ""              # "", "wait", "bite", "reel", "result"
var window := 0.7
var place := "home"
var progress := 0.0          # 끌어올리기 게이지 (0 ~ 1)
var bobber := Vector2.ZERO   # 찌가 떠 있는 자리 (월드)
var _zone_half := 0.17
var _pos := 0.3              # 찌의 높이 (0 아래 ~ 1 위)
var _vel := 0.0
var _zone := 0.5
var _t := 0.0
var _wait := 2.0
var _cast_t := 0.0           # 던진 뒤 흐른 시간 (찌가 날아가는 동안)
var _caught := ""
var _label: Label
var _mark: Label
var _gauge: Control
var _tex: Dictionary = {}    # 찌, 물보라, 잡은 것의 그림 (계속 쥐고 있어야 한다)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(640, 360)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge = Control.new()
	_gauge.size = size
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.draw.connect(_draw_gauge)
	add_child(_gauge)
	_label = UI.label(self, "", Vector2.ZERO, Vector2(220, 14), 9)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0.25, 0.18, 0.15))
	_label.add_theme_constant_override("outline_size", 4)
	_mark = UI.label(self, "", Vector2.ZERO, Vector2(40, 30), 24)
	_mark.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	_mark.add_theme_constant_override("outline_size", 5)
	_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mark.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	_mark.pivot_offset = Vector2(20, 15)
	_tex["bobber"] = UI.tex("life_bobber")
	_tex["splash"] = UI.tex("life_splash")


func is_active() -> bool:
	return phase != ""


func _player() -> Node2D:
	var p: Node2D = GameState.player_ref
	return p if is_instance_valid(p) else null


## at: 찌를 던질 물의 자리 (월드). 주지 않으면 보는 쪽 앞에 던진다.
func start(fine: bool = false, where: String = "home", at: Vector2 = Vector2.INF) -> void:
	if is_active():
		return
	window = 1.0 if fine else 0.7
	_zone_half = 0.21 if fine else 0.17
	place = where
	visible = true
	var p := _player()
	if p:
		var dir: Vector2 = p.get("facing")
		if at != Vector2.INF and at.distance_to(p.global_position) > 8.0 and at.distance_to(p.global_position) < 110.0:
			dir = (at - p.global_position).normalized()
			bobber = at
		else:
			bobber = p.global_position + dir * CAST_REACH
		if p.has_method("act"):
			p.call("act", "life_rod", dir, CAST_TIME, true)
	GameState.changed.emit()
	_cast()


func _cast() -> void:
	phase = "wait"
	_t = 0.0
	_cast_t = 0.0
	_wait = randf_range(1.2, 3.0)
	_mark.text = ""
	_mark.scale = Vector2.ONE
	_caught = ""
	_label.text = "! 가 뜨면 F   ·   Esc 그만두기"
	Sound.play("cast")


func _process(delta: float) -> void:
	if phase == "":
		return
	var p := _player()
	if p and p.has_method("is_acting") and not bool(p.call("is_acting")):
		stop()          # 맞거나 해서 자세가 풀렸다
		return
	_t += delta
	var before := _cast_t
	_cast_t += delta
	if before < CAST_TIME and _cast_t >= CAST_TIME:
		Sound.play("plop")
	match phase:
		"wait":
			if _t >= _wait:
				phase = "bite"
				_t = 0.0
				_mark.text = "!"
				_label.text = "지금이에요! F"
				Sound.play("bite")
		"bite":
			_mark.scale = Vector2.ONE * (1.0 + 0.15 * sin(_t * 30.0))
			if _t >= window:
				_result("")
		"reel":
			var held := Input.is_physical_key_pressed(KEY_F) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			step_reel(delta, held)
		"result":
			if _t >= 1.3:
				_cast()
	_layout()
	_gauge.queue_redraw()


## 끌어올리기 한 프레임. held: F 를 누르고 있는지. (테스트에서 직접 부를 수 있다)
func step_reel(delta: float, held: bool) -> void:
	if phase != "reel":
		return
	_vel += (2.4 if held else -1.8) * delta
	_vel = clampf(_vel, -0.9, 0.9)
	_pos += _vel * delta
	if _pos <= 0.0 or _pos >= 1.0:
		_pos = clampf(_pos, 0.0, 1.0)
		_vel = 0.0
	_zone = 0.5 + 0.26 * sin(_t * 1.2)
	if absf(_pos - _zone) <= _zone_half:
		progress += delta / FILL_TIME
	else:
		progress = maxf(0.0, progress - delta / (FILL_TIME * 2.0))
	if progress >= 1.0:
		_result(GameState.catch_fish(place))
	elif _t >= REEL_TIME:
		_result("")


## 입질에 맞춰 챈다. 맞으면 끌어올리기로 넘어간다 (true). 너무 이르면 놓친다.
func pull() -> bool:
	if phase == "bite":
		phase = "reel"
		_t = 0.0
		progress = 0.0
		_pos = 0.3
		_vel = 0.0
		_mark.text = ""
		_label.text = "F 를 눌렀다 뗐다 하며 빨간 찌를 초록 칸에!"
		return true
	if phase == "wait":
		_result("")
	return false


func _result(id: String) -> void:
	phase = "result"
	_t = 0.0
	_mark.text = ""
	_caught = id
	if id == "":
		_label.text = "놓쳤어요…"
	else:
		_tex["catch"] = UI.tex(str(Items.CONSUMABLES[id][1]))
		_label.text = "%s 을(를) 낚았어요!" % Items.CONSUMABLES[id][0]
		Sound.play("reel")


func stop() -> void:
	if phase == "":
		return
	phase = ""
	visible = false
	var p := _player()
	if p and p.has_method("stop_act"):
		p.call("stop_act")
	GameState.changed.emit()


func _input(event: InputEvent) -> void:
	if phase == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			stop()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_F:
			if phase != "reel":
				pull()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()      # 낚시하는 동안에는 공격하지 않는다


# ---------- 그리기 (월드 → 화면) ----------

func _screen(world: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world


## 찌가 지금 있는 자리 (화면): 던지는 동안은 낚싯대 끝에서 날아가고, 그다음에는 물 위에서 흔들린다
func _bobber_screen() -> Vector2:
	var target := _screen(bobber)
	var k := clampf(_cast_t / CAST_TIME, 0.0, 1.0)
	if k < 1.0:
		var from := _tip_screen()
		return from.lerp(target, k) + Vector2(0, -sin(k * PI) * 26.0)
	var dip := 0.0
	match phase:
		"wait": dip = sin(_cast_t * 3.0) * 1.2
		"bite": dip = 4.0 + sin(_t * 30.0) * 1.5
		"reel": dip = 3.0 + sin(_t * 14.0) * 2.0
	return target + Vector2(0, dip)


func _tip_screen() -> Vector2:
	var p := _player()
	if p == null:
		return _screen(bobber) + Vector2(0, -30)
	if p.has_method("act_tip"):
		return _screen(p.call("act_tip"))
	return _screen(p.global_position + Vector2(0, -24))


func _layout() -> void:
	var p := _player()
	var head := _screen(p.global_position) + Vector2(0, -58) if p else Vector2(320, 120)
	_label.position = Vector2(clampf(head.x - 110.0, 4.0, 416.0), clampf(head.y, 4.0, 340.0))
	_mark.position = _bobber_screen() + Vector2(-20, -40)


func _draw_gauge() -> void:
	if phase == "":
		return
	var g := _gauge
	var tip := _tip_screen()
	var bob := _bobber_screen()
	var shown := not (phase == "result" and _caught != "")
	if shown:
		# 낚싯줄: 가운데가 살짝 처진다
		var mid := (tip + bob) * 0.5 + Vector2(0, 8.0 if phase != "reel" else 2.0)
		var pts := PackedVector2Array()
		for i in 13:
			var k := i / 12.0
			pts.append(tip.lerp(mid, k).lerp(mid.lerp(bob, k), k))
		g.draw_polyline(pts, Color(0.95, 0.95, 0.95, 0.9), 1.0)
		var bt: Texture2D = _tex.get("bobber")
		if bt:
			g.draw_texture_rect(bt, Rect2(bob - Vector2(9, 12), Vector2(18, 18)), false)
		else:
			g.draw_circle(bob, 3.0, Color(0.9, 0.3, 0.3))
		var st: Texture2D = _tex.get("splash")
		if st and (phase == "bite" or (_cast_t >= CAST_TIME and _cast_t < CAST_TIME + 0.25)):
			g.draw_texture_rect(st, Rect2(bob - Vector2(12, 14), Vector2(24, 18)), false)
	if phase == "result" and _caught != "":
		# 낚은 것이 찌 자리에서 캐릭터 쪽으로 튀어 오른다
		var ct: Texture2D = _tex.get("catch")
		var k2 := clampf(_t / 0.5, 0.0, 1.0)
		var at := _screen(bobber).lerp(tip, k2) + Vector2(0, -sin(k2 * PI) * 30.0)
		if ct:
			g.draw_texture_rect(ct, Rect2(at - Vector2(12, 12), Vector2(24, 24)), false)
	if phase != "reel":
		return
	# 끌어올리기 게이지: 캐릭터 옆의 세로 막대(초록 칸과 빨간 찌), 그 아래의 진행 막대
	var p := _player()
	var base := _screen(p.global_position) + Vector2(26, -52) if p else Vector2(430, 120)
	var bar := Rect2(base, BAR_SIZE)
	g.draw_rect(bar.grow(2), Color(0.35, 0.27, 0.24))
	g.draw_rect(bar, Color(0.8, 0.9, 1.0))
	var zy := bar.end.y - (_zone + _zone_half) * bar.size.y
	g.draw_rect(Rect2(bar.position.x, zy, bar.size.x, _zone_half * 2.0 * bar.size.y).intersection(bar), Color(0.5, 0.85, 0.5))
	var by := bar.end.y - _pos * bar.size.y
	g.draw_rect(Rect2(bar.position.x - 2, by - 2, bar.size.x + 4, 4), Color(0.9, 0.35, 0.3))
	var prog := Rect2(base + Vector2(-34, BAR_SIZE.y + 6), Vector2(44, 5))
	g.draw_rect(prog.grow(1), Color(0.35, 0.27, 0.24))
	g.draw_rect(Rect2(prog.position, Vector2(prog.size.x * clampf(progress, 0.0, 1.0), prog.size.y)), Color(1.0, 0.8, 0.35))
	g.draw_rect(Rect2(prog.position + Vector2(0, 7), Vector2(prog.size.x * clampf(1.0 - _t / REEL_TIME, 0.0, 1.0), 2)), Color(0.8, 0.8, 0.85))
