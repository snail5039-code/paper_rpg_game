extends RefCounted
## 몬스터마다 다른 공격 효과 (scripts/actors/enemy_slime.gd 가 쓴다. 그림: docs/도트_프롬프트_stage1.md §88~89).
## 박치기가 맞으면 맞힘 별과 함께 그 몬스터의 효과가 터진다. 박치기를 시작할 때의 먼지·속도선은 공격 방식(arch)을 따른다.
## 키: 몬스터 종(kind 의 "_" 앞부분, 예: "m21") 또는 kind 그대로 (보스).
## 값: [효과 그림, 색 (그림 색을 그대로 쓰면 흰색), 크기 배율]. 본편 몬스터는 모두 자기 전용 그림을 쓴다 (연습 페이지 몬스터만 색을 바꿔 같이 쓴다).

const W := Color.WHITE

const HIT := {
	# 1장
	"slime": ["fx_hit_goo", W, 1.0], "squiggle": ["fx_mon_scribble", W, 0.9], "dots": ["fx_hit_dotspray", W, 0.9],
	"grass": ["fx_hit_blades", W, 1.0], "spider": ["fx_hit_web", W, 1.0], "bug": ["fx_mon_dust", W, 1.0],
	"m07": ["fx_hit_lead", W, 1.0], "m08": ["fx_hit_sticky", W, 1.0], "m09": ["fx_mon_claw", W, 1.0],
	"m10": ["fx_hit_band", W, 1.0],
	# 2장
	"m11": ["fx_hit_acorn", W, 0.9], "m12": ["fx_hit_shavings", W, 1.0], "m13": ["fx_hit_thorn", W, 1.1],
	"m14": ["fx_hit_spore", W, 1.0], "m15": ["fx_hit_spiral", W, 0.9], "m16": ["fx_hit_feather", W, 1.1],
	"m17": ["fx_hit_crayon", W, 1.0], "m18": ["fx_hit_petal", W, 1.1], "m19": ["fx_hit_chips", W, 1.0],
	"m20": ["fx_hit_moss", W, 1.1],
	# 3장
	"m21": ["fx_hit_lily", W, 1.0], "m22": ["fx_hit_paint", W, 1.0], "m23": ["fx_hit_pincer", W, 1.0],
	"m24": ["fx_hit_squid", W, 1.1], "m25": ["fx_hit_zap", W, 1.0], "m26": ["fx_hit_bubble", W, 1.0],
	"m27": ["fx_hit_rainbow", W, 1.1], "m28": ["fx_hit_palette", W, 1.1], "m29": ["fx_hit_wash", W, 1.0],
	"m30": ["fx_hit_water", W, 0.9],
	# 4장
	"m31": ["fx_hit_clang", W, 1.0], "m32": ["fx_hit_smear", W, 1.1], "m33": ["fx_hit_ruler", W, 1.0],
	"m34": ["fx_hit_glow", W, 0.9], "m35": ["fx_hit_tack", W, 1.0], "m36": ["fx_hit_clip", W, 0.9],
	"m37": ["fx_hit_signal", W, 1.1], "m38": ["fx_hit_rail", W, 1.0], "m39": ["fx_hit_marker", W, 1.0],
	"m40": ["fx_hit_rain", W, 1.1],
	# 5장
	"m41": ["fx_hit_pop", W, 1.0], "m42": ["fx_hit_horseshoe", W, 1.0], "m43": ["fx_hit_ticket", W, 1.0],
	"m44": ["fx_hit_candy", W, 1.1], "m45": ["fx_hit_cymbal", W, 1.1], "m46": ["fx_hit_bulb", W, 0.9],
	"m47": ["fx_hit_confetti", W, 1.1], "m48": ["fx_hit_popcorn", W, 1.1], "m49": ["fx_hit_capsule", W, 1.0],
	"m50": ["fx_hit_mirror", W, 1.0],
	# 6장
	"m51": ["fx_hit_strike", W, 1.0], "m52": ["fx_hit_hooks", W, 1.0], "m53": ["fx_hit_ink", W, 1.2],
	"m54": ["fx_hit_stamp", W, 1.0], "m55": ["fx_hit_marks", W, 1.0], "m56": ["fx_hit_ellipsis", W, 0.8],
	"m57": ["fx_hit_spacebar", W, 1.0], "m58": ["fx_hit_underline", W, 1.0], "m59": ["fx_hit_bang", W, 1.1],
	"m60": ["fx_hit_bracket", W, 1.0],
	# 7장
	"m61": ["fx_hit_paper", W, 1.1], "m62": ["fx_hit_tape", W, 1.0], "m63": ["fx_hit_lint", W, 0.9],
	"m64": ["fx_hit_staple", W, 1.1], "m65": ["fx_hit_bite", W, 0.9], "m66": ["fx_hit_crane", W, 1.0],
	"m67": ["fx_hit_corner", W, 1.0], "m68": ["fx_hit_glue", W, 1.0], "m69": ["fx_hit_ribbon", W, 1.0],
	"m70": ["fx_hit_bunny", W, 1.0],
	# 8장
	"m71": ["fx_hit_chalk", W, 1.0], "m72": ["fx_hit_crumbs", W, 0.9], "m73": ["fx_hit_clap", W, 1.2],
	"m74": ["fx_hit_scrape", W, 1.0], "m75": ["fx_hit_broken", W, 1.1], "m76": ["fx_hit_crow", W, 1.0],
	"m77": ["fx_hit_slipper", W, 0.9], "m78": ["fx_hit_clock", W, 1.0], "m79": ["fx_hit_grade", W, 1.1],
	"m80": ["fx_hit_note", W, 1.0],
	# 9장
	"m81": ["fx_hit_fade", W, 1.1], "m82": ["fx_hit_sting", W, 1.0], "m83": ["fx_hit_whiteclaw", W, 1.2],
	"m84": ["fx_hit_balloon", W, 1.1], "m85": ["fx_hit_spout", W, 1.3], "m86": ["fx_hit_dotwing", W, 0.9],
	"m87": ["fx_hit_pierce", W, 1.1], "m88": ["fx_hit_paperslash", W, 1.2], "m89": ["fx_hit_fog", W, 1.2],
	"m90": ["fx_hit_rainbowscribble", W, 1.3],
	# 연습 페이지
	"tm1": ["fx_mon_dust", W, 0.9], "tm2": ["fx_hit_typo", W, 0.9], "tm3": ["fx_hit_tack", W, 0.9],
	"tm4": ["fx_hit_sticky", W, 0.9], "tm6": ["fx_hit_question", W, 1.0], "tm7": ["fx_hit_stub", W, 0.9],
	"tm8": ["fx_hit_strand", W, 0.9], "tm9": ["fx_mon_scribble", W, 0.9], "tm10": ["fx_hit_paint", Color(0.6, 0.8, 1.0), 0.9],
	"tm11": ["fx_hit_paper", W, 0.9], "tm12": ["fx_hit_lead", W, 0.9], "tm13": ["fx_hit_cross", W, 1.2],
	"tmcheck": ["fx_hit_check", W, 0.8],
	# 보스
	"boss_bug": ["fx_hit_eraserbig", W, 1.4], "boss_crumple": ["fx_hit_crumple", W, 1.4], "boss_scribble": ["fx_hit_storm", W, 1.4],
}


## 그 몬스터의 맞힘 효과 [그림, 색, 크기 배율]. 표에 없으면 낙서 뭉치.
static func hit_of(kind: String) -> Array:
	if HIT.has(kind):
		return HIT[kind]
	var sp := kind.split("_")[0]
	return HIT.get(sp, ["fx_mon_scribble", W, 1.0])
