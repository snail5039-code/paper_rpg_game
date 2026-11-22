extends StaticBody2D
## 문방구 할아버지. F 로 말을 걸면 문방구 창(사기, 팔기, 만들기, 강화)이 열린다.

const Art := preload("res://scripts/art.gd")
const TALK_RANGE := 36.0

var hud: CanvasLayer   # 맵이 넣어 준다
var _emote: Sprite2D
var _greeted := false


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)
	var t := Art.tex("shopkeeper")
	if t:
		Art.make_sprite(self, t, Vector2(0, 6)).show_behind_parent = true
	_emote = Sprite2D.new()
	_emote.texture = Art.tex("key_f")
	_emote.scale = Art.SCALE
	_emote.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_emote.position = Vector2(0, -52)
	_emote.visible = false
	add_child(_emote)


func _process(_delta: float) -> void:
	var p := GameState.player_ref
	_emote.visible = is_instance_valid(p) and p.global_position.distance_to(global_position) < TALK_RANGE \
		and not GameState.menu_open and not GameState.dialogue_open


func interact() -> void:
	if not _greeted:
		_greeted = true
		await GameState.say("문방구 할아버지", [
			"어서 오렴. 필요한 게 있으면 골라 보거라.",
			"주인 잃은 것들도 받는단다. 선이든, 이름이든.",
		], "shop_smile")
	if hud:
		hud.call("open_shop")


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2(0, 5.0 / 0.4), 9, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO)
