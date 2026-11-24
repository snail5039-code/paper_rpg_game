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
var boss_loop: AudioStreamWAV


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
	# 몬스터에게 맞았을 때: 효과 그림 종류마다 다른 소리 (어느 그림이 어느 소리인지는 mon_fx_data.gd SOUND).
	# 몬스터마다 음높이를 달리 해서 틀어 준다.
	var hits := {
		"splat": [[[320.0, 120.0, 0.06], [170.0, 90.0, 0.13]], 0.5, 0.6],         # 철퍽 (끈적이·물감·먹물)
		"splash": [[[1300.0, 500.0, 0.08], [900.0, 300.0, 0.2]], 0.85, 0.5],      # 촤악 (물·빗방울)
		"crunch": [[[900.0, 700.0, 0.03], [1150.0, 800.0, 0.03], [700.0, 500.0, 0.04], [1000.0, 600.0, 0.06]], 0.8, 0.55],  # 와작 (부스러기)
		"clang": [[[1650.0, 1600.0, 0.04], [1250.0, 1230.0, 0.28]], 0.08, 0.45],  # 쨍 (쇠붙이)
		"glass": [[[2700.0, 2500.0, 0.035], [3300.0, 3000.0, 0.04], [2300.0, 2100.0, 0.14]], 0.35, 0.4],  # 쨍그랑 (유리·거울)
		"pop": [[[220.0, 950.0, 0.03], [950.0, 300.0, 0.07]], 0.2, 0.6],          # 펑 (풍선·팝콘)
		"slash": [[[1500.0, 300.0, 0.15]], 0.7, 0.5],                             # 쉭 (베기·긁기)
		"paper": [[[700.0, 500.0, 0.05], [950.0, 600.0, 0.05], [600.0, 400.0, 0.09]], 0.9, 0.5],  # 바스락 (종이)
		"puff": [[[320.0, 200.0, 0.22]], 0.95, 0.45],                             # 푹 (먼지·깃털·안개)
		"zap": [[[1900.0, 600.0, 0.07], [1800.0, 500.0, 0.08]], 0.15, 0.45],      # 찌릿 (불빛·찌르기)
		"chime": [[[1320.0, 1320.0, 0.06], [1760.0, 1760.0, 0.16]], 0.0, 0.4],    # 띵 (반짝이·점·표시)
		"thud": [[[150.0, 60.0, 0.15]], 0.45, 0.7],                               # 쿵 (도장·실내화)
		"snap": [[[2100.0, 1200.0, 0.025], [420.0, 200.0, 0.07]], 0.5, 0.55],     # 딱 (집게·괄호·거미줄)
		"storm": [[[130.0, 50.0, 0.45], [420.0, 100.0, 0.22]], 0.7, 0.75],        # 우르릉 (낙서 폭풍)
	}
	for k in hits:
		_sfx["hit_" + k] = _tone(hits[k][0], float(hits[k][1]), float(hits[k][2]))
	# 몬스터가 달려들 때: 공격 방식마다 (1장 기본 6종과 보스는 위의 mon_* 를 쓴다)
	var lunges := {
		"hop": [[[180.0, 520.0, 0.1], [520.0, 240.0, 0.08]], 0.05],              # 통 (뛰어오르기)
		"dash": [[[380.0, 1100.0, 0.16]], 0.85],                                  # 휙 (돌진)
		"swarm": [[[220.0, 250.0, 0.04], [250.0, 220.0, 0.04], [230.0, 260.0, 0.04], [260.0, 230.0, 0.04]], 0.35],  # 붕붕 (떼)
		"ambush": [[[300.0, 700.0, 0.06], [950.0, 300.0, 0.1]], 0.6],            # 확 (숨었다 덮치기)
		"grid": [[[1500.0, 1400.0, 0.025], [900.0, 900.0, 0.025], [1500.0, 1400.0, 0.025], [900.0, 900.0, 0.03]], 0.3],  # 타닥 (칸 따라 걷기)
		"roll": [[[160.0, 110.0, 0.26]], 0.6],                                    # 데구르 (구르기)
	}
	for k in lunges:
		_sfx["lunge_" + k] = _tone(lunges[k][0], float(lunges[k][1]), 0.5)
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
	# 보스: 나타날 때 낮은 나팔 소리, 가까이 있을 때 으르렁
	_sfx["boss_appear"] = _tone([[110.0, 110.0, 0.35], [147.0, 147.0, 0.35], [131.0, 98.0, 0.7]], 0.15, 0.8)
	_sfx["boss_roar"] = _tone([[160.0, 90.0, 0.45], [120.0, 60.0, 0.35]], 0.55, 0.7)
	# 강화소: 망치질, 성공, 실패(단계 하락), 파괴, 코팅지가 막음
	_sfx["forge_hit"] = _tone([[1800.0, 900.0, 0.05], [300.0, 200.0, 0.08]], 0.55, 0.6)
	_sfx["forge_ok"] = _tone([[784.0, 784.0, 0.08], [988.0, 988.0, 0.08], [1319.0, 1319.0, 0.1], [1568.0, 1568.0, 0.3]], 0.0, 0.6)
	_sfx["forge_down"] = _tone([[500.0, 300.0, 0.2], [300.0, 180.0, 0.3]], 0.15, 0.5)
	_sfx["forge_break"] = _tone([[900.0, 120.0, 0.5]], 0.8, 0.7)
	_sfx["forge_saved"] = _tone([[600.0, 600.0, 0.08], [400.0, 600.0, 0.2]], 0.1, 0.5)
	boss_loop = _rumble()
	_sfx["capture"] = _tone([[587.0, 587.0, 0.1], [740.0, 740.0, 0.1], [880.0, 880.0, 0.1], [1175.0, 1175.0, 0.25]], 0.0, 0.45)
	for i in 8:
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


## 보스 곁에서 계속 들리는 낮은 울림 (되풀이). 보스에 AudioStreamPlayer2D 로 붙여서 가까울수록 크게 들린다.
func _rumble() -> AudioStreamWAV:
	var secs := 2.0
	var total := int(secs * RATE)
	var data := PackedByteArray()
	data.resize(total * 2)
	var smooth := 0.0
	for i in total:
		var t := float(i) / RATE
		# 낮은 두 음 + 걸러 낸 잡음, 1초마다 숨 쉬듯 커졌다 작아진다 (끝과 처음이 이어지게 정수 주기)
		smooth = lerpf(smooth, randf_range(-1.0, 1.0), 0.04)
		var breath := 0.6 + 0.4 * sin(TAU * t / 1.0)
		var s := (sin(TAU * 55.0 * t) * 0.5 + sin(TAU * 82.5 * t) * 0.3 + smooth * 0.9) * breath * 0.55
		var v := clampi(int(s * 32767.0), -32768, 32767)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = total
	w.data = data
	return w


## 보스에 붙이는 울림: 가까울수록 크고, max_distance 밖에서는 들리지 않는다
func attach_boss_loop(boss: Node2D, reach: float = 260.0) -> AudioStreamPlayer2D:
	var p := AudioStreamPlayer2D.new()
	p.name = "BossRumble"
	p.stream = boss_loop
	p.bus = "Sfx"
	p.max_distance = reach
	p.attenuation = 1.4
	p.volume_db = -2.0
	boss.add_child(p)
	p.play()
	return p


func has(id: String) -> bool:
	return _sfx.has(id)


## pitch: 음높이 배율 (몬스터마다 다르게), vol_db: 크기 더하기
func play(id: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not _sfx.has(id):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sfx[id]
	p.pitch_scale = pitch
	p.volume_db = vol_db
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
