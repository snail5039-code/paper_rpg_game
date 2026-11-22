extends RefCounted
## 스프라이트 로더. assets/sprites/<이름>.png 가 있으면 텍스처를, 없으면 null 을 돌려준다.
## null 이면 각 스크립트가 임시 도형(_draw)으로 대신 그린다.
## 스프라이트는 1텍셀 = 1/3 월드 기준이므로 Sprite2D.scale 은 SCALE 을 쓴다.

const DIR := "res://assets/sprites/"
const SCALE := Vector2(1.0 / 3.0, 1.0 / 3.0)


const DRAWN_DIR := "user://drawn/"
static var _drawn: Dictionary = {}   # 내가 그린 아이콘 (이름 → 텍스처)


## "drawn_" 으로 시작하는 이름은 플레이어가 직접 그린 그림이다 (user://drawn/ 에 저장).
static func tex(name: String) -> Texture2D:
	if name.begins_with("drawn_"):
		if not _drawn.has(name):
			var img := Image.new()
			_drawn[name] = ImageTexture.create_from_image(img) if img.load(DRAWN_DIR + name + ".png") == OK else null
		return _drawn[name]
	var path := DIR + name + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


## 내가 그린 그림을 저장하고 이름을 돌려준다
static func save_drawn(img: Image) -> String:
	DirAccess.make_dir_recursive_absolute(DRAWN_DIR)
	var name := "drawn_%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 100000]
	img.save_png(DRAWN_DIR + name + ".png")
	_drawn[name] = ImageTexture.create_from_image(img)
	return name


## 발(아래쪽 가운데)이 foot 위치에 오도록 Sprite2D 를 만들어 parent 에 붙인다.
## hframes/vframes 를 주면 격자 시트로 쓴다 (frame_coords 로 프레임 선택).
static func make_sprite(parent: Node, texture: Texture2D, foot: Vector2 = Vector2.ZERO,
		hframes: int = 1, vframes: int = 1) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture
	s.hframes = hframes
	s.vframes = vframes
	s.scale = SCALE
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.centered = true
	s.position = foot
	s.offset = Vector2(0, -texture.get_height() / float(vframes) / 2.0)
	parent.add_child(s)
	return s


## 텍스처를 바꾸고 발 위치를 유지한다 (낱장 스프라이트용).
static func set_texture(s: Sprite2D, texture: Texture2D) -> void:
	if s.texture == texture:
		return
	s.texture = texture
	s.offset = Vector2(0, -texture.get_height() / 2.0)


## 바라보는 방향 → 걷기 시트의 행 (0 정면, 1 왼쪽, 2 오른쪽, 3 뒷면)
static func dir_row(facing: Vector2) -> int:
	if absf(facing.x) > absf(facing.y):
		return 2 if facing.x > 0 else 1
	return 0 if facing.y > 0 else 3
