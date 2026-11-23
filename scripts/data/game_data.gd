extends RefCounted
const Art := preload("res://scripts/core/art.gd")
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
		"radius": 10.0, "exp": 5, "def": 0, "drops": [0, 0.6, 1, 0.1],
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
	# --- 보스 (다시 그릴 수 없다). boss: "mid" 중간 보스, "boss" 대장, "field" 필드 보스
	#     slam: 몇 초마다 바닥을 내리친다 (빨간 동그라미가 먼저 보인다). summon: 체력이 절반이 되면 부르는 몬스터
	# --- 튜토리얼 장 "연습 페이지" 의 몬스터 (맵마다 하나). 그림은 assets/sprites/tm_<번호>.png 한 장.
	"tm1": {"name": "먼지 뭉치", "art": "single", "sprite": "tm_1", "hp": 8, "speed": 16.0, "damage": 0,
		"radius": 9.0, "exp": 1, "def": 0, "drops": [], "aggro": 0.0},
	"tm2": {"name": "오타", "art": "single", "sprite": "tm_2", "hp": 12, "speed": 26.0, "damage": 2,
		"radius": 10.0, "exp": 3, "def": 0, "drops": [2, 0.5]},
	"tm3": {"name": "압정", "art": "single", "sprite": "tm_3", "hp": 14, "speed": 34.0, "damage": 3,
		"radius": 9.0, "exp": 4, "def": 0, "drops": [4, 0.5], "aggro": 230.0, "windup": 0.6, "lunge_speed": 230.0},
	"tm4": {"name": "떨어진 스티커", "art": "single", "sprite": "tm_4", "hp": 14, "speed": 28.0, "damage": 3,
		"radius": 10.0, "exp": 5, "def": 0, "drops": [0, 0.6]},
	"tm5": {"name": "연습용 허수아비", "art": "single", "sprite": "tm_5", "hp": 9999, "speed": 0.0, "damage": 0,
		"radius": 13.0, "exp": 0, "def": 0, "drops": [], "aggro": 0.0, "dummy": true},
	"tm6": {"name": "큰 물음표", "art": "single", "sprite": "tm_6", "hp": 30, "speed": 24.0, "damage": 3,
		"radius": 11.0, "exp": 5, "def": 0, "drops": [5, 0.4]},
	"tm7": {"name": "몽당연필 벌레", "art": "single", "sprite": "tm_7", "hp": 16, "speed": 30.0, "damage": 3,
		"radius": 9.0, "exp": 5, "def": 0, "drops": [2, 0.6]},
	"tm8": {"name": "끈적이", "art": "single", "sprite": "tm_8", "hp": 20, "speed": 20.0, "damage": 3,
		"radius": 11.0, "exp": 5, "def": 0, "drops": [0, 0.7, 10, 0.4]},
	"tm9": {"name": "지워진 낙서 토끼", "art": "single", "sprite": "tm_9", "hp": 14, "speed": 32.0, "damage": 3,
		"radius": 10.0, "exp": 5, "def": 0, "drops": [6, 0.6]},
	"tm10": {"name": "물감 방울", "art": "single", "sprite": "tm_10", "hp": 18, "speed": 26.0, "damage": 3,
		"radius": 10.0, "exp": 5, "def": 0, "drops": [4, 0.6]},
	"tm11": {"name": "종이 참새", "art": "single", "sprite": "tm_11", "hp": 14, "speed": 38.0, "damage": 3,
		"radius": 9.0, "exp": 5, "def": 0, "drops": [8, 0.6]},
	"tm12": {"name": "모눈 두더지", "art": "single", "sprite": "tm_12", "hp": 20, "speed": 24.0, "damage": 4,
		"radius": 10.0, "exp": 6, "def": 0, "drops": [7, 0.6]},
	"tm13": {"name": "큰 가위표", "art": "single", "sprite": "tm_13", "hp": 150, "speed": 30.0, "damage": 6,
		"radius": 20.0, "exp": 40, "def": 1, "drops": [10, 1.0], "lunge_time": 0.5, "lunge_speed": 170.0,
		"boss": "mid", "scale": 1.0, "slam": 7.0, "aggro": 400.0, "summon": "tmcheck"},
	"tmcheck": {"name": "작은 체크표", "art": "single", "sprite": "tm_spare", "hp": 12, "speed": 34.0, "damage": 3,
		"radius": 8.0, "exp": 2, "def": 0, "drops": []},
	# 스킬 체험용 허수아비: 움직이지도 때리지도 쓰러지지도 않는다
	"dummy": {
		"name": "연습용 허수아비", "art": "single", "sprite": "deco_scarecrow", "hp": 9999, "speed": 0.0, "damage": 0,
		"radius": 13.0, "exp": 0, "def": 0, "drops": [], "aggro": 0.0,
	},
	"boss_bug": {
		"name": "왕 지우개똥 벌레", "art": "single", "sprite": "boss_0", "hp": 160, "speed": 30.0, "damage": 8,
		"radius": 20.0, "exp": 60, "def": 2, "drops": [10, 1.0, 11, 0.6], "lunge_time": 0.5, "lunge_speed": 170.0,
		"boss": "mid", "scale": 1.0, "summon": "bug_faded", "aggro": 150.0,
	},
	"boss_crumple": {
		"name": "구겨진 종이 구깃이", "art": "single", "sprite": "boss_1", "hp": 320, "speed": 34.0, "damage": 10,
		"radius": 24.0, "exp": 150, "def": 3, "drops": [6, 1.0, 7, 1.0], "lunge_time": 0.45, "lunge_speed": 200.0,
		"boss": "boss", "scale": 1.0, "slam": 6.0, "summon": "dots_erased", "aggro": 220.0, "unique": "u_star",
	},
	"boss_scribble": {
		"name": "떠돌이 큰 낙서", "art": "single", "sprite": "boss_2", "hp": 240, "speed": 46.0, "damage": 9,
		"radius": 22.0, "exp": 110, "def": 2, "drops": [0, 1.0, 1, 1.0], "lunge_time": 0.4, "lunge_speed": 230.0,
		"boss": "field", "scale": 1.0, "slam": 8.0, "aggro": 160.0, "unique": "u_pen",
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
	"ch1_gridwoods": Vector2i(2, 1), "ch1_erasedroad": Vector2i(1, 2), "ch1_bossroom": Vector2i(1, 3),
}
const MAP_NAMES := {
	"tut_1": "연습 페이지 1", "tut_2": "연습 페이지 2", "tut_3": "연습 페이지 3", "tut_4": "연습 페이지 4", "tut_5": "연습 페이지 5", "tut_6": "연습 페이지 6", "tut_7": "연습 페이지 7", "tut_8": "연습 페이지 8", "tut_9": "연습 페이지 9", "tut_10": "연습 페이지 10", "tut_11": "연습 페이지 11", "tut_12": "연습 페이지 12", "tut_13": "연습 페이지 13",
	"home": "내 마을", "ch1": "공책 마을", "ch1_meadow": "들판", "ch1_crossroad": "갈림길",
	"ch1_gridwoods": "모눈 숲", "ch1_erasedroad": "지워진 길", "ch1_bossroom": "구깃이의 방", "home_room": "내 집",
}

## 사냥터 화면 (scripts/maps/field.gd). 위치는 bg px (배경 1672×941).
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
			["boss_bug", Vector2(1300, 470)],
		],
	},
	"ch1_bossroom": {
		"name": "구깃이의 방", "bg": "bg_ch1_erasedroad", "tint": Color(0.78, 0.74, 0.82), "fatigue": 8,
		"gates": {"top": "ch1_erasedroad"},
		"solids": [],
		"monsters": [["boss_crumple", Vector2(836, 520)]],
	},
	"ch1_erasedroad": {
		"name": "지워진 길", "bg": "bg_ch1_erasedroad",
		"gates": {"top": "ch1_crossroad", "bottom": "ch1_bossroom"},
		"solids": [],
		"monsters": [
			["bug_faded", Vector2(400, 300)], ["bug_faded", Vector2(1250, 300)], ["bug_faded", Vector2(350, 600)],
			["bug_erased", Vector2(600, 680)], ["bug_erased", Vector2(1200, 680)],
			["slime_erased", Vector2(500, 450)], ["slime_erased", Vector2(1150, 450)],
			["dots_erased", Vector2(300, 740)], ["grass_erased", Vector2(1350, 720)],
		],
	},
}


## 친구 (다시 그려 준 몬스터). 종 → 이름, 그림으로 쓸 몬스터 종류, 힘 배율, 색, 스킬 이름
##  아래 세 종은 합치기로만 나온다. 그림은 mon_friend_<종> (tools/import_friends.py), 없으면 tint 로 색만 바꿔 쓴다.
const FRIENDS := {
	"slime": {"name": "낙서 슬라임", "kind": "slime_faded", "power": 1.0, "skill": "통통 박치기"},
	"tm9": {"name": "낙서 토끼", "kind": "tm9", "power": 1.0, "skill": "깡충"},     # 연습 페이지에서 다시 그리기를 배우는 낙서 (친구가 되지는 않는다)
	"squiggle": {"name": "삐뚤선", "kind": "squiggle_faded", "power": 1.0, "skill": "휘감기"},
	"dots": {"name": "점박이", "kind": "dots_faded", "power": 1.0, "skill": "점 뿌리기"},
	"grass": {"name": "풀낙서", "kind": "grass_faded", "power": 1.0, "skill": "풀베기"},
	"spider": {"name": "모눈 거미", "kind": "spider_faded", "power": 1.1, "skill": "모눈 덫"},
	"bug": {"name": "지우개똥 벌레", "kind": "bug_faded", "power": 1.1, "skill": "가루 뿌리기"},
	"grassmallang": {"name": "풀말랑", "kind": "slime_faded", "power": 1.6, "skill": "풀밭 깔기", "tint": Color(0.7, 1.0, 0.7)},
	"linespider": {"name": "줄거미", "kind": "spider_faded", "power": 1.6, "skill": "줄 치기", "tint": Color(1.0, 0.85, 0.6)},
	"snowflake": {"name": "눈송이", "kind": "dots_faded", "power": 1.6, "skill": "얼리기", "tint": Color(0.75, 0.9, 1.0)},
}
## 다른 종끼리 합치기: [재료, 재료, 새 종]. 둘 다 별 2개 이상이어야 한다.
const MERGES := [["slime", "grass", "grassmallang"], ["squiggle", "spider", "linespider"], ["dots", "bug", "snowflake"]]


## 몬스터 종류("slime_faded") → 친구 종("slime")
static func species_of(kind: String) -> String:
	return kind.split("_")[0]


## 내 마을에 지을 수 있는 것. id 는 그림 이름(assets/sprites/<id>.png) 이다.
##  w: 가로 크기(월드). use: 건물에 말을 걸었을 때 하는 일. cost: {"coins", "lead"}
##  건물은 자리를 고른 뒤 점선을 따라 그려서 짓는다. 소품은 바로 놓인다.
const BUILDS := {
	"bld_house": {"name": "내 집", "w": 70, "kind": "building", "use": "sleep", "cost": {"lead": 5}},
	"bld_shop": {"name": "문방구", "w": 70, "kind": "building", "use": "shop", "cost": {"lead": 15, "coins": 100}},
	"bld_craft": {"name": "조합대", "w": 70, "kind": "building", "use": "craft", "cost": {"lead": 10, "coins": 50}},
	"bld_storage": {"name": "창고", "w": 70, "kind": "building", "use": "storage", "cost": {"lead": 15, "coins": 100}},
	"bld_board": {"name": "게시판", "w": 50, "kind": "building", "use": "board", "cost": {"lead": 10, "coins": 80}},
	"bld_fishing": {"name": "낚시터", "w": 70, "kind": "building", "use": "fishing", "cost": {"lead": 20, "coins": 150}},
	"bld_villager_a": {"name": "주민 집 (보라 지붕)", "w": 70, "kind": "building", "use": "villager", "cost": {"lead": 20, "coins": 120}},
	"bld_villager_b": {"name": "주민 집 (초록 지붕)", "w": 70, "kind": "building", "use": "villager", "cost": {"lead": 20, "coins": 120}},
	"bld_farm": {"name": "밭", "w": 70, "kind": "building", "use": "farm", "cost": {"lead": 10, "coins": 80}, "walk": true},
	"bld_diner": {"name": "식당", "w": 70, "kind": "building", "use": "cook", "cost": {"lead": 20, "coins": 150}},
	"bld_pen": {"name": "친구 우리", "w": 80, "kind": "building", "use": "pen", "cost": {"lead": 15, "coins": 120}, "walk": true},
	"bld_museum": {"name": "박물관", "w": 76, "kind": "building", "use": "museum", "cost": {"lead": 25, "coins": 200}},
	"bld_forge": {"name": "강화소", "w": 72, "kind": "building", "use": "forge", "cost": {"lead": 25, "coins": 180}},
	"deco_tree_round": {"name": "둥근 나무", "w": 30, "kind": "deco", "cost": {"coins": 20}},
	"deco_tree_pine": {"name": "뾰족 나무", "w": 28, "kind": "deco", "cost": {"coins": 20}},
	"deco_bush": {"name": "덤불", "w": 24, "kind": "deco", "cost": {"coins": 10}},
	"deco_flower_red": {"name": "빨간 꽃", "w": 16, "kind": "deco", "cost": {"coins": 5}, "walk": true},
	"deco_flower_yellow": {"name": "노란 꽃", "w": 16, "kind": "deco", "cost": {"coins": 5}, "walk": true},
	"deco_fence_h": {"name": "울타리 (가로)", "w": 26, "kind": "deco", "cost": {"coins": 8}},
	"deco_fence_v": {"name": "울타리 (세로)", "w": 9, "kind": "deco", "cost": {"coins": 8}},
	"deco_rock": {"name": "바위", "w": 20, "kind": "deco", "cost": {"coins": 10}},
	"deco_stump": {"name": "그루터기", "w": 20, "kind": "deco", "cost": {"coins": 10}},
	"deco_grass": {"name": "풀포기", "w": 16, "kind": "deco", "cost": {"coins": 3}, "walk": true},
	"deco_bench": {"name": "벤치", "w": 28, "kind": "deco", "cost": {"coins": 25}},
	"deco_lamp": {"name": "가로등", "w": 12, "kind": "deco", "cost": {"coins": 30}},
	"deco_mailbox": {"name": "우체통", "w": 16, "kind": "deco", "cost": {"coins": 25}},
	"deco_well": {"name": "우물", "w": 26, "kind": "deco", "cost": {"coins": 40}},
	"deco_signpost": {"name": "표지판", "w": 20, "kind": "deco", "cost": {"coins": 15}},
	"deco_clothesline": {"name": "빨랫줄", "w": 36, "kind": "deco", "cost": {"coins": 20}},
	"deco_pot": {"name": "화분", "w": 16, "kind": "deco", "cost": {"coins": 10}},
	"deco_bridge": {"name": "널다리", "w": 34, "kind": "deco", "cost": {"coins": 20}, "walk": true},
	"deco_stones": {"name": "징검돌", "w": 28, "kind": "deco", "cost": {"coins": 10}, "walk": true},
	"deco_scarecrow": {"name": "허수아비", "w": 24, "kind": "deco", "cost": {"coins": 30}},
}
## 내 마을 넓히기: 종이 장수 → 가로 × 세로 (화면 한 장은 640 × 360)
const HOME_STEPS := [4, 6, 9, 12, 16]
const HOME_GRID := {4: Vector2i(2, 2), 6: Vector2i(3, 2), 9: Vector2i(3, 3), 12: Vector2i(4, 3), 16: Vector2i(4, 4)}


## 이야기가 있는 주민 (1장). 부탁을 들어주고 내 마을에 주민 집이 있으면 이사 온다. 이름은 플레이어가 지어 준다.
##  like: 좋아하는 선물 (호감도 +3), gift: 하트 1개부터 하루 한 번 주는 것, memory: 하트 3개에 들려주는 옛 기억
const VILLAGERS := {
	"baker": {"title": "빵집 아주머니", "sprite": "villager_0", "like": "c_radish", "gift": "bread",
		"memory": ["간판에 뭐라고 썼었는지 기억났어.", "가게 이름이 아니었어. 우리 애 이름이었지.", "…그 애가 누구였는지는, 아직 모르겠구나."]},
	"elder": {"title": "지팡이 할아버지", "sprite": "villager_1", "like": "f_carp", "gift": "g_twig",
		"memory": ["그 흰 자국 말이다. 날마다 그 앞에 서 있었지.", "이름은 끝내 못 찾았어. 그래도 누가 서 있었다는 건 내가 안다.", "잊지 않는 사람이 하나라도 있으면, 다 지워진 건 아니란다."]},
	"kid": {"title": "풍선 아이", "sprite": "villager_2", "like": "g_berry", "gift": "candy",
		"memory": ["풍선 준 사람, 생각났어!", "키가 크고… 손이 따뜻했어. 얼굴은 안 보여.", "나중에 만나면 내가 먼저 알아볼 거야."]},
}
const HEART_NEED := [10, 30, 60, 100, 150]

## 직접 만드는 주민: 성격마다 좋아하는 선물(like), 하트 1개부터 주는 하루 선물(gift), 옛 기억 대신 들려주는 이야기
const CUSTOM_MAX := 12

## 도감 묶음과, 다 채우면 오르는 능력
const DEX_NAMES := {"mon": "몬스터", "friend": "친구", "fish": "물고기", "crop": "작물", "gear": "장비", "mat": "재료"}
const DEX_BONUS := {"mon": {"atk": 3}, "friend": {"hp": 30}, "fish": {"mp": 20}, "crop": {"def": 2}, "gear": {"crit": 2}, "mat": {"drop": 5}}
const MUSEUM_STEPS := [25, 50, 75, 100]
const PERSONAS := {
	"glutton": {"name": "먹보", "like": "d_carp", "gift": "bread",
		"memory": ["배고프면 그림도 삐뚤어져.", "네가 만든 요리, 냄새만 맡아도 알아.", "다음엔 같이 먹자!"]},
	"angler": {"name": "낚시꾼", "like": "f_catfish", "gift": "f_minnow",
		"memory": ["물을 칠한 자리엔 꼭 뭔가 살아.", "밤에만 나오는 메기가 있대.", "낚싯줄은 연필선이랑 닮았어."]},
	"gardener": {"name": "꽃지기", "like": "c_flower", "gift": "s_flower",
		"memory": ["색종이 꽃은 물을 좋아해.", "꽃 하나 심으면 마을이 한 장 더 밝아져.", "오늘은 어떤 색으로 칠할까?"]},
	"collector": {"name": "수집가", "like": "j_bottle", "gift": "g_stone",
		"memory": ["병 속 쪽지를 다 모으면 무슨 말이 될까?", "버려진 것도 다 쓸 데가 있어.", "네 가방 구경해도 돼?"]},
}
## 주민 부품 (assets/sprites 의 그림 이름). 몸 위에 옷, 그 위에 얼굴을 겹친다. 그림이 없는 부품은 건너뛴다.
##  몸 그림이 아직 없을 때는 있는 주민 그림을 몸으로 쓴다.
const CUSTOM_PARTS := {
	"body": ["cv_body_0", "cv_body_1", "cv_body_2", "cv_body_3"],
	"cloth": ["cv_cloth_0", "cv_cloth_1", "cv_cloth_2", "cv_cloth_3", "cv_cloth_4", "cv_cloth_5"],
	"face": ["cv_face_0", "cv_face_1", "cv_face_2", "cv_face_3", "cv_face_4", "cv_face_5"],
}
const CUSTOM_BODY_FALLBACK := ["villager_0", "villager_1", "villager_2"]
## 날아간 풍선이 걸려 있는 곳 (화면, bg px)
# ---------- 건물 단계 (내 마을) ----------
## 건물은 5단계까지 올린다. 새로 지으면 1단계(초가집). 그림은 3단계가 <id>.png, 나머지는 <id>_l<단계>.png.
const BUILD_MAX_LV := 5
const BUILD_LV_NAMES := ["초가집", "흙집", "나무집", "벽돌집", "저택"]
## 안으로 들어갈 수 있는 건물 → 방의 배경 그림
const ROOMS := {
	"bld_house": "bg_room", "bld_shop": "bg_room_shop", "bld_craft": "bg_room_craft", "bld_storage": "bg_room_storage",
	"bld_diner": "bg_room_diner", "bld_villager_a": "bg_room_villager", "bld_villager_b": "bg_room_villager",
}
const ROOM_FURN_CAP := [3, 5, 8, 12, 16]            # 단계마다 방에 놓을 수 있는 가구 수
const ROOM_SCALE := [0.62, 0.72, 0.82, 0.91, 1.0]   # 단계마다 방의 크기 (5단계가 화면 가득)
## 점선을 잘 따라 그려서 짓거나 올리면 한동안 받는 효과 (건물마다 다르다)
const BUILD_BUFF := {
	"bld_house": "def", "bld_shop": "drop", "bld_craft": "atk", "bld_storage": "drop", "bld_board": "exp",
	"bld_fishing": "mpregen", "bld_villager_a": "exp", "bld_villager_b": "exp", "bld_farm": "mpregen", "bld_diner": "atk",
	"bld_pen": "exp", "bld_museum": "drop", "bld_forge": "atk",
}
## 친구 우리: 단계마다 친구 칸이 늘어난다 (우리가 없으면 FRIEND_BASE)
const FRIEND_BASE := 30
const FRIEND_PER_PEN_LV := 6
const PEN_WANDER := 6               # 우리 안에서 돌아다니는 친구 수 (같이 다니는 친구는 빼고)
const FARM_PLOTS_BY_LV := [2, 4, 6, 8, 10]
const STORAGE_BY_LV := [36, 48, 60, 72, 84]


## lv 단계의 건물을 다음 단계로 올리는 값 (지을 때 값의 몇 배 + 동전)
static func upgrade_cost(id: String, lv: int) -> Dictionary:
	var base: Dictionary = BUILDS[id]["cost"]
	return {"lead": int(base.get("lead", 0)) * (lv + 1), "coins": int(base.get("coins", 0)) * (lv + 1) + 60 * lv}


## 그 단계의 건물 그림 이름 (그림이 아직 없으면 3단계 그림)
static func build_sprite(id: String, lv: int) -> String:
	var name := id if lv == 3 else "%s_l%d" % [id, lv]
	return name if Art.has(name) else id


const BALLOONS := {"ch1_meadow": Vector2(1300, 620), "ch1_crossroad": Vector2(420, 330), "ch1_gridwoods": Vector2(1000, 470)}

## 난이도 단계: 이름, 권장 레벨, 몬스터 HP·공격·경험치 배율, 떨어지는 장비 등급 (가장 낮은 것, 가장 높은 것)
const DIFFICULTY := [
	{"name": "흐릿한", "level": 1, "hp": 1.0, "dmg": 1.0, "exp": 1.0, "tier": [0, 1]},
	{"name": "지워지는", "level": 20, "hp": 5.0, "dmg": 3.0, "exp": 6.0, "tier": [1, 2]},
	{"name": "찢어진", "level": 45, "hp": 20.0, "dmg": 8.0, "exp": 30.0, "tier": [2, 3]},
	{"name": "빈", "level": 70, "hp": 70.0, "dmg": 20.0, "exp": 120.0, "tier": [3, 4]},
]
## 필드 보스가 나올 수 있는 화면
const FIELD_BOSS_MAPS := ["ch1_meadow", "ch1_crossroad", "ch1_gridwoods"]
