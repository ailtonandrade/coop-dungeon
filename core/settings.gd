extends Node
## Preferências desta máquina (não vão no save do mundo nem no cross save).

signal changed

const PATH := "user://settings.cfg"

## "fixed": norte sempre pra cima. "rotating": gira com a direção do herói.
var minimap_mode := "fixed"


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		minimap_mode = config.get_value("hud", "minimap_mode", minimap_mode)


func toggle_minimap_mode() -> void:
	minimap_mode = "rotating" if minimap_mode == "fixed" else "fixed"
	_save()
	changed.emit()


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("hud", "minimap_mode", minimap_mode)
	config.save(PATH)
