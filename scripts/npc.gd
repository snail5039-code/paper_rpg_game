extends StaticBody2D
## 하루: 주인공이 이 공책에 맨 처음 그린 친구. 길잡이 역할.
## 퀘스트 "끊어진 다리 복구"를 준다.

const Art := preload("res://scripts/art.gd")
const IDLE_FRAME := 1
const TALK_RANGE := 40.0
const NOTICE_RANGE := 120.0

@export var npc_name := "하루"
@export var use_placeholder_art := true

var _near := false
var _sprite: Sprite2D
var _emote: Sprite2D
var _emote_name := ""
var _heart_timer := 0.0
var _talking := false


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	var t := Art.tex("npc_walk")
	if t:
		use_placeholder_art = false
		_sprite = Art.make_sprite(self, t, Vector2(0, 6), 4, 4)
		_sprite.frame_coords = Vector2i(IDLE_FRAME, 0)
		_sprite.show_behind_parent = true
	_emote = Sprite2D.new()
	_emote.scale = Art.SCALE
	_emote.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_emote.position = Vector2(0, -46)
	_emote.visible = false
	add_child(_emote)


func _process(delta: float) -> void:
	_heart_timer = maxf(0.0, _heart_timer - delta)
	var p := GameState.player_ref
	var dist := p.global_position.distance_to(global_position) if is_instance_valid(p) else INF
	_near = dist < TALK_RANGE
	if _sprite:
		# 플레이어가 가까이 오면 그쪽을 바라보고, 멀어지면 정면
		var row := Art.dir_row(p.global_position - global_position) if dist < NOTICE_RANGE else 0
		_sprite.frame_coords = Vector2i(IDLE_FRAME, row)

	# 머리 위 표시: 하트(기쁨) > F 키(말 걸 수 있음) > 느낌표(처음 발견)
	var want := ""
	if _heart_timer > 0.0:
		want = "emote_heart"
	elif _near:
		want = "key_f"
	elif GameState.quest == GameState.Quest.NOT_STARTED and dist < NOTICE_RANGE:
		want = "emote_alert"
	if want != _emote_name:
		_emote_name = want
		var tex := Art.tex(want) if want != "" else null
		_emote.texture = tex
		_emote.visible = tex != null
		queue_redraw()
	if _emote.visible:
		_emote.position.y = -46.0 - absf(sin(Time.get_ticks_msec() / 260.0)) * 2.0


func interact() -> void:
	if _talking:
		return
	_talking = true
	var Q := GameState.Quest
	var need := GameState.BRIDGE_COST
	var q := GameState.quest
	if q == Q.NOT_STARTED:
		await GameState.say(npc_name, ["어…? 혹시… 그린이야?!"], "haru_surprised")
		await GameState.say(npc_name, [
			"나야, 하루! 네가 이 공책에 맨 처음 그려 준 친구!",
			"진짜 오랜만이다. 다시 와 줘서 기뻐!",
		], "haru_smile")
		await GameState.say("나", ["하루…! 기억나. 그런데 마을이 왜 이렇게 허전해?"], "player")
		await GameState.say(npc_name, [
			"누가 지우개로 여기저기 지우고 다녀.",
			"집도, 나무도… 사람도. 흰 자국만 남았어.",
			"남은 사람들도 이름부터 지워졌어. 다들 자기 이름을 몰라.",
			"강 위의 다리도 감쪽같이 사라졌고…",
		], "haru_sad")
		await GameState.say(npc_name, [
			"풀밭에 지워지다 만 낙서들이 돌아다녀. 연필심을 갖고 있어.",
			"연필심 %d개만 모아서 다리를 다시 그려 줄래?" % need,
			"슬라임이 납작하게 움츠리면 곧 박치기한다는 뜻이야. 조심해!",
		], "haru_smile")
		GameState.set_quest(Q.FIND_LEAD)
		if GameState.lessons_on:
			await GameState.say(npc_name, ["아, 그 전에! 연필 쓰는 법부터 하나씩 알려 줄게.", "먼저 풀밭의 슬라임을 한 마리만 혼내 줘. 마우스 왼쪽을 누르면 연필을 휘둘러."], "haru_smile")
			GameState.set_lesson("attack")
	elif q == Q.FIND_LEAD:
		if GameState.pencil_lead < need:
			await GameState.say(npc_name, [
				"연필심이 %d개 더 필요해. 슬라임을 혼내 줘!" % (need - GameState.pencil_lead),
			], "haru_smile")
		else:
			await GameState.say(npc_name, [
				"연필심을 다 모았구나!",
				"강가에서 연필을 꺼내고, 빨간 점선을 따라 다리를 그려 봐.",
			], "haru_smile")
	elif q == Q.BRIDGE_BUILT or q == Q.CLEAN_DOOR:
		_heart_timer = 2.5
		await GameState.say(npc_name, [
			"다리다! 역시 그린이야!",
			"강 건너 빨간 문도 좀 봐 줄래? 뭔가 뿌옇게 변했어.",
		], "haru_smile")
	elif q == Q.DOOR_OPEN:
		await GameState.say(npc_name, ["문이 열렸어? 조심해서 다녀와!"], "haru_smile")
	else:
		_heart_timer = 2.5
		await GameState.say(npc_name, ["다음 페이지에서도 힘내, 그린이!"], "haru_smile")
	_talking = false


func _draw() -> void:
	if _sprite:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2(0, 5.0 / 0.4), 9, Color(0, 0, 0, 0.18))
		draw_set_transform(Vector2.ZERO)
	elif use_placeholder_art:
		draw_rect(Rect2(-4, -1, 8, 8), Color(0.92, 0.55, 0.65))
		draw_circle(Vector2(0, -6), 6, Color(1.0, 0.88, 0.78))
