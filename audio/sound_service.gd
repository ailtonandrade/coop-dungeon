extends Node
## Som do jogo (autoload "Sound"). O resto do código só pede eventos pelo nome:
##   Sound.play("hit", posição)   efeito no mundo (som 3D, ouvido em volta da câmera)
##   Sound.play("ui_confirm")     efeito sem posição (interface)
##   Sound.play_music("menu")     música com troca suave; Sound.play_ambience("ambiente")
## Os eventos ficam em SoundBank. Barramentos: Music, Ambience, SFX e UI, com o volume de cada
## um nas Settings (menu de pausa). Botões de qualquer tela tocam o som de mover e confirmar
## sozinhos.

const WORLD_VOICES := 24
const FLAT_VOICES := 8
const BUSES := ["Music", "Ambience", "SFX", "UI"]
## Distância (m) em que o som 3D tem o volume original; some de vez em MAX_DISTANCE.
const UNIT_SIZE := 9.0
const MAX_DISTANCE := 55.0
const MUSIC_FADE := 1.2

## Últimos eventos tocados (para os testes conferirem).
var played: Array[String] = []

var _streams := {}  # evento -> AudioStreamRandomizer
var _last_time := {}  # evento -> segundos da última vez
var _world_voices: Array[AudioStreamPlayer3D] = []
var _flat_voices: Array[AudioStreamPlayer] = []
var _next_world := 0
var _next_flat := 0
var _music: Array[AudioStreamPlayer] = []
var _music_name := ""
var _ambience: AudioStreamPlayer
var _quiet_until := 0.0
## Relógio do jogo (segundos de quadros), para os intervalos não dependerem do relógio de parede.
var _clock := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for event: String in SoundBank.EVENTS:
		var info: Dictionary = SoundBank.EVENTS[event]
		var randomizer := AudioStreamRandomizer.new()
		randomizer.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		randomizer.random_pitch = 1.0 + float(info.get("pitch", 0.0))
		randomizer.random_volume_offset_db = 1.0
		for file: String in info.files:
			var stream := load(SoundBank.SFX_DIR + file + ".ogg") as AudioStream
			if stream:
				randomizer.add_stream(-1, stream)
		_streams[event] = randomizer
	for i in WORLD_VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.unit_size = UNIT_SIZE
		voice.max_distance = MAX_DISTANCE
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		voice.panning_strength = 0.7
		voice.bus = "SFX"
		add_child(voice)
		_world_voices.append(voice)
	for i in FLAT_VOICES:
		var flat := AudioStreamPlayer.new()
		add_child(flat)
		_flat_voices.append(flat)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		add_child(player)
		_music.append(player)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Ambience"
	add_child(_ambience)
	Settings.changed.connect(apply_volumes)
	apply_volumes()
	get_tree().node_added.connect(_on_node_added)


func _process(delta: float) -> void:
	_clock += delta


## Toca um evento. `position` (Vector3) = som no mundo; sem posição = som "da tela".
func play(event: String, position: Variant = null) -> void:
	var info: Dictionary = SoundBank.EVENTS.get(event, {})
	if info.is_empty() or not _streams.has(event):
		push_warning("Som desconhecido: %s" % event)
		return
	var now := _clock
	if now < _quiet_until or now - float(_last_time.get(event, -10.0)) < float(info.get("gap", 0.0)):
		return
	_last_time[event] = now
	played.append(event)
	if played.size() > 64:
		played.remove_at(0)
	var volume := float(info.get("db", 0.0))
	if position is Vector3 and info.get("world", true):
		var voice := _world_voices[_next_world]
		_next_world = (_next_world + 1) % _world_voices.size()
		voice.stop()
		voice.stream = _streams[event]
		voice.volume_db = volume
		voice.bus = info.get("bus", "SFX")
		voice.global_position = position
		voice.play()
	else:
		var flat := _flat_voices[_next_flat]
		_next_flat = (_next_flat + 1) % _flat_voices.size()
		flat.stop()
		flat.stream = _streams[event]
		flat.volume_db = volume
		flat.bus = info.get("bus", "SFX")
		flat.play()


## Segura os efeitos por um tempo (ao carregar um mundo, tudo que já existe "nasce" de uma vez).
func quiet_for(seconds: float) -> void:
	_quiet_until = _clock + seconds


## Troca a música com fade (vazio = para).
func play_music(name: String) -> void:
	if name == _music_name:
		return
	_music_name = name
	var old := _music[0]
	var new := _music[1]
	_music.reverse()
	_fade(old, -40.0, true)
	if name.is_empty():
		return
	new.stream = _loop(SoundBank.MUSIC.get(name, name))
	new.volume_db = -40.0
	new.play()
	_fade(new, 0.0, false)


func play_ambience(name: String) -> void:
	if name.is_empty():
		_ambience.stop()
		return
	_ambience.stream = _loop(SoundBank.MUSIC.get(name, name))
	_ambience.play()


func apply_volumes() -> void:
	_set_bus_volume("Master", Settings.master_volume)
	_set_bus_volume("Music", Settings.music_volume)
	_set_bus_volume("Ambience", Settings.music_volume)
	_set_bus_volume("SFX", Settings.sfx_volume)
	_set_bus_volume("UI", Settings.sfx_volume)


func _set_bus_volume(bus: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(index, linear <= 0.001)


func _setup_buses() -> void:
	for bus: String in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	# Efeitos do mundo num ambiente com um pouco de eco (ferro-velho aberto, chapa de metal).
	var sfx := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx) == 0:
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.35
		reverb.damping = 0.6
		reverb.wet = 0.08
		reverb.dry = 1.0
		AudioServer.add_bus_effect(sfx, reverb)
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		AudioServer.add_bus_effect(master, AudioEffectHardLimiter.new())


func _loop(file: String) -> AudioStream:
	var stream := load(SoundBank.MUSIC_DIR + file + ".ogg") as AudioStreamOggVorbis
	if stream:
		stream.loop = true
	return stream


func _fade(player: AudioStreamPlayer, target_db: float, stop_after: bool) -> void:
	var tween := create_tween()
	tween.tween_property(player, "volume_db", target_db, MUSIC_FADE)
	if stop_after:
		tween.tween_callback(player.stop)


## Botões de qualquer tela: som ao focar (controle/teclado) e ao apertar.
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var button := node as BaseButton
		button.focus_entered.connect(func() -> void: play("ui_move"))
		button.pressed.connect(func() -> void: play("ui_confirm"))
