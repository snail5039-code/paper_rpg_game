extends Node2D
## 맵에 놓인 주울 것. F 로 줍는다.
##   mode "forage" : 사냥터의 채집 자리 (풀, 돌, 나뭇가지, 열매). 하루에 한 번, 날이 바뀌면 다시 생긴다.
##   mode "balloon": 풍선 아이의 날아간 풍선. 화면마다 하나.
##   mode "fish"   : 낚시 자리 (1장 마을의 강가). 줍는 것이 아니라 낚시를 시작한다.

const Art := preload("res://scripts/core/art.gd")
const Items := preload("res://scripts/data/items.gd")
const RANGE := 32.0

var mode := "forage"
var key := ""               # 채집 자리의 이름 ("화면:번호") 또는 풍선이 있는 화면
var cast_to := Vector2(64, 0)   # 낚시 자리: 찌가 떨어지는 물의 자리 (이 표지판 기준)
var _tex: Texture2D
var _key_tex: Texture2D
var _t := 0.0


func _ready() -> void:
	add_to_group("interactable")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_key_tex = Art.tex("key_f")
	match mode:
		"forage":
			_tex = Art.tex(str(Items.CONSUMABLES[str(Items.FORAGE[hash(key) % Items.FORAGE.size()])][1]))
		"balloon":
			_tex = Art.tex("deco_balloon")
		"fish":
			_tex = Art.tex("deco_signpost")
	_refresh()
	GameState.changed.connect(_refresh)


func _refresh() -> void:
	var here := true
	if mode == "forage":
		here = GameState.forage_left(key)
	elif mode == "balloon":
		here = not GameState.balloons.has(key) and int(GameState.villager("kid")["q"]) == 1
	visible = here
	if here and not is_in_group("interactable"):
		add_to_group("interactable")
	elif not here and is_in_group("interactable"):
		remove_from_group("interactable")


func _process(delta: float) -> void:
	_t += delta
	if visible:
		queue_redraw()


func interact() -> void:
	match mode:
		"forage":
			# 낫을 한 번 휘두른 뒤에 얻는다
			var p: Node2D = GameState.player_ref
			if is_instance_valid(p) and p.has_method("act") and p.is_inside_tree():
				if not bool(p.call("is_acting")):
					Sound.play("cut")
					p.call("act", "life_sickle", global_position - p.global_position, 0.4, false, _take)
			else:
				_take()
		"balloon":
			GameState.balloons.append(key)
			GameState.changed.emit()
			GameState.notify("날아간 풍선을 잡았어요. (%d/3)" % GameState.balloons.size())
		"fish":
			var hud := get_tree().get_first_node_in_group("hud")
			if hud:
				hud.call("start_fishing", false, key, global_position + cast_to)


func _take() -> void:
	var id := GameState.take_forage(key)
	if id != "":
		GameState.notify("%s 을(를) 얻었어요." % Items.CONSUMABLES[id][0])


func _draw() -> void:
	if _tex == null:
		draw_circle(Vector2.ZERO, 4, Color(0.4, 0.7, 0.4))
	else:
		var h := 26.0 if mode != "forage" else 12.0
		var w := h * _tex.get_width() / float(_tex.get_height())
		var bob := sin(_t * 2.0) * 2.0 if mode == "balloon" else 0.0
		draw_texture_rect(_tex, Rect2(Vector2(-w * 0.5, -h + 4 + bob), Vector2(w, h)), false)
	var p := GameState.player_ref
	if _key_tex and is_instance_valid(p) and p.global_position.distance_to(global_position) < RANGE:
		var kh := 10.0
		var kw := kh * _key_tex.get_width() / float(_key_tex.get_height())
		draw_texture_rect(_key_tex, Rect2(Vector2(-kw * 0.5, -44 if mode != "forage" else -28), Vector2(kw, kh)), false)
