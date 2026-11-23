extends Node2D
## 포탈(책갈피 문): F 로 들어가면 다른 맵으로 간다. 그림이 없어서 임시 도형으로 그린다.

const Art := preload("res://scripts/core/art.gd")
const TALK_RANGE := 36.0

var target_map := ""
var title := ""
var spawn_tag := ""
var locked := false

var _near := false
var _label: Label
var _sprite: Sprite2D


func _ready() -> void:
	add_to_group("interactable")
	var tex := Art.tex("portal_locked" if locked else "portal_open")
	if tex:
		_sprite = Art.make_sprite(self, tex, Vector2(0, 6))
		_sprite.show_behind_parent = true
	_label = Label.new()
	_label.text = title
	_label.position = Vector2(-60, -66)
	_label.size = Vector2(120, 16)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color(0.35, 0.28, 0.25) if not locked else Color(0.6, 0.58, 0.56))
	add_child(_label)


func _process(_delta: float) -> void:
	var p := GameState.player_ref
	var near := is_instance_valid(p) and p.global_position.distance_to(global_position) < TALK_RANGE
	if near != _near:
		_near = near
		queue_redraw()


func interact() -> void:
	if locked or target_map == "":
		GameState.notify("공책 마을에서 하루에게 이야기를 먼저 들어 보자." if target_map != "" else "아직 열리지 않은 페이지다.")
		return
	# 끝없는 탑: 언제나 1층부터 (난이도 단계와 상관없다)
	if target_map == "tower":
		if not GameState.start_tower():
			GameState.notify("빈 페이지 탑 (최고 기록 %d층)" % GameState.tower_best)
		return
	# 대장을 잡아 다음 단계가 열렸으면 들어가기 전에 난이도를 고른다
	var hud := get_tree().get_first_node_in_group("hud")
	if GameState.max_difficulty > 0 and hud:
		hud.call("open_menu", "portal", target_map + "|" + spawn_tag)
		return
	if not GameState.goto_map(target_map, spawn_tag):
		GameState.notify("%s (으)로 가는 문" % title)


func _draw() -> void:
	# 그림자
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2(0, 5.0 / 0.4), 14, Color(0, 0, 0, 0.15))
	draw_set_transform(Vector2.ZERO)
	if _sprite:
		if _near and not locked:
			var key_tex := Art.tex("key_f")
			if key_tex:
				var ks := Vector2(key_tex.get_width(), key_tex.get_height()) / 3.0
				draw_texture_rect(key_tex, Rect2(Vector2(-ks.x * 0.5, -84), ks), false)
		return
	# 책갈피 모양 문 (그림이 없을 때)
	var body := Color(0.86, 0.36, 0.34) if not locked else Color(0.8, 0.79, 0.77)
	var edge := Color(0.3, 0.22, 0.22) if not locked else Color(0.62, 0.6, 0.58)
	var pts := PackedVector2Array([Vector2(-13, 4), Vector2(-13, -38), Vector2(0, -46), Vector2(13, -38), Vector2(13, 4)])
	draw_colored_polygon(pts, body)
	pts.append(pts[0])
	draw_polyline(pts, edge, 1.5, true)
	draw_circle(Vector2(7, -16), 1.8, edge)
	if locked:
		draw_line(Vector2(-8, -30), Vector2(8, -8), edge, 1.5)
		draw_line(Vector2(8, -30), Vector2(-8, -8), edge, 1.5)
	elif _near:
		var key := Art.tex("key_f")
		if key:
			var size := Vector2(key.get_width(), key.get_height()) / 3.0
			draw_texture_rect(key, Rect2(Vector2(-size.x * 0.5, -78), size), false)
