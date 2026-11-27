extends Node2D
## 주인공이 쓰러지는 장면과 다시 일어나는 장면 (그림 6칸 띠, 둘 다 컷신: 그동안 게임이 멈춘다).
##  쓰러짐 (player_down): 휘청 → 무릎 → 엎어짐 → 대자로 누움 → 지우개로 문지른 듯 흐려짐 → 거의 지워짐. 지우개 가루가 퍼진다.
##  일어남 (player_wake): 이불 속에서 잠 → 뒤척임 → 앉아서 눈 비빔 → 기지개 → 일어섬 → 서 있음. 마을 침대 위에서 시작한다.
##  PlayerFall.down(주인공, 끝나면 부를 함수) / PlayerFall.wake(주인공, 침대를 깔까)

const Art := preload("res://scripts/core/art.gd")
const FOOT := Vector2(0, 6)
## 각 칸이 나타나는 시각
const DOWN_AT := [0.0, 0.14, 0.30, 0.50, 1.10, 1.60]
const DOWN_END := 2.2
const WAKE_AT := [0.0, 0.9, 1.6, 2.2, 2.8, 3.3]
const WAKE_END := 3.8
## 지우개 가루 덩이: [나타나는 시각, 자리]
const PUFFS := [[1.05, Vector2(-9, -8)], [1.2, Vector2(8, -4)], [1.35, Vector2(-3, -14)], [1.5, Vector2(11, -12)], [1.65, Vector2(-12, -2)], [1.8, Vector2(2, -6)]]

var mode := "down"
var with_bed := false
var _player: Node2D
var _done: Callable
var _t := 0.0
var _spr: Sprite2D
var _bed: Sprite2D
var _veil: ColorRect
var _layer: CanvasLayer
var _owns_cutscene := false
var _thud := false
var _glint := false
var _finished := false


## 쓰러지는 장면을 시작한다. 그림이 없으면 바로 done 을 부른다.
static func down(player: Node2D, done: Callable) -> Node2D:
	if Art.tex("player_down") == null or not is_instance_valid(player) or player.get_parent() == null:
		done.call()
		return null
	return _start("down", player, done, false)


## 일어나는 장면을 시작한다. bed 가 참이면 그 자리에 침대를 깔고 그 위에서 눈을 뜬다.
static func wake(player: Node2D, bed: bool) -> Node2D:
	if Art.tex("player_wake") == null or not is_instance_valid(player) or player.get_parent() == null:
		return null
	return _start("wake", player, Callable(), bed)


static func _start(which: String, player: Node2D, done: Callable, bed: bool) -> Node2D:
	var n: Node2D = load("res://scripts/actors/player_fall.gd").new()
	n.set("mode", which)
	n.set("with_bed", bed)
	n.set("_player", player)
	n.set("_done", done)
	n.process_mode = Node.PROCESS_MODE_ALWAYS
	n.z_index = 20
	player.get_parent().add_child(n)
	n.global_position = player.global_position
	return n


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var tex := Art.tex("player_down" if mode == "down" else "player_wake")
	if with_bed:
		var bt := Art.tex("furn_1")
		if bt:
			_bed = Art.make_sprite(self, bt, FOOT + Vector2(0, 5), 1, 1)
			_bed.z_index = -1
	_spr = Art.make_sprite(self, tex, FOOT + (Vector2(0, -5) if with_bed else Vector2.ZERO), 6, 1)
	_player.visible = false
	if "facing" in _player:
		_player.set("facing", Vector2.DOWN)
	if not GameState.cutscene:
		GameState.set_cutscene(true)
		_owns_cutscene = true
	if mode == "wake":
		_layer = CanvasLayer.new()
		_layer.layer = 40
		add_child(_layer)
		_veil = ColorRect.new()
		_veil.color = Color(0.1, 0.08, 0.12, 1.0)
		_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(_veil)
	_apply()


func _exit_tree() -> void:
	if _finished:
		return
	# 중간에 사라지면(맵이 바뀌는 경우) 멈춰 둔 것을 풀어 준다
	if _owns_cutscene:
		GameState.set_cutscene(false)
	if mode == "wake" and is_instance_valid(_player):
		_player.visible = true


func _process(delta: float) -> void:
	_t += delta
	_apply()
	queue_redraw()
	if _t >= (DOWN_END if mode == "down" else WAKE_END):
		_finish()


func _apply() -> void:
	var at: Array = DOWN_AT if mode == "down" else WAKE_AT
	var f := 0
	for i in at.size():
		if _t >= float(at[i]):
			f = i
	_spr.frame = f
	if mode == "down":
		if not _thud and _t >= 0.5:
			_thud = true
			Sound.play("hit", 0.6, -3.0)
		# 마지막 칸부터는 서서히 지워진다
		_spr.modulate.a = 1.0 - smoothstep(1.4, 2.1, _t) * 0.85 if _t > 1.4 else 1.0
	else:
		if _veil:
			_veil.color.a = 1.0 - smoothstep(0.0, 0.9, _t)
		if not _glint and _t >= float(WAKE_AT[4]):
			_glint = true
			Sound.play("levelup", 0.5, -8.0)
		# 이불이 걷히는 만큼 침대도 서서히 사라진다
		if _bed and _t > WAKE_END - 0.6:
			var a := clampf((WAKE_END - _t) / 0.6, 0.0, 1.0)
			_bed.modulate.a = a
			_spr.position = FOOT + Vector2(0, -5.0 * a)


func _draw() -> void:
	if mode == "down":
		for p in PUFFS:
			var u := (_t - float(p[0])) / 0.55
			if u < 0.0 or u >= 1.0:
				continue
			var t := Art.tex("fx_die_%d" % mini(3, int(u * 4.0)))
			if t:
				var s := 24.0
				draw_texture_rect(t, Rect2((p[1] as Vector2) + FOOT - Vector2(s, s) * 0.5 - Vector2(0, 6), Vector2(s, s)), false, Color(1, 1, 1, 1.0 - u * 0.4))
		var rub := Art.tex("fx_die_rub")
		if rub and _t > 1.0 and _t < 1.9:
			var sw := sin((_t - 1.0) * 16.0) * 10.0
			draw_texture_rect(rub, Rect2(Vector2(sw - 14, -6), Vector2(28, 14)), false, Color(1, 1, 1, 0.8))
	else:
		# 쿨쿨: 자는 동안 z 가 떠오른다
		if _t < float(WAKE_AT[2]):
			var font := ThemeDB.fallback_font
			for i in 3:
				var u := fposmod(_t * 0.7 + i / 3.0, 1.0)
				draw_string(font, Vector2(8 + u * 6.0, -14 - u * 16.0), "z" if i < 2 else "Z", HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(8 + u * 5.0), Color(0.3, 0.35, 0.55, 1.0 - u))
		# 일어서면 노란 고리와 반짝임
		if _t >= float(WAKE_AT[4]):
			var u := clampf((_t - float(WAKE_AT[4])) / 0.8, 0.0, 1.0)
			var ring := Art.tex("fx_die_ring")
			if ring:
				var s := 20.0 + u * 28.0
				draw_texture_rect(ring, Rect2(FOOT + Vector2(-s * 0.5, -s * 0.5 - 4), Vector2(s, s)), false, Color(1, 1, 1, 1.0 - u))
			var gl := Art.tex("fx_die_glint")
			if gl:
				var s := 16.0
				draw_texture_rect(gl, Rect2(Vector2(-s * 0.5, -22 - u * 6.0), Vector2(s, s)), false, Color(1, 1, 1, 1.0 - u))


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if _owns_cutscene:
		GameState.set_cutscene(false)
	if mode == "wake":
		if is_instance_valid(_player):
			_player.visible = true
			_player.set("_invuln", 1.5)
		GameState.notify("눈을 떴다. 다시 힘을 내자!")
	elif _done.is_valid():
		_done.call()
	queue_free()
