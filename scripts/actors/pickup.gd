extends Node2D
## 드롭 아이템: 연필심 또는 재료. 플레이어가 가까이 가면 빨려 들어와 획득된다.
## mat_id 가 0 이상이면 재료, 아니면 연필심.

const Art := preload("res://scripts/core/art.gd")
const Data := preload("res://scripts/data/game_data.gd")
const Items := preload("res://scripts/data/items.gd")

@export var amount := 1
var mat_id := -1
var item: Dictionary = {}   # 비어 있지 않으면 장비
var _full_notice := 0.0
var _t := 0.0
var _sprite: Sprite2D


func _ready() -> void:
	var t := Art.tex("prop_lead") if mat_id < 0 else Art.tex("mat_%d" % mat_id)
	if not item.is_empty():
		t = Art.tex(Items.icon(item))
	if t:
		_sprite = Art.make_sprite(self, t)
		if not item.is_empty():
			_sprite.scale = Vector2.ONE * (16.0 / t.get_width())
			_sprite.offset = Vector2(0, -t.get_height() / 2.0)
			_sprite.modulate = Items.tier_color(item)
		elif mat_id >= 0:
			_sprite.scale = Vector2.ONE * (14.0 / t.get_width())
			_sprite.offset = Vector2(0, -t.get_height() / 2.0)


func _physics_process(delta: float) -> void:
	_t += delta
	var p := GameState.player_ref
	if is_instance_valid(p) and _t > 0.3:
		var to := p.global_position - global_position
		if to.length() < 12.0:
			if not item.is_empty():
				if not GameState.add_item(item):
					_full_notice -= delta
					if _full_notice <= 0.0:
						_full_notice = 2.0
						GameState.notify("가방이 가득 찼어요.")
					return
				GameState.notify("%s 획득!" % Items.item_name(item))
			elif mat_id >= 0:
				if not GameState.mat_room(mat_id):
					_full_notice -= delta
					if _full_notice <= 0.0:
						_full_notice = 2.0
						GameState.notify("재료 가방이 가득 찼어요.")
					return
				GameState.add_material(mat_id, amount)
				GameState.notify("%s +%d" % [Data.MATERIALS[mat_id], amount])
			else:
				GameState.add_lead(amount)
				GameState.notify("연필심 +%d  (%d개 보유)" % [amount, GameState.pencil_lead])
			Sound.play("pickup")
			queue_free()
			return
		if to.length() < 44.0:
			global_position += to.normalized() * 150.0 * delta
	if _sprite:
		_sprite.position.y = -absf(sin(_t * 4.0)) * 4.0
	else:
		queue_redraw()


func _draw() -> void:
	if _sprite:
		return
	var y := -3.0 - absf(sin(_t * 4.0)) * 3.0
	draw_set_transform(Vector2(0, y), -0.6)
	draw_rect(Rect2(-1.5, -5, 3, 10), Color(0.3, 0.3, 0.35))
	draw_rect(Rect2(-1.5, -5, 3, 2), Color(0.55, 0.55, 0.6))
