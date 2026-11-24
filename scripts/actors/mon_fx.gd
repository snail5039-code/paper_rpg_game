extends Sprite2D
## 몬스터 공격 효과 (그림: fx_mon_*, docs/도트_프롬프트_stage1.md §88).
## 그림 한 장을 커졌다 사라지게 보여 주고 스스로 없어진다.
##   MonFx.pop(parent, "fx_mon_impact", 위치, 가로 크기)
## 예고 느낌표·보스 내리치기 자리처럼 오래 남는 것은 enemy_slime.gd 가 직접 둔다.

const Art := preload("res://scripts/core/art.gd")


## 효과 하나: width 는 월드 가로 크기. grow 배로 커지며 dur 초 동안 옅어진다.
static func pop(parent: Node, tex_name: String, pos: Vector2, width: float, dur: float = 0.3,
		rot: float = 0.0, grow: float = 1.35, flip := false, z := 30, tint := Color.WHITE) -> Sprite2D:
	var tex := Art.tex(tex_name)
	if tex == null or parent == null:
		return null
	var s: Sprite2D = new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.position = pos
	s.rotation = rot
	s.flip_h = flip
	s.z_index = z
	s.modulate = tint
	var k := width / tex.get_width()
	s.scale = Vector2.ONE * k * 0.6
	parent.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2.ONE * k, dur * 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "scale", Vector2.ONE * k * grow, dur * 0.75)
	tw.parallel().tween_property(s, "modulate:a", 0.0, dur * 0.75).set_ease(Tween.EASE_IN)
	tw.tween_callback(s.queue_free)
	return s


## 바닥에 납작하게 깔리는 것 (먼지, 충격파): 캐릭터보다 뒤에 그린다
static func ground(parent: Node, tex_name: String, pos: Vector2, width: float, dur: float = 0.4, grow: float = 1.3) -> Sprite2D:
	return pop(parent, tex_name, pos, width, dur, 0.0, grow, false, -1)
