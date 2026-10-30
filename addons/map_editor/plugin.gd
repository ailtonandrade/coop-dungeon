@tool
extends EditorPlugin
## Liga o painel "Mapa do Mundo" no editor (lado direito, embaixo do Inspector).

const Dock := preload("res://addons/map_editor/world_map_dock.gd")

var _dock: Control


func _enter_tree() -> void:
	_dock = Dock.new()
	_dock.name = "Mapa do Mundo"
	_dock.plugin = self
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _dock)


func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
