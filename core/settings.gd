extends Node
## Preferências desta máquina (não vão no save do mundo nem no cross save).

signal changed

const PATH := "user://settings.cfg"

## "fixed": norte sempre pra cima. "rotating": gira com a direção do herói.
var minimap_mode := "fixed"
## "iso": de cima, isométrica (padrão). "behind": atrás do herói, estilo GTA; só vale quando
## esta tela tem um jogador só (com mais gente no sofá volta para a de cima).
var camera_mode := "iso"
## Sensibilidade da câmera atrás do herói (mouse e analógico).
var look_sensitivity := 1.0
## Tamanho da interface (textos, menus, HUD): 1.0 = normal.
var ui_scale := 1.0
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
## Volumes (0 a 1): geral, música/ambiente e efeitos.
var master_volume := 0.9
var music_volume := 0.6
var sfx_volume := 0.9


func _ready() -> void:
	_load()
	apply_ui_scale.call_deferred()


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		minimap_mode = config.get_value("hud", "minimap_mode", minimap_mode)
		camera_mode = config.get_value("camera", "mode", camera_mode)
		look_sensitivity = config.get_value("camera", "look_sensitivity", look_sensitivity)
		ui_scale = config.get_value("display", "ui_scale", ui_scale)
		for key in ["voice_mode", "mic_device", "mic_threshold", "radio_voice", "voice_volume", "voice_proximity",
				"voice_peer_volume", "voice_peer_muted"]:
			set(key, config.get_value("voice", key, get(key)))
		last_character = config.get_value("characters", "last", last_character)
		master_volume = config.get_value("audio", "master", master_volume)
		music_volume = config.get_value("audio", "music", music_volume)
		sfx_volume = config.get_value("audio", "sfx", sfx_volume)


func toggle_minimap_mode() -> void:
	minimap_mode = "rotating" if minimap_mode == "fixed" else "fixed"
	_save()
	changed.emit()


const UI_SCALE_MIN := 0.8
const UI_SCALE_MAX := 1.6


func set_ui_scale(value: float) -> void:
	ui_scale = clampf(snappedf(value, 0.05), UI_SCALE_MIN, UI_SCALE_MAX)
	apply_ui_scale()
	_save()
	changed.emit()


## Aplica o tamanho da interface na janela (tudo que é 2D cresce junto, na mesma proporção).
func apply_ui_scale() -> void:
	if is_inside_tree():
		get_tree().root.content_scale_factor = ui_scale


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


func remember_character(slot: int, character_id: String) -> void:
	if slot >= 0 and slot < last_character.size():
		last_character[slot] = character_id
		_save()


## Muda um volume ("master", "music", "sfx") e salva.
func set_volume(which: String, value: float) -> void:
	set(which + "_volume", clampf(value, 0.0, 1.0))
	_save()
	changed.emit()


func toggle_camera_mode() -> void:
	camera_mode = "behind" if camera_mode == "iso" else "iso"
	_save()
	changed.emit()


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("hud", "minimap_mode", minimap_mode)
	config.set_value("camera", "mode", camera_mode)
	config.set_value("camera", "look_sensitivity", look_sensitivity)
	config.set_value("display", "ui_scale", ui_scale)
	for key in ["voice_mode", "mic_device", "mic_threshold", "radio_voice", "voice_volume", "voice_proximity",
			"voice_peer_volume", "voice_peer_muted"]:
		config.set_value("voice", key, get(key))
	config.set_value("characters", "last", last_character)
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.save(PATH)
