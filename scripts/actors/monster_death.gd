extends Node2D
## 몬스터가 쓰러지는 모습. 종류마다 셋 중 하나로 쓰러진다 (이름으로 정해져서 같은 몬스터는 늘 같게).
##   flat    번쩍 → 납작하게 눌림 → 잉크 얼룩만 남음
##   spin    폴짝 뛰어올라 빙글 돌며 작아져 별가루로
##   crumple 종이 공처럼 오그라들어 데구르르 → 펑 하고 종이 부스러기
## 모두 끝에 지우개 가루가 퍼진다 (fx_die_0~3). 그림이 없으면 몸 움직임만 보인다.
##   MonsterDeath.spawn(부모, 몬스터 Sprite2D, 몬스터 종류)
## 대화가 떠서 게임이 멈춰도 끝까지 보인다.
## 보스의 마지막 일격은 MonsterDeath.boss_beat(맵 아무 노드) 로 잠깐 느려지고 하얗게 번쩍인다.

const Art := preload("res://scripts/core/art.gd")
const STYLES := ["flat", "spin", "crumple"]
const LIFE := 1.0

var style := "flat"
var _spr: Sprite2D
var _base := Vector2.ONE
var _t := 0.0
var _seed := 0.0


static func style_of(kind: String) -> String:
	return STYLES[absi(kind.hash()) % STYLES.size()]


static func spawn(parent: Node, sprite: Sprite2D, kind: String) -> Node2D:
	var n: Node2D = load("res://scripts/actors/monster_death.gd").new()
	n.set("style", style_of(kind))
	n.process_mode = Node.PROCESS_MODE_ALWAYS
	n.z_index = 6
	parent.add_child(n)
	n.global_position = sprite.global_position
	n.call("_setup", sprite)
	return n


func _setup(sprite: Sprite2D) -> void:
	_spr = sprite.duplicate()
	_spr.position = Vector2.ZERO
	_spr.show_behind_parent = false
	_spr.modulate = Color.WHITE
	add_child(_spr)
	_base = _spr.scale
	_seed = randf() * TAU
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	Sound.play("pop", 0.5, -4.0)


func _process(delta: float) -> void:
	_t += delta
	var k := _t / LIFE
	match style:
		"flat":
			var sq := smoothstep(0.08, 0.3, k)
			_spr.scale = Vector2(_base.x * (1.0 + 0.4 * sq), _base.y * (1.0 - 0.8 * sq))
			_spr.modulate = Color(1, 1, 1, 1.0 - smoothstep(0.35, 0.6, k)).lerp(Color(2.2, 2.2, 2.2, 1.0 - smoothstep(0.35, 0.6, k)), 1.0 - smoothstep(0.0, 0.12, k))
		"spin":
			var up := sin(clampf(k / 0.5, 0.0, 1.0) * PI)
			_spr.position = Vector2(0, -16.0 * up)
			_spr.rotation = k * TAU * 3.0
			var sh := 1.0 - smoothstep(0.3, 0.55, k)
			_spr.scale = _base * sh
			_spr.modulate = Color(1.6, 1.6, 1.6, sh) if k < 0.12 else Color(1, 1, 1, sh)
		"crumple":
			var ball := smoothstep(0.0, 0.3, k)
			_spr.scale = _base * (1.0 - 0.55 * ball)
			_spr.rotation = sin(k * 18.0 + _seed) * 0.18 + k * 4.0 * ball
			_spr.position = Vector2(14.0 * smoothstep(0.1, 0.5, k), 0)
			var a := 1.0 - smoothstep(0.45, 0.6, k)
			_spr.modulate = Color(0.85, 0.85, 0.85, a)
	queue_redraw()
	if _t >= LIFE:
		queue_free()


func _draw() -> void:
	var k := _t / LIFE
	var c := Vector2(0, -4)
	# 지우개 가루: 몸이 사라질 즈음 퍼졌다 흩어진다
	var pu := (k - 0.3) / 0.5
	if pu >= 0.0 and pu < 1.0:
		var t := Art.tex("fx_die_%d" % mini(3, int(pu * 4.0)))
		if t:
			var s := 40.0
			draw_texture_rect(t, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, 1.0 - pu * 0.3))
	match style:
		"flat":
			var ink := Art.tex("fx_die_ink")
			if ink and k > 0.3:
				draw_texture_rect(ink, Rect2(Vector2(-14, -4), Vector2(28, 14)), false, Color(1, 1, 1, clampf((1.0 - k) * 2.0, 0.0, 1.0)))
		"spin":
			var star := Art.tex("fx_die_star")
			if star and k > 0.35 and k < 0.8:
				var u := (k - 0.35) / 0.45
				var s := 14.0 + u * 14.0
				draw_texture_rect(star, Rect2(c - Vector2(s, s) * 0.5 + Vector2(0, -8), Vector2(s, s)), false, Color(1, 1, 1, 1.0 - u))
		"crumple":
			var bits := Art.tex("fx_die_paper")
			if bits and k > 0.5:
				var u := (k - 0.5) / 0.5
				for i in 5:
					var a := _seed + i * TAU / 5.0
					var p := c + Vector2(14, 0) + Vector2.from_angle(a) * (6.0 + u * 20.0) + Vector2(0, u * u * 10.0)
					var s := 8.0 * (1.0 - u * 0.4)
					draw_texture_rect(bits, Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, 1.0 - u))


## 보스의 마지막 일격: 시간이 잠깐 느려지고 화면이 하얗게 번쩍인다. 게임 시간은 그대로 흐르되 느리게 보일 뿐이다.
static func boss_beat(anchor: Node) -> void:
	if anchor == null or not anchor.is_inside_tree():
		return
	var tree := anchor.get_tree()
	Engine.time_scale = 0.25
	tree.create_timer(0.55, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)
	var layer := CanvasLayer.new()
	layer.layer = 27
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var rect := ColorRect.new()
	rect.color = Color(1, 1, 1, 0.75)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	tree.root.add_child(layer)
	var tw := layer.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	tw.tween_property(rect, "color:a", 0.0, 0.45)
	tw.tween_callback(layer.queue_free)
