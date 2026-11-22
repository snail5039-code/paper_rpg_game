extends RefCounted
## 게임 데이터 표: 재료, 몬스터. (수치는 가안)

## 1장 재료 12개. 번호가 아이콘(assets/sprites/mat_<번호>.png)과 저장 키가 된다.
const MATERIALS := [
	"말랑 조각", "말랑 눈알", "삐뚤선 토막", "곧은 선",
	"점 가루", "굵은 점", "풀잎 낙서", "모눈 조각",
	"모눈 실", "네모 눈", "지우개똥", "몽당 지우개",
]

## 몬스터 종류. 수치는 docs/몬스터.md 의 1장 기준값("흐릿한" 단계)을 따른다.
##  art   : "frames" = 낱장 4자세(<sprite>_idle/squash/jump/hurt), "strip" = 6칸 시트(mon_<sprite>)
##          strip 칸 순서: 기본, 움직임1, 움직임2, 공격 예고, 공격, 맞음
##  drops : [흔한 재료 번호, 확률, 드문 재료 번호, 확률]
##  grid  : true 면 가로·세로로만 움직인다 (모눈 거미)
const MONSTERS := {
	"slime": {
		"name": "낙서 슬라임", "art": "frames", "sprite": "slime", "hp": 12, "speed": 40.0, "damage": 4,
		"radius": 10.0, "exp": 5, "def": 0, "drops": [0, 0.6, 1, 0.1],
	},
	"slime_faded": {
		"name": "조금 지워진 슬라임", "art": "frames", "sprite": "slimef", "hp": 12, "speed": 40.0, "damage": 4,
		"radius": 8.0, "exp": 5, "def": 0, "drops": [0, 0.6, 1, 0.1],
	},
	"slime_erased": {
		"name": "많이 지워진 슬라임", "art": "frames", "sprite": "slimee", "hp": 19, "speed": 46.0, "damage": 5,
		"radius": 10.0, "exp": 9, "def": 0, "drops": [0, 0.8, 1, 0.25],
	},
	"squiggle_faded": {
		"name": "조금 지워진 삐뚤선", "art": "strip", "sprite": "squiggle_faded", "hp": 10, "speed": 52.0, "damage": 5,
		"radius": 11.0, "exp": 5, "def": 0, "drops": [2, 0.6, 3, 0.1], "windup": 0.4, "lunge_speed": 210.0,
	},
	"squiggle_erased": {
		"name": "많이 지워진 삐뚤선", "art": "strip", "sprite": "squiggle_erased", "hp": 16, "speed": 60.0, "damage": 6,
		"radius": 11.0, "exp": 9, "def": 0, "drops": [2, 0.8, 3, 0.25], "windup": 0.35, "lunge_speed": 230.0,
	},
	"dots_faded": {
		"name": "조금 지워진 점박이", "art": "strip", "sprite": "dots_faded", "hp": 8, "speed": 44.0, "damage": 4,
		"radius": 11.0, "exp": 5, "def": 0, "drops": [4, 0.6, 5, 0.1], "aggro": 80.0,
	},
	"dots_erased": {
		"name": "많이 지워진 점박이", "art": "strip", "sprite": "dots_erased", "hp": 13, "speed": 50.0, "damage": 5,
		"radius": 11.0, "exp": 9, "def": 0, "drops": [4, 0.8, 5, 0.25], "aggro": 80.0,
	},
	"grass_faded": {
		"name": "조금 지워진 풀낙서", "art": "strip", "sprite": "grass_faded", "hp": 10, "speed": 20.0, "damage": 6,
		"radius": 9.0, "exp": 5, "def": 0, "drops": [6, 0.6, 7, 0.1], "aggro": 46.0, "windup": 0.3, "lunge_speed": 240.0,
	},
	"grass_erased": {
		"name": "많이 지워진 풀낙서", "art": "strip", "sprite": "grass_erased", "hp": 16, "speed": 24.0, "damage": 8,
		"radius": 9.0, "exp": 9, "def": 0, "drops": [6, 0.8, 7, 0.25], "aggro": 46.0, "windup": 0.25, "lunge_speed": 260.0,
	},
	"spider_faded": {
		"name": "조금 지워진 모눈 거미", "art": "strip", "sprite": "spider_faded", "hp": 12, "speed": 58.0, "damage": 4,
		"radius": 10.0, "exp": 6, "def": 0, "drops": [8, 0.6, 9, 0.1], "grid": true,
	},
	"spider_erased": {
		"name": "많이 지워진 모눈 거미", "art": "strip", "sprite": "spider_erased", "hp": 19, "speed": 66.0, "damage": 5,
		"radius": 10.0, "exp": 10, "def": 0, "drops": [8, 0.8, 9, 0.25], "grid": true,
	},
	"bug_faded": {
		"name": "조금 지워진 지우개똥 벌레", "art": "strip", "sprite": "bug_faded", "hp": 18, "speed": 34.0, "damage": 4,
		"radius": 12.0, "exp": 6, "def": 1, "drops": [10, 0.6, 11, 0.1], "lunge_time": 0.45, "lunge_speed": 150.0,
	},
	"bug_erased": {
		"name": "많이 지워진 지우개똥 벌레", "art": "strip", "sprite": "bug_erased", "hp": 29, "speed": 38.0, "damage": 5,
		"radius": 12.0, "exp": 10, "def": 2, "drops": [10, 0.8, 11, 0.25], "lunge_time": 0.5, "lunge_speed": 160.0,
	},
}


## 1장의 화면 배치 (지도용). 칸 좌표: x 는 왼쪽→오른쪽, y 는 위→아래.
##          [마을]
##  [들판]─[갈림길]─[모눈 숲]
##         [지워진 길]
const CH1_LAYOUT := {
	"ch1": Vector2i(1, 0), "ch1_meadow": Vector2i(0, 1), "ch1_crossroad": Vector2i(1, 1),
	"ch1_gridwoods": Vector2i(2, 1), "ch1_erasedroad": Vector2i(1, 2),
}
const MAP_NAMES := {
	"home": "내 마을", "ch1": "공책 마을", "ch1_meadow": "들판", "ch1_crossroad": "갈림길",
	"ch1_gridwoods": "모눈 숲", "ch1_erasedroad": "지워진 길",
}

## 사냥터 화면 (scripts/field.gd). 위치는 bg px (배경 1672×941).
##  gates   : 문이 있는 변 → 넘어갈 화면
##  solids  : 화면 안의 막힌 곳 (연못, 우물, 줄지어 선 나무)
##  monsters: [종류, 위치]
const FIELDS := {
	"ch1_crossroad": {
		"name": "갈림길", "bg": "bg_ch1_crossroad",
		"gates": {"top": "ch1", "bottom": "ch1_erasedroad", "left": "ch1_meadow", "right": "ch1_gridwoods"},
		"solids": [Rect2(672, 300, 90, 120), Rect2(915, 300, 140, 130)],
		"monsters": [["dots_faded", Vector2(350, 650)], ["dots_faded", Vector2(1250, 300)], ["squiggle_faded", Vector2(1200, 650)]],
	},
	"ch1_meadow": {
		"name": "들판", "bg": "bg_ch1_meadow",
		"gates": {"right": "ch1_crossroad"},
		"solids": [Rect2(185, 170, 250, 215)],
		"monsters": [
			["slime_faded", Vector2(560, 300)], ["slime_faded", Vector2(700, 650)], ["slime_faded", Vector2(1000, 250)],
			["grass_faded", Vector2(400, 600)], ["grass_faded", Vector2(900, 700)], ["grass_faded", Vector2(1250, 300)],
			["dots_faded", Vector2(620, 480)], ["dots_faded", Vector2(1150, 640)],
		],
	},
	"ch1_gridwoods": {
		"name": "모눈 숲", "bg": "bg_ch1_gridwoods",
		"gates": {"left": "ch1_crossroad"},
		"solids": [Rect2(108, 112, 1456, 228), Rect2(108, 610, 1456, 208)],
		"monsters": [
			["spider_faded", Vector2(500, 420)], ["spider_faded", Vector2(900, 520)], ["spider_faded", Vector2(1300, 430)],
			["squiggle_faded", Vector2(700, 400)], ["squiggle_faded", Vector2(1100, 540)],
			["spider_erased", Vector2(1450, 520)], ["squiggle_erased", Vector2(1420, 400)],
		],
	},
	"ch1_erasedroad": {
		"name": "지워진 길", "bg": "bg_ch1_erasedroad",
		"gates": {"top": "ch1_crossroad"},
		"solids": [],
		"monsters": [
			["bug_faded", Vector2(400, 300)], ["bug_faded", Vector2(1250, 300)], ["bug_faded", Vector2(350, 600)],
			["bug_erased", Vector2(600, 680)], ["bug_erased", Vector2(1200, 680)],
			["slime_erased", Vector2(500, 450)], ["slime_erased", Vector2(1150, 450)],
			["dots_erased", Vector2(300, 740)], ["grass_erased", Vector2(1350, 720)],
		],
	},
}
