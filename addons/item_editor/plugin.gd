@tool
extends EditorPlugin
## Liga o painel "Itens" no editor (lado esquerdo, junto da Cena).

const Dock := preload("res://addons/item_editor/item_dock.gd")

var _dock: Control


func _enter_tree() -> void:
	_dock = Dock.new()
	_dock.name = "Itens"
	_dock.plugin = self
	add_control_to_dock(DOCK_SLOT_LEFT_UR, _dock)


func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
