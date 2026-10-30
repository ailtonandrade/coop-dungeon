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


## Modo carimbo do painel: o plugin recebe os cliques da vista 3D enquanto ele está ligado.
func _handles(object: Object) -> bool:
	return _dock != null and _dock.stamping and object is Node


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if _dock == null or not _dock.stamping:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dock.stamp_at(camera, event.position)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dock.set_stamping(false)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_dock.set_stamping(false)
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
