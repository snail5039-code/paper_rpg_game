extends Node2D
## 드롭 아이템: 연필심. 플레이어가 가까이 가면 빨려 들어와 획득된다.

@export var amount := 1
var _t := 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	var p := GameState.player_ref
	if is_instance_valid(p) and _t > 0.3:
		var to := p.global_position - global_position
		if to.length() < 10.0:
			GameState.add_lead(amount)
			GameState.notify("연필심 +%d  (%d개 보유)" % [amount, GameState.pencil_lead])
			queue_free()
			return
		if to.length() < 34.0:
			global_position += to.normalized() * 120.0 * delta
	queue_redraw()


func _draw() -> void:
	var y := -3.0 - absf(sin(_t * 4.0)) * 3.0
	draw_set_transform(Vector2(0, y), -0.6)
	draw_rect(Rect2(-1.5, -5, 3, 10), Color(0.3, 0.3, 0.35))
	draw_rect(Rect2(-1.5, -5, 3, 2), Color(0.55, 0.55, 0.6))
