extends Control
## 공책 종이 창 하나. kind 에 따라 내용이 달라진다:
##   "bag"    가방 (I): 입은 장비, 가방 속 장비, 재료
##   "skills" 스킬 (K): 스킬 포인트로 배우고, Q·E·R 칸에 넣기
##   "shop"   문방구: 사기, 팔기, 만들기, 강화
## 내용은 GameState 가 바뀔 때마다 통째로 다시 만든다 (목록이 짧아서 충분하다).

const Art := preload("res://scripts/art.gd")
const Data := preload("res://scripts/game_data.gd")
const Items := preload("res://scripts/items.gd")
const UI := preload("res://scripts/ui_kit.gd")
const CraftCanvas := preload("res://scripts/craft_canvas.gd")

signal close_requested
signal build_chosen(id: String)   ## 짓기 창에서 고른 것 ("" 은 치우기, "expand" 는 넓히기)

const INK := Color(0.3, 0.25, 0.22)
const INK_SOFT := Color(0.5, 0.42, 0.38)
const TITLES := {"bag": "가방", "skills": "스킬", "shop": "문방구", "friends": "친구", "build": "짓기"}
const TABS := {"bag": ["장비", "재료", "소모품"], "skills": [], "shop": ["사기", "팔기", "만들기", "강화"], "friends": [], "build": ["건물", "소품"]}
const CLOSE_HINT := {"bag": "I  닫기", "skills": "K  닫기", "shop": "Esc  닫기", "friends": "P  닫기", "build": "N  닫기"}

var kind := "bag"
var tab := 0
var selected := -1            # 가방에서 고른 장비 (-1 없음). 입은 장비는 -2 - 부위 번호
var _win: Control
var _body: Control
var _info: Label
var _tab_buttons: Array = []
var _fixed: Array = []         # 다시 그려도 남기는 단추 (닫기)
var _message := ""
var _page := 0                # 가방 쪽 (한 쪽에 24칸)
var _canvas: Control          # 직접 그려서 만들기 화면
const PAGE := 24


func _ready() -> void:
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.08, 0.45)
	dim.size = Vector2(640, 360)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_win = TextureRect.new()
	(_win as TextureRect).texture = Art.tex("ui_window")
	(_win as TextureRect).expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	(_win as TextureRect).stretch_mode = TextureRect.STRETCH_SCALE
	_win.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_win.position = Vector2(110, 46)
	_win.size = Vector2(420, 268)
	_win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_win)
	UI.icon(_win, "ui_plaque", Vector2(150, 5), Vector2(120, 27), Color.WHITE, false)
	var title := _label(_win, str(TITLES[kind]), Vector2(166, 10), Vector2(100, 20), 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fixed.append(UI.icon_button(_win, "ui_close", Vector2(396, 0), Vector2(20, 20), func() -> void: close_requested.emit()))
	var x := 66.0
	for i in (TABS[kind] as Array).size():
		var b := UI.button(_win, str(TABS[kind][i]), Vector2(x, 37), Vector2(50, 19), _set_tab.bind(i), "tab")
		_tab_buttons.append(b)
		x += 52.0
	_body = Control.new()
	_body.position = Vector2(62, 62 if not (TABS[kind] as Array).is_empty() else 44)
	_body.size = Vector2(300, 130 if not (TABS[kind] as Array).is_empty() else 148)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win.add_child(_body)
	_info = _label(_win, "", Vector2(64, 194), Vector2(296, 46), 9)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var foot := _label(_win, str(CLOSE_HINT[kind]), Vector2(0, 243), Vector2(420, 14), 10)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_color_override("font_color", INK_SOFT)
	GameState.changed.connect(func() -> void:
		if visible:
			refresh())


func open() -> void:
	if is_instance_valid(_canvas):
		_canvas.queue_free()
	selected = -1
	_message = ""
	refresh()


func _set_tab(i: int) -> void:
	tab = i
	selected = -1
	_message = ""
	refresh()


# ---------- 부품 (그림은 scripts/ui_kit.gd) ----------

func _label(parent: Control, text: String, pos: Vector2, size: Vector2, font_size: int) -> Label:
	return UI.label(parent, text, pos, size, font_size)


func _button(parent: Control, text: String, pos: Vector2, size: Vector2, on_press: Callable) -> Button:
	return UI.button(parent, text, pos, size, on_press)


func _icon(parent: Control, tex_name: String, pos: Vector2, size: float, tint: Color = Color.WHITE) -> TextureRect:
	return UI.icon(parent, tex_name, pos, Vector2(size, size), tint)


## 칸 위에 얹는 투명 단추
func _hit(parent: Control, pos: Vector2, size: Vector2, on_press: Callable) -> Button:
	return UI.button(parent, "", pos, size, on_press, "plain")


func _list() -> VBoxContainer:
	return UI.scroll_list(_body, _body.size)


## 목록의 한 줄: 종이 띠 위에 아이콘, 글, 오른쪽 단추들 [[글, 눌렀을 때, 누를 수 있는지], ...]
func _row(box: VBoxContainer, icon_name: String, text: String, buttons: Array, tint: Color = Color.WHITE) -> void:
	var row := Control.new()
	row.custom_minimum_size = Vector2(286, 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	UI.icon(row, "ui_row", Vector2(0, 0), Vector2(286, 24), Color(1, 1, 1, 0.9), false)
	if icon_name != "":
		_icon(row, icon_name, Vector2(5, 3), 18, tint)
	var x := 280.0
	for i in range(buttons.size() - 1, -1, -1):
		var spec: Array = buttons[i]
		var w := maxf(20.0, 10.0 + str(spec[0]).length() * 8.0)
		x -= w + 2.0
		var b := _button(row, str(spec[0]), Vector2(x, 3), Vector2(w, 18), spec[1])
		b.disabled = not bool(spec[2])
	_label(row, text, Vector2(27, 5), Vector2(x - 29, 16), 9)


func refresh() -> void:
	_clear_action_buttons()
	for c in _body.get_children():
		c.queue_free()
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).disabled = i == tab
	_info.text = _message
	match kind:
		"bag": _refresh_bag()
		"skills": _refresh_skills()
		"shop": _refresh_shop()
		"friends": _refresh_friends()
		"build": _refresh_build()


# ---------- 가방 ----------

func _refresh_bag() -> void:
	if tab == 1:
		_materials_grid()
		return
	if tab == 2:
		var box := _list()
		for id in Items.CONSUMABLES:
			var n := GameState.consumable_count(str(id))
			if n > 0:
				var info: Array = Items.CONSUMABLES[id]
				_row(box, GameState.consumable_icon(str(id)), "%s ×%d   %s" % [info[0], n, info[3]], [])
		_info.text = "1 번 키: 반창고    2 번 키: 우유"
		return
	# 입은 장비 6칸 (2 × 3)
	for i in Items.SLOTS.size():
		var slot := str(Items.SLOTS[i])
		var pos := Vector2((i % 2) * 40, (i / 2) * 44)
		_icon(_body, "ui_slot_on" if selected == -2 - i else "ui_slot", pos, 36)
		if GameState.equipped.has(slot):
			var item: Dictionary = GameState.equipped[slot]
			_icon(_body, Items.icon(item), pos + Vector2(5, 5), 26, Items.tier_color(item))
		_hit(_body, pos, Vector2(36, 36), _select.bind(-2 - i))
		var name_l := _label(_body, str(Items.SLOT_NAMES[slot]), pos + Vector2(-2, 35), Vector2(40, 10), 7)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.add_theme_color_override("font_color", INK_SOFT)
	# 가방 속 장비 (한 쪽에 6 × 4). 아직 늘리지 않은 칸은 흐리게 보인다.
	var pages := maxi(1, ceili(float(GameState.bag_size) / PAGE))
	_page = clampi(_page, 0, pages - 1)
	for k in PAGE:
		var i := _page * PAGE + k
		var pos2 := Vector2(96 + (k % 6) * 34, (k / 6) * 33)
		if i >= GameState.bag_size:
			_icon(_body, "ui_slot", pos2, 31, Color(1, 1, 1, 0.25))
			continue
		_icon(_body, "ui_slot_on" if selected == i else "ui_slot", pos2, 31)
		if i < GameState.inventory.size():
			var item2: Dictionary = GameState.inventory[i]
			_icon(_body, Items.icon(item2), pos2 + Vector2(4, 4), 23, Items.tier_color(item2))
			_hit(_body, pos2, Vector2(31, 31), _select.bind(i))
	if pages > 1:
		UI.icon_button(_win, "ui_arrow_l", Vector2(292, 38), Vector2(17, 17), _turn_page.bind(-1)).disabled = _page == 0
		var pl := _label(_win, "%d / %d" % [_page + 1, pages], Vector2(310, 40), Vector2(34, 14), 9)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pl.set_meta("temp", true)
		UI.icon_button(_win, "ui_arrow_r", Vector2(345, 38), Vector2(17, 17), _turn_page.bind(1)).disabled = _page >= pages - 1
	# 고른 장비의 설명과 단추
	var item3 := _selected_item()
	if item3.is_empty():
		_info.text = _message if _message != "" else "장비 %d / %d칸   동전 %d   지우개 가루 %d" % [
			GameState.inventory.size(), GameState.bag_size, GameState.coins, GameState.dust]
		if GameState.bag_size < GameState.BAG_MAX:
			var cost := GameState.bag_expand_cost()
			var tl := _label(_win, "칸 늘리기 +%d" % GameState.BAG_STEP, Vector2(100, 215), Vector2(72, 14), 9)
			tl.set_meta("temp", true)
			_button(_win, "동전 %d" % int(cost[0]), Vector2(172, 211), Vector2(64, 20), _expand.bind("coins")).disabled = GameState.coins < int(cost[0])
			_button(_win, "지우개 가루 %d" % int(cost[1]), Vector2(240, 211), Vector2(88, 20), _expand.bind("dust")).disabled = GameState.dust < int(cost[1])
		return
	_info.text = Items.describe(item3).replace("\n", "   ")
	if selected >= 0:
		_button(_win, "입기", Vector2(226, 218), Vector2(40, 20), _equip_selected)
		_button(_win, "분해", Vector2(270, 218), Vector2(40, 20), _disassemble_selected)
	else:
		_button(_win, "벗기", Vector2(270, 218), Vector2(40, 20), _unequip_selected)


func _materials_grid() -> void:
	for i in Data.MATERIALS.size():
		var pos := Vector2(4 + (i % 6) * 49, (i / 6) * 62)
		var n := GameState.material_count(i)
		_icon(_body, "ui_slot", pos + Vector2(3, 0), 38)
		_icon(_body, "mat_%d" % i, pos + Vector2(9, 6), 26, Color(1, 1, 1, 1) if n > 0 else Color(0.2, 0.2, 0.2, 0.25))
		var count := _label(_body, str(n) if n > 0 else "", pos + Vector2(20, 24), Vector2(22, 12), 9)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var name_l := _label(_body, str(Data.MATERIALS[i]) if n > 0 else "?", pos + Vector2(-4, 39), Vector2(52, 12), 8)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.text = "필력 %d   경험치 %d / %d   연필심 %d   동전 %d   지우개 가루 %d" % [
		GameState.level, GameState.exp, GameState.exp_needed(), GameState.pencil_lead, GameState.coins, GameState.dust]


func _turn_page(d: int) -> void:
	_page += d
	selected = -1
	refresh()


func _expand(with: String) -> void:
	_message = "가방이 %d칸으로 늘었어요." % (GameState.bag_size + GameState.BAG_STEP) if GameState.expand_bag(with) else "값이 모자라요."
	refresh()


func _select(i: int) -> void:
	selected = i
	_message = ""
	_clear_action_buttons()
	refresh()


func _selected_item() -> Dictionary:
	if selected >= 0 and selected < GameState.inventory.size():
		return GameState.inventory[selected]
	if selected <= -2:
		var slot := str(Items.SLOTS[-2 - selected])
		if GameState.equipped.has(slot):
			return GameState.equipped[slot]
	return {}


## 입기·분해·벗기 단추는 창에 직접 붙이므로 따로 지운다
func _clear_action_buttons() -> void:
	for c in _win.get_children():
		if (c is Button and not _tab_buttons.has(c) and not _fixed.has(c)) or c.has_meta("temp"):
			c.queue_free()


func _equip_selected() -> void:
	var i := selected
	selected = -1
	_clear_action_buttons()
	if not GameState.equip(i):
		_message = "필력이 모자라서 쓸 수 없어요."
		refresh()


func _disassemble_selected() -> void:
	var i := selected
	selected = -1
	_clear_action_buttons()
	_message = "지우개 가루 %d개를 얻었어요." % GameState.disassemble(i)
	refresh()


func _unequip_selected() -> void:
	var slot := str(Items.SLOTS[-2 - selected])
	selected = -1
	_clear_action_buttons()
	if not GameState.unequip(slot):
		_message = "가방이 가득 차서 벗을 수 없어요."
		refresh()


# ---------- 스킬 ----------

func _refresh_skills() -> void:
	var box := _list()
	for id in Items.SKILL_ORDER:
		var info: Dictionary = Items.SKILLS[id]
		var rank := GameState.skill_rank(str(id))
		var locked := GameState.level < int(info["level"])
		var text := "%s  %d/%d" % [info["name"], rank, int(info["max"])]
		if locked:
			text += "  (필력 %d 부터)" % int(info["level"])
		elif str(info["kind"]) == "active":
			text += "  MP %d · %d초" % [int(info["mp"]), int(info["cd"])]
		var buttons: Array = []
		if str(info["kind"]) == "active" and rank > 0:
			for s in Items.SKILL_KEYS.size():
				var here: bool = str(GameState.skill_slots[s]) == str(id)
				buttons.append([str(Items.SKILL_KEYS[s]), GameState.set_skill_slot.bind(s, str(id)), not here])
		buttons.append(["+", _learn.bind(str(id)), GameState.skill_points > 0 and not locked and rank < int(info["max"])])
		_row(box, str(info["icon"]), text, buttons, Color(1, 1, 1, 0.35) if locked else Color.WHITE)
	if _message == "":
		_info.text = "스킬 포인트 %d   (레벨마다 1점)   + 로 배우고, Q·E·R 을 눌러 칸에 넣어요." % GameState.skill_points


func _learn(id: String) -> void:
	if GameState.learn_skill(id):
		_message = "%s: %s" % [Items.SKILLS[id]["name"], Items.SKILLS[id]["desc"]]
	refresh()


# ---------- 문방구 ----------

func _refresh_shop() -> void:
	var box := _list()
	var wallet := "동전 %d   연필심 %d   지우개 가루 %d" % [GameState.coins, GameState.pencil_lead, GameState.dust]
	if tab == 0:
		for entry in Items.SHOP:
			if typeof(entry) == TYPE_STRING:
				var info: Array = Items.CONSUMABLES[entry]
				_row(box, GameState.consumable_icon(str(entry)), "%s  (%d개 있음)  %s" % [info[0], GameState.consumable_count(str(entry)), info[3]],
					[["%d" % int(info[2]), _buy.bind(entry), GameState.coins >= int(info[2])]])
			else:
				var arr: Array = entry
				var sample := {"slot": arr[0], "shape": arr[1], "tier": arr[2], "level": 1, "plus": 0, "opts": []}
				_row(box, Items.icon(sample), Items.item_name(sample) + "  " + Items.stat_text(str(Items.MAIN_STAT[str(arr[0])]), Items.main_value(sample)),
					[["%d" % int(arr[3]), _buy.bind(entry), GameState.coins >= int(arr[3])]], Items.tier_color(sample))
	elif tab == 1:
		for i in GameState.inventory.size():
			var item: Dictionary = GameState.inventory[i]
			_row(box, Items.icon(item), Items.item_name(item),
				[["팔기 %d" % Items.sell_price(item), _sell.bind(i), true]], Items.tier_color(item))
		if GameState.inventory.is_empty():
			_row(box, "", "팔 장비가 없어요.", [])
	elif tab == 2:
		for recipe in Items.RECIPES:
			var parts: Array = []
			var mats: Dictionary = recipe[2]
			for id in mats:
				parts.append("%s %d/%d" % [Data.MATERIALS[int(id)], GameState.material_count(int(id)), int(mats[id])])
			if int(recipe[3]) > 0:
				parts.append("연필심 %d" % int(recipe[3]))
			var icon_name := ""
			var tint := Color.WHITE
			if typeof(recipe[1]) == TYPE_STRING:
				icon_name = str(Items.CONSUMABLES[recipe[1]][1])
			else:
				var r: Array = recipe[1]
				icon_name = "equip_%s_%d" % [r[0], int(r[1])]
				tint = Items.TIER_COLORS[int(r[2])]
			_row(box, icon_name, "%s  ←  %s" % [recipe[0], ", ".join(parts)], [["그리기", _craft.bind(recipe), GameState.can_craft(recipe)]], tint)
		wallet += "   직접 그려서 만들어요."
	else:
		var all: Array = []
		for slot in Items.SLOTS:
			if GameState.equipped.has(slot):
				all.append(GameState.equipped[slot])
		all.append_array(GameState.inventory)
		for item2 in all:
			var cost: Array = Items.enhance_cost(item2)
			var maxed := int(item2.get("plus", 0)) >= Items.MAX_PLUS
			var text := "%s   연필심 %d · 가루 %d · 성공 %d%%" % [Items.item_name(item2), int(cost[0]), int(cost[1]), roundi(Items.enhance_rate(item2) * 100.0)]
			_row(box, Items.icon(item2), Items.item_name(item2) + "  (최고 단계)" if maxed else text,
				[["강화", _enhance.bind(item2), not maxed]], Items.tier_color(item2))
		wallet += "   +7부터 실패하면 하락, +10부터 파괴"
	_info.text = (_message + "\n" if _message != "" else "") + wallet


func _buy(entry: Variant) -> void:
	_message = "샀어요." if GameState.buy(entry) else "동전이 모자라거나 가방이 가득 찼어요."
	refresh()


func _sell(i: int) -> void:
	_message = "동전 %d개를 받았어요." % GameState.sell_item(i)
	refresh()


## 직접 그려서 만들기 화면을 연다 (scripts/craft_canvas.gd)
func _craft(recipe: Array) -> void:
	if is_instance_valid(_canvas) or not GameState.can_craft(recipe):
		return
	_canvas = CraftCanvas.new()
	_canvas.call("setup", recipe)
	add_child(_canvas)
	_canvas.connect("done", func(msg: String) -> void:
		_message = msg
		refresh())


func is_drawing() -> bool:
	return is_instance_valid(_canvas)


func _enhance(item: Dictionary) -> void:
	var result := GameState.enhance(item)
	var texts := {"ok": "강화 성공!", "fail": "실패… 다행히 그대로예요.", "down": "실패… 한 단계 내려갔어요.",
		"broken": "실패… 장비가 지워졌어요.", "saved": "실패했지만 코팅지가 막아 줬어요."}
	_message = str(texts.get(result, result))
	refresh()


# ---------- 친구 (P) ----------

## 친구 종의 얼굴 그림 (띠 그림은 첫 칸만 잘라 쓴다)
func _friend_tex(sp: String) -> Texture2D:
	var l: Array = load("res://scripts/companion.gd").look(sp)
	var tex: Texture2D = l[0]
	if tex == null or int(l[1]) <= 1:
		return tex
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(0, 0, tex.get_width() / float(l[1]), tex.get_height())
	return at


func _refresh_friends() -> void:
	var box := _list()
	if GameState.friends.is_empty():
		_row(box, "icon_paper", "아직 친구가 없어요.", [])
	for i in GameState.friends.size():
		var f: Dictionary = GameState.friends[i]
		var with := GameState.companion == i
		var text := "%s  Lv %d  공격 %d%s" % [GameState.friend_name(f), int(f["lv"]), GameState.friend_attack(f), "  (동행)" if with else ""]
		var same := 0
		for o in GameState.friends:
			if not is_same(o, f) and str(o["sp"]) == str(f["sp"]):
				same += 1
		var buttons: Array = [["쉬기" if with else "동행", GameState.set_companion.bind(i), true]]
		buttons.append(["합치기", _merge.bind(i, false), int(f["stars"]) < 5 and same >= GameState.merge_need(f)])
		if GameState.cross_partner(i) >= 0:
			buttons.append(["섞기", _merge.bind(i, true), true])
		buttons.append(["보내기", _release.bind(i), true])
		_row(box, "", text, buttons)
		var row := box.get_child(box.get_child_count() - 1) as Control
		var face := UI.icon(row, "", Vector2(4, 2), Vector2(20, 20), Data.FRIENDS[str(f["sp"])].get("tint", Color.WHITE))
		face.texture = _friend_tex(str(f["sp"]))
	if _message == "":
		_info.text = "친구 %d / %d   쓰러진 몬스터에게 F: 도화지에 다시 그려 주면 친구가 돼요.\n합치기: 같은 종끼리 별 +1 (능력 +15%%).  G 키: 친구 스킬" % [
			GameState.friends.size(), GameState.FRIEND_MAX]


func _merge(i: int, cross: bool) -> void:
	var name := GameState.friend_name(GameState.friends[i])
	if cross:
		_message = "새 친구가 태어났어요!" if GameState.merge_cross(i) else "섞을 수 없어요."
	else:
		_message = "%s 에게 별이 하나 붙었어요." % name if GameState.merge_same(i) else "같은 종 친구가 모자라요."
	refresh()


func _release(i: int) -> void:
	_message = "%s 을(를) 공책으로 돌려보냈어요." % GameState.friend_name(GameState.friends[i])
	GameState.release_friend(i)
	refresh()


# ---------- 짓기 (내 마을, N) ----------

func _refresh_build() -> void:
	var box := _list()
	if tab == 0:
		var cost := GameState.home_expand_cost()
		if cost.is_empty():
			_row(box, "icon_paper", "종이를 다 이어 붙였어요. (16장)", [])
		else:
			_row(box, "icon_paper_thick", "종이 붙이기 (%d장)  ←  %s" % [GameState.home_sheets, GameState.cost_text(cost)],
				[["넓히기", _choose.bind("expand"), GameState.can_afford(cost)]])
	for id in Data.BUILDS:
		var b: Dictionary = Data.BUILDS[id]
		if (str(b["kind"]) == "building") != (tab == 0):
			continue
		_row(box, str(id), "%s  ←  %s" % [b["name"], GameState.cost_text(b["cost"])],
			[["고르기", _choose.bind(str(id)), GameState.can_afford(b["cost"])]])
	_row(box, "tool_eraser", "치우기 (누른 것을 치우고 동전의 절반을 돌려받는다)", [["고르기", _choose.bind(""), true]])
	if _message == "":
		_info.text = "연필심 %d   동전 %d\n건물은 자리를 고른 뒤 점선을 따라 그려서 지어요. 잘 그리면 정성 건물이 돼요." % [GameState.pencil_lead, GameState.coins]


func _choose(id: String) -> void:
	build_chosen.emit(id)
