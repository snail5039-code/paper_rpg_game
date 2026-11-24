extends StaticBody2D
## 사냥터의 나무 한 그루. F 를 누르면:
##   도끼를 들었으면 벤다 (세 번 찍으면 쓰러진다) → 통나무·나뭇가지. 그루터기가 되었다가 다음 날 다시 자란다.
##   아니면 맨손으로 흔든다 → 밤·도토리·사과 같은 열매가 1~3개 떨어진다. 하루에 한 번.
## 오늘 한 일은 GameState.foraged 에 적힌다 (tree_done, shake_tree, chop_tree).

const Art := preload("res://scripts/core/art.gd")
const Items := preload("res://scripts/data/items.gd")
const RANGE := 30.0
const TREE_H := 62.0        # 나무 그림의 높이 (월드)
const STUMP_H := 18.0
const CHOPS := 3            # 이만큼 찍으면 쓰러진다

var key := ""               # "화면:tree번호"
var look := 0               # 0: 1장 크레용 나무, 1: 2장 색연필 나무
var hits := 0               # 이번에 찍은 횟수 (화면을 나가면 처음부터)

var _tree_tex: Texture2D
var _stump_tex: Texture2D
var _key_tex: Texture2D
var _sway := 0.0            # 흔들림 세기 (0~1, 줄어든다)
var _sway_t := 0.0
var _fall := -1.0           # 쓰러지는 중 (0 → 1)
var _falling: Array = []    # 떨어지는 열매 [{tex, from, to, t}]
var _busy := false


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("tree")
	collision_layer = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)
	_tree_tex = Art.tex("tree_%d" % look)
	_stump_tex = Art.tex("stump_%d" % look)
	_key_tex = Art.tex("key_f")


func is_stump() -> bool:
	return GameState.tree_done(key, "chop") and _fall < 0.0


func _process(delta: float) -> void:
	_sway = maxf(0.0, _sway - delta * 1.6)
	_sway_t += delta
	if _fall >= 0.0:
		_fall = minf(1.0, _fall + delta * 1.8)
	for f in _falling:
		f["t"] = float(f["t"]) + delta * 1.7
	queue_redraw()


func interact() -> void:
	if _busy:
		return
	var p: Node2D = GameState.player_ref
	if is_instance_valid(p) and p.has_method("is_acting") and bool(p.call("is_acting")):
		return
	GameState.tip("tree", "도끼를 들고 F: 나무를 베어 통나무를 얻어요. 맨손(무기)으로 F: 나무를 흔들어 열매를 떨어뜨려요.")
	if GameState.tree_done(key, "chop"):
		GameState.notify("나무를 벤 자리예요. 내일이면 다시 자라요.")
		return
	if str(GameState.life_tool().get("life", "")) == "axe":
		_chop(p)
	else:
		_shake()


# ---------- 베기 ----------
func _chop(p: Node2D) -> void:
	if is_instance_valid(p) and p.has_method("act") and p.is_inside_tree():
		_busy = true
		p.call("act", "life_axe", global_position - p.global_position, 0.35, false, _hit)
	else:
		_hit()


func _hit() -> void:
	_busy = false
	hits += 1
	_sway = 0.5
	Sound.play("hit", 0.6, -2.0)
	if hits < CHOPS:
		return
	var got := GameState.chop_tree(key)
	if got.is_empty():
		return
	_fall = 0.0
	Sound.play("hit", 0.45, 2.0)
	var parts: Array = []
	for id in got:
		parts.append("%s %d개" % [Items.CONSUMABLES[id][0], int(got[id])])
	GameState.notify("나무를 베었어요! %s" % ", ".join(parts))


# ---------- 흔들기 ----------
func _shake() -> void:
	_sway = 1.0
	Sound.play("cut", 0.7, -4.0)
	if GameState.tree_done(key, "shake"):
		GameState.notify("오늘은 더 떨어질 게 없어요. 내일 다시 흔들어 봐요.")
		return
	var got := GameState.shake_tree(key)
	if got.is_empty():
		return
	var names: Array = []
	for i in got.size():
		var id := str(got[i])
		names.append(str(Items.CONSUMABLES[id][0]))
		var from := Vector2(randf_range(-16, 16), -TREE_H * randf_range(0.55, 0.8))
		var to := Vector2(randf_range(-20, 20), randf_range(4, 12))
		_falling.append({"tex": Art.tex(str(Items.CONSUMABLES[id][1])), "from": from, "to": to, "t": -0.18 * i})
	GameState.notify("나무에서 %s 이(가) 떨어졌어요!" % ", ".join(names))


func _draw() -> void:
	# 그림자
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2(0, 2.0 / 0.4), 13 if not is_stump() else 9, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO)
	if is_stump():
		_draw_tex(_stump_tex, STUMP_H, 0.0, Color.WHITE, Color(0.55, 0.38, 0.22))
	else:
		var ang := sin(_sway_t * 22.0) * 0.06 * _sway
		var a := 1.0
		if _fall >= 0.0:
			ang = _fall * _fall * 1.45          # 오른쪽으로 쓰러진다
			a = 1.0 - maxf(0.0, _fall - 0.6) / 0.4
			if _fall >= 1.0:
				a = 0.0
		draw_set_transform(Vector2.ZERO, ang)
		_draw_tex(_tree_tex, TREE_H, 0.0, Color(1, 1, 1, a), Color(0.3, 0.6, 0.3, a))
		draw_set_transform(Vector2.ZERO)
		if _fall >= 1.0:
			_fall = -1.0
	# 떨어지는 열매: 나무 위에서 땅으로 통통
	for f in _falling:
		var t := clampf(float(f["t"]), 0.0, 1.0)
		if float(f["t"]) < 0.0 or f["tex"] == null:
			continue
		var pos: Vector2 = (f["from"] as Vector2).lerp(f["to"], t) + Vector2(0, -sin(t * PI) * 6.0)
		var fade := 1.0 - clampf((float(f["t"]) - 1.6) / 0.4, 0.0, 1.0)
		var tex: Texture2D = f["tex"]
		var h := 9.0
		var w := h * tex.get_width() / float(tex.get_height())
		draw_texture_rect(tex, Rect2(pos - Vector2(w * 0.5, h), Vector2(w, h)), false, Color(1, 1, 1, fade))
	_falling = _falling.filter(func(f): return float(f["t"]) < 2.0)
	# F 키
	var p := GameState.player_ref
	if _key_tex and not _busy and is_instance_valid(p) and p.global_position.distance_to(global_position) < RANGE:
		var kh := 10.0
		var kw := kh * _key_tex.get_width() / float(_key_tex.get_height())
		var top := -(STUMP_H if is_stump() else TREE_H) - 14.0
		draw_texture_rect(_key_tex, Rect2(Vector2(-kw * 0.5, top), Vector2(kw, kh)), false)


func _draw_tex(tex: Texture2D, h: float, dx: float, mod: Color, fallback: Color) -> void:
	if tex == null:
		draw_rect(Rect2(Vector2(-3 + dx, -h), Vector2(6, h)), fallback.darkened(0.3))
		draw_circle(Vector2(dx, -h * 0.75), h * 0.35, fallback)
		return
	var w := h * tex.get_width() / float(tex.get_height())
	draw_texture_rect(tex, Rect2(Vector2(-w * 0.5 + dx, -h + 3), Vector2(w, h)), false, mod)
