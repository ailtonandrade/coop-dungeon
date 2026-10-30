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


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		minimap_mode = config.get_value("hud", "minimap_mode", minimap_mode)
		camera_mode = config.get_value("camera", "mode", camera_mode)
		look_sensitivity = config.get_value("camera", "look_sensitivity", look_sensitivity)


func toggle_minimap_mode() -> void:
	minimap_mode = "rotating" if minimap_mode == "fixed" else "fixed"
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
	config.save(PATH)
