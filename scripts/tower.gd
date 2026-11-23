extends "res://scripts/field.gd"
## 끝없는 탑 "빈 페이지 탑". 내 마을의 탑 문으로 들어가 1층부터 오른다.
##  - 층마다 화면 한 장. 몬스터를 다 물리치면 보상을 받고 위쪽 문이 열린다. 위로 나가면 다음 층.
##  - 5층마다 대장(1장의 보스 셋이 차례로). 층이 오를수록 몬스터가 세진다. 끝이 없다.
##  - 피로도가 들지 않는다. 쓰러지면 잃는 것 없이 그 판이 끝나고 내 마을로 돌아간다.
##  - 아래쪽 문으로 나가면 그만 오르고 내 마을로 돌아간다.
## 배경 그림: bg_tower_0, bg_tower_1 (보통 층), bg_tower_boss (대장 층). 위·아래 변 가운데에 문.
##  그림이 아직 없으면 1장 갈림길 그림을 흐리게 칠해서 쓴다.

const POOL := ["slime", "squiggle", "dots", "grass", "spider", "bug"]
const BOSSES := ["boss_bug", "boss_crumple", "boss_scribble"]
const FALLBACK_BG := "bg_ch1_crossroad"
const FALLBACK_SOLIDS := [Rect2(672, 300, 90, 120), Rect2(915, 300, 140, 130)]

var floor_no := 1
var remaining := 0          # 이 층에 남은 몬스터 (보스가 부른 부하는 빼고)
var cleared := false
var _barrier: StaticBody2D


static func is_boss_floor(f: int) -> bool:
	return f % 5 == 0


## 층이 오를수록 세진다
static func floor_mult(f: int) -> Vector2:
	return Vector2(1.0 + 0.18 * (f - 1), 1.0 + 0.1 * (f - 1))   # (HP·경험치, 공격)


## 그 층의 몬스터 [종류, bg px 자리]. 층마다 늘 같다.
static func floor_monsters(f: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * f
	var out: Array = []
	var n := mini(4 + f / 2, 10)
	if is_boss_floor(f):
		out.append([BOSSES[(f / 5 - 1) % BOSSES.size()], Vector2(836, 420)])
		n = 2
	for i in n:
		var sp := str(POOL[rng.randi() % POOL.size()])
		var form := "_erased" if f >= 6 and rng.randf() < minf(0.7, 0.1 * (f - 5)) else "_faded"
		var at := Vector2.ZERO
		for t in 30:
			at = Vector2(rng.randf_range(PLAY.position.x + 90, PLAY.end.x - 90), rng.randf_range(PLAY.position.y + 70, PLAY.end.y - 170))
			var ok := true
			for r in FALLBACK_SOLIDS:
				if (r as Rect2).grow(50).has_point(at):
					ok = false
			if ok:
				break
		out.append([sp + form, at])
	return out


func _make_config() -> Dictionary:
	floor_no = maxi(1, GameState.tower_floor)
	GameState.tower_floor = floor_no
	var want := "bg_tower_boss" if is_boss_floor(floor_no) else "bg_tower_%d" % (floor_no % 2)
	var own := Art.tex(want) != null
	return {
		"name": "빈 페이지 탑 %d층" % floor_no,
		"bg": want if own else FALLBACK_BG,
		"tint": Color.WHITE if own else Color(0.86, 0.86, 0.96),
		"gates": {"bottom": "home", "top": "tower"},
		"solids": [] if own else FALLBACK_SOLIDS,
		"monsters": floor_monsters(floor_no),
	}


func _title_text() -> String:
	return "빈 페이지 탑 %d층%s  (최고 %d층)" % [floor_no, "  대장!" if is_boss_floor(floor_no) else "", GameState.tower_best]


func _extras() -> void:
	if is_boss_floor(floor_no):
		Sound.play.call_deferred("boss_appear")
	# 위쪽 문은 층을 끝낼 때까지 막아 둔다
	_barrier = StaticBody2D.new()
	_barrier.name = "TopGateBarrier"
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(GATE_HALF_W * 2.0, PLAY.position.y) * WORLD_PER_BG
	shape.shape = box
	shape.position = bg(Vector2(BG_SIZE.x * 0.5, PLAY.position.y * 0.5))
	_barrier.add_child(shape)
	add_child(_barrier)
	if remaining == 0:
		_clear.call_deferred()


func _tips() -> void:
	await get_tree().create_timer(0.6, false).timeout
	GameState.tip("tower", "몬스터를 다 물리치면 위쪽 문이 열려요. 5층마다 대장! 아래쪽 문: 마을로")


func _setup_monster(m: Node2D, _kind: String) -> void:
	var k := floor_mult(floor_no)
	m.set("hp_mult", k.x)
	m.set("dmg_mult", k.y)
	m.set("tier", 0)
	remaining += 1
	m.connect("died", _on_tower_kill)


func _on_tower_kill(_home: Vector2) -> void:
	remaining -= 1
	if remaining <= 0 and not cleared:
		_clear()


## 층을 끝냈다: 보상, 위쪽 문 열기
func _clear() -> void:
	if cleared:
		return
	cleared = true
	var got := GameState.tower_clear(floor_no)
	Sound.play("craft")
	GameState.notify("%d층을 끝냈어요! %s  위쪽 문이 열렸어요." % [floor_no, got])
	if is_instance_valid(_barrier):
		_barrier.queue_free()
	if hud:
		hud.set("quest_text_override", _title_text() + "  · 위로!")


func _draw() -> void:
	# 닫힌 위쪽 문에 연필 가로줄을 긋는다
	if not cleared:
		var c := bg(Vector2(BG_SIZE.x * 0.5, PLAY.position.y - 10))
		var w := GATE_HALF_W * WORLD_PER_BG
		for i in 3:
			draw_line(c + Vector2(-w, i * 4.0), c + Vector2(w, i * 4.0 - 2.0), Color(0.3, 0.26, 0.26, 0.8), 2.0)


func _physics_process(_delta: float) -> void:
	if _leaving or not is_instance_valid(player):
		return
	queue_redraw()
	var p := player.global_position / WORLD_PER_BG
	if p.y < EXIT_MARGIN and cleared:
		_leaving = GameState.tower_next()
	elif p.y > BG_SIZE.y - EXIT_MARGIN:
		GameState.tower_floor = 0
		GameState.notify("탑에서 나왔어요. (최고 기록 %d층)" % GameState.tower_best)
		_leaving = GameState.goto_map("home", "")
