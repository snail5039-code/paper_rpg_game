extends StaticBody2D
## 내 마을에 지은 건물이나 놓은 소품 하나. 종류는 game_data.gd 의 BUILDS 표.
##  건물은 F 로 쓸 수 있다: 내 집(잠자기), 문방구, 조합대. 나머지는 아직 준비 중.
##  "정성"으로 지은 건물(따라 그리기 85% 이상)은 지붕 위에 별이 반짝인다.

const Art := preload("res://scripts/art.gd")
const Data := preload("res://scripts/game_data.gd")
const RANGE := 44.0

var id := "deco_bush"
var fine := false
var ghost := false          # 놓을 자리를 고르는 중인 흐린 그림 (부딪히지 않는다)
var info: Dictionary
var _sprite: Sprite2D
var _star: Texture2D
var _key: Texture2D
var _t := 0.0
var _height := 20.0


func _ready() -> void:
	info = Data.BUILDS.get(id, Data.BUILDS["deco_bush"])
	_star = Art.tex("fx_hit")
	_key = Art.tex("key_f")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var tex := Art.tex(id)
	var w := float(info["w"])
	if tex:
		_sprite = Art.make_sprite(self, tex, Vector2(0, 4))
		_sprite.scale = Vector2.ONE * (w / tex.get_width())
		_sprite.show_behind_parent = true
		_height = tex.get_height() * w / tex.get_width()
	if ghost:
		modulate = Color(1, 1, 1, 0.55)
		collision_layer = 0
		return
	collision_layer = 1 if not bool(info.get("walk", false)) else 0
	if collision_layer != 0:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(w * 0.8, maxf(8.0, _height * 0.3))
		shape.shape = rect
		shape.position = Vector2(0, 4 - rect.size.y * 0.5)
		add_child(shape)
	if str(info["kind"]) == "building":
		add_to_group("interactable")
	add_to_group("home_object")


func _process(delta: float) -> void:
	_t += delta
	if fine or is_in_group("interactable"):
		queue_redraw()


func interact() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	match str(info.get("use", "")):
		"sleep":
			GameState.sleep()
			var p := GameState.player_ref
			if is_instance_valid(p):
				p.set("hp", p.get("max_hp"))
				p.set("mp", float(p.get("max_mp")))
				p.emit_signal("hp_changed", p.get("hp"), p.get("max_hp"))
			GameState.notify("푹 잤어요. HP 와 MP 가 가득 찼고 저장했어요.")
		"shop":
			if hud:
				hud.call("open_shop", 0)
		"craft":
			if hud:
				hud.call("open_shop", 2)
		_:
			GameState.notify("%s: 아직 준비 중이에요." % info["name"])


func _draw() -> void:
	if ghost:
		return
	if fine and _star:
		var s := 10.0 + sin(_t * 4.0) * 2.0
		draw_texture_rect(_star, Rect2(Vector2(-s * 0.5, -_height - 6.0), Vector2(s, s)), false)
	var p := GameState.player_ref
	if is_in_group("interactable") and _key and is_instance_valid(p) and p.global_position.distance_to(global_position) < RANGE:
		var h := 10.0
		var w := h * _key.get_width() / float(_key.get_height())
		draw_texture_rect(_key, Rect2(Vector2(-w * 0.5, -_height - 20.0), Vector2(w, h)), false)
