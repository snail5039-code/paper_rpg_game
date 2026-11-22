extends RefCounted
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
	"coating": ["코팅지", "item_2", 300, "강화 실패 때 하락과 파괴를 한 번 막는다", "", 0.0],
}
const QUICK_SLOTS := ["bandage", "milk"]   # 1, 2 번 키

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
	"warmup": {"name": "손풀기", "icon": "skill_warmup", "level": 14, "mp": 0, "cd": 0.0, "max": 10, "kind": "passive",
		"mult": [0.02, 0.02], "desc": "공격 속도가 단계마다 2% 오른다"},
}
const SKILL_ORDER := ["slash", "circle", "dot", "hatch", "press", "erase", "sharpen", "warmup"]
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


static func item_name(item: Dictionary) -> String:
	var plus := int(item.get("plus", 0))
	var base := "%s %s" % [TIER_NAMES[int(item["tier"])], SHAPES[str(item["slot"])][int(item["shape"])]]
	return ("+%d " % plus if plus > 0 else "") + base


static func icon(item: Dictionary) -> String:
	return "equip_%s_%d" % [str(item["slot"]), int(item["shape"])]


static func tier_color(item: Dictionary) -> Color:
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
	return roundi(v * (1.0 + 0.08 * int(item.get("plus", 0))))


static func stat_text(key: String, value: int) -> String:
	return "%s +%d%s" % [STAT_LABEL[key], value, "%" if PERCENT_STATS.has(key) else ""]


static func describe(item: Dictionary) -> String:
	var lines: Array = [item_name(item), stat_text(str(MAIN_STAT[str(item["slot"])]), main_value(item))]
	for o in item["opts"]:
		lines.append("  " + stat_text(str(o[0]), int(o[1])))
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
