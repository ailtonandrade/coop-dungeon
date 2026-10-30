@tool
extends EditorPlugin
## Liga o painel "Itens" no editor (lado esquerdo, junto da Cena).

const Dock := preload("res://addons/item_editor/item_dock.gd")

var _dock: Control
var _scroll: ScrollContainer


func _enter_tree() -> void:
	_dock = Dock.new()
	_dock.plugin = self
	_dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# O painel é comprido: rola dentro da aba.
	_scroll = ScrollContainer.new()
	_scroll.name = "Itens"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.add_child(_dock)
	add_control_to_dock(DOCK_SLOT_LEFT_UR, _scroll)


func _exit_tree() -> void:
	if _scroll:
		remove_control_from_docks(_scroll)
		_scroll.queue_free()
		_scroll = null
		_dock = null
