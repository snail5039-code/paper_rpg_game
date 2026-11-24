extends Node2D
## 사냥터를 날거나 기어다니는 곤충 (채집 50종 중 kind "bug"). 잠자리채(F)로 잡는다.
##  - 가까이서 뛰어 오면(빠르게 움직이면) 놀라서 달아난다.
##  - 멈춰 선 채로 F 를 누르면 거의 잡히고, 움직이면서 휘두르면 잘 놓친다.
##  - 놓치거나 달아나면 화면 밖으로 날아가 사라진다. 화면에 다시 들어오면 새로 나온다.

const Art := preload("res://scripts/core/art.gd")
const Items := preload("res://scripts/data/items.gd")
const RANGE := 30.0           # F 가 닿는 거리
const SCARE := 46.0           # 이 안에서 뛰면 놀란다
const STILL_TIME := 0.35      # 이만큼 멈춰 있으면 "살금살금"

var id := ""                  # Items.FORAGE_INFO 의 곤충 id
var area := Rect2()           # 돌아다니는 범위 (월드)
var _tex: Texture2D
var _key_tex: Texture2D
var _t := 0.0
var _target := Vector2.ZERO
var _fleeing := false
var _flee_dir := Vector2.UP
var _flies := true            # 나는 곤충(나비·잠자리…)인지 기는 곤충인지
var _player_still := 0.0
var _last_player := Vector2.INF


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("bug")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_tex = Art.tex(str(Items.CONSUMABLES[id][1])) if Items.CONSUMABLES.has(id) else null
	_key_tex = Art.tex("key_f")
	var n := str(Items.CONSUMABLES.get(id, [""])[0])
	_flies = not (n.contains("개미") or n.contains("공벌레") or n.contains("애벌레") or n.contains("소금쟁이") or n.contains("귀뚜라미") or n.contains("메뚜기"))
	_t = randf() * 10.0
	_pick_target()


func _pick_target() -> void:
	if area.size == Vector2.ZERO:
		_target = position + Vector2(randf_range(-30, 30), randf_range(-20, 20))
	else:
		_target = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))


func _process(delta: float) -> void:
	_t += delta
	var p: Node2D = GameState.player_ref
	if is_instance_valid(p):
		if _last_player != Vector2.INF and p.global_position.distance_to(_last_player) < 0.4:
			_player_still += delta
		else:
			_player_still = 0.0
		_last_player = p.global_position
		# 가까이서 뛰면 놀라서 달아난다
		if not _fleeing and p.global_position.distance_to(global_position) < SCARE and _player_still <= 0.0 \
				and not bool(p.call("is_acting")) and randf() < delta * 2.2:
			_flee((global_position - p.global_position).normalized())
	if _fleeing:
		position += _flee_dir * 90.0 * delta
		modulate.a = maxf(0.0, modulate.a - delta * 0.9)
		if modulate.a <= 0.0:
			queue_free()
	else:
		var speed := 16.0 if _flies else 8.0
		position = position.move_toward(_target, speed * delta)
		if position.distance_to(_target) < 1.0 or randf() < delta * 0.25:
			_pick_target()
	queue_redraw()


func _flee(dir: Vector2) -> void:
	_fleeing = true
	_flee_dir = (dir + Vector2(0, -0.6)).normalized() if _flies else dir
	if is_in_group("interactable"):
		remove_from_group("interactable")


## 멈춰 서 있으면 잘 잡히는 확률
func catch_chance() -> float:
	return 0.95 if _player_still >= STILL_TIME else 0.4


func interact() -> void:
	if _fleeing:
		return
	if not GameState.need_life("net"):
		return
	var p: Node2D = GameState.player_ref
	var chance := minf(0.98, catch_chance() + GameState.life_power("net") * 0.75)
	if is_instance_valid(p) and p.has_method("act") and p.is_inside_tree():
		if bool(p.call("is_acting")):
			return
		Sound.play("cut")
		p.call("act", "life_net", global_position - p.global_position, 0.4, false, _swing.bind(chance))
	else:
		_swing(chance)


func _swing(chance: float) -> void:
	if _fleeing or not is_inside_tree():
		return
	GameState.wear_life("net")
	if randf() < chance:
		if GameState.catch_bug(id):
			queue_free()
	else:
		GameState.notify("%s 이(가) 날아가 버렸어요. 멈춰 선 채로 휘둘러 보세요." % Items.CONSUMABLES[id][0])
		var p: Node2D = GameState.player_ref
		_flee((global_position - p.global_position).normalized() if is_instance_valid(p) else Vector2.UP)


func _draw() -> void:
	if _tex:
		var h := 12.0
		var w := h * _tex.get_width() / float(_tex.get_height())
		var hover := (sin(_t * 9.0) * 1.5 - 6.0) if _flies else 0.0
		var flap := 1.0 if not _flies else (0.75 + 0.25 * absf(sin(_t * 18.0)))
		if _flies:
			draw_circle(Vector2(0, 2), 2.5, Color(0, 0, 0, 0.12))
		draw_set_transform(Vector2(0, hover), 0.0, Vector2(flap, 1.0))
		draw_texture_rect(_tex, Rect2(Vector2(-w * 0.5, -h + 3), Vector2(w, h)), false)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_circle(Vector2.ZERO, 3, Color(0.3, 0.3, 0.3))
	var p := GameState.player_ref
	if not _fleeing and _key_tex and is_instance_valid(p) and p.global_position.distance_to(global_position) < RANGE:
		var kh := 10.0
		var kw := kh * _key_tex.get_width() / float(_key_tex.get_height())
		draw_texture_rect(_key_tex, Rect2(Vector2(-kw * 0.5, -30), Vector2(kw, kh)), false)
