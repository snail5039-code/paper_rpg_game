extends Node2D
## 강 건너편 도리이(목표 지점). 다리를 만든 뒤 도착하면 MVP 클리어.

var _inside := false


func _physics_process(_delta: float) -> void:
	var p := GameState.player_ref
	if not is_instance_valid(p):
		return
	var inside := p.global_position.distance_to(global_position) < 14.0
	if inside and not _inside:
		_on_reached()
	_inside = inside


func _on_reached() -> void:
	var Q := GameState.Quest
	if GameState.quest == Q.BRIDGE_BUILT:
		GameState.set_quest(Q.CLEARED)
	if GameState.quest == Q.CLEARED:
		GameState.start_dialogue("공책", [
			"도리이를 지나자 공책 페이지가 바스락 넘어가려 한다...",
			"MVP 클리어!  (다음 페이지는 개발 중입니다)",
		])


func _draw() -> void:
	var red := Color(0.85, 0.25, 0.22)
	var ink := Color(0.2, 0.15, 0.15)
	draw_rect(Rect2(-9, -18, 3, 22), red)
	draw_rect(Rect2(6, -18, 3, 22), red)
	draw_rect(Rect2(-13, -22, 26, 3), ink)
	draw_rect(Rect2(-11, -16, 22, 2), red)
