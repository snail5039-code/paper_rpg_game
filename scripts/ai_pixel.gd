extends Node
## 내가 그린 그림을 AI 에게 보내 도트 아이콘으로 다시 그려 받는다 (선택 기능).
## OpenAI 키가 있을 때만 쓴다. 키가 없거나 실패하면 게임이 직접 도트로 바꾼 그림을 그대로 쓴다.
##
## 키를 넣는 곳 (둘 중 하나):
##   - 환경 변수 OPENAI_API_KEY
##   - user://openai_key.txt 파일 (키 한 줄)
## 키는 저장 파일이나 깃에 들어가지 않는다.

signal finished(img: Image)   ## 실패하면 null

const URL := "https://api.openai.com/v1/images/edits"
const MODEL := "gpt-image-1"
const KEY_FILE := "user://openai_key.txt"
const TIMEOUT := 60.0

static var enabled := true     # 테스트에서는 끈다


static func api_key() -> String:
	if not enabled:
		return ""
	var k := OS.get_environment("OPENAI_API_KEY").strip_edges()
	if k == "" and FileAccess.file_exists(KEY_FILE):
		k = FileAccess.get_file_as_string(KEY_FILE).strip_edges()
	return k


## sketch: 게임이 만든 도트 그림 (32 × 32). what: 무엇을 그렸는지 (아이템 이름).
func request(sketch: Image, what: String) -> void:
	var key := api_key()
	if key == "":
		finished.emit.call_deferred(null)
		return
	# 흰 바탕 512 × 512 로 키워 보낸다
	var big := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	big.fill(Color.WHITE)
	var up: Image = sketch.duplicate()
	up.resize(512, 512, Image.INTERPOLATE_NEAREST)
	big.blend_rect(up, Rect2i(0, 0, 512, 512), Vector2i.ZERO)
	var prompt := ("Redraw this child's rough sketch as one clean pixel art game item icon of: %s. "
		+ "Keep the same overall shape and pose as the sketch. Chunky visible pixels, thick dark pencil outline, "
		+ "soft crayon pastel colours, centred, transparent background, no text, no shadow.") % what
	var boundary := "----paperrpg%d" % randi()
	var body := PackedByteArray()
	for pair in [["model", MODEL], ["prompt", prompt], ["size", "1024x1024"], ["quality", "low"], ["background", "transparent"], ["n", "1"]]:
		body.append_array(("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n" % [boundary, pair[0], pair[1]]).to_utf8_buffer())
	body.append_array(("--%s\r\nContent-Disposition: form-data; name=\"image\"; filename=\"sketch.png\"\r\nContent-Type: image/png\r\n\r\n" % boundary).to_utf8_buffer())
	body.append_array(big.save_png_to_buffer())
	body.append_array(("\r\n--%s--\r\n" % boundary).to_utf8_buffer())
	var http := HTTPRequest.new()
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	http.timeout = TIMEOUT
	add_child(http)
	http.request_completed.connect(_on_done.bind(http))
	var err := http.request_raw(URL, ["Authorization: Bearer " + key, "Content-Type: multipart/form-data; boundary=" + boundary],
		HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		finished.emit.call_deferred(null)


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		push_warning("AI 도트 변환 실패 (결과 %d, 응답 %d)" % [result, code])
		finished.emit(null)
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	var img := Image.new()
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("data")) != TYPE_ARRAY or (data["data"] as Array).is_empty() \
			or img.load_png_from_buffer(Marshalls.base64_to_raw(str(data["data"][0].get("b64_json", "")))) != OK:
		finished.emit(null)
		return
	finished.emit(to_icon(img))


## 받은 큰 그림을 도트 아이콘 크기(32 × 32)로 줄인다: 그림이 있는 곳만 잘라 가운데에 놓는다
static func to_icon(img: Image) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		img = img.get_region(used)
	var s := 30.0 / maxi(img.get_width(), img.get_height())
	var w := maxi(1, roundi(img.get_width() * s))
	var h := maxi(1, roundi(img.get_height() * s))
	img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var out := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(img, Rect2i(0, 0, w, h), Vector2i((32 - w) / 2, (32 - h) / 2))
	# 반투명 가장자리를 없애 도트답게 만든다
	for y in 32:
		for x in 32:
			var c := out.get_pixel(x, y)
			c.a = 1.0 if c.a > 0.5 else 0.0
			out.set_pixel(x, y, c)
	return out
