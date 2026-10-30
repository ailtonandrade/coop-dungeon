extends SceneTree
## Teste da voz sem rede: qualidade da codificação (1 byte por amostra), troca de taxa do
## microfone, quem fala com rádio velho vai para o barramento do rádio, volume e mudo só para
## mim, voz por distância ligada/desligada, e a detecção de voz abrindo e fechando.
## Rodar: godot --headless --path coop-dungeon -s tests/voice_test.gd

var _failed := false
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	var voice := root.get_node("Voice")
	var settings := root.get_node("Settings")
	var script: Script = voice.get_script()

	var worst := 0.0
	for i in 200:
		var x := sin(i * 0.37) * 0.8
		worst = maxf(worst, absf(script.roundtrip(x) - x))
	_check(worst < 0.03, "1 byte por amostra mantém a voz (erro máximo %.3f)" % worst)
	_check(absf(script.roundtrip(0.002)) < 0.005, "silêncio continua silêncio")

	# Microfone a 48 mil por segundo vira 16 mil, sem perder o volume.
	var stereo := PackedVector2Array()
	for i in 4800:
		var v := sin(TAU * 300.0 * i / 48000.0) * 0.5
		stereo.append(Vector2(v, v))
	var mix_ratio := AudioServer.get_mix_rate() / 16000.0
	var out: PackedFloat32Array = voice._resample(stereo)
	_check(absf(out.size() - 4800 / mix_ratio) <= 2, "troca de taxa: %d amostras" % out.size())
	var peak := 0.0
	for x in out:
		peak = maxf(peak, absf(x))
	_check(peak > 0.4 and peak <= 0.51, "volume preservado (pico %.2f)" % peak)

	# Pacote de alguém com rádio ligado: toca no barramento do rádio, com chiado de abertura.
	var packet := PackedByteArray()
	packet.resize(641)
	packet[0] = 1
	for i in 640:
		packet[i + 1] = script._mulaw_encode(sin(i * 0.2) * 0.3)
	voice._receive(42, packet)
	var speaker: Dictionary = voice._speakers[42]
	_check(speaker.player.bus == "VozRadio", "quem liga o rádio é ouvido no barramento do rádio")
	_check(speaker.buffer.size() > 640, "rádio abre com um chiado antes da fala")
	_check(voice.is_speaking(42), "aparece falando")
	packet[0] = 0
	voice._receive(42, packet)
	_check(speaker.player.bus == "Voz", "sem rádio: voz limpa")

	# Volume e mudo só para mim (por nome; sem herói, a chave é o número).
	settings.voice_peer_volume = {"42": 0.5}
	settings.voice_peer_muted = {}
	voice._apply_speaker_settings(42)
	_check(absf(speaker.player.volume_db - linear_to_db(0.5)) < 0.01, "volume dessa pessoa só para mim")
	settings.voice_peer_muted = {"42": true}
	voice._apply_speaker_settings(42)
	_check(speaker.player.volume_db <= -79.0, "mutada só para mim")
	settings.voice_peer_muted = {}
	settings.voice_proximity = false
	voice._apply_speaker_settings(42)
	_check(speaker.player.attenuation_model == AudioStreamPlayer3D.ATTENUATION_DISABLED, "sem proximidade: mesmo volume longe ou perto")
	settings.voice_proximity = true
	voice._apply_speaker_settings(42)
	_check(speaker.player.attenuation_model == AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE, "com proximidade: cai com a distância")

	# Detecção de voz: fala abre, silêncio longo fecha.
	settings.voice_mode = "auto"
	var loud := PackedFloat32Array()
	var quiet := PackedFloat32Array()
	for i in 1600:
		loud.append(sin(i * 0.3) * 0.3)
		quiet.append(0.0)
	voice.inject_mic(loud)
	_check(voice.talking, "falando: microfone abre sozinho")
	voice._vad_timer = 0.0
	voice.inject_mic(quiet)
	_check(not voice.talking, "silêncio: fecha")
	settings.voice_mode = "off"
	voice.inject_mic(loud)
	_check(not voice.talking, "voz desligada: não abre")
	settings.voice_mode = "auto"
	voice._forget(42)
	_check(not voice._speakers.has(42), "quem sai da sala é esquecido")

	print("VOZ: ", "FALHOU" if _failed else "OK")
	quit(1 if _failed else 0)
	return false


func _check(ok: bool, text: String) -> void:
	print("  ", "ok  " if ok else "FALHOU", " ", text)
	if not ok:
		_failed = true
