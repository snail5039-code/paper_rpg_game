extends Node2D
## 튜토리얼 장 "연습 페이지" 의 맵 한 장 (13장이 같은 장면을 쓴다). 맵마다 선생 한 명, 그 맵의 몬스터, 할 일이 있다.
##  - 어느 맵인지는 GameState.current_map ("tut_1" ~ "tut_13"), 내용은 scripts/tut_data.gd 의 MAPS.
##  - 선생에게 말을 걸면 할 일을 준다. 다 해내면 도장이 찍히고 오른쪽 문이 열린다.
##  - 왼쪽 문으로 앞 맵에 돌아갈 수 있다. 13장을 끝내고 오른쪽으로 나가면 1장 공책 마을로 간다.
##  - 진행은 GameState.tut_cleared (끝낸 맵 수) 와 GameState.lesson (지금 하는 할 일) 에 저장된다.
##
## 위치는 전부 "bg px"(배경 1672×941 픽셀 좌표)로 적고 bg() 로 월드 좌표로 바꾼다.
## 맵은 화면보다 넓다 (월드 900×506, 카메라가 따라다닌다).

const Art := preload("res://scripts/art.gd")
const Data := preload("res://scripts/game_data.gd")
const Tut := preload("res://scripts/tut_data.gd")
const Items := preload("res://scripts/items.gd")
const HudScript := preload("res://scripts/hud.gd")
const PlayerScene := preload("res://scenes/player.tscn")
const Companion := preload("res://scripts/companion.gd")
const MonsterScene := preload("res://scenes/enemy.tscn")
const SpotScript := preload("res://scripts/pickup_spot.gd")
const TracePanel := preload("res://scripts/trace_panel.gd")
const TutorialScript := preload("res://scripts/tutorial.gd")
const ThingScript := preload("res://scripts/tut_thing.gd")

const BG_SIZE := Vector2(1672, 941)
const WORLD_PER_BG := 900.0 / 1672.0
const CAMERA_ZOOM := 1.5
const RESPAWN_SEC := 5.0
const PLAY := Rect2(96, 96, 1480, 749)     # 테두리 안쪽 (걸을 수 있는 곳)
const GATE_HALF_H := 105.0
const EXIT_MARGIN := 30.0
const ARRIVE := {"left": Vector2(170, 470), "right": Vector2(1500, 470)}

## 할 일마다: 왼쪽 위의 글 (%d 는 지금까지 한 수), 아래쪽 키 안내, 몇 번 해야 하는지, 무엇을 세는지
const LESSONS := {
	"move": {"text": "", "hints": [["key_wasd", "이동"], ["key_f", "말 걸기"]]},
	"attack": {"text": "할 일: 오타 세 마리 물리치기 (%d/3)", "hints": [["key_mouse_l", "공격 (세 번 이어 치면 마지막이 세다)"]], "need": 3, "count": "kill"},
	"dodge": {"text": "할 일: Space 로 세 번 피하기 (%d/3)", "hints": [["key_space", "회피: 구르는 동안은 맞지 않는다"], ["key_mouse_l", "공격"]], "need": 3, "count": "dodge"},
	"stat": {"text": "할 일: C 를 눌러 능력치 하나 올리기", "hints": [["", "C 능력치"], ["key_mouse_l", "공격"]], "need": 1, "count": "stat"},
	"trial": {"text": "할 일: 허수아비에게 스킬을 세 가지 써 보기 (%d/3)", "hints": [["", "Q E R 스킬   K 로 다른 스킬 넣기"]], "need": 3, "count": "skill"},
	"learn": {"text": "할 일: K 를 눌러 스킬 하나를 배워 칸에 넣기", "hints": [["", "K 스킬"]]},
	"ult": {"text": "할 일: V 를 눌러 필살기 써 보기", "hints": [["", "V 필살기 (점선 별을 따라 그린다)"], ["key_mouse_l", "공격"]]},
	"equip": {"text": "할 일: I 를 눌러 가방에서 모자 쓰기", "hints": [["", "I 가방 (장비를 두 번 누르면 입는다)"]]},
	"potion": {"text": "할 일: 1 키로 반창고 쓰기", "hints": [["", "1 반창고   2 우유"]], "need": 1, "count": "use"},
	"craft": {"text": "할 일: 풀 아저씨에게 말을 걸어 반창고 만들기", "hints": [["key_f", "풀 아저씨: 작업대 열기 → 만들기"]], "need": 1, "count": "craft"},
	"enhance": {"text": "할 일: 풀 아저씨에게 말을 걸어 장비 한 번 강화하기", "hints": [["key_f", "풀 아저씨: 작업대 열기 → 강화"]], "need": 1, "count": "enhance"},
	"capture": {"text": "할 일: 낙서 토끼를 쓰러뜨리고 흐린 자국에서 F 로 다시 그리기", "hints": [["key_mouse_l", "공격"], ["key_f", "흐린 자국: 다시 그리기"]], "need": 1, "count": "capture"},
	"fish": {"text": "할 일: 표지판 앞에서 F 로 물고기 한 마리 낚기", "hints": [["key_f", "표지판: 낚싯대 던지기 / 느낌표가 뜨면 F"]], "need": 1, "count": "fish"},
	"forage": {"text": "할 일: 풀이나 열매를 하나 줍기", "hints": [["key_f", "풀·열매: 낫으로 베기"]], "need": 1, "count": "forage"},
	"farm": {"text": "할 일: 아주머니에게 말을 걸어 씨앗을 심고 물 주기", "hints": [["key_f", "아주머니: 밭 열기"]]},
	"cook": {"text": "할 일: 아주머니에게 말을 걸어 무 조림 만들기", "hints": [["key_f", "아주머니: 솥 열기"]], "need": 1, "count": "cook"},
	"build": {"text": "할 일: 집터에서 F 를 누르고 점선을 따라 집 그리기", "hints": [["key_f", "집터: 그려서 짓기"]], "need": 1, "count": "build"},
	"sleep": {"text": "할 일: 집 앞에서 F 를 눌러 자기", "hints": [["key_f", "집: 자기"]], "need": 1, "count": "sleep"},
	"boss": {"text": "할 일: 큰 가위표 물리치기", "hints": [["key_mouse_l", "공격"], ["key_space", "회피"], ["", "Q E R 스킬   1 반창고"]], "need": 1, "count": "boss"},
}
## 할 일을 하는 동안 선생에게 다시 말을 걸면 열리는 창 [창 이름, 무엇에 대한 창인지]
const NPC_MENU := {"craft": ["shop", ""], "enhance": ["shop", ""], "farm": ["farm", "tut"], "cook": ["cook", ""]}

var map_no := 0              # 테스트에서 맵을 직접 고를 때 쓴다 (1 ~ 13). 0 이면 GameState.current_map.
var cfg: Dictionary
var actors: Node2D
var player: CharacterBody2D
var hud: CanvasLayer
var npc: Node2D
var lot: Node2D              # 12장의 집터
var last_exit := ""
var _leaving := false
var _busy := false
var _t := 0.0
var _gate: CollisionShape2D   # 오른쪽 문을 막는 벽 (할 일을 끝내면 사라진다)
var _gate_mark: Node2D
var _built := false
var _counts: Dictionary = {}  # 이 맵에서 센 것 ("kill", "boss")


static func bg(p: Vector2) -> Vector2:
	return p * WORLD_PER_BG


static func map_id(n: int) -> String:
	return "tut_%d" % n


func _ready() -> void:
	if get_tree().current_scene == self:
		add_to_group("game_map")
	if map_no <= 0:
		map_no = int(GameState.current_map.trim_prefix("tut_"))
	map_no = clampi(map_no, 1, Tut.MAPS.size())
	cfg = Tut.MAPS[map_no - 1]

	var tex := Art.tex(str(cfg["bg"]))
	if tex:
		var back := Sprite2D.new()
		back.name = "Background"
		back.texture = tex
		back.centered = false
		back.scale = Vector2.ONE * (BG_SIZE.x * WORLD_PER_BG / tex.get_width())
		back.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		back.z_index = -10
		add_child(back)
	_build_collision()

	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)
	for m in cfg["monsters"]:
		_spawn_monster(str(m[0]), bg(m[1]))

	# 선생
	var who: Array = cfg["npc"]
	npc = ThingScript.new()
	npc.set("label", str(who[0]))
	npc.set("sprite_name", str(who[1]))
	npc.set("on_use", _talk)
	npc.position = bg(who[2])
	actors.add_child(npc)
	_make_spots()

	player = PlayerScene.instantiate()
	var arrive := str(GameState.spawn_tag).trim_prefix("gate_")
	if not ARRIVE.has(arrive):
		arrive = "left"
	var start: Vector2 = bg(ARRIVE[arrive]) if map_no > 1 or arrive == "right" else bg(Vector2(500, 600))
	player.set("spawn_point", start)
	player.position = GameState.saved_position if GameState.has_saved_position and GameState.spawn_tag == "" else start
	GameState.spawn_tag = ""
	actors.add_child(player)
	Companion.attach(actors, player)

	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE * CAMERA_ZOOM
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = roundi(BG_SIZE.x * WORLD_PER_BG)
	cam.limit_bottom = roundi(BG_SIZE.y * WORLD_PER_BG)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	player.add_child(cam)

	hud = HudScript.new()
	hud.name = "HUD"
	add_child(hud)
	_refresh_gate()
	_show()
	# 하던 할 일이 스킬 체험이면 다시 열어 준다
	if not cleared() and (GameState.lesson == "trial" or GameState.lesson == "ult"):
		GameState.begin_trial()
	# 첫 맵: 오프닝 (책상 위의 공책 → 공책 속으로)
	if map_no == 1 and not GameState.intro_seen:
		var opening := TutorialScript.new()
		opening.name = "Opening"
		opening.set("hud", hud)
		opening.set("opening_lines", ["여긴… 공책 속이잖아!", "표지를 넘기자마자 빨려 들어왔다.", "손에는 연필이 들려 있다. 누가 있는지 둘러보자."])
		add_child(opening)


func _exit_tree() -> void:
	if GameState.trial:
		GameState.end_trial()


## 이 맵의 할 일을 다 끝냈는지
func cleared() -> bool:
	return GameState.tut_cleared >= map_no


func _lesson() -> String:
	var ids: Array = cfg["lessons"]
	return GameState.lesson if not cleared() and ids.has(GameState.lesson) else ""


func _count(what: String) -> int:
	if what == "kill" or what == "boss" or what == "build":
		return int(_counts.get(what, 0))
	return GameState.lesson_count(what)


func _show() -> void:
	var id := _lesson()
	var head := "연습 페이지 %d/%d · %s" % [map_no, Tut.MAPS.size(), cfg["name"]]
	var text := head
	var hints: Array = [["key_wasd", "이동"], ["key_f", "말 걸기"]]
	if id != "":
		var info: Dictionary = LESSONS[id]
		var line := str(info["text"])
		if line.contains("%d"):
			line = line % mini(_count(str(info["count"])), int(info["need"]))
		if line != "":
			text = line
		hints = info["hints"]
	elif cleared():
		text = head + "   (오른쪽 문이 열렸다)" if map_no < Tut.MAPS.size() else head + "   (오른쪽으로 나가면 공책 마을)"
		hints = [["key_wasd", "오른쪽 문으로"]]
	else:
		text = "할 일: %s 에게 말 걸기" % cfg["npc"][0]
	if str(hud.get("quest_text_override")) != text:
		hud.set("quest_text_override", text)
		GameState.changed.emit()
	hud.call("set_hints", hints)


func _process(delta: float) -> void:
	_show()
	if _busy or GameState.dialogue_open or GameState.cutscene:
		return
	_t += delta
	if _t < 0.2:
		return
	_t = 0.0
	var id := _lesson()
	if id != "" and _done(id):
		_finish(id)


func _done(id: String) -> bool:
	var info: Dictionary = LESSONS[id]
	match id:
		"move":
			return true
		"learn":
			for s in GameState.skill_slots:
				if str(s) != "" and int(GameState.skill_ranks.get(str(s), 0)) > 0:
					return true
			return false
		"ult":
			return GameState.lesson_count("skill_ult") >= 1
		"equip":
			return GameState.equipped.has("hat")
		"farm":
			return GameState.lesson_count("plant") >= 1 and GameState.lesson_count("water") >= 1
	return _count(str(info["count"])) >= int(info["need"])


func _say(lines: Array) -> void:
	await GameState.say(str(cfg["npc"][0]), lines, str(cfg["npc"][1]))


## 선생에게 말을 걸었을 때
func _talk() -> void:
	if _busy:
		return
	var id := _lesson()
	if cleared():
		_busy = true
		await _say([str((cfg["done"] as Array)[-1])])
		_busy = false
		return
	if id == "":
		_busy = true
		await _say(cfg["intro"])
		_busy = false
		_begin(str(cfg["lessons"][0]))
		return
	if NPC_MENU.has(id):
		var m: Array = NPC_MENU[id]
		if str(m[1]) != "":
			hud.call("open_menu", str(m[0]), str(m[1]))
		else:
			hud.call("toggle_menu", str(m[0]))
		if id == "craft" or id == "enhance":
			(hud.call("menu", "shop") as Control).call("_set_tab", 2 if id == "craft" else 3)
		return
	_busy = true
	await _say(["아직이야. 화면 왼쪽 위의 할 일을 봐!"])
	_busy = false


## 할 일을 시작한다: 필요한 것을 쥐여 준다
func _begin(id: String) -> void:
	GameState.set_lesson(id)
	_counts = {}
	var p: Node = GameState.player_ref
	match id:
		"stat":
			if GameState.level < 2:
				GameState.add_exp(GameState.exp_needed() - GameState.exp)
			elif GameState.stat_points <= 0:
				GameState.stat_points += 1
		"trial":
			GameState.begin_trial()
		"learn":
			if GameState.skill_points <= 0:
				GameState.skill_points += 1
		"ult":
			GameState.begin_trial()
		"equip":
			if not GameState.equipped.has("hat"):
				GameState.add_item(Items.make("hat", 2, 0, 1))
		"potion":
			GameState.add_consumable("bandage", 2, true)
			if is_instance_valid(p):
				p.set("hp", maxi(1, int(p.get("max_hp")) / 2))
				p.emit_signal("hp_changed", int(p.get("hp")), int(p.get("max_hp")))
		"craft":
			GameState.add_material(0, 4)
		"enhance":
			GameState.add_lead(20)
			GameState.dust += 10
		"capture":
			GameState.add_consumable("paper", 1, true)
		"farm":
			GameState.add_consumable("s_radish", 2, true)
		"cook":
			GameState.add_consumable("c_radish", 2, true)
	GameState.changed.emit()
	_show()


## 할 일 하나를 끝낸다: 도장, 선생의 말, 다음 할 일 (없으면 문이 열린다)
func _finish(id: String) -> void:
	_busy = true
	if id == "trial" or id == "ult":
		GameState.end_trial()
	if id != "move":
		hud.call("stamp")
		await get_tree().create_timer(0.7, true).timeout
	var ids: Array = cfg["lessons"]
	var next := ids.find(id) + 1
	if next < ids.size():
		await _say(cfg["mid" if next == 1 else "mid%d" % next])
		_busy = false
		_begin(str(ids[next]))
		return
	await _say(cfg["done"])
	GameState.tut_cleared = maxi(GameState.tut_cleared, map_no)
	GameState.set_lesson("")
	if map_no >= Tut.MAPS.size():
		GameState.settings["tutorial_done"] = true
		GameState.save_settings()
	_refresh_gate()
	Sound.play("craft")
	_busy = false


# ---------- 맵에 놓이는 것 ----------

func _make_spots() -> void:
	var spots: Dictionary = cfg.get("spots", {})
	if spots.has("fish"):
		var f: Node2D = SpotScript.new()
		f.set("mode", "fish")
		f.set("key", "home")
		f.set("cast_to", bg(spots.get("cast", Vector2(120, 0))))
		f.position = bg(spots["fish"])
		actors.add_child(f)
	var i := 0
	for at in spots.get("forage", []):
		var g: Node2D = SpotScript.new()
		g.set("mode", "forage")
		g.set("key", "tut:%d" % i)
		g.position = bg(at)
		actors.add_child(g)
		i += 1
	if spots.has("lot"):
		lot = ThingScript.new()
		lot.set("label", "집터")
		lot.set("sprite_name", "")
		lot.set("on_use", _use_lot)
		lot.position = bg(spots["lot"])
		actors.add_child(lot)
		if cleared():
			_built = true
			lot.call("show_sprite", "bld_house", 70.0)


## 12장의 집터: 처음에는 점선을 따라 그려 집을 짓고, 지은 뒤에는 잔다
func _use_lot() -> void:
	if _busy:
		return
	if not _built:
		if _lesson() != "build":
			GameState.notify("먼저 삼각자 목수에게 말을 걸어 보자.")
			return
		_busy = true
		var panel: Control = hud.call("trace_panel")
		panel.call("start", "내 집 짓기", TracePanel.house(Rect2(245, 170, 150, 100)), 8.0, Art.tex("bld_house"), Rect2(240, 130, 160, 140))
		var score: float = await panel.finished
		_busy = false
		if score < 0.0:
			return
		_built = true
		lot.call("show_sprite", "bld_house", 70.0)
		Sound.play("craft")
		GameState.notify("집을 지었어요! (따라 그리기 %d%%)" % roundi(score * 100.0))
		_counts["build"] = 1
		return
	_busy = true
	GameState.set_cutscene(true)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var dark := ColorRect.new()
	dark.color = Color(0.08, 0.07, 0.12, 0.0)
	dark.size = Vector2(640, 360)
	layer.add_child(dark)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(dark, "color:a", 1.0, 0.5)
	tw.tween_interval(0.5)
	tw.tween_callback(GameState.sleep)
	tw.tween_property(dark, "color:a", 0.0, 0.5)
	await tw.finished
	layer.queue_free()
	GameState.set_cutscene(false)
	GameState.notify("푹 잤어요. 피로도가 다 풀렸어요.")
	_busy = false


# ---------- 문과 충돌 ----------

func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "MapCollision"
	add_child(body)
	var w := BG_SIZE.x
	var h := BG_SIZE.y
	var cy := h * 0.5
	var rects: Array = [Rect2(0, 0, w, PLAY.position.y), Rect2(0, PLAY.end.y, w, h - PLAY.end.y)]
	for side in ["left", "right"]:
		var x0 := 0.0 if side == "left" else PLAY.end.x
		var x1 := PLAY.position.x if side == "left" else w
		if side == "left" and map_no == 1:
			rects.append(Rect2(x0, 0, x1 - x0, h))
		else:
			rects.append(Rect2(x0, 0, x1 - x0, cy - GATE_HALF_H))
			rects.append(Rect2(x0, cy + GATE_HALF_H, x1 - x0, h - cy - GATE_HALF_H))
	rects.append(Rect2(-60, -60, w + 120, 60))
	rects.append(Rect2(-60, h, w + 120, 60))
	rects.append(Rect2(-60, 0, 60, h))
	rects.append(Rect2(w, 0, 60, h))
	for r in cfg.get("solids", []):
		rects.append(r)
	for r in rects:
		body.add_child(_box(r))
	# 오른쪽 문을 막는 벽 (할 일을 끝내면 치운다)
	_gate = _box(Rect2(PLAY.end.x, cy - GATE_HALF_H, w - PLAY.end.x, GATE_HALF_H * 2.0))
	body.add_child(_gate)
	_gate_mark = Node2D.new()
	_gate_mark.position = bg(Vector2(PLAY.end.x + 10, cy))
	_gate_mark.z_index = 5
	_gate_mark.draw.connect(_draw_gate)
	add_child(_gate_mark)


func _box(rect: Rect2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size * WORLD_PER_BG
	shape.shape = box
	shape.position = bg(rect.get_center())
	return shape


func _refresh_gate() -> void:
	if _gate:
		_gate.set_deferred("disabled", cleared())
	if _gate_mark:
		_gate_mark.queue_redraw()


## 닫힌 문에는 빨간 점선, 열린 문에는 초록 화살표
func _draw_gate() -> void:
	var half := GATE_HALF_H * WORLD_PER_BG
	if not cleared():
		for i in 9:
			var y := -half + i * half * 2.0 / 9.0
			_gate_mark.draw_line(Vector2(0, y), Vector2(0, y + half * 0.13), Color(0.9, 0.3, 0.3, 0.9), 2.5)
		return
	var bob := sin(Time.get_ticks_msec() / 250.0) * 3.0
	var tip := Vector2(14 + bob, 0)
	_gate_mark.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-12, -9), tip + Vector2(-12, 9)]), Color(0.4, 0.8, 0.45, 0.95))
	_gate_mark.draw_line(tip + Vector2(-26, 0), tip + Vector2(-10, 0), Color(0.4, 0.8, 0.45, 0.95), 5.0)


func _physics_process(_delta: float) -> void:
	if cleared() and _gate_mark:
		_gate_mark.queue_redraw()
	if _leaving or not is_instance_valid(player):
		return
	var p := player.global_position / WORLD_PER_BG
	if p.x > BG_SIZE.x - EXIT_MARGIN and cleared():
		last_exit = "right"
		if map_no >= Tut.MAPS.size():
			_leave_chapter()
		else:
			_leaving = GameState.goto_map(map_id(map_no + 1), "gate_left")
	elif p.x < EXIT_MARGIN and map_no > 1:
		last_exit = "left"
		_leaving = GameState.goto_map(map_id(map_no - 1), "gate_right")


## 연습 페이지를 다 넘겼다: 1장 공책 마을로
func _leave_chapter() -> void:
	_leaving = true
	GameState.set_lesson("")
	if not GameState.goto_map("ch1", ""):
		_leaving = false


# ---------- 몬스터 ----------

func _spawn_monster(kind: String, pos: Vector2) -> void:
	var m: Node2D = MonsterScene.instantiate()
	m.set("kind", kind)
	m.position = pos
	m.connect("died", _on_monster_died.bind(kind))
	actors.add_child(m)


func _on_monster_died(home: Vector2, kind: String) -> void:
	_counts["kill"] = int(_counts.get("kill", 0)) + 1
	if Data.MONSTERS[kind].has("boss"):
		_counts["boss"] = 1
		return
	await get_tree().create_timer(RESPAWN_SEC, false).timeout
	if is_inside_tree():
		_spawn_monster(kind, home)
