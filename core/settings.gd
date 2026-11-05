extends Node
## Preferências desta máquina (não vão no save do mundo nem no cross save).

signal changed

const PATH := "user://settings.cfg"

## "camera": gira junto com a câmera (o que está pra cima na tela está pra cima no mapa).
## "fixed": norte sempre pra cima.
var minimap_mode := "camera"
## "iso": de cima, isométrica (padrão). "behind": atrás do herói, estilo GTA; só vale quando
## esta tela tem um jogador só (com mais gente no sofá volta para a de cima).
var camera_mode := "iso"
## Sensibilidade da câmera atrás do herói (mouse e analógico).
var look_sensitivity := 1.0
## Idioma ("pt_BR", "en"); vazio = o do sistema (português se for português, senão inglês).
var language := ""
## Qualidade gráfica: "baixa", "media" ou "alta" (Graphics).
var graphics_quality := "media"
## Tamanho da interface (textos, menus, HUD): 1.0 = normal.
var ui_scale := 1.0
## Personagem ativo (escolhido no menu): é com ele que o primeiro jogador entra no mundo.
var active_character := ""
## Último personagem escolhido em cada vaga do sofá (P1 a P4), para já vir marcado.
var last_character: Array = ["", "", "", ""]
## Voz: "off" (desligado), "auto" (abre sozinho quando fala) ou "push" (apertar para falar).
var voice_mode := "auto"
## Microfone deste PC (nome da lista do sistema; "Default" = o padrão do sistema).
var mic_device := "Default"
## Sensibilidade da detecção de voz (volume mínimo do microfone, 0 a 1).
var mic_threshold := 0.03
## Minha voz sai com filtro de rádio velho (os outros ouvem assim).
var radio_voice := false
## Volume das vozes que eu ouço (0 a 1) e se caem com a distância entre os heróis.
var voice_volume := 0.9
var voice_proximity := true
## Por pessoa (pelo nome): volume e mudo só para mim.
var voice_peer_volume := {}
var voice_peer_muted := {}
## Tela: "janela", "sem_bordas" (tela cheia sem bordas, troca de janela rápido) ou "tela_cheia"
## (exclusiva). A resolução vale para a janela; nas telas cheias é a do monitor (para aliviar o
## PC, use a qualidade gráfica, que baixa a resolução do 3D). Vazio = como o jogo abriu.
var window_mode := ""
var window_resolution := ""
var vsync := true
const WINDOW_MODES := ["janela", "sem_bordas", "tela_cheia"]
const WINDOW_MODE_NAMES := {"janela": "Janela", "sem_bordas": "Janela sem bordas (tela cheia)", "tela_cheia": "Tela cheia"}
const RESOLUTIONS := ["1280x720", "1366x768", "1600x900", "1920x1080", "2560x1440", "3840x2160"]

## Volumes (0 a 1): geral, música/ambiente e efeitos.
var master_volume := 0.9
var music_volume := 0.6
var ambience_volume := 0.6
var sfx_volume := 0.9


func _ready() -> void:
	_load()
	apply_language()
	apply_display.call_deferred()
	apply_ui_scale.call_deferred()
	get_tree().node_added.connect(func(node: Node) -> void: Graphics.on_node_added(node, graphics_quality))
	(func() -> void: Graphics.apply(get_tree(), graphics_quality)).call_deferred()


func _load() -> void:
	var config := ConfigFile.new()
	# Primeira vez nesta máquina: qualidade pela placa de vídeo (integrada = baixa).
	graphics_quality = Graphics.suggested_quality()
	if config.load(PATH) == OK:
		# Chave nova: o modo antigo ("rotating" pelo herói) deu lugar ao que segue a câmera.
		minimap_mode = config.get_value("hud", "minimap_mode_v2", minimap_mode)
		camera_mode = config.get_value("camera", "mode", camera_mode)
		look_sensitivity = config.get_value("camera", "look_sensitivity", look_sensitivity)
		ui_scale = config.get_value("display", "ui_scale", ui_scale)
		graphics_quality = config.get_value("display", "graphics", Graphics.suggested_quality())
		window_mode = config.get_value("display", "window_mode", window_mode)
		window_resolution = config.get_value("display", "resolution", window_resolution)
		vsync = config.get_value("display", "vsync", vsync)
		language = config.get_value("display", "language", language)
		if not Graphics.LEVELS.has(graphics_quality):
			graphics_quality = "media"
		for key in ["voice_mode", "mic_device", "mic_threshold", "radio_voice", "voice_volume", "voice_proximity",
				"voice_peer_volume", "voice_peer_muted"]:
			set(key, config.get_value("voice", key, get(key)))
		last_character = config.get_value("characters", "last", last_character)
		active_character = config.get_value("characters", "active", active_character)
		master_volume = config.get_value("audio", "master", master_volume)
		music_volume = config.get_value("audio", "music", music_volume)
		# Antes era um volume só para música e ambiente: sem o novo, herda o antigo.
		ambience_volume = config.get_value("audio", "ambience", music_volume)
		sfx_volume = config.get_value("audio", "sfx", sfx_volume)


func toggle_minimap_mode() -> void:
	minimap_mode = "camera" if minimap_mode == "fixed" else "fixed"
	_save()
	changed.emit()


const UI_SCALE_MIN := 0.8
const UI_SCALE_MAX := 1.6


func set_ui_scale(value: float) -> void:
	ui_scale = clampf(snappedf(value, 0.05), UI_SCALE_MIN, UI_SCALE_MAX)
	apply_ui_scale()
	_save()
	changed.emit()


## A interface é desenhada para 1920x1080 e encolhe junto com a janela; numa janela pequena
## (1280x720) os textos ficavam minúsculos. Abaixo desta fração do tamanho de 1080p, compensa.
const UI_MIN_WINDOW_SCALE := 0.9


## Aplica o tamanho da interface na janela (tudo que é 2D cresce junto, na mesma proporção).
func apply_ui_scale() -> void:
	if not is_inside_tree():
		return
	var root := get_tree().root
	if not root.size_changed.is_connected(apply_ui_scale):
		root.size_changed.connect(apply_ui_scale)
	var window_scale := root.size.y / 1080.0 if root.size.y > 0 else 1.0
	root.content_scale_factor = ui_scale * maxf(1.0, UI_MIN_WINDOW_SCALE / window_scale)


## Muda uma opção de voz ("voice_mode", "mic_device", "radio_voice"...) e salva.
func set_voice(key: String, value: Variant) -> void:
	set(key, value)
	_save()
	changed.emit()


## Volume (0 a 1) e mudo de uma pessoa, só para mim.
func set_peer_voice(name: String, volume: float, muted: bool) -> void:
	voice_peer_volume[name] = clampf(volume, 0.0, 1.5)
	voice_peer_muted[name] = muted
	_save()
	changed.emit()


func set_look_sensitivity(value: float) -> void:
	look_sensitivity = clampf(value, 0.3, 3.0)
	_save()
	changed.emit()


func set_active_character(character_id: String) -> void:
	active_character = character_id
	_save()
	changed.emit()


func remember_character(slot: int, character_id: String) -> void:
	if slot >= 0 and slot < last_character.size():
		last_character[slot] = character_id
		_save()


## Muda um volume ("master", "music", "ambience", "sfx") e salva.
func set_volume(which: String, value: float) -> void:
	set(which + "_volume", clampf(value, 0.0, 1.0))
	_save()
	changed.emit()


## Idioma em uso agora.
func current_language() -> String:
	# Sem tela (testes automáticos): português, a língua dos textos que os testes conferem.
	if DisplayServer.get_name() == "headless":
		return "pt_BR"
	if Txt.LANGUAGES.has(language):
		return language
	return "pt_BR" if OS.get_locale().begins_with("pt") else "en"


func apply_language() -> void:
	TranslationServer.set_locale(current_language())


## Troca para o próximo idioma. No menu principal a tela se monta de novo já traduzida.
func cycle_language() -> void:
	var codes := Txt.LANGUAGES.keys()
	language = codes[(codes.find(current_language()) + 1) % codes.size()]
	apply_language()
	_save()
	changed.emit()
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path == "res://ui/main_menu.tscn":
		get_tree().reload_current_scene.call_deferred()


## Resoluções que cabem na tela deste PC.
func available_resolutions() -> Array:
	var screen := DisplayServer.screen_get_size()
	var list := RESOLUTIONS.filter(func(r: String) -> bool:
		var parts := r.split("x")
		return int(parts[0]) <= screen.x and int(parts[1]) <= screen.y)
	return list if not list.is_empty() else [RESOLUTIONS[0]]


func current_resolution() -> String:
	if window_resolution in available_resolutions():
		return window_resolution
	var size := DisplayServer.window_get_size()
	return "%dx%d" % [size.x, size.y]


func cycle_window_mode() -> void:
	var current := window_mode if window_mode in WINDOW_MODES else "janela"
	window_mode = WINDOW_MODES[(WINDOW_MODES.find(current) + 1) % WINDOW_MODES.size()]
	apply_display()
	_save()
	changed.emit()


func cycle_resolution() -> void:
	var list := available_resolutions()
	var index := list.find(window_resolution)
	window_resolution = list[(index + 1) % list.size()]
	if window_mode != "janela":
		window_mode = "janela"
	apply_display()
	_save()
	changed.emit()


func toggle_vsync() -> void:
	vsync = not vsync
	apply_display()
	_save()
	changed.emit()


## Aplica modo de tela, resolução da janela e VSync (sem tela, nos testes, não faz nada).
func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	match window_mode:
		"sem_bordas":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"tela_cheia":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"janela":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			if window_resolution in available_resolutions():
				var parts := window_resolution.split("x")
				var size := Vector2i(int(parts[0]), int(parts[1]))
				DisplayServer.window_set_size(size)
				var screen := DisplayServer.screen_get_usable_rect()
				DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)


## Passa para a próxima qualidade gráfica (baixa → média → alta → baixa) e aplica na hora.
func cycle_graphics_quality() -> void:
	graphics_quality = Graphics.LEVELS[(Graphics.LEVELS.find(graphics_quality) + 1) % Graphics.LEVELS.size()]
	Graphics.apply(get_tree(), graphics_quality)
	_save()
	changed.emit()


## Escolha direta de uma opção (listas da tela de configurações). Aplica e salva.
func set_choice(key: String, value: Variant) -> void:
	match key:
		"language":
			if value == current_language():
				return
			language = value
			apply_language()
			_save()
			changed.emit()
			var scene := get_tree().current_scene
			if scene and scene.scene_file_path == "res://ui/main_menu.tscn":
				get_tree().reload_current_scene.call_deferred()
			return
		"graphics_quality":
			graphics_quality = value
			Graphics.apply(get_tree(), graphics_quality)
		"window_mode":
			window_mode = value
			apply_display()
		"window_resolution":
			window_resolution = value
			window_mode = "janela"
			apply_display()
		"vsync":
			vsync = value
			apply_display()
		"camera_mode", "minimap_mode":
			set(key, value)
	_save()
	changed.emit()


func toggle_camera_mode() -> void:
	camera_mode = "behind" if camera_mode == "iso" else "iso"
	_save()
	changed.emit()


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("hud", "minimap_mode_v2", minimap_mode)
	config.set_value("camera", "mode", camera_mode)
	config.set_value("camera", "look_sensitivity", look_sensitivity)
	config.set_value("display", "ui_scale", ui_scale)
	config.set_value("display", "graphics", graphics_quality)
	config.set_value("display", "window_mode", window_mode)
	config.set_value("display", "resolution", window_resolution)
	config.set_value("display", "vsync", vsync)
	config.set_value("display", "language", language)
	for key in ["voice_mode", "mic_device", "mic_threshold", "radio_voice", "voice_volume", "voice_proximity",
			"voice_peer_volume", "voice_peer_muted"]:
		config.set_value("voice", key, get(key))
	config.set_value("characters", "last", last_character)
	config.set_value("characters", "active", active_character)
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "ambience", ambience_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.save(PATH)
