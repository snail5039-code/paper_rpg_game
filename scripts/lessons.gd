extends Node
## 튜토리얼 수업: 하루(내 마을에서는 말랑이)가 할 일을 하나씩 주고, 해내면 다음 것을 알려 준다.
##   1장 마을: 공격 → 회피 → 능력치 → 스킬 체험 → 스킬 배우기 → 장비 → 반창고 → 말랑이(다시 그리기) → 다리 → 빨간 문
##   내 마을 : 종이 붙이기 → 내 집 짓기 → 잠자기
## 지금 수업은 GameState.lesson (저장된다). "" 이면 수업이 없다 (끝났거나, 건너뛰었거나, 예전 저장).
## 수업은 새로 만든 캐릭터에게만 켜진다 (GameState.lessons_on).
## 스킬 체험: 모든 스킬을 MP 없이 써 볼 수 있고 (GameState.trial), 맞아 주는 허수아비가 나온다.

const Items := preload("res://scripts/items.gd")
const Data := preload("res://scripts/game_data.gd")

const VILLAGE := ["attack", "dodge", "stat", "trial", "learn", "equip", "potion", "capture", "bridge", "door"]
const HOME := ["sheet", "house", "sleep"]
const TRIAL_NEED := 3        # 서로 다른 스킬을 이만큼 써 보면 체험이 끝난다

## 수업마다: 화면 왼쪽 위의 "할 일" 글, 아래쪽 키 안내
const TEXT := {
	"attack": ["할 일: 슬라임 한 마리 물리치기", [["key_mouse_l", "공격 (세 번 이어 치면 마지막이 세다)"]]],
	"dodge": ["할 일: Space 로 두 번 피하기 (%d/2)", [["key_space", "회피: 피하는 동안은 맞지 않는다"]]],
	"stat": ["할 일: C 를 눌러 능력치 하나 올리기", [["", "C 능력치"]]],
	"trial": ["할 일: 허수아비에게 스킬을 세 가지 써 보기 (%d/3)", [["", "Q E R 스킬   V 필살기   K 로 다른 스킬 넣기"]]],
	"learn": ["할 일: K 를 눌러 스킬 하나를 배워 칸에 넣기", [["", "K 스킬"]]],
	"equip": ["할 일: I 를 눌러 가방에서 모자 쓰기", [["", "I 가방 (장비를 두 번 누르면 입는다)"]]],
	"potion": ["할 일: 1 키로 반창고 쓰기", [["", "1 반창고   2 우유"]]],
	"capture": ["할 일: 슬라임을 쓰러뜨리고 흐린 자국에서 F 로 다시 그리기", [["key_mouse_l", "공격"], ["key_f", "흐린 자국: 다시 그리기"]]],
	"bridge": ["", []],
	"door": ["", []],
	"sheet": ["할 일: N 을 눌러 종이 한 장 이어 붙이기", [["", "N 짓기 → 종이 붙이기"]]],
	"house": ["할 일: N 을 눌러 내 집 짓기", [["", "N 짓기 → 내 집 (점선을 따라 그린다)"]]],
	"sleep": ["할 일: 내 집에 들어가 침대에서 자기", [["key_f", "집 앞: 들어가기 / 침대: 자기"]]],
}

var hud: CanvasLayer
var place := "village"       # "village" 또는 "home"
var spawn_dummy: Callable    # 허수아비를 세우는 함수 (마을이 넣어 준다). 돌려주는 것: 허수아비 노드
var _busy := false
var _t := 0.0
var _dummy: Node
var _base_text := ""         # 수업이 없을 때 HUD 가 보여 주던 글


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if hud:
		_base_text = str(hud.get("quest_text_override"))
	if GameState.lesson == "trial":
		_begin_trial.call_deferred()


func _exit_tree() -> void:
	if GameState.trial:
		GameState.end_trial()


func _process(delta: float) -> void:
	if hud == null:
		return
	var id := GameState.lesson
	var mine: Array = HOME if place == "home" else VILLAGE
	if place == "home" and id == "home" and GameState.lessons_on and GameState.home_intro_seen \
			and not _busy and not GameState.dialogue_open and not GameState.cutscene:
		_start("sheet")
		return
	if not mine.has(id):
		_show("")
		return
	var info: Array = TEXT[id]
	var text := str(info[0])
	if text.contains("%d"):
		text = text % GameState.lesson_count("dodge" if id == "dodge" else "skill")
	_show(text)
	if _busy or GameState.cutscene or GameState.dialogue_open:
		return
	_t += delta
	if _t < 0.25:
		return
	_t = 0.0
	if _done(id):
		_finish(id)


func _show(text: String) -> void:
	var want := text if text != "" else _base_text
	if str(hud.get("quest_text_override")) != want:
		hud.set("quest_text_override", want)
		GameState.changed.emit()


## 지금 수업의 키 안내 (없으면 빈 배열). 마을의 조작 안내(tutorial.gd)가 물어본다.
static func hints() -> Array:
	var id := GameState.lesson
	return TEXT[id][1] if TEXT.has(id) else []


func _done(id: String) -> bool:
	match id:
		"attack": return GameState.lesson_count("kill") >= 1
		"dodge": return GameState.lesson_count("dodge") >= 2
		"stat": return GameState.lesson_count("stat") >= 1
		"trial": return GameState.lesson_count("skill") >= TRIAL_NEED
		"learn":
			for s in GameState.skill_slots:
				if str(s) != "" and int(GameState.skill_ranks.get(str(s), 0)) > 0:
					return true
			return false
		"equip": return GameState.equipped.has("hat")
		"potion": return GameState.lesson_count("use") >= 1
		"capture": return not GameState.friends.is_empty()
		"bridge": return GameState.bridge_built
		"door": return GameState.quest >= GameState.Quest.CLEARED
		"sheet": return GameState.lesson_count("expand") >= 1
		"house":
			for o in GameState.home_objects:
				if str(o.get("id", "")) == "bld_house":
					return true
			return false
		"sleep": return GameState.lesson_count("sleep") >= 1
	return false


func _haru(lines: Array, face: String = "haru_smile") -> void:
	if place == "home":
		await GameState.say("말랑이", lines, "mallang")
	else:
		await GameState.say("하루", lines, face)


## 수업 하나를 마친다: 칭찬하고, 다음 수업을 시작한다
func _finish(id: String) -> void:
	_busy = true
	if hud.has_method("stamp") and id != "door":
		hud.call("stamp")
		await get_tree().create_timer(0.7, true).timeout
	match id:
		"attack":
			await _haru(["잘했어! 연필을 세 번 이어서 휘두르면 마지막 한 방이 더 세."])
		"dodge":
			await _haru(["그거야! 납작하게 움츠리는 걸 보고 피하면 안 맞아."])
		"stat":
			await _haru(["필력이 오를 때마다 능력치 3점을 받아. 필압은 공격력, 끈기는 HP 야."])
		"trial":
			GameState.end_trial()
			if is_instance_valid(_dummy):
				_dummy.queue_free()
			await _haru(["어땠어? 지금은 구경만 한 거야.", "진짜로 쓰려면 스킬 포인트로 배워야 해. 하나 줄게!"])
		"learn":
			await _haru(["좋아! 스킬은 MP 를 써. MP 는 가만있어도 차고, 때리면 더 빨리 차."])
		"equip":
			await _haru(["잘 어울린다! 장비는 몬스터가 떨어뜨리기도 하고, 문방구에서 만들 수도 있어."])
		"potion":
			await _haru(["다치면 참지 말고 붙여. 문방구 할아버지가 팔아."])
		"capture":
			await GameState.say("말랑이", ["…어?", "나, 원래도 이렇게 웃었어?"], "mallang")
			await _haru(["말랑이야! 지워지기 전엔 저렇게 웃었어…", "다시 그려 준 낙서는 친구가 돼서 같이 싸워 줘. P 를 누르면 볼 수 있어."])
		"house":
			await _haru(["집이다! 여긴 이제 우리 집이야."])
		"sleep":
			GameState.add_coins(100)
			GameState.settings["tutorial_done"] = true
			GameState.save_settings()
			await _haru(["잘 잤어? 자고 나면 피로도가 다 풀려.",
				"이제 알려 줄 건 다 알려 줬어. 여기는 마음대로 꾸며도 돼!",
				"낚시터나 밭도 지어 봐. 처음 쓸 때 어떻게 하는지 알려 줄게. (동전 100개를 받았다)"])
	var mine: Array = HOME if place == "home" else VILLAGE
	var next := mine.find(id) + 1
	_busy = false
	if next >= mine.size():
		GameState.set_lesson("home" if place == "village" else "")
		return
	_start(str(mine[next]))


## 수업을 시작한다: 무엇을 할지 알려 주고, 필요한 것을 쥐여 준다
func _start(id: String) -> void:
	_busy = true
	GameState.set_lesson(id)
	match id:
		"dodge":
			await _haru(["이번엔 피하는 법! Space 를 누르면 가는 쪽으로 휙 굴러.", "두 번만 해 봐."])
		"stat":
			if GameState.level < 2:
				GameState.add_exp(GameState.exp_needed() - GameState.exp)
			elif GameState.stat_points <= 0:
				GameState.stat_points += 1
			await _haru(["필력이 올랐네! C 를 눌러서 능력치를 하나 올려 봐."])
		"trial":
			await _haru(["이제 연필로 할 수 있는 걸 전부 보여 줄게.",
				"잠깐 동안 스킬을 마음껏 써도 돼. MP 도 안 줄어!",
				"저기 허수아비한테 Q, E, R 을 눌러 봐. K 를 누르면 다른 스킬로 바꿔 넣을 수 있어."])
			_begin_trial()
		"learn":
			if GameState.skill_points <= 0:
				GameState.skill_points += 1
			GameState.changed.emit()
			await _haru(["K 를 눌러서 마음에 든 스킬을 배우고, Q·E·R 칸에 넣어 봐."])
		"equip":
			GameState.add_item(Items.make("hat", 2, 0, 1))
			await _haru(["이거 받아. 내가 쓰던 야구 모자야!", "I 를 눌러 가방을 열고, 모자를 두 번 눌러서 써 봐."])
		"potion":
			GameState.add_consumable("bandage", 2, true)
			var p: Node = GameState.player_ref
			if is_instance_valid(p):
				p.set("hp", maxi(1, int(p.get("max_hp")) / 2))
				p.emit_signal("hp_changed", int(p.get("hp")), int(p.get("max_hp")))
			await _haru(["어, 좀 긁혔네? 반창고 줄게.", "1 키를 누르면 바로 붙여."])
		"capture":
			GameState.add_consumable("paper", 1, true)
			await _haru(["저 슬라임들… 원래는 다 우리 친구였어.", "도화지를 줄게. 쓰러뜨린 다음 흐린 자국 위에서 F 를 눌러 다시 그려 줘."], "haru_sad")
		"bridge":
			await _haru(["이제 다리를 그리러 가자! 연필심 %d개가 필요해." % GameState.BRIDGE_COST,
				"강가에서 Tab 으로 연필을 꺼내서 빨간 점선을 따라 그려."])
		"sheet":
			var cost := GameState.home_expand_cost()
			if cost.is_empty():
				GameState.lesson_note("expand")      # 이미 다 넓힌 마을 (다른 캐릭터가 해 둠)
			GameState.add_lead(int(cost.get("lead", 0)))
			GameState.add_coins(int(cost.get("coins", 0)))
			await _haru(["여기… 아무것도 없네. 근데 지워진 게 아니야. 아직 안 그린 거야!",
				"종이가 좁지? N 을 눌러서 종이를 한 장 이어 붙여 봐. 재료는 내가 주워 왔어."])
		"house":
			GameState.add_lead(int(Data.BUILDS["bld_house"]["cost"].get("lead", 0)))
			await _haru(["이제 잘 곳이 있어야지. N 을 눌러 내 집을 골라서 놓고, 점선을 따라 그려 봐."])
		"sleep":
			await _haru(["집에 들어가서 침대에서 한번 자 봐. 사냥터를 다니면 피로도가 쌓이거든."])
	_busy = false


func _begin_trial() -> void:
	GameState.begin_trial()
	if spawn_dummy.is_valid() and not is_instance_valid(_dummy):
		_dummy = spawn_dummy.call()
