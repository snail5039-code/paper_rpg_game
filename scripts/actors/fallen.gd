extends Node2D
## 쓰러진 몬스터가 남긴 흐린 자국. 사라지기 전에 F 로 다가가 도화지에 "다시 그려 주면" 친구가 된다.
##  - 8초 동안 남는다. 도화지(문방구)가 있어야 한다.
##  - 따라 그리기 화면(scripts/ui/trace_panel.gd)에서 빠진 테두리를 그린다. 정확할수록 성공률이 높다.

const Art := preload("res://scripts/core/art.gd")
const Data := preload("res://scripts/data/game_data.gd")
const Companion := preload("res://scripts/actors/companion.gd")
const TracePanel := preload("res://scripts/ui/trace_panel.gd")

const LIFE := 8.0
const RANGE := 34.0
const TRACE_TIME := 6.0

var kind := "slime_faded"
var _t := 0.0
var _busy := false
var _sprite: Sprite2D
var _paper: Texture2D
var _key: Texture2D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("fallen")
	_paper = Art.tex("icon_paper")
	_key = Art.tex("key_f")
	var l := Companion.look(Data.species_of(kind))
	if l[0] != null:
		_sprite = Art.make_sprite(self, l[0], Vector2(0, 7), int(l[1]), 1)
		_sprite.modulate = Color(1, 1, 1, 0.35)
		_sprite.show_behind_parent = true


func _process(delta: float) -> void:
	if _busy:
		return
	_t += delta
	if _sprite:
		_sprite.modulate.a = 0.35 * clampf((LIFE - _t) / 2.0, 0.0, 1.0) + 0.08 * sin(_t * 6.0)
	if _t >= LIFE:
		queue_free()
	queue_redraw()


func interact() -> void:
	if _busy:
		return
	if not GameState.has_paper():
		GameState.notify("도화지가 있어야 다시 그려 줄 수 있어요. (문방구)")
		return
	if GameState.friends.size() >= GameState.friend_cap():
		GameState.notify("친구가 너무 많아요. (최대 %d. 친구 우리를 올리면 늘어나요)" % GameState.friend_cap())
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	_busy = true
	var panel: Control = hud.call("trace_panel")
	var name := str(Data.FRIENDS[Data.species_of(kind)]["name"])
	var tex: Texture2D = _sprite.texture if _sprite else null
	var region := AtlasTexture.new()
	if tex and _sprite.hframes > 1:
		region.atlas = tex
		region.region = Rect2(0, 0, tex.get_width() / float(_sprite.hframes), tex.get_height())
		tex = region
	panel.call("start", "%s 다시 그리기" % name, [TracePanel.blob(Vector2(320, 190), 78, 66)], TRACE_TIME,
		tex, Rect2(250, 130, 140, 120))
	var score: float = await panel.finished
	if score < 0.0:
		_busy = false   # 그만뒀다: 도화지를 쓰지 않는다
		return
	var result := GameState.try_capture(kind, score)
	Sound.play("capture" if result == "ok" or result == "practice" else "fail")
	if result == "practice":
		GameState.notify("%s 가 제 모습을 찾고 깡충깡충 뛰어갔어요! (따라 그리기 %d%%)" % [name, roundi(score * 100.0)])
	elif result == "ok":
		GameState.notify("%s 이(가) 친구가 됐어요! (따라 그리기 %d%%)" % [name, roundi(score * 100.0)])
	else:
		GameState.notify("선이 흩어져 버렸어요… (따라 그리기 %d%%)" % roundi(score * 100.0))
	queue_free()


func _draw() -> void:
	var p := GameState.player_ref
	var near := is_instance_valid(p) and p.global_position.distance_to(global_position) < RANGE
	if _paper:
		var s := 12.0
		draw_texture_rect(_paper, Rect2(Vector2(-s * 0.5, -34 + sin(_t * 4.0) * 2.0), Vector2(s, s)), false)
	if near and _key and not _busy:
		var h := 10.0
		var w := h * _key.get_width() / float(_key.get_height())
		draw_texture_rect(_key, Rect2(Vector2(-w * 0.5, -50), Vector2(w, h)), false)
