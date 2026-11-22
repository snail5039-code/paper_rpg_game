extends StaticBody2D
## 내 마을에 지은 건물이나 놓은 소품 하나. 종류는 game_data.gd 의 BUILDS 표.
##  건물은 F 로 쓸 수 있다: 내 집(잠자기), 문방구, 조합대. 나머지는 아직 준비 중.
##  "정성"으로 지은 건물(따라 그리기 85% 이상)은 지붕 위에 별이 반짝인다.

const Art := preload("res://scripts/art.gd")
const Data := preload("res://scripts/game_data.gd")
const RANGE := 44.0

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
	if str(info.get("use", "")) == "villager" or str(info.get("use", "")) == "farm":
		GameState.changed.connect(_refresh_extra)
		_refresh_extra()
	add_to_group("home_object")


func _process(delta: float) -> void:
	_t += delta
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
				GameState.notify("빈 집이에요. 1장 마을 사람의 부탁을 들어주면 이사 와요.")
			elif hud:
				hud.call("open_menu", "resident", who)
		"farm":
			if hud:
				hud.call("open_menu", "farm", GameState.house_key({"x": position.x, "y": position.y}))
		"cook":
			if hud:
				hud.call("open_menu", "cook", "")
		_:
			GameState.notify("%s: 아직 준비 중이에요." % info["name"])


## 주민 집의 주민, 밭의 작물 그림을 지금 상태에 맞춘다
func _refresh_extra() -> void:
	var key := GameState.house_key({"x": position.x, "y": position.y})
	var want := ""
	if str(info.get("use", "")) == "villager":
		var who := GameState.resident_of(key)
		want = str(Data.VILLAGERS[who]["sprite"]) if who != "" else ""
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
		s.position = Vector2(-w * 0.26 + (i % 3) * w * 0.26, -_height * 0.5 + (i / 3) * _height * 0.3)
		add_child(s)
		_extra.append(s)


func _draw() -> void:
	if ghost:
		return
	if fine and _star:
		var s := 10.0 + sin(_t * 4.0) * 2.0
		draw_texture_rect(_star, Rect2(Vector2(-s * 0.5, -_height - 6.0), Vector2(s, s)), false)
	var p := GameState.player_ref
	if is_in_group("interactable") and _key and is_instance_valid(p) and p.global_position.distance_to(global_position) < RANGE:
		var h := 10.0
		var w := h * _key.get_width() / float(_key.get_height())
		draw_texture_rect(_key, Rect2(Vector2(-w * 0.5, -_height - 20.0), Vector2(w, h)), false)
