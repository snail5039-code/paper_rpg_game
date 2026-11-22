extends Node
## 소리 (autoload "Sound"). 효과음과 배경음을 코드로 만들어 낸다 (임시: AI 로 만든 소리가 오면 파일로 바꾼다).
##   Sound.play("hit")   효과음: swing, hit, hurt, pickup, levelup, click, craft, capture, fail
##   Sound.music(true)   배경음 켜기 / 끄기
## 크기는 설정(GameState.settings)의 전체·배경음·효과음을 따른다.

const RATE := 22050

var _sfx: Dictionary = {}
var _players: Array = []
var _next := 0
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "Sfx"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	# 효과음: [시작 음높이(Hz), 끝 음높이, 길이(초), 소음 섞는 정도, 크기]
	var defs := {
		"swing": [520.0, 260.0, 0.09, 0.5, 0.35], "hit": [220.0, 90.0, 0.11, 0.6, 0.55], "hurt": [180.0, 70.0, 0.22, 0.3, 0.6],
		"pickup": [660.0, 990.0, 0.1, 0.0, 0.4], "click": [880.0, 700.0, 0.04, 0.1, 0.3], "fail": [300.0, 150.0, 0.3, 0.1, 0.45],
	}
	for k in defs:
		var d: Array = defs[k]
		_sfx[k] = _tone([[d[0], d[1], d[2]]], d[3], d[4])
	_sfx["levelup"] = _tone([[523.0, 523.0, 0.1], [659.0, 659.0, 0.1], [784.0, 784.0, 0.1], [1047.0, 1047.0, 0.16],
		[1319.0, 1319.0, 0.16], [1568.0, 1568.0, 0.4]], 0.0, 0.85)
	# 스킬: 긋기, 동그라미, 점, 빗금, 눌러 쓰기, 지우기, 필살기
	var skills := {
		"sk_slash": [[900.0, 300.0, 0.16]], "sk_circle": [[400.0, 800.0, 0.1], [800.0, 400.0, 0.12]],
		"sk_dot": [[1200.0, 1500.0, 0.05], [700.0, 500.0, 0.06]],
		"sk_hatch": [[800.0, 600.0, 0.04], [850.0, 650.0, 0.04], [900.0, 700.0, 0.04], [950.0, 750.0, 0.04], [1000.0, 800.0, 0.05]],
		"sk_press": [[160.0, 60.0, 0.28]], "sk_erase": [[500.0, 900.0, 0.2]],
		"sk_ult": [[300.0, 1200.0, 0.25], [1200.0, 200.0, 0.35]],
	}
	var skill_noise := {"sk_slash": 0.45, "sk_circle": 0.35, "sk_dot": 0.1, "sk_hatch": 0.4, "sk_press": 0.55, "sk_erase": 0.6, "sk_ult": 0.3}
	for k in skills:
		_sfx[k] = _tone(skills[k], float(skill_noise[k]), 0.5)
	# 몬스터가 달려들 때: 종마다 다른 소리 (말랑, 삐뚤선, 점박이, 풀낙서, 거미, 벌레, 보스)
	var mons := {
		"mon_slime": [[[180.0, 420.0, 0.1], [420.0, 200.0, 0.08]], 0.05], "mon_squiggle": [[[700.0, 350.0, 0.07], [600.0, 300.0, 0.07]], 0.35],
		"mon_dots": [[[1000.0, 1000.0, 0.03], [1300.0, 1300.0, 0.03], [1600.0, 1600.0, 0.04]], 0.0],
		"mon_grass": [[[500.0, 800.0, 0.12]], 0.7], "mon_spider": [[[1500.0, 900.0, 0.05], [1400.0, 800.0, 0.05]], 0.25],
		"mon_bug": [[[240.0, 260.0, 0.05], [250.0, 230.0, 0.05], [240.0, 260.0, 0.05]], 0.5],
		"mon_boss": [[[140.0, 70.0, 0.3]], 0.4], "slam": [[[110.0, 40.0, 0.4]], 0.65],
	}
	for k in mons:
		_sfx[k] = _tone(mons[k][0], float(mons[k][1]), 0.5)
	_sfx["stamp"] = _tone([[150.0, 70.0, 0.12], [900.0, 1400.0, 0.14]], 0.35, 0.7)
	# 생활: 찌 던지기, 입질, 낚아 올리기, 땅 긁기, 물 주기, 풀 베기
	var life := {
		"cast": [[[500.0, 1100.0, 0.18]], 0.5], "plop": [[[300.0, 120.0, 0.1]], 0.3], "bite": [[[1300.0, 1300.0, 0.06], [1700.0, 1700.0, 0.1]], 0.0],
		"reel": [[[600.0, 900.0, 0.12], [900.0, 1300.0, 0.14]], 0.1], "dig": [[[200.0, 120.0, 0.12]], 0.75],
		"water": [[[900.0, 600.0, 0.25]], 0.85], "cut": [[[1100.0, 500.0, 0.09]], 0.6],
	}
	for k in life:
		_sfx[k] = _tone(life[k][0], float(life[k][1]), 0.45)
	_sfx["craft"] = _tone([[659.0, 659.0, 0.08], [880.0, 880.0, 0.16]], 0.0, 0.4)
	_sfx["capture"] = _tone([[587.0, 587.0, 0.1], [740.0, 740.0, 0.1], [880.0, 880.0, 0.1], [1175.0, 1175.0, 0.25]], 0.0, 0.45)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "Sfx"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.stream = _melody()
	_music.volume_db = -14.0
	add_child(_music)
	apply_settings()


## 음 여러 개를 이어 붙인 짧은 소리. notes: [[시작 Hz, 끝 Hz, 초], ...]
func _tone(notes: Array, noise: float, volume: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	var phase := 0.0
	for n in notes:
		var count := int(float(n[2]) * RATE)
		for i in count:
			var t := float(i) / count
			phase += TAU * lerpf(float(n[0]), float(n[1]), t) / RATE
			var env := minf(1.0, t * 30.0) * pow(1.0 - t, 1.5)
			var s := (sin(phase) * (1.0 - noise) + randf_range(-1.0, 1.0) * noise) * env * volume
			var v := clampi(int(s * 32767.0), -32768, 32767)
			data.append(v & 0xFF)
			data.append((v >> 8) & 0xFF)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w


## 배경음: 오르골 같은 느린 가락 한 바퀴 (16박, 되풀이)
func _melody() -> AudioStreamWAV:
	var scale := [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5]
	var tune := [0, 2, 3, 2, 4, 3, 2, 0, 1, 2, 4, 5, 4, 3, 2, 1]
	var beat := 0.5
	var total := int(tune.size() * beat * RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	for b in tune.size():
		for voice in [[float(scale[tune[b]]), 0.22], [float(scale[tune[b]]) * 0.5, 0.12]]:
			var freq: float = voice[0]
			var len := int(beat * 2.2 * RATE)
			for i in len:
				var idx := (int(b * beat * RATE) + i) % total
				var t := float(i) / RATE
				buf[idx] += sin(TAU * freq * t) * exp(-t * 3.0) * float(voice[1])
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		var v := clampi(int(buf[i] * 32767.0), -32768, 32767)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = total
	w.data = data
	return w


func play(id: String) -> void:
	if not _sfx.has(id):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sfx[id]
	p.play()


func music(on: bool) -> void:
	if on and not _music.playing:
		_music.play()
	elif not on:
		_music.stop()


## 설정의 소리 크기(0~1)와 전체 화면을 적용한다
func apply_settings() -> void:
	var s: Dictionary = GameState.settings
	for pair in [["Master", "master"], ["Music", "music"], ["Sfx", "sfx"]]:
		var idx := AudioServer.get_bus_index(str(pair[0]))
		var v := clampf(float(s.get(str(pair[1]), 0.8)), 0.0, 1.0)
		AudioServer.set_bus_mute(idx, v <= 0.001)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))
	if DisplayServer.get_name() != "headless":
		var full := bool(s.get("fullscreen", false))
		var mode := DisplayServer.window_get_mode()
		if full and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif not full and mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
