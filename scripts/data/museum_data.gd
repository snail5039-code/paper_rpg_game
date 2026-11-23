extends RefCounted
## 박물관의 전시대 배치와 전시 묶음 (scripts/maps/museum.gd, museum_display.gd, 전시 창이 같이 쓴다).

const Items := preload("res://scripts/data/items.gd")

## 전시 가구: [그림, 발 자리, 묶음, 그 묶음 안에서 몇 번째부터, 몇 개, 칸 배치(열, 줄), 그림 안 전시 영역(비율 Rect2)]
const DISPLAYS := [
	["prop_tank", Vector2(150, 300), "fish", 0, 25, Vector2i(0, 0), Rect2(0.06, 0.16, 0.88, 0.5)],
	["prop_tank", Vector2(270, 300), "fish", 25, 25, Vector2i(0, 0), Rect2(0.06, 0.16, 0.88, 0.5)],
	["prop_bugcase", Vector2(640, 284), "bug", 0, 6, Vector2i(3, 2), Rect2(0.16, 0.14, 0.68, 0.42)],
	["prop_bugcase", Vector2(715, 284), "bug", 6, 6, Vector2i(3, 2), Rect2(0.16, 0.14, 0.68, 0.42)],
	["prop_bugcase", Vector2(790, 284), "bug", 12, 6, Vector2i(3, 2), Rect2(0.16, 0.14, 0.68, 0.42)],
	["prop_planter", Vector2(640, 392), "flower", 0, 6, Vector2i(6, 1), Rect2(0.08, 0.0, 0.84, 0.32)],
	["prop_planter", Vector2(760, 392), "flower", 6, 6, Vector2i(6, 1), Rect2(0.08, 0.0, 0.84, 0.32)],
	["prop_table", Vector2(640, 488), "thing", 0, 10, Vector2i(5, 2), Rect2(0.1, 0.06, 0.8, 0.34)],
	["prop_table", Vector2(760, 488), "thing", 10, 10, Vector2i(5, 2), Rect2(0.1, 0.06, 0.8, 0.34)],
	["prop_board", Vector2(100, 400), "mon", 0, 15, Vector2i(5, 3), Rect2(0.16, 0.2, 0.68, 0.4)],
	["prop_board", Vector2(170, 400), "mon", 15, 15, Vector2i(5, 3), Rect2(0.16, 0.2, 0.68, 0.4)],
	["prop_board", Vector2(240, 400), "mon", 30, 15, Vector2i(5, 3), Rect2(0.16, 0.2, 0.68, 0.4)],
	["prop_board", Vector2(100, 495), "mon", 45, 15, Vector2i(5, 3), Rect2(0.16, 0.2, 0.68, 0.4)],
	["prop_board", Vector2(170, 495), "mon", 60, 15, Vector2i(5, 3), Rect2(0.16, 0.2, 0.68, 0.4)],
	["prop_board", Vector2(240, 495), "mon", 75, 15, Vector2i(5, 3), Rect2(0.16, 0.2, 0.68, 0.4)],
	["prop_showcase", Vector2(335, 400), "gear", 0, 15, Vector2i(5, 3), Rect2(0.12, 0.3, 0.76, 0.46)],
	["prop_showcase", Vector2(405, 400), "gear", 15, 15, Vector2i(5, 3), Rect2(0.12, 0.3, 0.76, 0.46)],
	["prop_showcase", Vector2(335, 495), "gear", 30, 15, Vector2i(5, 3), Rect2(0.12, 0.3, 0.76, 0.46)],
	["prop_showcase", Vector2(405, 495), "gear", 45, 15, Vector2i(5, 3), Rect2(0.12, 0.3, 0.76, 0.46)],
]
const GROUP_NAMES := {"fish": "물고기 수조", "bug": "곤충 표본장", "flower": "꽃밭", "thing": "채집물 진열대", "mon": "몬스터 스케치", "gear": "장비 진열장"}


## 전시 묶음 → 가구에 놓는 id 들. 채집물은 곤충·꽃·그 밖의 것(과일 포함)으로 나눈다.
static func groups() -> Dictionary:
	var g := {"fish": GameState.museum_entries("fish"), "bug": [], "flower": [], "thing": [],
		"mon": GameState.museum_entries("mon"), "gear": GameState.museum_entries("gear")}
	for id in Items.FORAGE_INFO:
		var kind := str(Items.FORAGE_INFO[id][0])
		(g["bug" if kind == "bug" else ("flower" if kind == "flower" else "thing")] as Array).append(str(id))
	return g


## 전시 묶음 → 박물관 기증 묶음
static func cat_of(group: String) -> String:
	return "forage" if group in ["bug", "flower", "thing"] else group
