extends RefCounted
## 한국어 조사 고르기. 글 속의 "낙서 슬라임 을(를)" 같은 자리를 앞 글자의 받침에 맞춰 "낙서 슬라임을" 로 바꾼다.
## 앞 글자가 한글이나 숫자가 아니면 (예: 별표, 괄호) 원래 "을(를)" 을 그대로 둔다.

const PAIRS := {"은(는)": ["은", "는"], "을(를)": ["을", "를"], "이(가)": ["이", "가"], "와(과)": ["과", "와"], "(으)로": ["으로", "로"]}
# 숫자를 읽었을 때 받침이 있는지 (영 일 이 삼 사 오 육 칠 팔 구)
const DIGIT_BATCHIM := [true, true, false, true, false, false, true, true, true, false]
const DIGIT_RIEUL := [false, true, false, false, false, false, false, true, true, false]

static var _re: RegEx


static func fix(text: String) -> String:
	if text.find("(") < 0:
		return text
	if _re == null:
		_re = RegEx.create_from_string("(\\S) ?(은\\(는\\)|을\\(를\\)|이\\(가\\)|와\\(과\\)|\\(으\\)로)")
	var out := ""
	var at := 0
	for m in _re.search_all(text):
		out += text.substr(at, m.get_start() - at)
		var ch := m.get_string(1)
		var pair := m.get_string(2)
		var bat := _batchim(ch)   # -1 모름, 0 없음, 1 있음, 2 ㄹ 받침
		if bat < 0:
			out += m.get_string(0)
		else:
			var opts: Array = PAIRS[pair]
			var first := bat == 1 or (bat == 2 and pair != "(으)로")
			out += ch + str(opts[0] if first else opts[1])
		at = m.get_end()
	return out + text.substr(at)


## 앞 글자의 받침: -1 알 수 없음, 0 없음, 1 있음, 2 ㄹ 받침
static func _batchim(ch: String) -> int:
	var c := ch.unicode_at(0)
	if c >= 0xAC00 and c <= 0xD7A3:
		var jong := (c - 0xAC00) % 28
		return 0 if jong == 0 else (2 if jong == 8 else 1)
	if c >= 48 and c <= 57:
		var d := c - 48
		return 2 if DIGIT_RIEUL[d] else (1 if DIGIT_BATCHIM[d] else 0)
	return -1
