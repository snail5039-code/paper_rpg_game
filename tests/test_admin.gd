extends Node
## 관리자 창(F10) 테스트 + 캡처.
## 실행: godot --headless --path . res://tests/test_admin.tscn
##       godot --path . res://tests/test_admin.tscn -- <캡처 폴더>

var passed := 0
var failed := 0
var _dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(ok: bool, text: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("  %s  %s" % ["PASS" if ok else "FAIL", text])


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func key(code: int) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = down
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await frames(2)


func buttons(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Button:
			out.append(c)
		buttons(c, out)


func press(text: String) -> bool:
	var all := []
	buttons(get_tree().root.get_node("AdminPanel"), all)
	for b in all:
		if (b as Button).text.contains(text):
			(b as Button).pressed.emit()
			return true
	return false


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else ""
	GameState.save_path = "user://test_admin_save.json"
	GameState.level = 1
	GameState.coins = 0
	print("[관리자 창]")
	check(get_tree().root.get_node_or_null("AdminPanel") == null, "처음엔 닫혀 있음")
	await key(KEY_F10)
	var p := get_tree().root.get_node_or_null("AdminPanel")
	check(p != null, "F10 으로 열림")
	check(get_tree().paused, "열려 있는 동안 게임이 멈춤")
	await frames(3)
	if _dir != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_dir.path_join("admin.png"))
	var maps := []
	buttons(p, maps)
	check(maps.filter(func(b): return (b as Button).text.contains("큰나무 뿌리")).size() == 1, "맵 목록에 2장 대장 방이 있음")
	check(maps.filter(func(b): return (b as Button).text.contains("연습 13장")).size() == 1, "맵 목록에 연습 페이지가 있음")
	var lv := GameState.level
	check(press("레벨 +5"), "레벨 단추가 있음")
	check(GameState.level == lv + 5, "레벨 +5")
	var c := GameState.coins
	press("동전 +10000")
	check(GameState.coins == c + 10000, "동전 +10000")
	press("무적")
	check(GameState.god_mode, "무적이 켜짐")
	GameState.god_mode = false
	var s2 := GameState.ch2_step
	var steps := []
	buttons(p, steps)
	var plus := steps.filter(func(b): return (b as Button).text == "+")
	(plus[1] as Button).pressed.emit()
	check(GameState.ch2_step == s2 + 1, "2장 단계를 올림")
	press("2장 길 열기")
	check(int(GameState.bosses_beaten.get("boss_crumple", 0)) >= 1, "2장 길이 열림")
	await key(KEY_F10)
	check(get_tree().root.get_node_or_null("AdminPanel") == null, "F10 으로 다시 닫힘")
	await frames(2)
	check(not get_tree().paused, "닫으면 게임이 다시 움직임")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	print("\n결과: %d 통과 / %d 실패" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
