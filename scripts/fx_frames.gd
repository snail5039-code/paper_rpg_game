extends Sprite2D
## 한 번 재생하고 사라지는 프레임 효과 (가로로 이어 붙인 시트).
## 사용: Fx.spawn(parent, texture, 발 위치, 프레임 수, 초당 프레임)

const Art := preload("res://scripts/art.gd")

var fps := 12.0
var _t := 0.0


static func spawn(parent: Node, tex: Texture2D, foot: Vector2, frames: int, frames_per_sec: float = 12.0) -> Sprite2D:
	var s: Sprite2D = new()
	s.texture = tex
	s.hframes = frames
	s.scale = Art.SCALE
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.position = foot
	s.offset = Vector2(0, -tex.get_height() / 2.0)
	s.set("fps", frames_per_sec)
	parent.add_child(s)
	return s


func _process(delta: float) -> void:
	_t += delta
	var f := int(_t * fps)
	if f >= hframes:
		queue_free()
	else:
		frame = f
