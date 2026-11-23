extends StaticBody2D
## 내 마을에 지은 건물이나 놓은 소품 하나. 종류는 game_data.gd 의 BUILDS 표.
##  건물은 F 로 쓸 수 있다: 내 집(잠자기), 문방구, 조합대. 나머지는 아직 준비 중.
##  "정성"으로 지은 건물(따라 그리기 85% 이상)은 지붕 위에 별이 반짝인다.

const Art := preload("res://scripts/art.gd")
const Data := preload("res://scripts/game_data.gd")
const RANGE := 44.0
const PLOT_REACH := 18.0     # 이만큼 가까운 밭 칸에 물뿌리개로 물을 준다
const PEN_SPEED := 9.0       # 우리 안의 친구가 걷는 빠르기
const Companion := preload("res://scripts/companion.gd")
var _drop: Texture2D

var id := "deco_bush"
var fine := false
var lv := 3                 # 건물 단계 (1 초가집 ~ 5 저택). 3단계가 기준 그림이다.
var ghost := false          # 놓을 자리를 고르는 중인 흐린 그림 (부딪히지 않는다)
var info: Dictionary
var _sprite: Sprite2D
var _star: Texture2D
var _key: Texture2D
var _t := 0.0
var _asked := -10.0
var _extra: Array = []          # 주민이나 작물 그림
var _extra_state := "?"
const Items := preload("res://scripts/items.gd")
var _height := 20.0


func _ready() -> void:
	info = Data.BUILDS.get(id, Data.BUILDS["deco_bush"])
	_star = Art.tex("fx_hit")
	_key = Art.tex("key_f")
	_drop = Art.tex("icon_water")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var is_building := str(info["kind"]) == "building"
	var tex := Art.tex(Data.build_sprite(id, lv) if is_building else id)
	var w := float(info["w"])
	if tex:
		_sprite = Art.make_sprite(self, tex, Vector2(0, 4))
		# 단계마다 그림의 크기가 다르다: 3단계 그림을 기준으로 같은 배율을 쓴다 (초가집은 작고 저택은 크다)
		var base := Art.tex(id)
		var k := w / (base.get_width() if base else tex.get_width())
		_sprite.scale = Vector2.ONE * k
		w = tex.get_width() * k
		_sprite.show_behind_parent = true
		_height = tex.get_height() * k
	if ghost:
		modulate = Color(1, 1, 1, 0.55)
		collision_layer = 0
		return
	collision_layer = 1 if not bool(info.get("walk", false)) else 0
	if collision_layer != 0:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(w * 0.8, maxf(8.0, _height * 0.3))
		shape.shape = rect
		shape.position = Vector2(0, 4 - rect.size.y * 0.5)
		add_child(shape)
	if str(info["kind"]) == "building":
		add_to_group("interactable")
	# 주민 집 앞에는 그 집에 사는 주민이 서 있다. 밭에는 자라는 작물이 보인다.
	if str(info.get("use", "")) == "villager" or str(info.get("use", "")) == "farm" or str(info.get("use", "")) == "pen":
		GameState.changed.connect(_refresh_extra)
		_refresh_extra()
	add_to_group("home_object")


func _process(delta: float) -> void:
	_t += delta
	if str(info.get("use", "")) == "pen" and not _extra.is_empty():
		_wander(delta)
	if fine or is_in_group("interactable"):
		queue_redraw()


func interact() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	# 지붕 있는 건물은 안으로 들어간다. 맵을 옮길 수 없는 곳(테스트)에서는 아래에서 바로 쓴다.
	if Data.ROOMS.has(id) and GameState.enter_room(GameState.house_key({"x": position.x, "y": position.y}), id):
		return
	match str(info.get("use", "")):
		"sleep":
			if _t - _asked > 3.0:
				_asked = _t
				GameState.notify("잠을 자면 다음 날 아침이 돼요. 한 번 더 F 를 누르면 자요.")
				return
			_asked = -10.0
			GameState.sleep()
			var p := GameState.player_ref
			if is_instance_valid(p):
				p.set("hp", p.get("max_hp"))
				p.set("mp", float(p.get("max_mp")))
				p.emit_signal("hp_changed", p.get("hp"), p.get("max_hp"))
			GameState.notify("푹 잤어요. HP 와 MP 가 가득 찼고 저장했어요.")
		"shop":
			if hud:
				hud.call("open_shop", 0)
		"craft":
			if hud:
				hud.call("open_shop", 2)
		"storage":
			if hud:
				hud.call("toggle_menu", "storage")
		"board":
			GameState.board_refresh()
			if hud:
				hud.call("toggle_menu", "board")
		"fishing":
			if hud:
				hud.call("start_fishing", fine, "home", global_position + Vector2(0, -10))
		"villager":
			var who := GameState.resident_of(GameState.house_key({"x": position.x, "y": position.y}))
			if who == "":
				# 빈 집: 한 번 더 F 를 누르면 새 주민을 직접 그려서 데려온다
				if GameState.custom_villagers.size() < Data.CUSTOM_MAX and _t - _asked <= 3.0 and hud:
					_asked = -10.0
					hud.call("open_villager_maker", GameState.house_key({"x": position.x, "y": position.y}))
					return
				_asked = _t
				GameState.notify("빈 집이에요. 1장 마을 사람의 부탁을 들어주면 이사 와요.%s" % (
					" 한 번 더 F: 새 주민을 직접 그리기" if GameState.custom_villagers.size() < Data.CUSTOM_MAX else ""))
			elif hud:
				hud.call("open_menu", "resident", who)
		"farm":
			# 물이 필요한 칸 앞에 서 있으면 물뿌리개로 그 칸에 물을 준다. 아니면 밭 창을 연다.
			var p := GameState.player_ref
			var plot := thirsty_plot_near(p.global_position) if is_instance_valid(p) else -1
			if plot >= 0:
				water_plot(plot)
			elif hud:
				hud.call("open_menu", "farm", GameState.house_key({"x": position.x, "y": position.y}))
		"cook":
			if hud:
				hud.call("open_menu", "cook", "")
		"pen":
			if hud:
				hud.call("open_menu", "friends", "pen")
		"museum":
			if hud:
				hud.call("open_menu", "dex", "museum")
		_:
			GameState.notify("%s: 아직 준비 중이에요." % info["name"])


## 밭 칸 i 의 자리 (이 건물 기준). 3칸씩 줄을 짓는다.
func plot_pos(i: int) -> Vector2:
	var w := float(info["w"])
	return Vector2(-w * 0.26 + (i % 3) * w * 0.26, -_height * 0.5 + (i / 3) * _height * 0.3)


## pos(월드) 가까이에 있는, 물이 필요한 밭 칸 (-1 은 없음)
func thirsty_plot_near(pos: Vector2) -> int:
	if str(info.get("use", "")) != "farm":
		return -1
	var plots := GameState.farm_plots(GameState.house_key({"x": position.x, "y": position.y}))
	var best := -1
	var best_d := PLOT_REACH
	for i in plots.size():
		if not GameState.plot_needs_water(plots[i]):
			continue
		var d := (global_position + plot_pos(i)).distance_to(pos)
		if d < best_d:
			best = i
			best_d = d
	return best


## 물뿌리개로 밭 칸 하나에 물을 준다 (캐릭터가 물뿌리개를 기울인다)
func water_plot(i: int) -> bool:
	var key := GameState.house_key({"x": position.x, "y": position.y})
	if not GameState.water_plot(key, i):
		return false
	Sound.play("water")
	var p := GameState.player_ref
	if is_instance_valid(p) and p.has_method("act"):
		var dir := (global_position + plot_pos(i) - p.global_position).normalized()
		p.call("act", "life_can", dir if dir != Vector2.ZERO else Vector2.DOWN, 0.5)
	var left := 0
	for q in GameState.farm_plots(key):
		if GameState.plot_needs_water(q):
			left += 1
	GameState.notify("%d번 칸에 물을 줬어요.%s" % [i + 1, " (남은 칸 %d)" % left if left > 0 else " 오늘 물 주기 끝!"])
	return true


## 친구 우리: 같이 다니지 않는 친구들(최대 Data.PEN_WANDER)이 우리 안을 돌아다닌다
func _refresh_pen() -> void:
	var want := ""
	var list: Array = []
	for i in GameState.friends.size():
		if i != GameState.companion and list.size() < Data.PEN_WANDER:
			list.append(str(GameState.friends[i]["sp"]))
	want = ",".join(list)
	if want == _extra_state:
		return
	_extra_state = want
	for c in _extra:
		(c as Node).queue_free()
	_extra = []
	for sp in list:
		var l: Array = Companion.look(str(sp))
		if l[0] == null:
			continue
		var s := Art.make_sprite(self, l[0], Vector2.ZERO, int(l[1]), 1)
		s.scale = Art.SCALE * 0.7
		s.modulate = l[2]
		s.position = _pen_spot()
		s.set_meta("goal", _pen_spot())
		_extra.append(s)


## 우리 안의 아무 자리 (울타리 안쪽)
func _pen_spot() -> Vector2:
	var w := float(info["w"])
	return Vector2(randf_range(-w * 0.34, w * 0.34), randf_range(-_height * 0.55, -_height * 0.12))


## 우리 안의 친구들이 천천히 걸어 다닌다
func _wander(delta: float) -> void:
	for s in _extra:
		var sp := s as Sprite2D
		var goal: Vector2 = sp.get_meta("goal", sp.position)
		if sp.position.distance_to(goal) < 1.0:
			if randf() < delta * 0.6:
				sp.set_meta("goal", _pen_spot())
			continue
		var step := (goal - sp.position).normalized() * PEN_SPEED * delta
		sp.flip_h = step.x > 0
		sp.position = goal if step.length() >= sp.position.distance_to(goal) else sp.position + step
		if sp.hframes > 1:
			sp.frame = int(_t * 6.0) % sp.hframes


## 주민 집의 주민, 밭의 작물 그림을 지금 상태에 맞춘다
func _refresh_extra() -> void:
	var key := GameState.house_key({"x": position.x, "y": position.y})
	var want := ""
	if str(info.get("use", "")) == "pen":
		_refresh_pen()
		return
	if str(info.get("use", "")) == "villager":
		var who := GameState.resident_of(key)
		want = str(GameState.villager_info(who)["sprite"]) if who != "" else ""
	else:
		for p in GameState.farm_plots(key):
			want += "%s%d%s," % [str(p["seed"]), int(p["grown"]), "w" if bool(p["watered"]) else ""]
	if want == _extra_state:
		return
	_extra_state = want
	for c in _extra:
		(c as Node).queue_free()
	_extra = []
	var w := float(info["w"])
	if str(info.get("use", "")) == "villager":
		var vt := Art.tex(want) if want != "" else null
		if vt:
			_extra.append(Art.make_sprite(self, vt, Vector2(w * 0.5 + 6.0, 6)))
		return
	# 밭: 3 × 2 칸에 새싹 또는 다 자란 작물
	var plots := GameState.farm_plots(key)
	for i in plots.size():
		var p: Dictionary = plots[i]
		if str(p["seed"]) == "":
			continue
		var ripe := GameState.plot_ripe(p)
		var tex := Art.tex(str(Items.CONSUMABLES[str(Items.CROPS[str(p["seed"])][0])][1]) if ripe else "crop_sprout")
		if tex == null:
			continue
		var s := Sprite2D.new()
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		s.scale = Vector2.ONE * (12.0 / tex.get_width())
		s.position = plot_pos(i)
		add_child(s)
		_extra.append(s)


func _draw() -> void:
	if ghost:
		return
	if fine and _star:
		var s := 10.0 + sin(_t * 4.0) * 2.0
		draw_texture_rect(_star, Rect2(Vector2(-s * 0.5, -_height - 6.0), Vector2(s, s)), false)
	var p := GameState.player_ref
	# 밭: 가까이 오면 물이 필요한 칸 위에 물방울을 띄운다
	if _drop and str(info.get("use", "")) == "farm" and is_instance_valid(p) and p.global_position.distance_to(global_position) < RANGE + 30.0:
		var plots := GameState.farm_plots(GameState.house_key({"x": position.x, "y": position.y}))
		for i in plots.size():
			if GameState.plot_needs_water(plots[i]):
				var bob := sin(_t * 5.0 + i) * 1.5
				draw_texture_rect(_drop, Rect2(plot_pos(i) + Vector2(-4, -14 + bob), Vector2(8, 8)), false)
	if is_in_group("interactable") and _key and is_instance_valid(p) and p.global_position.distance_to(global_position) < RANGE:
		var h := 10.0
		var w := h * _key.get_width() / float(_key.get_height())
		draw_texture_rect(_key, Rect2(Vector2(-w * 0.5, -_height - 20.0), Vector2(w, h)), false)
