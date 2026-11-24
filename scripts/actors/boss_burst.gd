extends Node2D
## 보스가 쓰러질 때: 보스가 하얗게 번쩍이며 부풀었다가, 종이와 잉크로 크게 터진다 (그림 fx_boss_pop_0~5).
## 구겨진 종이, 찢어진 공책 조각, 잉크 방울, 반짝이(그림 boss_debris_0~5)가 사방으로 튀어 땅에 떨어지고,
## 잉크 얼룩은 땅에 잠깐 남는다.
## BossBurst.spawn(부모, 보스 Sprite2D) 로 부른다. 대화가 떠서 게임이 멈춰도 끝까지 보인다.

const Art := preload("res://scripts/core/art.gd")
const SWELL := 0.16           # 번쩍이며 부푸는 시간
const POP_FPS := 15.0
const POP_FRAMES := 6
const LIFE := 2.4
const GRAVITY := 300.0
const DEBRIS := 22

var _boss_tex: Texture2D      # 보스의 지금 모습 (프레임 하나)
var _boss_src := Rect2()
var _boss_rect := Rect2()     # 이 노드 기준 그림 자리
var _boss_flip := false
var _pop: Array = []          # 터짐 그림 6장
var _pop_size := 90.0
var _debris_tex: Array = []
var _bits: Array = []         # [{tex, pos, vel, rot, spin, size, ground, landed, ink}]
var _center := Vector2.ZERO
var _t := 0.0
var _launched := false


static func spawn(parent: Node, sprite: Sprite2D, _tint: Color = Color.BLACK) -> Node2D:
	var b: Node2D = load("res://scripts/actors/boss_burst.gd").new()
	b.global_position = sprite.global_position
	b.z_index = 30
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(b)
	b.call("_setup", sprite)
	return b


func _setup(sprite: Sprite2D) -> void:
	_boss_tex = sprite.texture
	if _boss_tex:
		var fsize := Vector2(_boss_tex.get_width() / float(maxi(1, sprite.hframes)), _boss_tex.get_height() / float(maxi(1, sprite.vframes)))
		_boss_src = Rect2(Vector2(sprite.frame_coords) * fsize, fsize)
		var local := sprite.get_rect()
		var sc := sprite.global_scale.abs()
		_boss_rect = Rect2(sprite.global_position - global_position + local.position * sc, local.size * sc)
		_boss_flip = sprite.flip_h
		_center = _boss_rect.get_center()
		_pop_size = maxf(96.0, maxf(_boss_rect.size.x, _boss_rect.size.y) * 2.0)
	for i in POP_FRAMES:
		_pop.append(Art.tex("fx_boss_pop_%d" % i))
	for i in 6:
		_debris_tex.append(Art.tex("boss_debris_%d" % i))
	Sound.play("hit", 0.5, 4.0)


func _launch() -> void:
	_launched = true
	Sound.play("boss_appear", 0.7, -1.0)
	var floor_y := _boss_rect.end.y if _boss_tex else 8.0
	for i in DEBRIS:
		var kind := i % 6
		var tex: Texture2D = _debris_tex[kind]
		if tex == null:
			continue
		var a := randf_range(PI * 1.05, PI * 1.95) if i % 3 else randf() * TAU     # 대부분 위쪽으로
		var spd := randf_range(90, 210)
		var sz := randf_range(9, 15) if kind != 5 else randf_range(7, 11)
		_bits.append({"tex": tex, "pos": _center + Vector2(randf_range(-6, 6), randf_range(-6, 6)),
			"vel": Vector2.from_angle(a) * spd + Vector2(randf_range(-30, 30), -40),
			"rot": randf() * TAU, "spin": randf_range(-9, 9) if kind != 3 else 0.0, "size": sz,
			"ground": floor_y + randf_range(-6, 14), "landed": -1.0, "ink": kind == 3 or kind == 4, "spark": kind == 5})


func _process(delta: float) -> void:
	_t += delta
	if not _launched and _t >= SWELL:
		_launch()
	for b in _bits:
		if float(b["landed"]) >= 0.0:
			b["landed"] = float(b["landed"]) + delta
			continue
		b["vel"] = (b["vel"] as Vector2) + Vector2(0, GRAVITY * delta)
		b["pos"] = (b["pos"] as Vector2) + (b["vel"] as Vector2) * delta
		b["rot"] = float(b["rot"]) + float(b["spin"]) * delta
		var p: Vector2 = b["pos"]
		if (b["vel"] as Vector2).y > 0.0 and p.y >= float(b["ground"]):
			# 땅에 닿으면 한 번 통 튀고 멈춘다 (잉크는 철퍽 퍼진다)
			if bool(b["ink"]) or absf((b["vel"] as Vector2).y) < 70.0:
				b["landed"] = 0.0
				b["pos"] = Vector2(p.x, float(b["ground"]))
			else:
				b["vel"] = Vector2((b["vel"] as Vector2).x * 0.5, -(b["vel"] as Vector2).y * 0.35)
				b["spin"] = float(b["spin"]) * 0.5
	if _t >= LIFE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	# 1. 번쩍이며 부푸는 보스
	if _boss_tex and _t < SWELL + 0.05:
		var k := clampf(_t / SWELL, 0.0, 1.0)
		var grow := 1.0 + 0.22 * k
		var r := Rect2(_center - _boss_rect.size * grow * 0.5, _boss_rect.size * grow)
		var flash := Color(1.0 + 1.3 * k, 1.0 + 1.3 * k, 1.0 + 1.3 * k, 1.0 - clampf((_t - SWELL) / 0.05, 0.0, 1.0))
		if _boss_flip:
			draw_set_transform(Vector2(r.get_center().x * 2.0, 0), 0.0, Vector2(-1, 1))
		draw_texture_rect_region(_boss_tex, r, _boss_src, flash)
		draw_set_transform(Vector2.ZERO)
	# 2. 떨어진 조각 (땅에 붙은 것이 먼저)
	var fade := 1.0 - clampf((_t - (LIFE - 0.6)) / 0.6, 0.0, 1.0)
	for b in _bits:
		var tex: Texture2D = b["tex"]
		var sz := float(b["size"])
		var landed := float(b["landed"])
		var sq := Vector2.ONE
		if landed >= 0.0 and bool(b["ink"]):
			sq = Vector2(1.0 + minf(landed * 6.0, 0.6), maxf(0.45, 1.0 - landed * 4.0))   # 철퍽
		var a := fade
		if bool(b["spark"]):
			a *= 0.6 + 0.4 * sin(_t * 30.0 + sz)
		var w := sz * tex.get_width() / float(tex.get_height())
		draw_set_transform(b["pos"], float(b["rot"]) if landed < 0.0 or not bool(b["ink"]) else 0.0, sq)
		draw_texture_rect(tex, Rect2(Vector2(-w * 0.5, -sz * 0.5), Vector2(w, sz)), false, Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO)
	# 3. 크게 터지는 그림
	if _t >= SWELL * 0.6:
		var f := int((_t - SWELL * 0.6) * POP_FPS)
		if f < POP_FRAMES and _pop[f] != null:
			var tex: Texture2D = _pop[f]
			var h := _pop_size
			var w := h * tex.get_width() / float(tex.get_height())
			draw_texture_rect(tex, Rect2(_center - Vector2(w, h) * 0.5, Vector2(w, h)), false)
