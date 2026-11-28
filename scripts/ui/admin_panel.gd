extends CanvasLayer
## 관리자 창 (F10). 테스트용: 어느 맵으로든 바로 가고, 진행 단계·레벨·동전 같은 것을 바로 바꾼다.
## 열려 있는 동안 게임이 멈춘다. 저장 파일에는 영향 없이 그 자리의 값만 바꾸지만, 맵을 옮기면 저장된다.

const UIKit := preload("res://scripts/ui/ui_kit.gd")
const Data := preload("res://scripts/data/game_data.gd")
const TutData := preload("res://scripts/data/tut_data.gd")

const GROUPS := [
	["2장 색연필 숲", ["ch2", "ch2_path", "ch2_grove", "ch2_cliff", "ch2_gray", "ch2_mushroom", "ch2_bigtree", "ch2_bossroom"]],
	["1장 공책 마을", ["ch1", "ch1_meadow", "ch1_crossroad", "ch1_gridwoods", "ch1_erasedroad", "ch1_bossroom"]],
	["내 마을", ["home", "home_room", "museum", "tower"]],
	["연습 페이지", ["tut_1", "tut_2", "tut_3", "tut_4", "tut_5", "tut_6", "tut_7", "tut_8", "tut_9", "tut_10", "tut_11", "tut_12", "tut_13"]],
]

var _info: Label
var _was_menu := false


static func toggle(tree: SceneTree) -> void:
	var old := tree.root.get_node_or_null("AdminPanel")
	if old:
		old.close()
		return
	var p: CanvasLayer = load("res://scripts/ui/admin_panel.gd").new()
	p.name = "AdminPanel"
	tree.root.add_child(p)


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_menu = GameState.menu_open
	GameState.set_menu_open(true)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.1, 0.94)
	bg.size = Vector2(640, 360)
	add_child(bg)
	UIKit.label(bg, "관리자 창 (F10으로 닫기)  -  테스트용", Vector2(8, 4), Vector2(400, 14), 10).add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	UIKit.button(bg, "닫기", Vector2(584, 4), Vector2(48, 16), close)
	_info = UIKit.label(bg, "", Vector2(8, 22), Vector2(624, 12), 8)
	_info.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	# 왼쪽: 맵 목록
	var holder := Control.new()
	holder.position = Vector2(8, 38)
	holder.size = Vector2(300, 316)
	bg.add_child(holder)
	var list := UIKit.scroll_list(holder, Vector2(300, 316))
	for g in GROUPS:
		var h := Label.new()
		h.text = "― %s ―" % g[0]
		h.add_theme_font_size_override("font_size", 9)
		h.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
		list.add_child(h)
		for id in g[1]:
			var b := Button.new()
			b.text = _label(id)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 9)
			b.custom_minimum_size = Vector2(280, 16)
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(_go.bind(id))
			list.add_child(b)
	# 오른쪽: 바로 바꾸기
	var x := 320.0
	var y := 40.0
	var rows := [
		["체력·MP 회복", func(): _heal()], ["피로도 가득", func(): GameState.fatigue = GameState.FATIGUE_MAX + 10],
		["레벨 +5", func(): _levels(5)], ["레벨 +20", func(): _levels(20)],
		["동전 +10000", func(): GameState.add_coins(10000)], ["연필심 +100", func(): GameState.add_lead(100)],
		["무적 켜기/끄기", func(): GameState.god_mode = not GameState.god_mode], ["2장 길 열기 (1장 대장)", func(): GameState.bosses_beaten["boss_crumple"] = maxi(1, int(GameState.bosses_beaten.get("boss_crumple", 0)))],
	]
	for i in rows.size():
		var cell := Vector2(x + (i % 2) * 158.0, y + (i / 2) * 20.0)
		UIKit.button(bg, rows[i][0], cell, Vector2(154, 17), _act.bind(rows[i][1]))
	y += 4 * 20.0 + 8.0
	_stepper(bg, "1장 단계", Vector2(x, y), "ch1_step", 0, 8)
	_stepper(bg, "2장 단계", Vector2(x, y + 22), "ch2_step", 0, 6)
	UIKit.button(bg, "2장 경계 처음으로", Vector2(x, y + 44), Vector2(154, 17), _act.bind(func(): GameState.ch2_drain = 0.0))
	UIKit.button(bg, "스티커 +1", Vector2(x + 158, y + 44), Vector2(154, 17), _act.bind(func(): GameState.stickers = mini(6, GameState.stickers + 1)))
	UIKit.label(bg, "맵을 누르면 피로도와 상관없이 바로 간다.\n단계를 바꾼 뒤에는 그 맵에 다시 들어가야 적용된다.", Vector2(x, y + 70), Vector2(312, 40), 8).add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	_refresh()


## 목록에 보이는 이름: 어디인지 한눈에 알 수 있게 (연습 페이지는 번호·이름·선생)
func _label(id: String) -> String:
	if id.begins_with("tut_"):
		var n := int(id.substr(4))
		var m: Dictionary = TutData.MAPS[n - 1]
		return "연습 %d장 · %s  (선생: %s)" % [n, m["name"], (m["npc"] as Array)[0]]
	match id:
		"home": return "내 마을 (집·건물 짓는 곳)"
		"home_room": return "내 집 안 (방)"
		"museum": return "박물관"
		"tower": return "끝없는 탑 (1층)"
		"ch1": return "1장 · 공책 마을 (마을)"
		"ch2": return "2장 · 숲 입구 마을 (마을)"
		"ch1_bossroom", "ch2_bossroom":
			return "%s · %s (대장 방)" % [id.substr(2, 1) + "장", str(Data.MAP_NAMES.get(id, id))]
	return "%s장 · %s (사냥터)" % [id.substr(2, 1), str(Data.MAP_NAMES.get(id, id))]


func _stepper(parent: Control, title: String, pos: Vector2, key: String, lo: int, hi: int) -> void:
	var l := UIKit.label(parent, "", pos + Vector2(0, 2), Vector2(150, 14), 9)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.set_meta("key", key)
	l.set_meta("title", title)
	l.add_to_group("admin_step_label")
	UIKit.button(parent, "-", pos + Vector2(110, 0), Vector2(22, 17), _step.bind(key, -1, lo, hi))
	UIKit.button(parent, "+", pos + Vector2(136, 0), Vector2(22, 17), _step.bind(key, 1, lo, hi))


func _step(key: String, d: int, lo: int, hi: int) -> void:
	GameState.set(key, clampi(int(GameState.get(key)) + d, lo, hi))
	GameState.changed.emit()
	_refresh()


func _act(f: Callable) -> void:
	f.call()
	GameState.changed.emit()
	_refresh()


func _heal() -> void:
	var p: Node = GameState.player_ref
	if p == null or not is_instance_valid(p):
		return
	p.set("hp", p.get("max_hp"))
	p.set("mp", p.get("max_mp"))
	if p.has_signal("hp_changed"):
		p.emit_signal("hp_changed", p.get("hp"), p.get("max_hp"))


func _levels(n: int) -> void:
	for i in n:
		if GameState.level >= GameState.MAX_LEVEL:
			break
		GameState.add_exp(GameState.exp_needed() - GameState.exp)


func _refresh() -> void:
	_info.text = "지금 %s  ·  레벨 %d  ·  동전 %d  ·  연필심 %d  ·  피로도 %d  ·  무적 %s" % [
		str(Data.MAP_NAMES.get(GameState.current_map, GameState.current_map)), GameState.level, GameState.coins,
		GameState.pencil_lead, GameState.fatigue, "켜짐" if GameState.god_mode else "꺼짐"]
	for l in get_tree().get_nodes_in_group("admin_step_label"):
		l.text = "%s: %d" % [l.get_meta("title"), int(GameState.get(str(l.get_meta("key"))))]


func _go(id: String) -> void:
	var tired := GameState.fatigue
	GameState.fatigue = GameState.FATIGUE_MAX + 10
	var tag := ""
	close()
	if not GameState.goto_map(id, tag):
		GameState.fatigue = tired
		GameState.notify("지금은 그 맵으로 갈 수 없어요.")


func close() -> void:
	GameState.set_menu_open(_was_menu)
	queue_free()
