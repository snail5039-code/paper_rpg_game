extends Node
## 1장 뒷이야기 "흰 집" (docs/스토리.md 의 1장 뒷이야기). 빨간 문을 지나 빈 페이지에 간 뒤, 1장으로 돌아오면 시작한다.
## field.gd 가 1장 사냥터 화면마다, village.gd 가 1장 마을에 붙인다.
## 단계 (GameState.ch1_step):
##   0 아직 → 1 흰 집 앞에서 하루와 할아버지 (들판으로) → 2 허수를 만나 편지 조각 줍기 (3장)
##   → 3 갈림길의 이정표 아저씨 (팻말 다시 그리기, 기억 한 장면) → 4 모눈 숲의 왕 지우개똥 벌레 (우편 가방)
##   → 5 지워진 길 끝의 빈 우편함 (구깃이의 방이 열림) → 6 구깃이를 쓰러뜨리고 구겨진 편지를 펴 줌
##   → 7 흰 집에 편지를 넣음 → 8 끝
## 큰 장면은 그림책(scripts/ui/story_book.gd)으로 보여 준다: 그림 ch1_page_0~3.

const Data := preload("res://scripts/data/game_data.gd")
const SpotScript := preload("res://scripts/actors/story_spot.gd")
const StoryBook := preload("res://scripts/ui/story_book.gd")

const END_STEP := 8
const SCRAPS := 3
## 화면마다 이야기 자리 (bg px). field.gd 의 나무 자리가 이 근처를 피한다.
const SPOTS := {
	"ch1": {"whitehouse": Vector2(450, 700)},
	"ch1_meadow": {"heosu": Vector2(1180, 470), "scrap0": Vector2(560, 720), "scrap1": Vector2(930, 300), "scrap2": Vector2(1420, 690)},
	"ch1_crossroad": {"signpost": Vector2(560, 560)},
	"ch1_gridwoods": {},
	"ch1_erasedroad": {"mailbox": Vector2(1000, 720)},
	"ch1_bossroom": {},
}
## 들판의 편지 조각에 남은 글자
const SCRAP_TEXT := ["\"…내일…\"", "\"…네 그림…\"", "\"…같이…\""]
const BOOK := "1장 뒷이야기 · 흰 집"

var map_id := ""
var map: Node          # field.gd 또는 village.gd
var _busy := false


static func todo(step: int) -> String:
	match step:
		0:
			return "할 일: 마을의 흰 자국 앞으로"
		1:
			return "할 일: 들판에 가 보기"
		2:
			return "할 일: 들판에 흩어진 편지 조각 줍기 (%d/%d)" % [GameState.ch1_scraps.size(), SCRAPS]
		3:
			return "할 일: 갈림길의 이정표 아저씨에게"
		4:
			return "할 일: 모눈 숲의 왕 지우개똥 벌레에게서 우편 가방 되찾기"
		5:
			return "할 일: 지워진 길 끝의 우편함에게"
		6:
			return "할 일: 아래쪽 구깃이의 방으로"
		7:
			return "할 일: 마을의 흰 집에 편지 가져가기"
	return "1장 끝. 편지 한 통이 도착했다"


## 1장의 이야기가 붙는 곳인지 (빨간 문을 지난 뒤의 1장)
static func active_here(id: String) -> bool:
	return GameState.quest == GameState.Quest.CLEARED and SPOTS.has(id)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	map = get_parent()
	var actors: Node2D = map.get("actors")
	var here: Dictionary = SPOTS.get(map_id, {})
	var st := GameState.ch1_step
	if map_id == "ch1":
		if st == 0:
			_spot(actors, "whitehouse", "", here["whitehouse"])
			_begin.call_deferred()
		elif st == 7:
			_spot(actors, "whitehouse", "story_letter", here["whitehouse"])
	elif map_id == "ch1_meadow":
		if st == 1:
			_spot(actors, "heosu", "npc_heosu", here["heosu"])
		elif st == 2:
			_spot(actors, "heosu", "npc_heosu", here["heosu"])
			for i in SCRAPS:
				if not GameState.ch1_scraps.has("scrap%d" % i):
					_spot(actors, "scrap%d" % i, "story_scrap", here["scrap%d" % i])
		elif st > 2:
			_spot(actors, "heosu", "npc_heosu", here["heosu"])
	elif map_id == "ch1_crossroad":
		_spot(actors, "signpost", "npc_signpost" if st != 3 else "npc_signpost", here["signpost"])
	elif map_id == "ch1_gridwoods" and st == 4:
		_enter_woods.call_deferred()
	elif map_id == "ch1_erasedroad" and st >= 4:
		_spot(actors, "mailbox", "npc_mailbox", here["mailbox"])
	elif map_id == "ch1_bossroom" and st == 6:
		_boss_intro.call_deferred()
	# 보스는 다시 나오기도 하니, 새로 들어오는 몬스터에도 단다
	for e in map.get_tree().get_nodes_in_group("enemies"):
		_hook(e)
	actors.child_entered_tree.connect(_hook)
	_refresh()
	GameState.changed.connect(_refresh)


func _exit_tree() -> void:
	if GameState.changed.is_connected(_refresh):
		GameState.changed.disconnect(_refresh)


func _hook(n: Node) -> void:
	if not n.has_signal("died"):
		return
	var kind := str(n.get("kind"))
	if kind == "boss_bug" and not n.is_connected("died", _on_bug_died):
		n.connect("died", _on_bug_died.unbind(1))
	elif kind == "boss_crumple" and not n.is_connected("died", _on_crumple_died):
		n.connect("died", _on_crumple_died.unbind(1))


func _spot(actors: Node2D, what: String, sprite: String, at: Vector2) -> Node2D:
	var s: Node2D = SpotScript.new()
	s.set("what", what)
	s.set("sprite_name", sprite)
	s.set("story", self)
	s.position = map.call("bg", at)
	actors.add_child(s)
	return s


func _refresh() -> void:
	var hud: Node = map.get("hud")
	if hud == null:
		return
	var title := "1장 · %s" % str(Data.MAP_NAMES.get(map_id, "공책 마을"))
	if map.has_method("_title_text"):
		title = str(map.call("_title_text"))
	# 대장과 싸우는 동안에는 위쪽 가운데의 대장 체력 막대와 겹치지 않게 할 일을 빼고 이름만
	hud.set("quest_text_override", title if map_id.ends_with("bossroom") and GameState.ch1_step == 6 else "%s   ·   %s" % [title, todo(GameState.ch1_step)])
	hud.call("_refresh")


func _done(step: int) -> void:
	GameState.ch1_step = step
	GameState.changed.emit()
	GameState.save_game()


# ---------- 1. 흰 집 ----------

func _begin() -> void:
	await map.get_tree().create_timer(0.6, false).timeout
	if GameState.ch1_step != 0 or _busy:
		return
	_busy = true
	await StoryBook.play(map, [["ch1_page_0", [
		"빈 페이지에서 돌아오니, 마을이 조금 더 하얘져 있었다.",
		"하루가 집 모양 흰 자국 앞에 서 있었다.",
	]]], BOOK)
	await GameState.say("하루", ["그린아, 여기. 누가 살았어.", "매일 아침 노란 가방을 메고 나갔는데…", "…얼굴이 생각이 안 나."], "haru_sad")
	await GameState.say("지팡이 할아버지", ["편지를 날라 주던 녀석이야.", "너희 둘이 공책 귀퉁이에 쪽지를 써 두면, 그 녀석이 날랐지.",
		"이름은… 나도 모르겠구나. 들판에서 자주 봤다는 허수아비가 있단다."])
	await GameState.say("나", ["(쪽지… 하루랑 공책에 쪽지를 주고받았던가?)"], "player_sad")
	_busy = false
	_done(1)


# ---------- 이야기 자리에서 F (story_spot.gd 가 부른다) ----------

func on_spot(spot: Node2D) -> void:
	if _busy:
		return
	_busy = true
	var what := str(spot.get("what"))
	match what:
		"whitehouse":
			if GameState.ch1_step == 0:
				_busy = false
				await _begin()
				spot.set("done", true)
			elif GameState.ch1_step == 7:
				await _ending()
				spot.set("done", true)
		"heosu":
			await _heosu()
		"signpost":
			await _signpost()
		"mailbox":
			await _mailbox()
		_:
			if what.begins_with("scrap"):
				await _scrap(spot, what)
	_busy = false


# ---------- 2. 들판: 허수와 편지 조각 ----------

func _heosu() -> void:
	match GameState.ch1_step:
		1:
			await GameState.say("허수", ["…오, 사람이다. 나는 허수. 여기 서서 들판을 지켜.",
				"노란 가방? 응, 알아. 매일 이 길로 지나갔어. 휘파람을 불면서.",
				"그런데 어느 날 가방에서 편지가 날렸어. 점박이들이 쪼아서 들판 여기저기로 흩어졌지.",
				"나는 발이 땅에 박혀서 못 주워. …주워 줄래?"], "heosu")
			_done(2)
			GameState.notify("들판에 흩어진 편지 조각 3장을 찾자.")
			_respawn_spots()
		2:
			await GameState.say("허수", ["%d장 남았어. 연못 쪽이랑, 위쪽 풀밭이랑…" % (SCRAPS - GameState.ch1_scraps.size())], "heosu")
		_:
			await GameState.say("허수", ["그 사람 휘파람 소리, 아직 귀에 남아 있어.", "곡은 생각 안 나. 소리만."], "heosu")


func _scrap(spot: Node2D, key: String) -> void:
	if GameState.ch1_step != 2 or GameState.ch1_scraps.has(key):
		spot.set("done", true)
		return
	GameState.ch1_scraps.append(key)
	var n := GameState.ch1_scraps.size()
	spot.set("done", true)
	await GameState.say("나", ["편지 조각이다. 글씨가 거의 지워졌어.", "남은 건… %s" % SCRAP_TEXT[int(key.trim_prefix("scrap"))],
		"받는 사람 이름 자리는 하얗게 비어 있다."], "player")
	GameState.notify("편지 조각 %d/%d" % [n, SCRAPS])
	if n >= SCRAPS:
		await GameState.say("하루", ["\"내일\", \"네 그림\", \"같이\"…", "어디서 많이 본 말인데."], "haru_sad")
		await GameState.say("허수", ["다 모았구나. 고마워.", "그 사람, 마지막 날엔 갈림길 쪽으로 갔어. 이정표 아저씨가 봤을 거야."], "heosu")
		_done(3)
	else:
		GameState.changed.emit()
		GameState.save_game()


func _respawn_spots() -> void:
	var actors: Node2D = map.get("actors")
	var here: Dictionary = SPOTS[map_id]
	for i in SCRAPS:
		if not GameState.ch1_scraps.has("scrap%d" % i):
			_spot(actors, "scrap%d" % i, "story_scrap", here["scrap%d" % i])


# ---------- 3. 갈림길: 이정표 아저씨 ----------

func _signpost() -> void:
	if GameState.ch1_step != 3:
		var lines := ["어디로 가나? 위는 마을, 왼쪽은 들판, 오른쪽은 모눈 숲, 아래는… 지워진 길이야."]
		if GameState.ch1_step > 3:
			lines = ["새 팻말이 아주 마음에 들어.", "다만 그 팻말이 무슨 이름이었는지는, 이제 아무도 모르지."]
		await GameState.say("이정표 아저씨", lines, "signpost")
		return
	await GameState.say("이정표 아저씨", ["노란 가방을 멘 사람? 그래, 늘 내 앞에서 멈췄지.", "그런데 그 사람이 마지막에 어느 쪽으로 갔는지…",
		"그 쪽 팻말이 지워져 버렸어. 팻말이 없으면, 나도 기억이 안 나."], "signpost")
	await GameState.say("나", ["다시 그려 볼게요."], "player")
	var hud: Node = map.get("hud")
	if hud:
		var panel: Control = hud.call("trace_panel")
		# 오른쪽을 가리키는 화살표 팻말
		panel.call("start", "지워진 팻말 다시 그리기", [
			PackedVector2Array([Vector2(200, 160), Vector2(400, 160), Vector2(450, 195), Vector2(400, 230), Vector2(200, 230), Vector2(200, 160)]),
			PackedVector2Array([Vector2(320, 230), Vector2(320, 290)])], 10.0)
		var score: float = await panel.finished
		if score < 0.4:
			await GameState.say("나", ["…삐뚤어졌어. 다시 해 보자."], "player")
			return
	await GameState.say("이정표 아저씨", ["…아.", "생각났어. 그날 일이."], "signpost")
	await StoryBook.play(map, [["ch1_page_1", [
		"노란 가방을 멘 사람이 이정표 앞에 멈춰 섰다.",
		"모자를 눌러써서 얼굴은 보이지 않았다. 아무도 그 얼굴을 본 기억이 없다.",
		"가방은 그날따라 무거웠다. 전하지 못한 편지가 가득해서.",
		"그 사람은 모눈 숲 쪽으로 걸어갔다. 그리고 돌아오지 않았다.",
	]]], BOOK)
	await GameState.say("이정표 아저씨", ["모눈 숲이야. 그 숲엔 커다란 지우개똥 벌레가 살지.", "무엇이든 갉아 먹는 녀석이야. 조심해."], "signpost")
	_done(4)


# ---------- 4. 모눈 숲: 왕 지우개똥 벌레 ----------

func _enter_woods() -> void:
	await map.get_tree().create_timer(0.6, false).timeout
	await GameState.say("하루", ["저기, 왕 지우개똥 벌레야. 뭘 물고 있어.", "…노란 가방이야!"], "haru_surprised")


func _on_bug_died() -> void:
	if GameState.ch1_step != 4:
		return
	await map.get_tree().create_timer(0.8, false).timeout
	await GameState.say("나", ["가방을 놓고 갔어.", "한쪽이 갉아 먹혔다. 안은… 비어 있어."], "player")
	await GameState.say("나", ["바닥에 우표만 하나 붙어 있다. 작은 집 그림이 그려진 우표."], "player_sad")
	await GameState.say("하루", ["편지는 다 어디 갔지?", "…지워진 길 끝에 오래된 우편함이 있어. 거기라면 알지도 몰라."], "haru_sad")
	_done(5)


# ---------- 5. 지워진 길: 빈 우편함 ----------

func _mailbox() -> void:
	if GameState.ch1_step < 5:
		await GameState.say("빈 우편함", ["…편지가 안 온 지 오래됐어."], "mailbox")
		return
	if GameState.ch1_step > 5:
		await GameState.say("빈 우편함", ["아래쪽 방이야. 조심해.", "…그리고 혹시 펴 보게 되면, 나한테도 무슨 말이었는지 알려 줘."], "mailbox")
		return
	await GameState.say("빈 우편함", ["노란 가방…! 그 사람 가방이구나.", "그 사람, 마지막 날 여기 왔었어. 가방에 편지가 가득했지.",
		"받을 사람 이름이 다 지워져서, 아무한테도 전할 수가 없었대.", "그래서 하나씩 구겨서 아래쪽 방에 버렸어. 울면서."], "mailbox")
	await GameState.say("빈 우편함", ["그 구겨진 편지들이 너무 많이 쌓여서…", "어느 날 일어났어. 이제 그걸 구깃이라고 불러."], "mailbox")
	await GameState.say("하루", ["구깃이가… 편지였어?"], "haru_surprised")
	_done(6)
	GameState.notify("지워진 길 아래쪽, 구깃이의 방으로 가는 길이 열렸어요.")


# ---------- 6. 구깃이의 방 ----------

func _boss_intro() -> void:
	await map.get_tree().create_timer(0.6, false).timeout
	await GameState.say("구깃이", ["…보고 싶… …답장… …왜 안 와…", "…내일… 내일… 내일…"], "crumple")
	await GameState.say("나", ["편지 조각으로 말하고 있어."], "player_sad")


func _on_crumple_died() -> void:
	if GameState.ch1_step != 6:
		return
	await map.get_tree().create_timer(0.8, false).timeout
	await GameState.say("나", ["구겨진 종이가 남았다. 펴 보자."], "player")
	var hud: Node = map.get("hud")
	if hud:
		var panel: Control = hud.call("trace_panel")
		# 구김 선을 따라 펴기: 접힌 자국 넷과 종이 가장자리
		panel.call("start", "구겨진 편지 펴기", [
			PackedVector2Array([Vector2(180, 110), Vector2(460, 110), Vector2(460, 290), Vector2(180, 290), Vector2(180, 110)]),
			PackedVector2Array([Vector2(180, 170), Vector2(460, 170)]),
			PackedVector2Array([Vector2(180, 230), Vector2(460, 230)]),
			PackedVector2Array([Vector2(320, 110), Vector2(320, 290)])], 12.0)
		await panel.finished      # 어떻게 그리든 편지는 펴진다
	await StoryBook.play(map, [["ch1_page_2", [
		"편지는 크레용으로 쓴 아이 글씨였다.",
		"\"그린아, 네 그림 진짜 좋아. 웃은 건 그래서야.\"",
		"\"내일도 같이 그리자. 꼭.\"",
		"보낸 사람 이름 자리에는, 작은 해가 하나 그려져 있었다.",
	]]], BOOK)
	await GameState.say("하루", ["이거… 내 글씨야.", "그런데 언제 썼는지, 기억이 안 나.", "웃은 건 그래서라니… 내가 뭘 보고 웃었지?"], "haru_blank")
	await GameState.say("나", ["……", "(답장을 했었나. 기억나지 않는다.)"], "player_sad")
	await GameState.say("하루", ["이 편지, 흰 집에 갖다 주자. 날라 주던 사람 집이니까."], "haru_sad")
	_done(7)


# ---------- 7. 다시 흰 집 ----------

func _ending() -> void:
	await StoryBook.play(map, [["ch1_page_3", [
		"흰 집 자리에, 우편함을 하나 그렸다. 문은 그리지 않았다. 들어올 사람이 없으니까.",
		"편지를 넣었다. 툭, 하고 작은 소리가 났다.",
		"편지를 날라 주던 사람은 돌아오지 않았다. 이름도 얼굴도, 끝내 알 수 없었다.",
	]]], BOOK)
	await GameState.say("지팡이 할아버지", ["그래도 이제 한 통은 도착했구나.", "그 녀석도 그거면 됐을 게다."])
	await GameState.say("하루", ["그린아. 너는 그때 답장했어?"], "haru_blank")
	await GameState.say("나", ["…모르겠어."], "player_sad")
	await GameState.say("하루", ["그렇구나.", "가자. 다음 페이지로."], "haru_smile")
	_done(END_STEP)
	GameState.notify("1장 뒷이야기 \"흰 집\"을 끝냈어요.")
