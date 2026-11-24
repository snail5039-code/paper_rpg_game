extends RefCounted
## 몬스터마다 다른 공격 효과 (scripts/actors/enemy_slime.gd 가 쓴다. 그림: docs/도트_프롬프트_stage1.md §88~89).
## 박치기가 맞으면 맞힘 별과 함께 그 몬스터의 효과가 터진다. 박치기를 시작할 때의 먼지·속도선은 공격 방식(arch)을 따른다.
## 키: 몬스터 종(kind 의 "_" 앞부분, 예: "m21") 또는 kind 그대로 (보스).
## 값: [효과 그림, 색 (그림 색을 그대로 쓰면 흰색), 크기 배율]

const W := Color.WHITE

const HIT := {
	# 1장 기본
	"slime": ["fx_hit_paint", W, 1.0], "squiggle": ["fx_mon_scribble", W, 0.9], "dots": ["fx_hit_ink", W, 0.9],
	"grass": ["fx_hit_petal", W, 1.0], "spider": ["fx_mon_claw", W, 1.0], "bug": ["fx_mon_dust", W, 1.0],
	"m07": ["fx_hit_lead", W, 1.0], "m08": ["fx_hit_sticky", W, 1.0], "m09": ["fx_mon_claw", Color(0.75, 0.75, 0.85), 1.0],
	"m10": ["fx_hit_band", W, 1.0],
	# 2장 색연필 숲
	"m11": ["fx_hit_petal", Color(0.8, 0.75, 0.7), 0.9], "m12": ["fx_hit_shavings", W, 1.0], "m13": ["fx_hit_thorn", W, 1.1],
	"m14": ["fx_hit_spore", W, 1.0], "m15": ["fx_hit_bubble", Color(0.95, 0.85, 0.6), 0.9], "m16": ["fx_hit_shavings", Color(0.9, 0.8, 1.0), 1.1],
	"m17": ["fx_hit_crayon", W, 1.0], "m18": ["fx_hit_petal", W, 1.1], "m19": ["fx_hit_lead", Color(1.0, 0.7, 0.6), 1.0],
	"m20": ["fx_hit_spore", Color(0.6, 0.95, 0.55), 1.1],
	# 3장 물감 호수
	"m21": ["fx_hit_water", Color(0.7, 1.0, 0.7), 1.0], "m22": ["fx_hit_paint", W, 1.0], "m23": ["fx_hit_paint", Color(1.0, 0.65, 0.45), 1.0],
	"m24": ["fx_hit_ink", W, 1.1], "m25": ["fx_hit_zap", Color(0.7, 0.9, 1.0), 1.0], "m26": ["fx_hit_bubble", W, 1.0],
	"m27": ["fx_hit_paint", Color(0.6, 1.0, 0.6), 1.1], "m28": ["fx_hit_crayon", W, 1.1], "m29": ["fx_hit_paint", Color(0.6, 0.75, 1.0), 1.0],
	"m30": ["fx_hit_water", W, 0.9],
	# 4장 도시
	"m31": ["fx_hit_clip", W, 1.0], "m32": ["fx_hit_paint", Color(0.55, 0.5, 0.5), 1.1], "m33": ["fx_hit_clip", Color(1.0, 0.95, 0.7), 1.0],
	"m34": ["fx_hit_zap", Color(0.75, 1.0, 0.5), 0.9], "m35": ["fx_hit_tack", W, 1.0], "m36": ["fx_hit_clip", Color(0.8, 0.8, 0.95), 0.9],
	"m37": ["fx_hit_zap", W, 1.1], "m38": ["fx_hit_zap", Color(1.0, 0.75, 0.55), 1.0], "m39": ["fx_hit_ink", Color(0.65, 0.8, 1.0), 1.0],
	"m40": ["fx_hit_water", Color(0.8, 0.8, 1.0), 1.1],
	# 5장 놀이공원
	"m41": ["fx_hit_confetti", Color(0.6, 0.6, 0.7), 1.0], "m42": ["fx_hit_note", W, 1.0], "m43": ["fx_hit_sticky", Color(1.0, 0.9, 0.7), 1.0],
	"m44": ["fx_hit_spore", Color(1.0, 0.75, 0.9), 1.1], "m45": ["fx_hit_note", Color(1.0, 0.85, 0.5), 1.1], "m46": ["fx_hit_zap", Color(1.0, 0.95, 0.6), 0.9],
	"m47": ["fx_hit_confetti", W, 1.1], "m48": ["fx_hit_popcorn", W, 1.1], "m49": ["fx_hit_clip", Color(1.0, 0.7, 0.8), 1.0],
	"m50": ["fx_hit_confetti", Color(0.85, 0.9, 1.0), 1.0],
	# 6장 글자
	"m51": ["fx_hit_ink", Color(1.0, 0.6, 0.6), 1.0], "m52": ["fx_hit_marks", W, 1.0], "m53": ["fx_hit_ink", W, 1.2],
	"m54": ["fx_hit_stamp", W, 1.0], "m55": ["fx_hit_marks", Color(1.0, 0.85, 0.6), 1.0], "m56": ["fx_hit_ink", Color(0.8, 0.8, 0.8), 0.8],
	"m57": ["fx_hit_marks", Color(0.7, 0.95, 0.75), 1.0], "m58": ["fx_hit_ink", Color(0.6, 0.7, 1.0), 1.0], "m59": ["fx_hit_marks", Color(1.0, 0.65, 0.6), 1.1],
	"m60": ["fx_hit_marks", Color(0.75, 0.8, 1.0), 1.0],
	# 7장 종이
	"m61": ["fx_hit_paper", W, 1.1], "m62": ["fx_hit_tape", W, 1.0], "m63": ["fx_hit_paper", Color(0.95, 0.95, 1.0), 0.9],
	"m64": ["fx_hit_clip", W, 1.1], "m65": ["fx_hit_paper", Color(0.85, 0.85, 0.8), 0.9], "m66": ["fx_hit_paper", Color(1.0, 0.85, 0.85), 1.0],
	"m67": ["fx_hit_paper", Color(0.75, 0.75, 0.85), 1.0], "m68": ["fx_hit_tape", Color(0.9, 1.0, 0.85), 1.0], "m69": ["fx_hit_sticky", Color(0.9, 0.85, 1.0), 1.0],
	"m70": ["fx_mon_dust", W, 1.0],
	# 8장 학교
	"m71": ["fx_hit_chalk", W, 1.0], "m72": ["fx_hit_chalk", Color(1.0, 0.85, 0.85), 0.9], "m73": ["fx_hit_chalk", Color(0.8, 0.85, 0.8), 1.2],
	"m74": ["fx_hit_tack", Color(0.85, 0.75, 0.6), 1.0], "m75": ["fx_hit_crayon", Color(1.0, 0.85, 0.85), 1.1], "m76": ["fx_hit_stamp", Color(0.7, 0.7, 0.8), 1.0],
	"m77": ["fx_mon_dust", Color(0.9, 0.95, 1.0), 0.9], "m78": ["fx_hit_band", Color(0.8, 0.9, 1.0), 1.0], "m79": ["fx_hit_stamp", Color(1.0, 0.75, 0.7), 1.1],
	"m80": ["fx_hit_note", Color(0.75, 0.85, 1.0), 1.0],
	# 9장 빈 페이지
	"m81": ["fx_hit_fade", W, 1.1], "m82": ["fx_hit_water", Color(0.95, 0.95, 1.0), 1.0], "m83": ["fx_hit_fade", Color(0.85, 0.85, 0.9), 1.2],
	"m84": ["fx_hit_bubble", Color(0.95, 0.95, 0.95), 1.1], "m85": ["fx_hit_water", Color(0.85, 0.95, 1.0), 1.3], "m86": ["fx_hit_fade", Color(0.9, 0.85, 1.0), 0.9],
	"m87": ["fx_hit_lead", Color(0.85, 0.85, 0.9), 1.1], "m88": ["fx_hit_paper", Color(0.95, 0.95, 0.95), 1.2], "m89": ["fx_hit_spore", Color(0.92, 0.92, 0.95), 1.2],
	"m90": ["fx_mon_scribble", W, 1.3],
	# 연습 페이지
	"tm1": ["fx_mon_dust", W, 0.9], "tm2": ["fx_hit_marks", W, 0.9], "tm3": ["fx_hit_tack", W, 0.9], "tm4": ["fx_hit_sticky", W, 0.9],
	"tm6": ["fx_hit_marks", Color(1.0, 0.85, 0.6), 1.0], "tm7": ["fx_hit_shavings", W, 0.9], "tm8": ["fx_hit_tape", Color(0.85, 1.0, 0.8), 0.9],
	"tm9": ["fx_mon_scribble", W, 0.9], "tm10": ["fx_hit_paint", Color(0.6, 0.8, 1.0), 0.9], "tm11": ["fx_hit_paper", W, 0.9],
	"tm12": ["fx_hit_lead", W, 0.9], "tm13": ["fx_hit_ink", Color(1.0, 0.55, 0.55), 1.2], "tmcheck": ["fx_hit_stamp", W, 0.8],
	# 보스
	"boss_bug": ["fx_mon_dust", W, 1.4], "boss_crumple": ["fx_hit_paper", W, 1.4], "boss_scribble": ["fx_mon_scribble", W, 1.4],
}


## 그 몬스터의 맞힘 효과 [그림, 색, 크기 배율]. 표에 없으면 낙서 뭉치.
static func hit_of(kind: String) -> Array:
	if HIT.has(kind):
		return HIT[kind]
	var sp := kind.split("_")[0]
	return HIT.get(sp, ["fx_mon_scribble", W, 1.0])
