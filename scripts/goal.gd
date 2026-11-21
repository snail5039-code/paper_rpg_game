extends Node2D
## 강 건너편 빨간 문(목표 지점). 다리를 만든 뒤 도착하면 MVP 클리어.
## 문 그림은 배경에 이미 있고, 다리가 완성되면 그 위에서 반짝이는 문 스프라이트가 켜진다.

const Art := preload("res://scripts/art.gd")

const DOOR_FOOT := Vector2(-2, -4)

var _inside := false
var _t := 0.0
var _sprite: Sprite2D


func _ready() -> void:
	var t := Art.tex("prop_door")
	if t:
		_sprite = Art.make_sprite(self, t, DOOR_FOOT)
		_sprite.visible = false


func _physics_process(delta: float) -> void:
	_t += delta
	if _sprite:
		# 다리가 생기면 문이 "열릴 준비"가 된 것처럼 깜빡인다
		_sprite.visible = GameState.bridge_built
		_sprite.modulate.a = 0.55 + 0.45 * absf(sin(_t * 2.5))
	var p := GameState.player_ref
	if not is_instance_valid(p):
		return
	var inside := p.global_position.distance_to(global_position) < 20.0
	if inside and not _inside:
		_on_reached()
	_inside = inside


func _on_reached() -> void:
	var Q := GameState.Quest
	if GameState.quest == Q.BRIDGE_BUILT:
		GameState.set_quest(Q.CLEARED)
	if GameState.quest == Q.CLEARED:
		GameState.start_dialogue("공책", [
			"빨간 문을 열자 공책 페이지가 바스락 넘어가려 한다...",
			"MVP 클리어!  (다음 페이지는 개발 중입니다)",
		])


func _draw() -> void:
	if _sprite:
		return
	var red := Color(0.85, 0.25, 0.22)
	var ink := Color(0.2, 0.15, 0.15)
	draw_rect(Rect2(-9, -18, 3, 22), red)
	draw_rect(Rect2(6, -18, 3, 22), red)
	draw_rect(Rect2(-13, -22, 26, 3), ink)
	draw_rect(Rect2(-11, -16, 22, 2), red)
