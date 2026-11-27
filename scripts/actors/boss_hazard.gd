extends Node2D
## 보스 기술의 위험 자리 (boss_brain.gd 가 둔다).
## 빨간 과녁(원) 또는 빨간 띠(선)가 warn 초 동안 차오른 뒤 터져 그 안에 있으면 피해를 준다.
## linger 가 있으면 터진 뒤에도 그 자리에 남아 tick 초마다 약한 피해를 준다 (포자 구름, 물감 웅덩이).
## drop_tex 가 있으면 그 그림이 위에서(from 이 있으면 from 에서 포물선으로) 날아와 터지는 순간 떨어진다.

const Art := preload("res://scripts/core/art.gd")
const MonFx := preload("res://scripts/actors/mon_fx.gd")

var shape := "circle"        # "circle" 또는 "line"
var radius := 24.0           # 원의 반지름 (바닥이라 세로는 0.6 배로 납작하게 보인다)
var to := Vector2.ZERO       # 선의 끝 (전역 좌표, 시작은 position)
var width := 20.0            # 선의 굵기
var warn := 0.8
var damage := 5
var linger := 0.0
var tick := 0.6
var linger_tex := ""
var linger_w := 60.0
var drop_tex := ""
var drop_w := 24.0
var from := Vector2.INF
var burst_tex := ""          # 터질 때 그림 (없으면 충격파와 먼지)
var burst_w := 0.0
var burst_up := 0.0          # 터지는 그림을 이만큼 위에 (뿌리처럼 솟는 것)
var sound := "slam"

var _t := 0.0
var _fired := false
var _tick_t := 0.0
var _drop: Sprite2D
var _stay: Sprite2D
static var _target_tex: Texture2D


func _ready() -> void:
	z_index = -1
	if _target_tex == null:
		_target_tex = Art.tex("fx_mon_target")
	if drop_tex != "":
		_drop = _sprite(drop_tex, drop_w)
		_drop.z_index = 32
		_drop.z_as_relative = false
		_place_drop(0.0)


func _sprite(tex_name: String, w: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Art.tex(tex_name)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if s.texture:
		s.scale = Vector2.ONE * w / s.texture.get_width()
	add_child(s)
	return s


func _place_drop(k: float) -> void:
	if from == Vector2.INF:
		_drop.position = Vector2(0, -170.0 * (1.0 - k * k))   # 위에서 점점 빨리 떨어진다
	else:
		var g := from.lerp(global_position, k) + Vector2(0, -70.0 * sin(k * PI))
		_drop.position = g - global_position
	_drop.rotation = k * 9.0


func _physics_process(delta: float) -> void:
	_t += delta
	if not _fired:
		if _drop:
			_place_drop(clampf(_t / warn, 0.0, 1.0))
		queue_redraw()
		if _t >= warn:
			_fire()
		return
	_tick_t -= delta
	if _tick_t <= 0.0:
		_tick_t = tick
		_hurt(maxi(1, damage / 2))
	if _t >= warn + linger:
		set_physics_process(false)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.4)
		tw.tween_callback(queue_free)


func _fire() -> void:
	_fired = true
	_tick_t = tick
	queue_redraw()
	if _drop:
		_drop.queue_free()
		_drop = null
	var par := get_parent()
	var gp := global_position
	if shape == "line":
		var tex := Art.tex(burst_tex if burst_tex != "" else "fx_boss_slash")
		if tex:
			# 그림의 획은 왼쪽 아래 → 오른쪽 위 (-45°). 선 방향에 맞춰 돌리고 길이에 맞춘다.
			var s := Sprite2D.new()
			s.texture = tex
			s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			s.position = (gp + to) * 0.5
			s.rotation = (to - gp).angle() + PI / 4.0
			s.scale = Vector2.ONE * (gp.distance_to(to) * 1.1 / (tex.get_width() * 1.41))
			s.z_index = 30
			par.add_child(s)
			var tw := s.create_tween()
			tw.tween_property(s, "modulate:a", 0.0, 0.45).set_delay(0.15)
			tw.tween_callback(s.queue_free)
	elif burst_tex != "":
		MonFx.pop(par, burst_tex, gp + Vector2(0, -burst_up), burst_w if burst_w > 0.0 else radius * 2.4, 0.45, 0.0, 1.1)
		MonFx.ground(par, "fx_mon_dust", gp, radius * 1.6, 0.4)
	else:
		MonFx.ground(par, "fx_mon_shock", gp, radius * 2.4, 0.45, 1.25)
		MonFx.ground(par, "fx_mon_dust", gp + Vector2(0, -3), radius * 1.4, 0.4)
	if sound != "":
		Sound.play(sound, randf_range(0.9, 1.1), -4.0)
	_hurt(damage)
	if linger > 0.0 and linger_tex != "":
		_stay = _sprite(linger_tex, linger_w)
		_stay.modulate.a = 0.0
		var tw := _stay.create_tween()
		tw.tween_property(_stay, "modulate:a", 0.9, 0.25)
	if linger <= 0.0:
		queue_free()


func hits(pos: Vector2) -> bool:
	var gp := global_position
	if shape == "line":
		return Geometry2D.get_closest_point_to_segment(pos, gp, to).distance_to(pos) <= width * 0.5 + 5.0
	var d := pos - gp
	d.y /= 0.6
	return d.length() <= radius + 4.0


func _hurt(amount: int) -> void:
	var p := GameState.player_ref
	if is_instance_valid(p) and hits(p.global_position):
		var dir := p.global_position - (global_position if shape == "circle" else Geometry2D.get_closest_point_to_segment(p.global_position, global_position, to))
		p.call("take_damage", amount, dir.normalized() if dir.length() > 0.1 else Vector2.DOWN)


func _draw() -> void:
	if _fired:
		return
	var k := clampf(_t / warn, 0.0, 1.0)
	var blink := 0.55 + 0.45 * absf(sin(k * PI * (3.0 + k * 5.0)))
	if shape == "line":
		var v := to - global_position
		draw_set_transform(Vector2.ZERO, v.angle())
		var l := v.length()
		draw_rect(Rect2(0, -width * 0.5, l, width), Color(0.9, 0.2, 0.2, 0.16 * blink + 0.06))
		draw_rect(Rect2(0, -width * 0.5, l * k, width), Color(0.9, 0.2, 0.2, 0.22))
		draw_line(Vector2(0, -width * 0.5), Vector2(l, -width * 0.5), Color(0.85, 0.15, 0.15, 0.7 * blink), 1.0)
		draw_line(Vector2(0, width * 0.5), Vector2(l, width * 0.5), Color(0.85, 0.15, 0.15, 0.7 * blink), 1.0)
		draw_set_transform(Vector2.ZERO)
		return
	var w := radius * 2.0
	var h := w * 0.6
	if _target_tex:
		draw_texture_rect(_target_tex, Rect2(-w * 0.5, -h * 0.5, w, h), false, Color(1, 1, 1, blink))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
	draw_circle(Vector2.ZERO, radius * 0.84 * k, Color(0.9, 0.2, 0.2, 0.28))
	draw_set_transform(Vector2.ZERO)
