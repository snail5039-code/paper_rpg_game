extends StaticBody2D
## NPC 1명: 퀘스트 "끊어진 다리 복구"를 준다.

@export var npc_name := "하루"
@export var use_placeholder_art := true

var _near := false


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1


func _process(_delta: float) -> void:
	var p := GameState.player_ref
	var near := is_instance_valid(p) and p.global_position.distance_to(global_position) < 26.0
	if near != _near:
		_near = near
		queue_redraw()


func interact() -> void:
	var Q := GameState.Quest
	var need := GameState.BRIDGE_COST
	var lines: Array = []
	var q := GameState.quest
	if q == Q.NOT_STARTED:
		lines = [
			"어머, 공책 마을에 온 걸 환영해!",
			"그런데 큰일이야. 강 위의 다리를 누가 지워 버렸어...",
			"저기 풀밭의 낙서 슬라임들이 연필심을 갖고 있대.",
			"연필심 %d개를 모아서 다리를 다시 그려 줄래?" % need,
			"강가에서 [Tab]을 누르면 연필 모드야. 점선을 따라 그리면 돼!",
		]
		GameState.set_quest(Q.FIND_LEAD)
	elif q == Q.FIND_LEAD:
		if GameState.pencil_lead < need:
			lines = ["연필심이 %d개 더 필요해. 슬라임을 혼내 줘! (마우스 왼쪽 클릭)" % (need - GameState.pencil_lead)]
		else:
			lines = ["연필심을 다 모았구나! 강가에서 [Tab]을 누르고 점선을 따라 다리를 그려 봐."]
	elif q == Q.BRIDGE_BUILT:
		lines = ["다리가 생겼어! 강 건너편 빨간 도리이로 가 봐."]
	else:
		lines = ["다음 페이지도 기대할게!"]
	GameState.start_dialogue(npc_name, lines)


func _draw() -> void:
	if use_placeholder_art:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2(0, 16), 6, Color(0, 0, 0, 0.18))
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(-4, -1, 8, 8), Color(0.92, 0.55, 0.65))  # 기모노
		draw_rect(Rect2(-4, 2, 8, 2), Color(0.95, 0.85, 0.4))     # 오비
		draw_rect(Rect2(-4, -1, 8, 8), Color(0.15, 0.15, 0.2), false, 1.0)
		draw_circle(Vector2(0, -6), 6, Color(1.0, 0.88, 0.78))
		draw_arc(Vector2(0, -6), 6, PI, TAU, 12, Color(0.3, 0.2, 0.15), 3.0)
		draw_circle(Vector2(0, -13), 2.5, Color(0.3, 0.2, 0.15))   # 올림머리
		draw_rect(Rect2(-3, -6, 1, 2), Color(0.1, 0.1, 0.15))
		draw_rect(Rect2(2, -6, 1, 2), Color(0.1, 0.1, 0.15))
	if _near:
		draw_rect(Rect2(-5, -27, 10, 9), Color(1, 1, 1))
		draw_rect(Rect2(-5, -27, 10, 9), Color(0.2, 0.2, 0.25), false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-3, -19.5), "F", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.2, 0.2, 0.25))
