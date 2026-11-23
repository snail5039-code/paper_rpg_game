extends RefCounted
const Art := preload("res://scripts/core/art.gd")
## 아이템 데이터와 계산: 장비(6부위 × 모양 10 × 등급 5), 소모품, 조합법, 강화, 스킬.
## 수치는 docs/세부설정.md 를 따른다 (가안).
##
## 장비 한 개는 Dictionary 다 (저장할 수 있게 기본 자료형만 쓴다):
##   {"slot": "tool", "shape": 0, "tier": 1, "level": 3, "plus": 0, "opts": [["atk", 2], ...]}

const SLOTS := ["tool", "hat", "cloth", "shoe", "bag", "acc"]
const SLOT_NAMES := {"tool": "도구", "hat": "모자", "cloth": "옷", "shoe": "신발", "bag": "가방", "acc": "장신구"}
const SHAPES := {
	"tool": ["연필", "몽당연필", "샤프", "깃펜", "붓", "넓은 붓", "분필", "사인펜", "형광펜", "크레용"],
	"hat": ["종이배 모자", "신문지 모자", "야구 모자", "털모자", "밀짚모자", "종이 왕관", "머리띠", "고깔모자", "안전모", "베레모"],
	"cloth": ["후드티", "체육복", "우비", "앞치마", "멜빵바지", "잠옷", "세일러복", "망토", "조끼", "스웨터"],
	"shoe": ["운동화", "장화", "슬리퍼", "실내화", "샌들", "롤러스케이트", "털부츠", "구두", "고무신", "축구화"],
	"bag": ["책가방", "신발주머니", "필통", "도시락 가방", "크로스백", "쇼핑백", "보자기", "화구 가방", "허리 가방", "바구니"],
	"acc": ["머리끈", "이름표", "구슬", "목도리", "손목시계", "안경", "반창고 스티커", "열쇠고리", "구름 배지", "구슬 팔찌"],
}
const TIER_NAMES := ["낙서", "스케치", "색칠", "덧칠", "완성"]
const TIER_COLORS := [Color(0.72, 0.72, 0.72), Color(1, 1, 1), Color(0.62, 0.82, 1.0), Color(0.82, 0.68, 1.0), Color(1.0, 0.86, 0.45)]
const TIER_OPT_COUNT := [0, 1, 2, 3, 3]
## 부위마다 붙는 기본 능력
const MAIN_STAT := {"tool": "atk", "hat": "def", "cloth": "hp", "shoe": "mspd", "bag": "mp", "acc": "crit"}
const STAT_LABEL := {
	"atk": "공격력", "def": "방어", "hp": "최대 HP", "mp": "최대 MP", "crit": "치명타 확률",
	"critdmg": "치명타 피해", "aspd": "공격 속도", "mspd": "이동 속도", "drop": "드롭률", "exp": "경험치",
}
const PERCENT_STATS := ["crit", "critdmg", "aspd", "mspd", "drop", "exp"]
## 무작위 옵션: [최소, 최대] (낙서 등급 기준, 등급마다 50%씩 커진다)
const OPT_RANGE := {
	"atk": [1, 3], "hp": [5, 15], "mp": [4, 10], "def": [1, 2], "crit": [1, 3],
	"critdmg": [5, 15], "aspd": [2, 5], "mspd": [2, 4], "drop": [3, 8], "exp": [3, 8],
}

## 완성 등급 장비의 고유 효과 (부위마다 하나). 유일 장비는 자기만의 효과가 있다.
const FX_BY_SLOT := {"tool": "ink", "hat": "brim", "cloth": "pad", "shoe": "light", "bag": "pocket", "acc": "spark"}
const FX_TEXT := {
	"ink": "잉크 번짐: 치명타가 나면 MP 3 회복",
	"brim": "단단한 챙: 받는 피해 10% 감소",
	"pad": "두꺼운 솜: 1초마다 HP 1 회복",
	"light": "가벼운 발: 회피를 20% 더 자주",
	"pocket": "넉넉한 주머니: 소모품 회복량 30% 증가",
	"spark": "반짝임: 필살기 게이지가 30% 빨리 참",
	"u_star": "구겨진 별: 치명타가 나면 필살기 게이지 +5",
	"u_pen": "마르지 않는 잉크: 공격이 맞을 때마다 HP 1 회복",
	"v_brooch": "갓 구운 냄새: 소모품과 음식의 회복량 20% 증가",
	"v_watch": "느긋한 시계: 사냥터 화면에 들어갈 때 피로도가 1 덜 든다",
	"v_badge": "둥실둥실: 이동 속도 +10%",
	"set_eraser": "지우개 세트: 받는 피해 15% 감소",
	"set_crumple": "구김 세트: 치명타가 나면 HP 2 회복",
	"set_scribble": "낙서 세트: 필살기 게이지가 50% 빨리 참",
}
## 유일 장비: 대장과 필드 보스가 "빈" 단계에서만 떨어뜨린다. 옵션이 정해져 있다.
##   icon: 가방 아이콘 그림, held: 손에 드는 그림 (도구만), shape: 그림이 없을 때 대신 쓰는 모양
const UNIQUES := {
	"u_star": {"name": "구깃이의 구겨진 별", "slot": "acc", "shape": 2, "icon": "unique_star",
		"opts": [["critdmg", 40], ["atk", 14], ["aspd", 10]]},
	"u_pen": {"name": "떠돌이의 만년필", "slot": "tool", "shape": 3, "icon": "unique_pen", "held": "tool_unique_pen",
		"opts": [["crit", 8], ["aspd", 12], ["hp", 60]]},
	# 주민 전용 장신구: 호감도 하트 5개가 되면 그 주민이 준다 (level: 필요 필력)
	"v_brooch": {"name": "빵집 아주머니의 밀가루 브로치", "slot": "acc", "shape": 1, "icon": "vgift_3", "level": 10,
		"opts": [["hp", 80], ["def", 4], ["drop", 10]]},
	"v_watch": {"name": "지팡이 할아버지의 회중시계", "slot": "acc", "shape": 4, "icon": "vgift_4", "level": 10,
		"opts": [["mp", 40], ["exp", 12], ["crit", 4]]},
	"v_badge": {"name": "풍선 아이의 풍선 배지", "slot": "acc", "shape": 8, "icon": "vgift_5", "level": 10,
		"opts": [["mspd", 8], ["aspd", 8], ["atk", 6]]},
}
## 세트 장비 (1장): 보스마다 한 벌. 여섯 부위가 있고 2·4·6부위를 입으면 효과가 붙는다.
##   shapes: 부위마다 그림이 없을 때 쓰는 모양 번호. bonus: 입은 부위 수 → 능력 (6부위는 고유 효과 fx 도)
##   아이콘 그림은 set_<id>_<부위>.png, 겉모습은 hat_set_<id>_<0~2>, player_walk_set_<id>, player_attack_set_<id>, tool_set_<id>
const SETS := {
	"eraser": {"name": "지우개", "boss": "boss_bug", "color": Color(1.0, 0.72, 0.78),
		"shapes": {"tool": 6, "hat": 2, "cloth": 3, "shoe": 3, "bag": 2, "acc": 6},
		"bonus": {2: {"hp": 60}, 4: {"def": 6, "drop": 10}, 6: {"hp": 120, "fx": "set_eraser"}}},
	"crumple": {"name": "구김", "boss": "boss_crumple", "color": Color(0.78, 0.86, 1.0),
		"shapes": {"tool": 2, "hat": 5, "cloth": 7, "shoe": 7, "bag": 7, "acc": 2},
		"bonus": {2: {"atk": 8}, 4: {"critdmg": 20, "crit": 4}, 6: {"atk": 16, "fx": "set_crumple"}}},
	"scribble": {"name": "낙서", "boss": "boss_scribble", "color": Color(0.85, 1.0, 0.72),
		"shapes": {"tool": 9, "hat": 3, "cloth": 9, "shoe": 9, "bag": 9, "acc": 8},
		"bonus": {2: {"mspd": 6}, 4: {"aspd": 10, "exp": 10}, 6: {"mp": 50, "fx": "set_scribble"}}},
}
const SET_DROP := {"mid": 0.2, "boss": 0.35, "field": 0.35}   # 보스를 잡을 때 그 보스의 세트 한 부위가 나올 확률
const SET_MIN_TIER := 2                                       # 세트 장비는 색칠 등급부터


## 세트 장비 한 부위를 만든다 (등급은 난이도를 따르되 색칠 이상)
static func make_set(set_id: String, slot: String, tier: int, level: int) -> Dictionary:
	var s: Dictionary = SETS[set_id]
	var item := make(slot, int(s["shapes"][slot]), clampi(maxi(tier, SET_MIN_TIER), 0, 4), level)
	item["set"] = set_id
	return item


static func set_of(item: Dictionary) -> String:
	return str(item.get("set", "")) if SETS.has(str(item.get("set", ""))) else ""


## 세트 효과 설명 줄들 (입은 부위 수 n 을 주면 받는 줄에 표시)
static func set_lines(set_id: String, n: int = -1) -> Array:
	var s: Dictionary = SETS[set_id]
	var out: Array = []
	for need in [2, 4, 6]:
		var b: Dictionary = s["bonus"][need]
		var parts: Array = []
		for k in b:
			if str(k) == "fx":
				parts.append(str(FX_TEXT[str(b[k])]))
			else:
				parts.append(stat_text(str(k), int(b[k])))
		out.append("%s%d부위: %s" % ["✔ " if n >= need else "  ", need, ", ".join(parts)])
	return out


## 강화 겉모습: 입은 장비 중 가장 높은 강화 단계에 따라 발밑에 오라가 생긴다 (+4 하늘, +7 보라, +10 금빛)
const AURA_MIN := 4


static func best_plus(equipped: Dictionary) -> int:
	var best := 0
	for slot in equipped:
		best = maxi(best, int((equipped[slot] as Dictionary).get("plus", 0)))
	return best


static func aura_color(plus: int) -> Color:
	if plus >= 10:
		return Color(1.0, 0.82, 0.3, 0.95)
	if plus >= 7:
		return Color(0.78, 0.55, 1.0, 0.9)
	if plus >= AURA_MIN:
		return Color(0.5, 0.8, 1.0, 0.8)
	return Color(1, 1, 1, 0)


## 주민 전용: 하트 4개에 배우는 조합법, 하트 5개에 받는 장신구
const VILLAGER_RECIPES := {
	"baker": ["단팥빵", "v_redbean", {0: 3, 4: 2}, 4],
	"elder": ["지팡이 차", "v_tea", {2: 3, 6: 2}, 4],
	"kid": ["풍선껌", "v_gum", {4: 3, 8: 2}, 4],
}
const VILLAGER_ACC := {"baker": "v_brooch", "elder": "v_watch", "kid": "v_badge"}
const UNIQUE_COLOR := Color(1.0, 0.62, 0.55)
const UNIQUE_LEVEL := 70
const UNIQUE_DROP_RATE := 0.25

const MAX_PLUS := 12
const ENHANCE_RATE := [1.0, 1.0, 1.0, 0.8, 0.8, 0.8, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1]   # +0→+1 … +11→+12
const DUST_BY_TIER := [1, 2, 4, 8, 20]
const SELL_BY_TIER := [8, 20, 60, 160, 400]

## 소모품: id → [이름, 아이콘, 값, 설명, 효과 종류, 효과 크기]
const CONSUMABLES := {
	"bandage": ["반창고", "item_0", 15, "HP 를 30% 회복한다", "hp", 0.3],
	"milk": ["우유", "item_3", 12, "MP 를 50% 회복한다", "mp", 0.5],
	"candy": ["사탕", "item_4", 6, "HP 를 12% 회복한다", "hp", 0.12],
	"paper": ["도화지", "icon_paper", 30, "쓰러진 몬스터를 다시 그릴 때 쓴다", "", 0.0],
	"paper_thick": ["두꺼운 도화지", "icon_paper_thick", 150, "다시 그리기 성공률이 20% 오른다", "", 0.0],
	"f_carp": ["연필 붕어", "food_0", 12, "내 마을 물에서 낚는다. HP 를 10% 회복한다", "hp", 0.1],
	"f_minnow": ["모눈 송사리", "food_1", 8, "내 마을 물에서 낚는다. HP 를 10% 회복한다", "hp", 0.1],
	"f_clam": ["지우개 조개", "food_2", 15, "내 마을 물에서 낚는다. HP 를 10% 회복한다", "hp", 0.1],
	"f_catfish": ["잉크 메기", "food_3", 40, "내 마을 물에서 밤에만 낚인다. HP 를 15% 회복한다", "hp", 0.15],
	"f_crayon": ["크레용 피라미", "food_4", 10, "1장 강에서 낚는다. HP 를 10% 회복한다", "hp", 0.1],
	"f_cray": ["낙서 가재", "food_5", 18, "1장 강에서 낚는다. HP 를 10% 회복한다", "hp", 0.1],
	"f_boat": ["종이배", "food_6", 14, "1장 강에 떠다닌다. 팔 수 있다", "", 0.0],
	"f_moon": ["달빛 은어", "food_7", 45, "1장 강에서 밤에만 낚인다. MP 를 30% 회복한다", "mp", 0.3],
	"j_scrap": ["찢어진 종이", "food_8", 3, "어디서나 가끔 낚인다. 팔 수 있다", "", 0.0],
	"j_bottle": ["병 속 쪽지", "food_9", 30, "누군가의 쪽지가 들어 있다. 글씨는 지워졌다", "", 0.0],
	"j_boot": ["낡은 장화", "food_10", 5, "누가 신던 걸까", "", 0.0],
	"j_crane": ["접힌 종이학", "food_11", 60, "밤에 아주 가끔 낚인다", "", 0.0],
	"c_radish": ["연필 무", "crop_0", 10, "밭에서 하루면 자란다. HP 를 10% 회복한다", "hp", 0.1],
	"c_carrot": ["크레용 당근", "crop_1", 18, "밭에서 이틀이면 자란다. HP 를 10% 회복한다", "hp", 0.1],
	"c_cabbage": ["모눈 양배추", "crop_2", 18, "밭에서 이틀이면 자란다. HP 를 10% 회복한다", "hp", 0.1],
	"c_flower": ["색종이 꽃", "crop_3", 28, "밭에서 사흘이면 핀다. 선물로 좋다", "", 0.0],
	"c_tomato": ["물감 토마토", "crop_4", 28, "밭에서 사흘이면 익는다. HP 를 10% 회복한다", "hp", 0.1],
	"c_cotton": ["솜사탕 목화", "crop_5", 40, "밭에서 나흘이면 핀다", "", 0.0],
	"c_corn": ["별사탕 옥수수", "crop_6", 40, "밭에서 나흘이면 익는다. HP 를 10% 회복한다", "hp", 0.1],
	"c_grape": ["잉크 포도", "crop_7", 55, "밭에서 닷새면 익는다. MP 를 10% 회복한다", "mp", 0.1],
	"g_grass": ["풀", "forage_0", 2, "사냥터에서 뜯는다", "", 0.0],
	"g_stone": ["돌", "forage_1", 3, "사냥터에서 줍는다", "", 0.0],
	"g_twig": ["나뭇가지", "forage_2", 3, "사냥터에서 줍는다", "", 0.0],
	"g_berry": ["열매", "forage_3", 6, "사냥터에서 딴다. HP 를 10% 회복한다", "hp", 0.1],
	"bread": ["빵", "icon_bread", 20, "빵집 아주머니가 굽는다. HP 를 40% 회복한다", "hp", 0.4],
	"d_carp": ["붕어 구이", "dish_0", 30, "HP 를 30% 회복한다", "food", 0.0],
	"d_radish": ["무 조림", "dish_1", 35, "HP 20% 회복, 5분간 방어 +10%", "food", 0.0],
	"d_cake": ["당근 케이크", "dish_2", 70, "10분간 경험치 +10%", "food", 0.0],
	"d_wrap": ["양배추 쌈", "dish_3", 60, "10분간 공격력 +10%", "food", 0.0],
	"d_soup": ["토마토 수프", "dish_4", 70, "MP 를 50% 회복한다", "food", 0.0],
	"d_corn": ["옥수수 구이", "dish_5", 60, "10분간 드롭률 +10%", "food", 0.0],
	"d_juice": ["포도 주스", "dish_6", 120, "10분간 MP 회복 2배", "food", 0.0],
	"d_stew": ["메기 매운탕", "dish_7", 90, "HP 와 MP 를 전부 회복한다", "food", 0.0],
	"s_radish": ["연필 무 씨앗", "icon_seed", 6, "밭에 심으면 1일 뒤에 거둔다 (하루 한 번 물 주기)", "", 0.0],
	"s_carrot": ["크레용 당근 씨앗", "icon_seed", 12, "밭에 심으면 2일 뒤에 거둔다 (하루 한 번 물 주기)", "", 0.0],
	"s_cabbage": ["모눈 양배추 씨앗", "icon_seed", 12, "밭에 심으면 2일 뒤에 거둔다 (하루 한 번 물 주기)", "", 0.0],
	"s_flower": ["색종이 꽃 씨앗", "icon_seed", 18, "밭에 심으면 3일 뒤에 거둔다 (하루 한 번 물 주기)", "", 0.0],
	"s_tomato": ["물감 토마토 씨앗", "icon_seed", 18, "밭에 심으면 3일 뒤에 거둔다 (하루 한 번 물 주기)", "", 0.0],
	"s_cotton": ["솜사탕 목화 씨앗", "icon_seed", 24, "밭에 심으면 4일 뒤에 거둔다 (하루 한 번 물 주기)", "", 0.0],
	"s_corn": ["별사탕 옥수수 씨앗", "icon_seed", 24, "밭에 심으면 4일 뒤에 거둔다 (하루 한 번 물 주기)", "", 0.0],
	"s_grape": ["잉크 포도 씨앗", "icon_seed", 30, "밭에 심으면 5일 뒤에 거둔다 (하루 한 번 물 주기)", "", 0.0],
	"coating": ["코팅지", "item_2", 300, "강화 실패 때 하락과 파괴를 한 번 막는다", "", 0.0],
	"v_redbean": ["단팥빵", "vgift_0", 60, "빵집 아주머니의 비법. HP 60% 회복, 5분간 방어 +10%", "food", 0.0],
	"v_tea": ["지팡이 차", "vgift_1", 60, "지팡이 할아버지의 차. MP 60% 회복, 10분간 MP 회복 2배", "food", 0.0],
	"v_gum": ["풍선껌", "vgift_2", 50, "풍선 아이의 껌. HP 20% 회복, 10분간 경험치 +10%", "food", 0.0],
}
const QUICK_SLOTS := ["bandage", "milk"]   # 1, 2 번 키

## 요리의 효과: hp·mp 는 회복하는 비율, buff 는 한동안 오르는 것 (def, exp, atk, drop, mpregen), time 은 초
const FOOD_FX := {
	"d_carp": {"hp": 0.3},
	"d_radish": {"hp": 0.2, "buff": "def", "time": 300},
	"d_cake": {"buff": "exp", "time": 600},
	"d_wrap": {"buff": "atk", "time": 600},
	"d_soup": {"mp": 0.5},
	"d_corn": {"buff": "drop", "time": 600},
	"d_juice": {"buff": "mpregen", "time": 600},
	"d_stew": {"hp": 1.0, "mp": 1.0},
	"v_redbean": {"hp": 0.6, "buff": "def", "time": 300},
	"v_tea": {"mp": 0.6, "buff": "mpregen", "time": 600},
	"v_gum": {"hp": 0.2, "buff": "exp", "time": 600},
}
const BUFF_NAMES := {"def": "방어 +10%", "exp": "경험치 +10%", "atk": "공격력 +10%", "drop": "드롭률 +10%", "mpregen": "MP 회복 2배"}

## 요리법 (식당): 요리 id → 재료 {id: 개수}
const DISHES := {
	"d_carp": {"f_carp": 1},
	"d_radish": {"c_radish": 2},
	"d_cake": {"c_carrot": 2, "bread": 1},
	"d_wrap": {"c_cabbage": 1, "f_cray": 1},
	"d_soup": {"c_tomato": 2},
	"d_corn": {"c_corn": 1},
	"d_juice": {"c_grape": 2},
	"d_stew": {"f_catfish": 1, "c_carrot": 1},
}

## 작물: 씨앗 id → [거두는 것, 자라는 날]
const CROPS := {
	"s_radish": ["c_radish", 1], "s_carrot": ["c_carrot", 2], "s_cabbage": ["c_cabbage", 2], "s_flower": ["c_flower", 3],
	"s_tomato": ["c_tomato", 3], "s_cotton": ["c_cotton", 4], "s_corn": ["c_corn", 4], "s_grape": ["c_grape", 5],
}
const FARM_PLOTS := 6

## 낚시터마다 낚이는 것: [낮, 밤, 드물게(낮), 드물게(밤)]
const FISH := {
	"home": [["f_carp", "f_minnow", "f_clam"], ["f_catfish", "f_carp"], ["j_scrap", "j_bottle", "j_boot"], ["j_crane", "j_bottle"]],
	"ch1": [["f_crayon", "f_cray", "f_boat"], ["f_moon", "f_cray"], ["j_scrap", "j_bottle", "j_boot"], ["j_crane", "j_bottle"]],
}
const FORAGE := ["g_grass", "g_stone", "g_twig", "g_berry"]

## 가구 (집 안 꾸미기). id 는 그림 이름. 값은 동전.
const FURNITURE := {
	"furn_0": ["책상", 80], "furn_1": ["침대", 0], "furn_2": ["스탠드", 60], "furn_3": ["책장", 120],
	"furn_4": ["러그", 70], "furn_5": ["화분", 40], "furn_6": ["액자", 50], "furn_7": ["의자", 40],
	"furn_8": ["둥근 탁자", 90], "furn_9": ["장난감 상자", 100], "furn_10": ["벽시계", 60], "furn_11": ["창문", 80],
}

## 조합법: [이름, 결과, 재료 {재료 번호: 개수}, 연필심]
##   결과가 문자열이면 소모품 id, 배열이면 장비 [부위, 모양, 등급]
const RECIPES := [
	["반창고", "bandage", {0: 2}, 0],
	["우유", "milk", {4: 2}, 0],
	["도화지", "paper", {7: 1, 6: 2}, 1],
	["스케치 연필", ["tool", 0, 1], {2: 4}, 3],
	["스케치 신문지 모자", ["hat", 1, 1], {6: 4}, 3],
	["스케치 후드티", ["cloth", 0, 1], {0: 4}, 3],
	["스케치 운동화", ["shoe", 0, 1], {10: 4}, 3],
	["스케치 필통", ["bag", 2, 1], {8: 4}, 3],
	["스케치 구슬", ["acc", 2, 1], {4: 4}, 3],
	["색칠 샤프", ["tool", 2, 2], {2: 6, 3: 2}, 8],
	["색칠 우비", ["cloth", 2, 2], {0: 6, 1: 2}, 8],
	["색칠 안경", ["acc", 5, 2], {8: 6, 9: 2}, 8],
	["색칠 털모자", ["hat", 3, 2], {6: 6, 7: 2}, 8],
	["색칠 장화", ["shoe", 1, 2], {10: 6, 11: 2}, 8],
	["색칠 크로스백", ["bag", 4, 2], {4: 6, 5: 2}, 8],
	["덧칠 깃펜", ["tool", 3, 3], {2: 10, 3: 5, 11: 2}, 20],
	["덧칠 종이 왕관", ["hat", 5, 3], {6: 10, 7: 5, 11: 2}, 20],
	["덧칠 망토", ["cloth", 7, 3], {0: 10, 1: 5, 11: 2}, 20],
	["덧칠 롤러스케이트", ["shoe", 5, 3], {10: 10, 9: 5, 11: 2}, 20],
	["덧칠 화구 가방", ["bag", 7, 3], {8: 10, 5: 5, 11: 2}, 20],
	["덧칠 구름 배지", ["acc", 8, 3], {4: 10, 9: 5, 11: 2}, 20],
]

## 문방구에서 파는 것: 소모품 id 또는 장비 [부위, 모양, 등급, 값]
const SHOP := [
	"bandage", "milk", "candy", "paper", "paper_thick",
	["tool", 0, 0, 40], ["hat", 2, 0, 30], ["cloth", 1, 0, 35], ["shoe", 3, 0, 30], ["bag", 1, 0, 30], ["acc", 0, 0, 30],
]

## 연필잡이 스킬 (세부설정 4).
##  kind: "active" 는 Q·E·R 칸에 넣어 쓰고, "passive" 는 찍기만 하면 된다
##  mult: [1단계 배율, 단계마다 더하는 양]
const SKILLS := {
	"slash": {"name": "길게 긋기", "icon": "skill_slash", "level": 2, "mp": 6, "cd": 4.0, "max": 5, "kind": "active",
		"mult": [1.4, 0.2], "desc": "앞으로 미끄러지며 지나간 적을 모두 벤다"},
	"circle": {"name": "동그라미", "icon": "skill_circle", "level": 5, "mp": 8, "cd": 6.0, "max": 5, "kind": "active",
		"mult": [1.2, 0.15], "desc": "한 바퀴 돌며 주변의 적을 벤다"},
	"dot": {"name": "점 찍기", "icon": "skill_dot", "level": 8, "mp": 5, "cd": 3.0, "max": 5, "kind": "active",
		"mult": [1.0, 0.15], "desc": "연필심 조각을 던져 멀리 있는 적을 맞힌다"},
	"hatch": {"name": "빗금", "icon": "skill_hatch", "level": 12, "mp": 10, "cd": 7.0, "max": 5, "kind": "active",
		"mult": [0.5, 0.08], "desc": "한 적을 빠르게 다섯 번 찌른다"},
	"press": {"name": "꾹 눌러 쓰기", "icon": "skill_press", "level": 16, "mp": 14, "cd": 10.0, "max": 5, "kind": "active",
		"mult": [2.5, 0.4], "desc": "방어를 무시하는 강한 한 방"},
	"erase": {"name": "쓱 지우기", "icon": "skill_erase", "level": 20, "mp": 8, "cd": 8.0, "max": 3, "kind": "active",
		"mult": [0.8, 0.2], "desc": "잠깐 동안 어떤 공격도 맞지 않는다"},
	"sharpen": {"name": "연필 깎기", "icon": "skill_sharpen", "level": 10, "mp": 0, "cd": 0.0, "max": 10, "kind": "passive",
		"mult": [0.03, 0.03], "desc": "공격력이 단계마다 3% 오른다"},
	# 필살기: V 키. 게이지(맞히거나 맞으면 참)가 가득 차면 쓸 수 있다. 배율은 따라 그린 만큼 3 ~ 10.
	"ult": {"name": "밑그림 (필살기)", "icon": "skill_ult", "level": 5, "mp": 0, "cd": 0.0, "max": 1, "kind": "ult",
		"mult": [3.0, 0.0], "desc": "V 키. 게이지가 차면 점선 별을 따라 그려 화면의 모든 적을 벤다"},
	"warmup": {"name": "손풀기", "icon": "skill_warmup", "level": 14, "mp": 0, "cd": 0.0, "max": 10, "kind": "passive",
		"mult": [0.02, 0.02], "desc": "공격 속도가 단계마다 2% 오른다"},
}
const SKILL_ORDER := ["slash", "circle", "dot", "hatch", "press", "erase", "sharpen", "warmup", "ult"]
const SKILL_KEYS := ["Q", "E", "R"]


# ---------- 장비 ----------

static func make(slot: String, shape: int, tier: int, level: int = 1) -> Dictionary:
	var item := {"slot": slot, "shape": shape, "tier": tier, "level": level, "plus": 0, "opts": []}
	var keys: Array = OPT_RANGE.keys()
	keys.erase(str(MAIN_STAT[slot]))
	keys.shuffle()
	for i in int(TIER_OPT_COUNT[tier]):
		var key := str(keys[i])
		var r: Array = OPT_RANGE[key]
		var scale := 1.0 + tier * 0.5
		item["opts"].append([key, roundi(randf_range(float(r[0]), float(r[1])) * scale)])
	return item


## 몬스터가 떨어뜨리는 장비: 부위와 모양은 무작위, 등급은 낮은 쪽이 잘 나온다
static func random_drop(level: int, max_tier: int = 1) -> Dictionary:
	var slot := str(SLOTS[randi() % SLOTS.size()])
	var tier := 0
	while tier < max_tier and randf() < 0.3:
		tier += 1
	return make(slot, randi() % 10, tier, maxi(1, level))


## 유일 장비를 만든다 (옵션이 정해져 있다)
static func make_unique(id: String) -> Dictionary:
	var u: Dictionary = UNIQUES[id]
	return {"slot": str(u["slot"]), "shape": int(u["shape"]), "tier": 4, "level": int(u.get("level", UNIQUE_LEVEL)), "plus": 0,
		"opts": (u["opts"] as Array).duplicate(true), "unique": id}


static func is_unique(item: Dictionary) -> bool:
	return UNIQUES.has(str(item.get("unique", "")))


## 장비의 고유 효과 id ("" 은 없음): 유일 장비는 자기 것, 완성 등급은 부위마다 하나
static func fx_of(item: Dictionary) -> String:
	if is_unique(item):
		return str(item["unique"])
	return str(FX_BY_SLOT[str(item["slot"])]) if int(item["tier"]) >= 4 else ""


static func item_name(item: Dictionary) -> String:
	var plus := int(item.get("plus", 0))
	var base := "%s %s" % [TIER_NAMES[int(item["tier"])], SHAPES[str(item["slot"])][int(item["shape"])]]
	if is_unique(item):
		base = "★ " + str(UNIQUES[str(item["unique"])]["name"])
	elif set_of(item) != "":
		base = "◆ %s 세트 %s" % [SETS[set_of(item)]["name"], SLOT_NAMES[str(item["slot"])]]
	return ("+%d " % plus if plus > 0 else "") + base


## 직접 그려 만든 장비는 내 그림이 아이콘이다
static func icon(item: Dictionary) -> String:
	var own := str(item.get("art", ""))
	if own != "":
		return own
	if is_unique(item) and Art.has(str(UNIQUES[str(item["unique"])]["icon"])):
		return str(UNIQUES[str(item["unique"])]["icon"])
	if set_of(item) != "":
		var own_set := "set_%s_%s" % [set_of(item), str(item["slot"])]
		if Art.has(own_set):
			return own_set
	return "equip_%s_%d" % [str(item["slot"]), int(item["shape"])]


## 아이콘에 입히는 색. 유일 장비의 그림은 색이 칠해져 있어서 그대로 둔다 (그림이 없을 때만 붉게).
static func tier_color(item: Dictionary) -> Color:
	if is_unique(item):
		return Color.WHITE if not icon(item).begins_with("equip_") else UNIQUE_COLOR
	if set_of(item) != "":
		return Color.WHITE if icon(item).begins_with("set_") else SETS[set_of(item)]["color"]
	return TIER_COLORS[int(item["tier"])]


## 부위의 기본 능력 값 (강화 한 단계마다 8% 오른다)
static func main_value(item: Dictionary) -> int:
	var tier := int(item["tier"])
	var lv := int(item["level"])
	var v := 0.0
	match str(item["slot"]):
		"tool": v = 8 + tier * 5 + lv * 2
		"hat": v = 1 + tier * 2 + lv / 2
		"cloth": v = 10 + tier * 12 + lv * 4
		"shoe": v = 2 + tier * 2
		"bag": v = 6 + tier * 8 + lv * 2
		"acc": v = 1 + tier * 2
	return roundi(v * (1.0 + 0.08 * int(item.get("plus", 0))) * (1.0 + 0.01 * int(item.get("bonus", 0))))


static func stat_text(key: String, value: int) -> String:
	return "%s +%d%s" % [STAT_LABEL[key], value, "%" if PERCENT_STATS.has(key) else ""]


static func describe(item: Dictionary) -> String:
	var lines: Array = [item_name(item), stat_text(str(MAIN_STAT[str(item["slot"])]), main_value(item))]
	for o in item["opts"]:
		lines.append("  " + stat_text(str(o[0]), int(o[1])))
	if fx_of(item) != "":
		lines.append(str(FX_TEXT[fx_of(item)]))
	if set_of(item) != "":
		lines.append("%s 세트 효과" % SETS[set_of(item)]["name"])
		lines.append_array(set_lines(set_of(item)))
	if int(item.get("bonus", 0)) > 0:
		lines.append("직접 그림 +%d%%" % int(item["bonus"]))
	lines.append("필요 필력 %d" % int(item["level"]))
	return "\n".join(lines)


static func sell_price(item: Dictionary) -> int:
	return int(SELL_BY_TIER[int(item["tier"])]) + int(item.get("plus", 0)) * 5


static func dust_value(item: Dictionary) -> int:
	return int(DUST_BY_TIER[int(item["tier"])]) + int(item.get("plus", 0))


# ---------- 강화 ----------

## 다음 단계로 올리는 값: [연필심, 지우개 가루]
static func enhance_cost(item: Dictionary) -> Array:
	var p := int(item.get("plus", 0)) + 1
	return [p * 3, p * 2]


static func enhance_rate(item: Dictionary) -> float:
	return float(ENHANCE_RATE[clampi(int(item.get("plus", 0)), 0, MAX_PLUS - 1)])


# ---------- 스킬 ----------

static func skill_mult(id: String, rank: int) -> float:
	var m: Array = SKILLS[id]["mult"]
	return float(m[0]) + float(m[1]) * maxi(0, rank - 1)
