extends RefCounted
## 보스마다 전용 기술 두 개, 등장 방식, 이름표 문구 (scripts/actors/boss_brain.gd 가 쓴다).
## 기술은 boss_brain.gd 의 _sk_<이름> 함수. 체력이 절반 아래로 떨어지면 2페이즈: 빨라지고 기술을 더 자주, 이어서 쓴다.
## 그림은 fx_boss_* (docs/도트_프롬프트_stage1.md §105).

const BOSSES := {
	"tm13": {"skills": ["x_slash", "check_fan"], "intro": "x", "title": "틀린 답의 심판"},
	"boss_bug": {"skills": ["roll_combo", "crumb_ring"], "intro": "roll", "title": "모눈 숲의 왕"},
	"boss_crumple": {"skills": ["paper_lob", "slam_line"], "intro": "paper", "title": "구겨진 마음"},
	"boss_scribble": {"skills": ["spiral", "blink"], "intro": "scribble", "title": "길 잃은 낙서"},
	"boss_oak": {"skills": ["root_line", "acorn_rain"], "intro": "rise", "title": "색연필 숲의 뿌리"},
	"boss_mushking": {"skills": ["spore_clouds", "jump_slam"], "intro": "sprout", "title": "색 빠진 골짜기의 왕"},
	"boss_colorworm": {"skills": ["burrow", "paint_spit"], "intro": "erupt", "title": "무지개를 삼킨 것"},
}

## 기술 이름 (2페이즈 알림, 도감 등에 쓴다)
const SKILL_NAMES := {
	"x_slash": "X자 베기", "check_fan": "체크표 던지기",
	"roll_combo": "데굴데굴 연속 구르기", "crumb_ring": "지우개 가루 뿌리기",
	"paper_lob": "종이 공 던지기", "slam_line": "연속 내려치기",
	"spiral": "엉킨 선 소용돌이", "blink": "낙서 순간 이동",
	"root_line": "뿌리 솟기", "acorn_rain": "도토리 비",
	"spore_clouds": "포자 구름", "jump_slam": "뛰어올라 내려찍기",
	"burrow": "땅속 기습", "paint_spit": "물감 침 뱉기",
}

const RANK := {"mid": "중간 보스", "boss": "대장", "field": "필드 보스"}


static func of(kind: String) -> Dictionary:
	return BOSSES.get(kind, {})
