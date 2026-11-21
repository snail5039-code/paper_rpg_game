extends RefCounted
## 설계도 판정기.
## 그림 실력이 아니라 "안내선을 얼마나 따라 그렸는가"로만 판정한다.
##  - coverage : 안내선 샘플점 중 플레이어 선이 근처(tolerance)를 지나간 비율
##  - accuracy : 플레이어가 그린 점 중 안내선 근처에 있는 비율 (마구 칠하기 방지)

const SAMPLE_STEP := 4.0


static func evaluate(guides: Array, strokes: Array, tolerance: float = 8.0,
		min_coverage: float = 0.8, min_accuracy: float = 0.6) -> Dictionary:
	var guide_samples := PackedVector2Array()
	for g in guides:
		guide_samples.append_array(_resample(g, SAMPLE_STEP))

	var stroke_points := PackedVector2Array()
	for s in strokes:
		stroke_points.append_array(_resample(s, SAMPLE_STEP))  # 꼭짓점만 보면 긴 직선 낙서를 못 잡는다

	if stroke_points.is_empty():
		return _result(false, 0.0, 0.0, "아직 아무것도 그리지 않았어요.")
	if guide_samples.is_empty():
		return _result(false, 0.0, 0.0, "설계도가 없어요.")

	var covered := 0
	for p in guide_samples:
		if _min_dist_to_polylines(p, strokes) <= tolerance:
			covered += 1

	var accurate := 0
	for p in stroke_points:
		if _min_dist_to_polylines(p, guides) <= tolerance:
			accurate += 1

	var coverage := float(covered) / guide_samples.size()
	var accuracy := float(accurate) / stroke_points.size()
	var ok := coverage >= min_coverage and accuracy >= min_accuracy

	var reason := ""
	if ok:
		reason = "설계도 완성! (따라 그리기 %d%%, 정확도 %d%%)" % [roundi(coverage * 100), roundi(accuracy * 100)]
	elif coverage < min_coverage:
		reason = "점선을 끝까지 따라 그려 주세요. (따라 그리기 %d%% / 필요 %d%%)" % [roundi(coverage * 100), roundi(min_coverage * 100)]
	else:
		reason = "점선 밖에 그린 선이 너무 많아요. (정확도 %d%% / 필요 %d%%)" % [roundi(accuracy * 100), roundi(min_accuracy * 100)]
	return _result(ok, coverage, accuracy, reason)


static func _result(ok: bool, coverage: float, accuracy: float, reason: String) -> Dictionary:
	return {"success": ok, "coverage": coverage, "accuracy": accuracy, "reason": reason}


static func _resample(line: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if line.size() == 1:
		out.append(line[0])
		return out
	for i in range(line.size() - 1):
		var a := line[i]
		var b := line[i + 1]
		var n := maxi(1, ceili(a.distance_to(b) / step))
		for k in n:
			out.append(a.lerp(b, float(k) / n))
	if line.size() > 0:
		out.append(line[line.size() - 1])
	return out


static func _min_dist_to_polylines(p: Vector2, lines: Array) -> float:
	var best := INF
	for line in lines:
		var pl: PackedVector2Array = line
		if pl.size() == 1:
			best = minf(best, p.distance_to(pl[0]))
			continue
		for i in range(pl.size() - 1):
			var q := Geometry2D.get_closest_point_to_segment(p, pl[i], pl[i + 1])
			best = minf(best, p.distance_to(q))
	return best
