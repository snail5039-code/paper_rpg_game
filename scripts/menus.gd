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
const TITLES := {"bag": "가방", "skills": "스킬", "shop": "문방구", "friends": "친구", "build": "짓기", "storage": "창고", "board": "게시판", "pause": "도움말", "farm": "밭", "cook": "식당", "resident": "주민", "furnish": "꾸미기", "portal": "난이도"}
const TABS := {"bag": ["장비", "재료", "소모품"], "skills": [], "shop": ["사기", "팔기", "만들기", "강화", "씨앗", "가구"], "farm": [], "cook": [], "resident": [], "furnish": [], "portal": [], "friends": [], "build": ["건물", "소품"], "storage": ["넣기", "꺼내기"], "board": [], "pause": ["조작", "게임", "저장"]}
const CLOSE_HINT := {"bag": "I  닫기", "skills": "K  닫기", "shop": "Esc  닫기", "friends": "P  닫기", "build": "N  닫기", "storage": "Esc  닫기", "board": "Esc  닫기", "pause": "Esc  닫기", "farm": "Esc  닫기", "cook": "Esc  닫기", "resident": "Esc  닫기", "furnish": "N  닫기", "portal": "Esc  닫기"}

var kind := "bag"
var tab := 0
var selected := -1            # 가방에서 고른 장비 (-1 없음). 입은 장비는 -2 - 부위 번호
var _win: Control
var _body: Control
var _info: Label
var _tab_buttons: Array = []
var _fixed: Array = []         # 다시 그려도 남기는 단추 (닫기)
var _message := ""
var _pending := ""             # 한 번 더 눌러야 하는 행동 (확인 대기)
var ctx := ""                  # 무엇에 대한 창인지 (밭의 자리, 주민의 id, 포탈의 목적지)
var _seed := ""                # 밭에서 고른 씨앗
var _memory := 0
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
		var many := (TABS[kind] as Array).size() > 4
		var b := UI.button(_win, str(TABS[kind][i]), Vector2(x, 37), Vector2(44 if many else 50, 19), _set_tab.bind(i), "tab")
		_tab_buttons.append(b)
		x += 46.0 if many else 52.0
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
	_pending = ""
	_message = ""
	refresh()


func _set_tab(i: int) -> void:
	tab = i
	_pending = ""
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
		var w := maxf(22.0, ceilf(UI.text_width(str(spec[0]))) + 14.0)
		x -= w + 3.0
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
		"storage": _refresh_storage()
		"board": _refresh_board()
		"pause": _refresh_pause()
		"farm": _refresh_farm()
		"cook": _refresh_cook()
		"resident": _refresh_resident()
		"furnish": _refresh_furnish()
		"portal": _refresh_portal()


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
				_row(box, GameState.consumable_icon(str(id)), "%s ×%d   %s" % [info[0], n, info[3]],
					[["쓰기", _use.bind(str(id)), true], ["1", GameState.set_quick_slot.bind(0, str(id)), str(GameState.quick_slots[0]) != str(id)],
						["2", GameState.set_quick_slot.bind(1, str(id)), str(GameState.quick_slots[1]) != str(id)]] if str(info[4]) != "" else [])
		_info.text = "1 번 키: %s    2 번 키: %s\n1, 2 단추를 누르면 그 키에 넣어요." % [
			Items.CONSUMABLES[str(GameState.quick_slots[0])][0], Items.CONSUMABLES[str(GameState.quick_slots[1])][0]]
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
		_info.text += _compare(item3)
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


## 되돌릴 수 없는 행동은 같은 단추를 한 번 더 눌러야 한다. 두 번째에 true 를 돌려준다.
func _sure(key: String, text: String) -> bool:
	if _pending == key:
		_pending = ""
		return true
	_pending = key
	_message = text + "  한 번 더 누르면 진행해요."
	refresh()
	return false


## 아낄 만한 장비인지 (등급이 있거나, 강화했거나, 직접 그린 것)
func _precious(item: Dictionary) -> bool:
	return int(item["tier"]) >= 1 or int(item.get("plus", 0)) > 0 or str(item.get("art", "")) != ""


## 지금 입은 같은 부위 장비와 기본 능력을 견준 글
func _compare(item: Dictionary) -> String:
	var slot := str(item["slot"])
	if not GameState.equipped.has(slot):
		return "   (그 자리는 비어 있음)"
	var d := Items.main_value(item) - Items.main_value(GameState.equipped[slot])
	return "   (입은 것보다 %s%d)" % ["+" if d >= 0 else "", d]


func _select(i: int) -> void:
	if i >= 0 and i == selected and kind == "bag":
		_equip_selected()      # 고른 장비를 한 번 더 누르면 바로 입는다
		return
	_pending = ""
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
	var it := _selected_item()
	if not it.is_empty() and _precious(it) and not _sure("dis%d" % selected, "%s 을(를) 분해하면 되돌릴 수 없어요." % Items.item_name(it)):
		return
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
		# 줄의 이름 쪽을 누르면 설명이 나온다 (배우기 전에도 볼 수 있다)
		_hit(box.get_child(box.get_child_count() - 1) as Control, Vector2.ZERO, Vector2(150, 24), _show_skill.bind(str(id)))
	if _message == "":
		_info.text = "스킬 포인트 %d (레벨마다 1점)   이름을 누르면 설명이 나와요.\n+ 로 배우고, Q·E·R 을 눌러 칸에 넣어요." % GameState.skill_points


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
					[["%d" % GameState.price_of(entry), _buy.bind(entry), GameState.coins >= GameState.price_of(entry)]])
			else:
				var arr: Array = entry
				var sample := {"slot": arr[0], "shape": arr[1], "tier": arr[2], "level": 1, "plus": 0, "opts": []}
				_row(box, Items.icon(sample), Items.item_name(sample) + "  " + Items.stat_text(str(Items.MAIN_STAT[str(arr[0])]), Items.main_value(sample)),
					[["%d" % GameState.price_of(entry), _buy.bind(entry), GameState.coins >= GameState.price_of(entry)]], Items.tier_color(sample))
	elif tab == 1:
		for i in GameState.inventory.size():
			var item: Dictionary = GameState.inventory[i]
			_row(box, Items.icon(item), Items.item_name(item),
				[["팔기 %d" % Items.sell_price(item), _sell.bind(i), true]], Items.tier_color(item))
		# 먹거리와 잡동사니도 판다 (값의 절반)
		for gid in Items.CONSUMABLES:
			var g := str(gid)
			if GameState.consumable_count(g) > 0 and (g.begins_with("f_") or g.begins_with("j_") or g.begins_with("c_") or g.begins_with("g_") or g.begins_with("d_")):
				_row(box, GameState.consumable_icon(g), "%s ×%d" % [Items.CONSUMABLES[g][0], GameState.consumable_count(g)],
					[["팔기 %d" % maxi(1, int(Items.CONSUMABLES[g][2]) / 2), _sell_goods.bind(g), true]])
		if box.get_child_count() == 0:
			_row(box, "", "팔 것이 없어요.", [])
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
	elif tab == 4:
		for sid in Items.CROPS:
			var info2: Array = Items.CONSUMABLES[sid]
			_row(box, str(info2[1]), "%s  (%d개 있음)  %d일" % [info2[0], GameState.consumable_count(str(sid)), int(Items.CROPS[sid][1])],
				[["%d" % GameState.price_of(sid), _buy.bind(sid), GameState.coins >= GameState.price_of(sid)]])
		wallet += "   밭(내 마을, N)에 심어요."
	elif tab == 5:
		for fid in Items.FURNITURE:
			var cost2 := int(Items.FURNITURE[fid][1])
			if cost2 <= 0:
				continue
			_row(box, str(fid), "%s  (%d개 있음)" % [Items.FURNITURE[fid][0], GameState.furniture_count(str(fid))],
				[["%d" % cost2, _buy_furniture.bind(str(fid)), GameState.coins >= cost2]])
		wallet += "   내 집 안에서 N 으로 놓아요."
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
	var it: Dictionary = GameState.inventory[i]
	if _precious(it) and not _sure("sell%d" % i, "%s 을(를) 팔면 되돌릴 수 없어요." % Items.item_name(it)):
		return
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
	if not _sure("rel%d" % i, "%s 을(를) 보내면 다시 만날 수 없어요." % GameState.friend_name(GameState.friends[i])):
		return
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


## 가방의 소모품을 쓴다 (HP·MP 회복)
func _use(id: String) -> void:
	var p := GameState.player_ref
	if is_instance_valid(p) and bool(p.call("use_consumable", id)):
		_message = "%s 을(를) 썼어요." % Items.CONSUMABLES[id][0]
	else:
		_message = "지금은 쓸 필요가 없어요."
	refresh()


# ---------- 창고 (내 마을의 창고 건물) ----------

func _refresh_storage() -> void:
	var box := _list()
	var from: Array = GameState.inventory if tab == 0 else GameState.storage
	for i in from.size():
		var item: Dictionary = from[i]
		_row(box, Items.icon(item), Items.item_name(item) + "  " + Items.stat_text(str(Items.MAIN_STAT[str(item["slot"])]), Items.main_value(item)),
			[["넣기" if tab == 0 else "꺼내기", _move.bind(i), true]], Items.tier_color(item))
	if from.is_empty():
		_row(box, "", "가방에 넣을 장비가 없어요." if tab == 0 else "창고가 비어 있어요.", [])
	if _message == "":
		_info.text = "창고 %d / %d칸   가방 %d / %d칸\n창고는 모든 캐릭터가 같이 써요." % [
			GameState.storage.size(), GameState.storage_size(), GameState.inventory.size(), GameState.bag_size]


func _move(i: int) -> void:
	var ok := GameState.store_item(i) if tab == 0 else GameState.take_item(i)
	_message = "" if ok else ("창고가 가득 찼어요." if tab == 0 else "가방이 가득 찼어요.")
	refresh()


# ---------- 게시판 (하루 부탁 3개) ----------

func _refresh_board() -> void:
	var box := _list()
	for i in GameState.board_quests.size():
		var q: Dictionary = GameState.board_quests[i]
		var name := str(Data.FRIENDS[str(q["sp"])]["name"])
		var text := "%s 물리치기 %d/%d   동전 %d · 경험 %d" % [name, mini(int(q["have"]), int(q["need"])), int(q["need"]),
			GameState.board_reward(q, "coins"), GameState.board_reward(q, "exp")]
		var done := int(q["have"]) >= int(q["need"])
		_row(box, "ui_stamp_0" if bool(q["claimed"]) else "ui_note", text,
			[["받음" if bool(q["claimed"]) else "받기", _claim.bind(i), done and not bool(q["claimed"])]])
	if _message == "":
		_info.text = "%d일째의 부탁이에요. 날이 바뀌면 새 부탁 3개가 붙어요." % GameState.day


func _claim(i: int) -> void:
	_message = "보상을 받았어요!" if GameState.board_claim(i) else "아직 다 하지 못했어요."
	refresh()


func _show_skill(id: String) -> void:
	var info: Dictionary = Items.SKILLS[id]
	_message = "%s: %s  (필력 %d 부터, 최대 %d단계)" % [info["name"], info["desc"], int(info["level"]), int(info["max"])]
	refresh()


# ---------- 도움말 (Esc) ----------

const HELP_KEYS := [
	["W A S D", "이동"], ["마우스 왼쪽", "공격 (3연타)"], ["Space", "회피"], ["F", "말 걸기 · 들어가기"],
	["Q  E  R", "스킬"], ["V", "필살기"], ["1  2", "소모품"], ["G", "친구 스킬"],
	["I", "가방"], ["K", "스킬 배우기"], ["C", "능력치"], ["P", "친구"],
	["M", "지도"], ["Tab", "연필 (낙서)"], ["B", "내 마을: 칠하기"], ["N", "내 마을: 짓기"],
]
const HELP_GAME := [
	"피로도: 사냥터 화면마다 2 줄어요. 아침 6시나 내 집에서 자면 가득 차요.",
	"시간: 하루는 90분 (낮 60, 밤 30). 밤에는 몬스터가 세지고 큰 물고기가 잘 잡혀요.",
	"다시 그리기: 도화지(문방구)가 있으면 쓰러진 몬스터에게 F. 따라 그리면 친구가 돼요.",
	"쓰러지면: 연필심의 10%를 잃고 내 마을로 돌아가요.",
	"만들기: 문방구에서 견본을 따라 그려요. 비슷할수록 좋은 물건이 나와요.",
]


func _refresh_pause() -> void:
	if tab == 0:
		for i in HELP_KEYS.size():
			var pos := Vector2((i % 2) * 150, (i / 2) * 16)
			var k := _label(_body, str(HELP_KEYS[i][0]), pos, Vector2(52, 14), 9)
			k.add_theme_color_override("font_color", Color(0.75, 0.35, 0.3))
			_label(_body, str(HELP_KEYS[i][1]), pos + Vector2(54, 0), Vector2(94, 14), 9)
		_info.text = "창이 열린 채로 다른 창의 키를 누르면 바로 바뀌어요."
	elif tab == 1:
		var t := _label(_body, "\n".join(HELP_GAME), Vector2.ZERO, _body.size + Vector2(0, 40), 9)
		t.clip_text = false
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info.text = ""
	else:
		_label(_body, "게임은 맵을 옮길 때와 잠잘 때 저절로 저장돼요.", Vector2(0, 6), Vector2(300, 14), 9)
		_button(_body, "지금 저장하기", Vector2(60, 34), Vector2(180, 24), _save_now)
		_button(_body, "저장하고 게임 끝내기", Vector2(60, 66), Vector2(180, 24), _quit)
		if _message == "":
			_info.text = "%d일째  %s   피로도 %d" % [GameState.day, GameState.clock_text(), GameState.fatigue]


func _save_now() -> void:
	_message = "저장했어요." if GameState.save_game() else "저장하지 못했어요."
	refresh()


func _quit() -> void:
	if not _sure("quit", "게임을 끝낼까요?"):
		return
	GameState.save_game()
	get_tree().quit()


func _sell_goods(id: String) -> void:
	_message = "동전 %d개를 받았어요." % GameState.sell_goods(id)
	refresh()


func _buy_furniture(id: String) -> void:
	_message = "%s 을(를) 샀어요." % Items.FURNITURE[id][0] if GameState.buy_furniture(id) else "동전이 모자라요."
	refresh()


# ---------- 밭 ----------

func _owned_seeds() -> Array:
	var out: Array = []
	for sid in Items.CROPS:
		if GameState.consumable_count(str(sid)) > 0:
			out.append(str(sid))
	return out


func _refresh_farm() -> void:
	var box := _list()
	var seeds := _owned_seeds()
	if not seeds.has(_seed):
		_seed = str(seeds[0]) if not seeds.is_empty() else ""
	if _seed == "":
		_row(box, "icon_seed", "씨앗이 없어요. (문방구의 씨앗 탭)", [])
	else:
		_row(box, "icon_seed", "심을 씨앗: %s ×%d" % [Items.CONSUMABLES[_seed][0], GameState.consumable_count(_seed)],
			[["다른 씨앗", _next_seed, seeds.size() > 1]])
	_row(box, "icon_water", "물 주기 (심은 칸 전부, 하루 한 번)", [["물 주기", _water, true]])
	var plots := GameState.farm_plots(ctx)
	for i in plots.size():
		var p: Dictionary = plots[i]
		if str(p["seed"]) == "":
			_row(box, "", "%d번 칸: 비어 있음" % (i + 1), [["심기", _plant.bind(i), _seed != ""]])
			continue
		var crop := str(Items.CROPS[str(p["seed"])][0])
		var need := int(Items.CROPS[str(p["seed"])][1])
		if GameState.plot_ripe(p):
			_row(box, str(Items.CONSUMABLES[crop][1]), "%d번 칸: %s  다 자랐어요!" % [i + 1, Items.CONSUMABLES[crop][0]], [["거두기", _harvest.bind(i), true]])
		else:
			_row(box, "crop_sprout", "%d번 칸: %s  %d/%d일  %s" % [i + 1, Items.CONSUMABLES[crop][0], int(p["grown"]), need,
				"물 줌" if bool(p["watered"]) else "물이 필요해요"], [])
	if _message == "":
		_info.text = "물을 준 칸만 날이 바뀔 때 하루만큼 자라요."


func _next_seed() -> void:
	var seeds := _owned_seeds()
	_seed = str(seeds[(seeds.find(_seed) + 1) % seeds.size()])
	refresh()


func _plant(i: int) -> void:
	_message = "심었어요. 물을 주세요." if GameState.plant(ctx, i, _seed) else "심을 수 없어요."
	refresh()


func _water() -> void:
	var n := GameState.water(ctx)
	_message = "%d칸에 물을 줬어요." % n if n > 0 else "물을 줄 칸이 없어요."
	refresh()


func _harvest(i: int) -> void:
	var id := GameState.harvest(ctx, i)
	_message = "%s 을(를) 거뒀어요." % Items.CONSUMABLES[id][0] if id != "" else "아직 덜 자랐어요."
	refresh()


# ---------- 식당 ----------

func _refresh_cook() -> void:
	var box := _list()
	for dish in Items.DISHES:
		var parts: Array = []
		var need: Dictionary = Items.DISHES[dish]
		for id in need:
			parts.append("%s %d/%d" % [Items.CONSUMABLES[id][0], GameState.consumable_count(str(id)), int(need[id])])
		_row(box, str(Items.CONSUMABLES[dish][1]), "%s  ←  %s" % [Items.CONSUMABLES[dish][0], ", ".join(parts)],
			[["요리", _cook.bind(str(dish)), GameState.can_cook(str(dish))]])
		_hit(box.get_child(box.get_child_count() - 1) as Control, Vector2.ZERO, Vector2(200, 24), _show_dish.bind(str(dish)))
	if _message == "":
		_info.text = "요리 이름을 누르면 효과가 나와요. 만든 요리는 가방의 소모품에서 먹어요."


func _show_dish(dish: String) -> void:
	_message = "%s: %s" % [Items.CONSUMABLES[dish][0], Items.CONSUMABLES[dish][3]]
	refresh()


func _cook(dish: String) -> void:
	_message = "%s 을(를) 만들었어요. (%s)" % [Items.CONSUMABLES[dish][0], Items.CONSUMABLES[dish][3]] if GameState.cook(dish) else "재료가 모자라요."
	refresh()


# ---------- 주민 ----------

func _refresh_resident() -> void:
	if not Data.VILLAGERS.has(ctx):
		return
	var box := _list()
	var v := GameState.villager(ctx)
	var info: Dictionary = Data.VILLAGERS[ctx]
	var like := str(info["like"])
	var h := GameState.hearts(ctx)
	_row(box, "", "이야기하기  (하루 한 번, 호감 +1)", [["이야기", _talk, int(v["talk_day"]) != GameState.day]])
	_row(box, GameState.consumable_icon(like), "선물하기: %s  (가진 것 %d, 호감 +3)" % [Items.CONSUMABLES[like][0], GameState.consumable_count(like)],
		[["주기", _give, int(v.get("give_day", 0)) != GameState.day and GameState.consumable_count(like) > 0]])
	_row(box, GameState.consumable_icon(str(info["gift"])), "오늘의 선물: %s  (하트 1개부터)" % Items.CONSUMABLES[str(info["gift"])][0],
		[["받기", _daily, h >= 1 and int(v["gift_day"]) != GameState.day]])
	_row(box, "", "옛 기억  (하트 3개부터)", [["듣기", _recall, h >= 3]])
	var next := "다 채웠어요" if h >= 5 else "다음 하트까지 %d" % (int(Data.HEART_NEED[h]) - int(v["aff"]))
	var head := "%s (%s)   %s%s   호감 %d  (%s)" % [GameState.villager_name(ctx), info["title"], "♥".repeat(h), "♡".repeat(5 - h), int(v["aff"]), next]
	_info.text = head + ("\n" + _message if _message != "" else "")


func _talk() -> void:
	var lines := ["여기 살게 해 줘서 고마워.", "네가 그린 마을, 마음에 들어.", "오늘은 날이 좋네. 종이 냄새가 나."]
	if GameState.hearts(ctx) >= 5:
		lines = ["나는 %s. 네가 지어 준 이름이야. 이제 누가 물어도 대답할 수 있어." % GameState.villager_name(ctx)]
	_message = "\"%s\"" % lines[GameState.day % lines.size()] if GameState.villager_talk(ctx) else "오늘은 이미 이야기했어요."
	refresh()


func _give() -> void:
	_message = "\"이거 내가 좋아하는 건데! 고마워.\"" if GameState.villager_give(ctx) else "줄 수 없어요."
	refresh()


func _daily() -> void:
	var id := GameState.villager_daily(ctx)
	_message = "%s 을(를) 받았어요." % Items.CONSUMABLES[id][0] if id != "" else "오늘은 이미 받았어요."
	refresh()


func _recall() -> void:
	var mem: Array = Data.VILLAGERS[ctx]["memory"]
	_message = "\"%s\"" % mem[_memory % mem.size()]
	_memory += 1
	refresh()


# ---------- 꾸미기 (내 집 안, N) ----------

func _refresh_furnish() -> void:
	var box := _list()
	var any := false
	for fid in Items.FURNITURE:
		var n := GameState.furniture_count(str(fid))
		if n > 0:
			any = true
			_row(box, str(fid), "%s ×%d" % [Items.FURNITURE[fid][0], n], [["놓기", _choose.bind(str(fid)), true]])
	if not any:
		_row(box, "", "가진 가구가 없어요. (문방구의 가구 탭, 주민의 선물)", [])
	_row(box, "tool_eraser", "치우기 (누른 가구를 가방으로)", [["고르기", _choose.bind(""), true]])
	if _message == "":
		_info.text = "가구를 고른 뒤 방 안을 눌러 놓아요. 오른쪽 클릭으로 그만둬요."


# ---------- 난이도 (내 마을의 문) ----------

func _refresh_portal() -> void:
	var box := _list()
	for i in Data.DIFFICULTY.size():
		var d: Dictionary = Data.DIFFICULTY[i]
		var open := i <= GameState.max_difficulty
		_row(box, "portal_open" if open else "portal_locked", "%s  필력 %d+  HP×%d 공격×%d 경험×%d" % [d["name"], int(d["level"]), int(d["hp"]), int(d["dmg"]), int(d["exp"])],
			[["들어가기", _enter.bind(i), open]])
	if _message == "":
		_info.text = "대장을 물리치면 다음 단계가 열려요. 단계가 높을수록 좋은 장비가 나와요."


func _enter(i: int) -> void:
	var parts := ctx.split("|")
	if GameState.set_difficulty(i):
		close_requested.emit()
		GameState.goto_map(parts[0], parts[1] if parts.size() > 1 else "")
