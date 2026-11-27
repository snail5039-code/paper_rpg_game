extends Sprite2D
## 보스가 쏘는 탄 (체크표, 지우개 가루, 낙서 공, 물감 방울). 곧게 날아가다 주인공에 닿으면 피해를 주고 사라진다.
## puddle 이 있으면 다 날아간 자리에 그 설정으로 위험 자리(boss_hazard.gd)를 남긴다 (물감 웅덩이).

const Art := preload("res://scripts/core/art.gd")
const Hazard := preload("res://scripts/actors/boss_hazard.gd")
## 그림이 바라보는 쪽 (오른쪽이 0). 물감 방울은 머리가 왼쪽이다.
const FACING := {"fx_boss_paint": PI}

var vel := Vector2.ZERO
var life := 2.0
var hit_r := 8.0
var damage := 4
var spin := 0.0
var puddle: Dictionary = {}
var _t := 0.0


static func fire(parent: Node, tex_name: String, at: Vector2, v: Vector2, w: float, dmg: int, life_s := 2.0, spin_s := 0.0) -> Sprite2D:
	var s: Sprite2D = load("res://scripts/actors/boss_shot.gd").new()
	s.texture = Art.tex(tex_name)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if s.texture:
		s.scale = Vector2.ONE * w / s.texture.get_width()
	s.global_position = at
	s.set("vel", v)
	s.set("damage", dmg)
	s.set("life", life_s)
	s.set("spin", spin_s)
	s.set("hit_r", maxf(6.0, w * 0.45))
	s.z_index = 25
	if spin_s == 0.0:
		s.rotation = v.angle() + float(FACING.get(tex_name, 0.0))
	parent.add_child(s)
	return s


func _physics_process(delta: float) -> void:
	_t += delta
	global_position += vel * delta
	if spin != 0.0:
		rotation += spin * delta
	var p := GameState.player_ref
	if is_instance_valid(p) and (p.global_position + Vector2(0, -6)).distance_to(global_position) <= hit_r + 6.0:
		p.call("take_damage", damage, vel.normalized())
		_end(false)
		return
	if _t >= life:
		_end(true)


func _end(leave_puddle: bool) -> void:
	set_physics_process(false)
	if leave_puddle and not puddle.is_empty():
		var h: Node2D = Hazard.new()
		for k in puddle:
			h.set(k, puddle[k])
		h.position = global_position + Vector2(0, 6)
		get_parent().add_child(h)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)
