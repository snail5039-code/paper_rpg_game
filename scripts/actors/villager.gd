extends StaticBody2D
## 마을 주민. 이름이 먼저 지워져서 이름표가 비어 있다. F 로 말을 걸면 대사를 한다.

const Art := preload("res://scripts/core/art.gd")
const TALK_RANGE := 34.0

var sprite_name := "villager_0"
var lines: Array = []
var speaker := "□□이"
var vid := ""               # 이야기가 있는 주민의 id (game_data.gd 의 VILLAGERS). 비어 있으면 대사만 한다.

const Data := preload("res://scripts/data/game_data.gd")
const ASK := {
	"baker": "저기, 가게 간판이 지워졌는데… 다시 그려 줄 수 있니? (다시 말을 걸면 그리기)",
	"elder": "저 흰 자국이 누구였는지, 이름이라도 찾아 줄 수 있겠니? (내일 다시 말 걸기)",
	"kid": "내 풍선 세 개가 날아가 버렸어! 찾아 줄래? (들판, 갈림길, 모눈 숲)",
	"painter": "우리 집 지붕이 반쯤 색이 빠졌어. 다시 칠해 줄 수 있겠니? (다시 말을 걸면 칠하기)",
	"weaver": "숄을 고치고 싶은데 실이 모자라. 숲에서 덩굴 선을 세 개만 구해 줄래?",
}
const WEAVER_NEED := 3
const VINE_MAT := 16          # 덩굴 선 (game_data.gd 의 MATERIALS)

## 되풀이 주민: 만날 때마다 같은 말을 한 글자씩 짧게 한다. 다 줄면 입만 벙긋거린다.
const ECHO_LINE := "이 숲은 원래 아주 예쁜 색이었어요"
var echo := false

var _emote: Sprite2D
var _talking := false


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)
	var t := Art.tex(sprite_name)
	if t:
		Art.make_sprite(self, t, Vector2(0, 6)).show_behind_parent = true
	_emote = Sprite2D.new()
	_emote.texture = Art.tex("key_f")
	_emote.scale = Art.SCALE
	_emote.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_emote.position = Vector2(0, -44)
	_emote.visible = false
	add_child(_emote)


func _process(_delta: float) -> void:
	var p := GameState.player_ref
	_emote.visible = is_instance_valid(p) and p.global_position.distance_to(global_position) < TALK_RANGE


func interact() -> void:
	if _talking or lines.is_empty():
		return
	_talking = true
	if echo:
		await GameState.say(speaker, [echo_text(GameState.ch2_echo, GameState.ch2_step)])
		GameState.ch2_echo += 1
		GameState.save_game()
	elif vid == "":
		await GameState.say(speaker, lines)
	else:
		await _quest_talk()
	_talking = false


## 되풀이 주민의 말: n 번째 만남이면 끝에서 n 글자를 뺀다. 2장을 끝내면 말이 없다.
static func echo_text(n: int, step: int) -> String:
	var keep := ECHO_LINE.length() - n
	if step >= 6 or keep <= 0:
		return "(입만 벙긋거린다)"
	return ECHO_LINE.substr(0, keep) + "…"


## 이야기가 있는 주민: 부탁 → 들어주기 → (내 마을에 집이 있으면) 이름을 지어 주고 이사
func _quest_talk() -> void:
	var v := GameState.villager(vid)
	var hud := get_tree().get_first_node_in_group("hud")
	match int(v["q"]):
		0:
			await GameState.say(speaker, lines + [str(ASK[vid])])
			v["q"] = 1
			v["q_day"] = GameState.day
			GameState.changed.emit()
			GameState.save_game()
		1:
			if vid == "baker" and hud:
				# 지워진 간판을 다시 그려 준다
				var panel: Control = hud.call("trace_panel")
				panel.call("start", "빵집 간판 다시 그리기", [
					PackedVector2Array([Vector2(230, 130), Vector2(410, 130), Vector2(410, 230), Vector2(230, 230), Vector2(230, 130)]),
					PackedVector2Array([Vector2(270, 180), Vector2(370, 180)])], 8.0)
				var score: float = await panel.finished
				if score >= 0.5:
					v["q"] = 2
					await GameState.say(speaker, ["어머, 간판이 다시 생겼네! 고마워.", "글씨는… 뭐라고 썼었는지 모르겠지만, 이거면 됐어."])
				else:
					await GameState.say(speaker, ["아직 잘 안 보이는구나. 다시 한번 그려 줄래?"])
			elif vid == "elder":
				if GameState.day > int(v["q_day"]):
					v["q"] = 2
					await GameState.say(speaker, ["밤새 찾아봤단다. 이름표도, 편지도, 벽의 낙서도.", "…없더구나. 어디에도.", "그래도 찾아 준다고 해 줘서 고맙다."])
				else:
					await GameState.say(speaker, ["나도 좀 더 찾아보마. 내일 다시 오렴."])
			elif vid == "painter" and hud:
				# 색이 빠진 지붕을 다시 칠한다 (지붕 모양을 따라 그리기)
				var panel2: Control = hud.call("trace_panel")
				panel2.call("start", "곰 아저씨네 지붕 다시 칠하기", [
					PackedVector2Array([Vector2(220, 230), Vector2(320, 140), Vector2(420, 230)]),
					PackedVector2Array([Vector2(250, 205), Vector2(390, 205)]),
					PackedVector2Array([Vector2(275, 180), Vector2(365, 180)])], 9.0)
				var s2: float = await panel2.finished
				if s2 >= 0.5:
					v["q"] = 2
					await GameState.say(speaker, ["오오, 지붕에 색이 돌아왔어!", "…내 털은 아직 반쪽이 회색이지만. 그래도 집이라도 칠해졌으니 됐다."])
				else:
					await GameState.say(speaker, ["음, 아직 회색이 더 많구나. 한 번 더 칠해 줄래?"])
			elif vid == "weaver":
				if GameState.material_count(VINE_MAT) >= WEAVER_NEED:
					GameState.add_material(VINE_MAT, -WEAVER_NEED)
					v["q"] = 2
					await GameState.say(speaker, ["덩굴 선이구나. 고맙다, 고마워.", "이걸로 끊긴 데를 이으면… 그래, 매듭은 그대로지만 따뜻하겠어."])
				else:
					await GameState.say(speaker, ["덩굴 선이 %d개 더 있어야 해. 절벽의 가시 덩굴이 갖고 있을 거야." % (WEAVER_NEED - GameState.material_count(VINE_MAT))])
			elif vid == "kid":
				if GameState.balloons.size() >= 3:
					v["q"] = 2
					await GameState.say(speaker, ["내 풍선! 세 개 다 찾았어?", "고마워, 그린이 형아!"])
				else:
					await GameState.say(speaker, ["풍선이 들판이랑 갈림길이랑 모눈 숲으로 날아갔어. (%d/3)" % GameState.balloons.size()])
			GameState.changed.emit()
			GameState.save_game()
		2:
			if GameState.free_house() == "":
				await GameState.say(speaker, ["네가 그리는 마을에 나도 살 수 있을까?", "살 집이 생기면 불러 줘. (내 마을에서 N → 주민 집)"])
			elif hud:
				await GameState.say(speaker, ["정말 가도 돼? …그런데 나, 이름이 없어.", "네가 지어 줄래?"])
				var new_name: String = await hud.call("ask_name", str(Data.VILLAGERS[vid]["title"]))
				if GameState.move_in(vid, new_name):
					await GameState.say(GameState.villager_name(vid), ["%s… 좋은 이름이야. 이제 그게 내 이름이구나." % GameState.villager_name(vid), "먼저 가 있을게. 네 마을에서 보자!"])
					queue_free()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2(0, 5.0 / 0.4), 8, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO)
