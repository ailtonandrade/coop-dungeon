extends Node
## Voz pela rede (autoload "Voice").
##
## Captura: o microfone escolhido neste PC (o Godot capta de um microfone por vez; no sofá,
## todos do mesmo PC usam ele, e quem está junto já se ouve na sala). A voz abre sozinha
## quando a pessoa fala (detecção de voz) ou só apertando o botão (V / direcional para cima),
## conforme as Settings.
##
## Envio: 16 mil amostras por segundo em mu-law (1 byte por amostra), em pacotes de 40 ms,
## só enquanto fala. Convidados mandam ao host; o host repassa aos outros (e não repassa quem
## ele mutou para todos).
##
## Reprodução: cada pessoa toca num som 3D preso no herói dela, então a voz cai com a distância
## entre os heróis (opcional nas Settings). Quem liga o "rádio velho" na própria voz é ouvido
## pelos outros com o filtro (faixa estreita, chiado, um "tchh" ao abrir).

signal changed

const RATE := 16000
const PACKET_SAMPLES := 640  # 40 ms
## Silêncio depois da fala antes de fechar (para não cortar o fim das palavras).
const VAD_HANGOVER := 0.35
## Pacotes guardados antes de começar a tocar (contra rede irregular).
const PREBUFFER_PACKETS := 2
const SPEAKING_TIMEOUT := 0.3
const FLAG_RADIO := 1
const MIC_BUS := "Microfone"
const VOICE_BUS := "Voz"
const RADIO_BUS := "VozRadio"
## Distância (m) da voz no volume normal e onde some (o mapa de cima mostra uns 30 m).
const UNIT_SIZE := 10.0
const MAX_DISTANCE := 60.0

## Meu microfone: volume atual (0 a 1, para o medidor) e se estou transmitindo.
var mic_level := 0.0
var talking := false
## Liga o microfone mesmo fora do online (medidor da tela de configurações).
var monitor := false:
	set(value):
		monitor = value
		_update_capture()
## Host decide e todos sabem: peer -> true (mutado para todos).
var muted_by_host := {}
## Pacotes recebidos por pessoa (para os testes e para a tela).
var heard := {}

var _mic_player: AudioStreamPlayer
var _capture: AudioEffectCapture
var _capturing := false
var _resample_pos := 0.0
var _resample_sum := 0.0
var _resample_count := 0
var _outgoing := PackedFloat32Array()
var _vad_timer := 0.0
var _speakers := {}  # peer -> {player, playback, buffer, playing, last_heard, radio}
var _decode_table := PackedFloat32Array()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_decode_table.resize(256)
	for i in 256:
		_decode_table[i] = _mulaw_decode_raw(i)
	_setup_buses()
	_mic_player = AudioStreamPlayer.new()
	_mic_player.bus = MIC_BUS
	add_child(_mic_player)
	Settings.changed.connect(_on_settings_changed)
	multiplayer.peer_disconnected.connect(_forget)
	_on_settings_changed()


## Lista de microfones do sistema.
func devices() -> PackedStringArray:
	return AudioServer.get_input_device_list()


func is_speaking(peer: int) -> bool:
	if peer == multiplayer.get_unique_id():
		return talking
	var speaker: Dictionary = _speakers.get(peer, {})
	return not speaker.is_empty() and Time.get_ticks_msec() / 1000.0 - float(speaker.last_heard) < SPEAKING_TIMEOUT


## Fui mutado pelo host (não adianta mandar voz).
func am_muted() -> bool:
	return muted_by_host.get(multiplayer.get_unique_id(), false)


## Host: muta (ou desmuta) alguém para todos da sala.
func set_muted_for_all(peer: int, muted: bool) -> void:
	if not NetService.is_host():
		return
	if muted:
		muted_by_host[peer] = true
	else:
		muted_by_host.erase(peer)
	_rpc_mute_state.rpc(muted_by_host)
	changed.emit()


## Nome de quem fala por um PC: os personagens dele em jogo ("Nina + Zé").
func peer_label(peer: int) -> String:
	var names := PackedStringArray()
	for player in get_tree().get_nodes_in_group("players"):
		if player.owner_peer == peer:
			names.append(player.display_name)
	return " + ".join(names) if not names.is_empty() else "Jogador %d" % peer


## Chave das preferências por pessoa (o nome do primeiro personagem dela).
func peer_key(peer: int) -> String:
	for player in get_tree().get_nodes_in_group("players"):
		if player.owner_peer == peer:
			return player.display_name
	return str(peer)


## Pessoas que eu posso ouvir (outros PCs da sala).
func remote_peers() -> Array[int]:
	var peers: Array[int] = []
	for player in get_tree().get_nodes_in_group("players"):
		if player.owner_peer != multiplayer.get_unique_id() and not peers.has(player.owner_peer):
			peers.append(player.owner_peer)
	return peers


## Testes: entra como se fosse áudio do microfone (já em RATE).
func inject_mic(samples: PackedFloat32Array) -> void:
	_feed(samples, samples.size() / float(RATE))


## Captura

func _on_settings_changed() -> void:
	_set_bus_volume(VOICE_BUS, Settings.voice_volume)
	_set_bus_volume(RADIO_BUS, Settings.voice_volume)
	if devices().has(Settings.mic_device) and AudioServer.input_device != Settings.mic_device:
		AudioServer.input_device = Settings.mic_device
	for peer: int in _speakers:
		_apply_speaker_settings(peer)
	_update_capture()


func _update_capture() -> void:
	var want := (monitor or (NetService.is_online() and Settings.voice_mode != "off")) and DisplayServer.get_name() != "headless"
	if want == _capturing:
		return
	_capturing = want
	if want:
		_mic_player.stream = AudioStreamMicrophone.new()
		_mic_player.play()
	else:
		_mic_player.stop()
		_outgoing.clear()
		talking = false
		mic_level = 0.0


func _process(delta: float) -> void:
	# Liga/desliga o microfone conforme a sessão (online ou não) e as Settings.
	_update_capture()
	if _capturing and _capture:
		var frames := _capture.get_frames_available()
		if frames > 0:
			var stereo := _capture.get_buffer(frames)
			_feed(_resample(stereo), frames / AudioServer.get_mix_rate())
	elif not _capturing:
		_vad_timer = 0.0
	_vad_timer = maxf(_vad_timer - delta, 0.0)
	_update_speakers()


## Junta as amostras do microfone (na taxa do sistema) em RATE, por média (filtro simples).
func _resample(stereo: PackedVector2Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var step := AudioServer.get_mix_rate() / RATE
	for frame in stereo:
		_resample_sum += (frame.x + frame.y) * 0.5
		_resample_count += 1
		_resample_pos += 1.0
		if _resample_pos >= step:
			_resample_pos -= step
			out.append(_resample_sum / _resample_count)
			_resample_sum = 0.0
			_resample_count = 0
	return out


## Amostras novas do meu microfone: medidor, detecção de voz e envio.
func _feed(samples: PackedFloat32Array, seconds: float) -> void:
	if samples.is_empty():
		return
	var sum := 0.0
	for x in samples:
		sum += x * x
	var rms := sqrt(sum / samples.size())
	mic_level = lerpf(mic_level, minf(rms * 4.0, 1.0), 0.5)
	var open := false
	match Settings.voice_mode:
		"auto":
			if rms > Settings.mic_threshold:
				_vad_timer = VAD_HANGOVER + seconds
			open = _vad_timer > 0.0
		"push":
			open = InputService.push_to_talk_pressed()
	var was := talking
	talking = open and not am_muted()
	if talking != was:
		changed.emit()
	if not talking or not NetService.is_online():
		_outgoing.clear()
		return
	_outgoing.append_array(samples)
	while _outgoing.size() >= PACKET_SAMPLES:
		var packet := PackedByteArray()
		packet.resize(PACKET_SAMPLES + 1)
		packet[0] = FLAG_RADIO if Settings.radio_voice else 0
		for i in PACKET_SAMPLES:
			packet[i + 1] = _mulaw_encode(_outgoing[i])
		_outgoing = _outgoing.slice(PACKET_SAMPLES)
		_send(packet)


func _send(packet: PackedByteArray) -> void:
	if NetService.is_host():
		for peer in NetService.ready_peers():
			_rpc_voice_relay.rpc_id(peer, multiplayer.get_unique_id(), packet)
	else:
		_rpc_voice.rpc_id(1, packet)


## Rede (canal 2, sem esperar pacote perdido: voz atrasada não serve)

@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func _rpc_voice(packet: PackedByteArray) -> void:
	if not NetService.is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	if muted_by_host.has(sender) or packet.size() != PACKET_SAMPLES + 1:
		return
	_receive(sender, packet)
	for peer in NetService.ready_peers():
		if peer != sender:
			_rpc_voice_relay.rpc_id(peer, sender, packet)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _rpc_voice_relay(from_peer: int, packet: PackedByteArray) -> void:
	if from_peer != multiplayer.get_unique_id() and packet.size() == PACKET_SAMPLES + 1:
		_receive(from_peer, packet)


@rpc("authority", "call_remote", "reliable")
func _rpc_mute_state(state: Dictionary) -> void:
	muted_by_host = state
	if am_muted():
		talking = false
	changed.emit()


## Reprodução

func _receive(peer: int, packet: PackedByteArray) -> void:
	heard[peer] = int(heard.get(peer, 0)) + 1
	if muted_by_host.has(peer):
		return
	var speaker := _speaker(peer)
	speaker.radio = packet[0] & FLAG_RADIO != 0
	var samples := PackedFloat32Array()
	samples.resize(PACKET_SAMPLES)
	for i in PACKET_SAMPLES:
		samples[i] = _decode_table[packet[i + 1]]
	if speaker.radio:
		for i in PACKET_SAMPLES:
			samples[i] += randf_range(-0.02, 0.02)
		# Começo de fala no rádio: "tchh" curto.
		if not speaker.playing and speaker.buffer.is_empty():
			var squelch := PackedFloat32Array()
			squelch.resize(960)
			for i in squelch.size():
				squelch[i] = randf_range(-0.25, 0.25) * (1.0 - float(i) / squelch.size())
			speaker.buffer.append_array(squelch)
	speaker.buffer.append_array(samples)
	speaker.last_heard = Time.get_ticks_msec() / 1000.0
	_apply_speaker_settings(peer)


func _speaker(peer: int) -> Dictionary:
	if _speakers.has(peer):
		return _speakers[peer]
	var player := AudioStreamPlayer3D.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = RATE
	generator.buffer_length = 0.5
	player.stream = generator
	player.unit_size = UNIT_SIZE
	player.max_distance = MAX_DISTANCE
	add_child(player)
	player.play()
	var speaker := {
		"player": player, "playback": player.get_stream_playback(), "buffer": PackedFloat32Array(),
		"playing": false, "last_heard": 0.0, "radio": false,
	}
	_speakers[peer] = speaker
	_apply_speaker_settings(peer)
	return speaker


func _apply_speaker_settings(peer: int) -> void:
	var speaker: Dictionary = _speakers.get(peer, {})
	if speaker.is_empty():
		return
	var player: AudioStreamPlayer3D = speaker.player
	var key := peer_key(peer)
	var muted: bool = Settings.voice_peer_muted.get(key, false) or muted_by_host.has(peer)
	var volume: float = Settings.voice_peer_volume.get(key, 1.0)
	player.volume_db = -80.0 if muted else linear_to_db(maxf(volume, 0.0001))
	player.bus = RADIO_BUS if speaker.radio else VOICE_BUS
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE if Settings.voice_proximity \
			else AudioStreamPlayer3D.ATTENUATION_DISABLED
	player.panning_strength = 0.6 if Settings.voice_proximity else 0.0


func _update_speakers() -> void:
	for peer: int in _speakers:
		var speaker: Dictionary = _speakers[peer]
		var player: AudioStreamPlayer3D = speaker.player
		player.global_position = _peer_position(peer, player.global_position)
		var playback: AudioStreamGeneratorPlayback = speaker.playback
		if playback == null:
			continue
		var buffer: PackedFloat32Array = speaker.buffer
		if not speaker.playing:
			if buffer.size() >= PACKET_SAMPLES * PREBUFFER_PACKETS:
				speaker.playing = true
			else:
				continue
		var room := playback.get_frames_available()
		var count := mini(room, buffer.size())
		for i in count:
			playback.push_frame(Vector2(buffer[i], buffer[i]))
		speaker.buffer = buffer.slice(count)
		if speaker.buffer.is_empty():
			speaker.playing = false


## Onde a voz sai: no meio dos heróis daquele PC (se não tiver, onde estava).
func _peer_position(peer: int, fallback: Vector3) -> Vector3:
	var sum := Vector3.ZERO
	var count := 0
	for player in get_tree().get_nodes_in_group("players"):
		if player.owner_peer == peer:
			sum += player.global_position + Vector3.UP * 1.6
			count += 1
	return sum / count if count > 0 else fallback


func _forget(peer: int) -> void:
	if _speakers.has(peer):
		_speakers[peer].player.queue_free()
		_speakers.erase(peer)
	muted_by_host.erase(peer)
	heard.erase(peer)


## Barramentos e codificação

func _setup_buses() -> void:
	if AudioServer.get_bus_index(MIC_BUS) == -1:
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, MIC_BUS)
		AudioServer.set_bus_mute(index, true)  # não toca o próprio microfone de volta
		AudioServer.add_bus_effect(index, AudioEffectCapture.new())
	_capture = AudioServer.get_bus_effect(AudioServer.get_bus_index(MIC_BUS), 0) as AudioEffectCapture
	for bus in [VOICE_BUS, RADIO_BUS]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	var radio := AudioServer.get_bus_index(RADIO_BUS)
	if AudioServer.get_bus_effect_count(radio) == 0:
		# Rádio velho: só a faixa do meio, um pouco de "chiado de bit" e saturação.
		var band := AudioEffectBandPassFilter.new()
		band.cutoff_hz = 1600.0
		band.resonance = 0.65
		AudioServer.add_bus_effect(radio, band)
		var crunch := AudioEffectDistortion.new()
		crunch.mode = AudioEffectDistortion.MODE_LOFI
		crunch.drive = 0.35
		crunch.pre_gain = 6.0
		crunch.post_gain = -4.0
		AudioServer.add_bus_effect(radio, crunch)
		var high := AudioEffectHighPassFilter.new()
		high.cutoff_hz = 450.0
		AudioServer.add_bus_effect(radio, high)


func _set_bus_volume(bus: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))


## mu-law de 8 bits: sinal + 7 bits de volume em escala logarítmica (voz soa bem em 1 byte).
static func _mulaw_encode(x: float) -> int:
	var magnitude := log(1.0 + 255.0 * minf(absf(x), 1.0)) / log(256.0)
	var value := roundi(magnitude * 127.0)
	return (value | 0x80) if x < 0.0 else value


static func _mulaw_decode_raw(byte: int) -> float:
	var magnitude := float(byte & 0x7F) / 127.0
	var value := (pow(256.0, magnitude) - 1.0) / 255.0
	return -value if byte & 0x80 else value


## Para os testes: ida e volta de um valor.
static func roundtrip(x: float) -> float:
	return _mulaw_decode_raw(_mulaw_encode(x))
