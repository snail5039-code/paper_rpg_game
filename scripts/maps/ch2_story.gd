extends Node
## 2장 색연필 숲 이야기 (docs/스토리.md 2장). field.gd 가 2장 화면마다 붙인다.
## 단계 (GameState.ch2_step):
##   0 아직 안 옴 → 1 숲에 옴 → 2 귀퉁이와 사냥 시합 중 → 3 도토리 숲에서 콩콩이 → 4 절벽에서 덩굴이
##   → 5 큰나무 뿌리로 (큰나무 앞의 아래쪽 길이 열림) → 6 큰나무 할아범의 뿌리를 그려 줌, 첫 스티커
## 숲 입구 마을에는 주민 셋(색칠 곰 아저씨, 덩굴 할머니, 되풀이 주민)이 있다.

const Data := preload("res://scripts/data/game_data.gd")
const Art := preload("res://scripts/core/art.gd")
const VillagerScript := preload("res://scripts/actors/villager.gd")
const SpotScript := preload("res://scripts/actors/story_spot.gd")

const RACE_GOAL := 10
const RIVAL_SEC := 14.0          # 귀퉁이는 이만큼마다 한 마리씩 잡는다 (2장 사냥터에 있을 때만)
const GUTUNGI_POS := Vector2(560, 640)     # 숲길 (bg px)
const KONG_POS := Vector2(760, 560)        # 도토리 숲
const VINE_POS := Vector2(1000, 380)       # 절벽과 덩굴: 끊어진 덩굴 아래
const VILLAGE_NPCS := [
	# [vid 또는 "echo", 그림, 자리 (bg px), 처음 대사]
	["painter", "villager_3", Vector2(470, 380), ["어서 와. 숲 입구 마을이야.", "요즘 숲 색이 자꾸 빠져. 저쪽 집은 벌써 회색이 됐지."]],
	["weaver", "villager_4", Vector2(330, 620), ["아이고, 손님이네. 덩굴로 뭘 짜는 걸 좋아한단다."]],
	["echo", "villager_5", Vector2(1150, 520), []],
]

var field: Node2D
var _rival_t := 0.0


static func todo(step: int) -> String:
	match step:
		0, 1:
			return "할 일: 숲길로 가 보기"
		2:
			var r: Dictionary = GameState.ch2_race
			if str(r["result"]) != "":
				return "할 일: 숲길의 귀퉁이에게 가기"
			return "할 일: 귀퉁이보다 먼저 2장 몬스터 %d마리 (나 %d · 귀퉁이 %d)" % [RACE_GOAL, int(r["kills"]), int(r["rival"])]
		3:
			return "할 일: 도토리 숲에서 모자를 잃은 도토리 찾기"
		4:
			return "할 일: 절벽과 덩굴에서 끊어진 덩굴 이어 주기"
		5:
			return "할 일: 큰나무 앞의 아래쪽 길로, 큰나무 할아범에게"
	return "2장을 끝냈다. 연필이 조금 짧아졌다"


func _ready() -> void:
	field = get_parent()
	var id := str(field.get("field_id"))
	var actors: Node2D = field.get("actors")
	if GameState.ch2_step == 0:
		GameState.ch2_step = 1
		_arrive.call_deferred()
	if id == "ch2":
		for v in VILLAGE_NPCS:
			if v[0] != "echo" and int(GameState.villager(str(v[0]))["q"]) == 3:
				continue      # 내 마을로 이사 갔다
			var vn: Node2D = VillagerScript.new()
			if v[0] == "echo":
				vn.set("echo", true)
				vn.set("speaker", "숲 사람")
			else:
				vn.set("vid", v[0])
				vn.set("speaker", str(Data.VILLAGERS[v[0]]["title"]))
			vn.set("sprite_name", v[1])
			vn.set("lines", v[3] if not (v[3] as Array).is_empty() else ["…"])
			vn.position = field.call("bg", v[2])
			actors.add_child(vn)
	elif id == "ch2_path" and GameState.ch2_step <= 2:
		_spot(actors, "gutungi", "npc_gutungi", GUTUNGI_POS, Color.WHITE, 1.0)
	elif id == "ch2_grove" and GameState.ch2_step == 3:
		_spot(actors, "kongkong", "mon_friend_kongkong", KONG_POS, Color(0.72, 0.72, 0.72, 0.85), 6.0)
	elif id == "ch2_cliff" and GameState.ch2_step == 4:
		_spot(actors, "vine", "mon_friend_vine", VINE_POS, Color(0.72, 0.72, 0.72, 0.85), 6.0)
	elif id == "ch2_bossroom" and GameState.ch2_step == 5:
		_boss_intro.call_deferred()
	for e in field.get_tree().get_nodes_in_group("enemies"):
		if str(e.get("kind")) == "boss_oak":
			e.connect("died", _on_oak_died.unbind(1))
	_refresh()
	GameState.changed.connect(_refresh)


func _exit_tree() -> void:
	if GameState.changed.is_connected(_refresh):
		GameState.changed.disconnect(_refresh)


func _spot(actors: Node2D, what: String, sprite: String, at: Vector2, tint: Color, frames: float) -> Node2D:
	var s: Node2D = SpotScript.new()
	s.set("what", what)
	s.set("sprite_name", sprite)
	s.set("tint", tint)
	s.set("frames", int(frames))
	s.set("story", self)
	s.position = field.call("bg", at)
	actors.add_child(s)
	return s


## 화면 위 이름 아래에 할 일을 붙인다
func _refresh() -> void:
	var hud: Node = field.get("hud")
	if hud == null:
		return
	var id := str(field.get("field_id"))
	# 대장과 싸우는 동안에는 위쪽 가운데의 대장 체력 막대와 겹치지 않게 할 일을 빼고 이름만
	hud.set("quest_text_override", str(field.call("_title_text")) if id.ends_with("bossroom") and GameState.ch2_step == 5 else "%s   ·   %s" % [field.call("_title_text"), todo(GameState.ch2_step)])
	hud.call("_refresh")


func _process(delta: float) -> void:
	# 귀퉁이도 사냥 중 (2장 사냥터에 있을 때만, 창이나 대화가 열려 있으면 멈춘다)
	if GameState.ch2_step != 2 or str(GameState.ch2_race["result"]) != "" or bool(field.get("cfg").get("town", false)):
		return
	if GameState.menu_open or GameState.dialogue_open or GameState.cutscene:
		return
	_rival_t += delta
	if _rival_t >= RIVAL_SEC:
		_rival_t = 0.0
		GameState.ch2_race["rival"] = float(GameState.ch2_race["rival"]) + 1.0
		if int(GameState.ch2_race["rival"]) >= RACE_GOAL:
			GameState.ch2_race["result"] = "lose"
			GameState.notify("귀퉁이가 먼저 10마리를 채웠어요… 숲길로 가 보자.")
		GameState.changed.emit()


# ---------- 장면 ----------

func _arrive() -> void:
	await field.get_tree().create_timer(0.5, false).timeout
	await GameState.say("하루", ["여기가 색연필 숲이야. 예전엔 온통 알록달록했는데…",
		"봐, 저쪽은 벌써 회색이 됐어. 색이 빠진 자리가 조금씩 다가와."], "haru_sad")
	await GameState.say("나", ["색이 빠지면… 어떻게 돼?"], "player")
	await GameState.say("하루", ["모르겠어. 그래서 무서워. 숲길로 가 보자."], "haru_sad")
	GameState.save_game()


## 스토리 자리에서 F (story_spot.gd 가 부른다)
func on_spot(spot: Node2D) -> void:
	match str(spot.get("what")):
		"gutungi":
			await _gutungi(spot)
		"kongkong":
			await _redraw_friend(spot, "kongkong")
		"vine":
			await _redraw_friend(spot, "vine")


func _gutungi(spot: Node2D) -> void:
	if GameState.ch2_step <= 1:
		await GameState.say("???", ["어이, 거기 연필 든 녀석."], "gutungi_smirk")
		await GameState.say("귀퉁이", ["난 귀퉁이. 페이지 귀퉁이에 사는 끄적이지. 지우개도 거기까진 안 닿거든.",
			"너도 스티커 모으러 왔지? 여섯 개 다 내가 먼저 모을 거야.",
			"못 믿겠으면 시합하자. 이 숲 녀석들 %d마리, 누가 먼저 잡나." % RACE_GOAL], "gutungi_smirk")
		await GameState.say("나", ["…좋아."], "player")
		GameState.ch2_step = 2
		GameState.ch2_race = {"kills": 0, "rival": 0.0, "result": ""}
		GameState.notify("사냥 시합 시작! 2장 사냥터의 몬스터를 %d마리 잡자." % RACE_GOAL)
	elif str(GameState.ch2_race["result"]) == "":
		await GameState.say("귀퉁이", ["뭐 해? 벌써 %d마리째야." % int(GameState.ch2_race["rival"])], "gutungi_smirk")
		return
	else:
		var won := str(GameState.ch2_race["result"]) == "win"
		if won:
			await GameState.say("귀퉁이", ["…흥. 운이 좋았네.", "이거나 가져. 시합은 시합이니까."], "gutungi_smirk")
			GameState.add_coins(150)
		else:
			await GameState.say("귀퉁이", ["봤지? 내가 먼저야. 스티커도 그럴 거고."], "gutungi_smirk")
		# 말랑이를 보고
		await GameState.say("귀퉁이", ["…그 슬라임, 네 친구야?"], "gutungi_quiet")
		await GameState.say("귀퉁이", ["정 주지 마."], "gutungi_quiet")
		await GameState.say("귀퉁이", ["어차피 다 지워져. 그럼 나만 남아서 기억하게 되거든.", "…간다. 다음에 또 보자, 연필."], "gutungi_quiet")
		GameState.ch2_step = 3
		spot.set("done", true)      # 말이 끝나면 스스로 사라진다
	GameState.changed.emit()
	GameState.save_game()


## 색이 빠지고 한 군데가 지워진 친구를 따라 그려 다시 그려 준다
func _redraw_friend(spot: Node2D, sp: String) -> void:
	var hud: Node = field.get("hud")
	if hud == null:
		return
	if sp == "kongkong":
		await GameState.say("나", ["도토리…? 모자가 지워졌네. 떨고 있어."], "player")
	else:
		await GameState.say("나", ["덩굴이 중간에 끊겨 있어. 잎도 색이 빠졌고."], "player")
	var panel: Control = hud.call("trace_panel")
	var guides: Array
	if sp == "kongkong":
		# 도토리 모자: 둥근 갓과 빗금
		guides = [PackedVector2Array([Vector2(240, 210), Vector2(260, 160), Vector2(320, 140), Vector2(380, 160), Vector2(400, 210), Vector2(240, 210)]),
			PackedVector2Array([Vector2(270, 170), Vector2(330, 205)]), PackedVector2Array([Vector2(310, 145), Vector2(380, 200)]),
			PackedVector2Array([Vector2(320, 140), Vector2(320, 110)])]
	else:
		# 끊어진 덩굴을 잇는 구불구불한 선과 새 잎
		guides = [PackedVector2Array([Vector2(200, 230), Vector2(250, 190), Vector2(300, 220), Vector2(350, 180), Vector2(400, 210), Vector2(440, 170)]),
			PackedVector2Array([Vector2(300, 220), Vector2(290, 250), Vector2(320, 240), Vector2(300, 220)])]
	panel.call("start", "콩콩이의 모자 다시 그리기" if sp == "kongkong" else "끊어진 덩굴 이어 그리기", guides, 10.0)
	var score: float = await panel.finished
	if score < 0.4:
		await GameState.say("나", ["…다시 해 보자."], "player")
		return
	GameState.add_friend(sp)
	spot.set("done", true)      # 말이 끝나면 스스로 사라진다
	if sp == "kongkong":
		await GameState.say("콩콩이", ["모자! 내 모자다!", "…근데 원래 이 색이었어? 기억이 안 나. 그래도 좋아!"])
		await GameState.say("하루", ["콩콩이래. 같이 가고 싶대. 도토리를 아주 멀리 쏠 수 있어."], "haru_smile")
		GameState.ch2_step = 4
	else:
		await GameState.say("덩굴이", ["이어졌다… 이어졌어.", "끊긴 데가 아직 좀 아파. 그래도 따라갈래."])
		await GameState.say("하루", ["이제 큰나무로 갈 수 있겠어. 숲이 시작된 곳이야."], "haru_smile")
		GameState.ch2_step = 5
		GameState.notify("큰나무 앞의 아래쪽 길이 열렸어요.")
	GameState.notify("%s 이(가) 친구가 되었어요! (P: 친구 창)" % Data.FRIENDS[sp]["name"])
	GameState.changed.emit()
	GameState.save_game()


func _boss_intro() -> void:
	await field.get_tree().create_timer(0.6, false).timeout
	await GameState.say("큰나무 할아범", ["…또 누가 왔구나.", "뿌리가 지워져서, 나는 이제 서 있기도 힘들단다.",
		"반만 남는 게 더 아프구나. 차라리 다 지워 다오."], "oak")
	await GameState.say("나", ["그럴 순 없어요."], "player")


## 큰나무 할아범을 쓰러뜨리면: 뿌리를 다시 그려 준다 (2장을 처음 끝낼 때만)
func _on_oak_died() -> void:
	if GameState.ch2_step != 5:
		return
	await field.get_tree().create_timer(0.8, false).timeout
	await GameState.say("큰나무 할아범", ["…왜 끝내 주지 않느냐."], "oak")
	await GameState.say("나", ["뿌리를 다시 그릴게요."], "player")
	var hud: Node = field.get("hud")
	if hud:
		var panel: Control = hud.call("trace_panel")
		panel.call("start", "큰나무 할아범의 뿌리 다시 그리기", [
			PackedVector2Array([Vector2(320, 120), Vector2(300, 170), Vector2(240, 210), Vector2(190, 240)]),
			PackedVector2Array([Vector2(320, 120), Vector2(325, 180), Vector2(320, 240)]),
			PackedVector2Array([Vector2(320, 120), Vector2(345, 170), Vector2(400, 205), Vector2(450, 240)])], 12.0)
		await panel.finished      # 어떻게 그리든 뿌리는 생긴다
	await GameState.say("큰나무 할아범", ["…새 뿌리구나. 단단하다.", "그런데 이상하지. 이 숲의 옛날 일이, 하나도 생각나지 않는구나."], "oak")
	await GameState.say("하루", ["할아범…"], "haru_sad")
	await GameState.say("큰나무 할아범", ["가거라."], "oak")
	GameState.ch2_step = 6
	GameState.stickers = maxi(GameState.stickers, 1)
	await GameState.say("하루", ["그린아, 이거. 첫 번째 스티커야. 표지의 자국 하나에 꼭 맞을 거야."], "haru_smile")
	await GameState.say("나", ["(연필을 보니… 눈에 띄게 짧아졌다.)"], "player_sad")
	GameState.notify("첫 번째 스티커를 받았어요! (1/6)")
	GameState.changed.emit()
	GameState.save_game()
