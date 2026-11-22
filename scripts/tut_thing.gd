extends Node2D
## 튜토리얼 맵에 서 있는, F 로 쓸 수 있는 것: 선생(그림 한 장)이나 집터(점선 네모).
##   label: 머리 위 이름, sprite_name: 그림 (없으면 점선 집터를 그린다), on_use: F 를 눌렀을 때 부를 것

const Art := preload("res://scripts/art.gd")
const RANGE := 40.0

var label := ""
var sprite_name := ""
var on_use: Callable
var _sprite: Sprite2D
var _key_tex: Texture2D
var _alert_tex: Texture2D
var _near := false
var _t := 0.0


func _ready() -> void:
	add_to_group("interactable")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_key_tex = Art.tex("key_f")
	_alert_tex = Art.tex("emote_alert")
	if sprite_name != "":
		show_sprite(sprite_name, 30.0)


## 그림을 보여 준다 (가로가 width 월드가 되게)
func show_sprite(tex_name: String, width: float) -> void:
	var tex := Art.tex(tex_name)
	if tex == null:
		return
	if _sprite:
		_sprite.queue_free()
	_sprite = Art.make_sprite(self, tex)
	_sprite.scale = Vector2.ONE * (width / tex.get_width())
	_sprite.show_behind_parent = true
	sprite_name = tex_name
	queue_redraw()


func interact() -> void:
	if on_use.is_valid():
		on_use.call()


func _process(delta: float) -> void:
	_t += delta
	var p := GameState.player_ref
	_near = is_instance_valid(p) and p.global_position.distance_to(global_position) < RANGE
	queue_redraw()


func _draw() -> void:
	if _sprite == null:
		# 집터: 점선 네모
		var r := Rect2(-34, -34, 68, 44)
		var col := Color(0.85, 0.35, 0.3, 0.85)
		for i in 9:
			var a := i / 9.0
			var b := a + 0.06
			draw_line(r.position + Vector2(r.size.x * a, 0), r.position + Vector2(r.size.x * b, 0), col, 1.5)
			draw_line(r.position + Vector2(r.size.x * a, r.size.y), r.position + Vector2(r.size.x * b, r.size.y), col, 1.5)
			draw_line(r.position + Vector2(0, r.size.y * a), r.position + Vector2(0, r.size.y * b), col, 1.5)
			draw_line(r.position + Vector2(r.size.x, r.size.y * a), r.position + Vector2(r.size.x, r.size.y * b), col, 1.5)
	else:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2(0, 2.0), 9, Color(0, 0, 0, 0.16))
		draw_set_transform(Vector2.ZERO)
	var top := -52.0 if _sprite else -44.0
	var mark := _key_tex if _near else _alert_tex
	if mark:
		var s := 12.0 / mark.get_width()
		var bob := absf(sin(_t * 4.0)) * 2.0
		draw_texture_rect(mark, Rect2(Vector2(-6, top - bob), mark.get_size() * s), false)
	if label != "":
		var font := ThemeDB.fallback_font
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		draw_string_outline(font, Vector2(-w * 0.5, 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, 3, Color(1, 1, 1, 0.9))
		draw_string(font, Vector2(-w * 0.5, 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.3, 0.24, 0.22))
