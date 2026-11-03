class_name ClockBadge
extends HBoxContainer
## Relógio do mundo na HUD: ícone de sol (dia) ou lua (noite), desenhado, e a hora "18:42".

const ICON := 18.0

var _icon: Control
var _label: Label
var _night := false


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon = Control.new()
	_icon.custom_minimum_size = Vector2(ICON, ICON)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.draw.connect(_draw_icon)
	add_child(_icon)
	_label = UiSkin.label("", 17, UiSkin.TEXT, "SemiBold", 4)
	add_child(_label)


func _process(_delta: float) -> void:
	var clock := DayNight.of(get_tree())
	visible = clock != null
	if clock == null:
		return
	_label.text = clock.clock_text()
	if clock.is_night() != _night:
		_night = clock.is_night()
		_icon.queue_redraw()


func _draw_icon() -> void:
	var center := Vector2(ICON, ICON) / 2.0
	if _night:
		# Lua: um círculo claro com um "recorte" da cor do fundo deslocado.
		_icon.draw_circle(center, 7.0, Color(0.82, 0.87, 1.0))
		_icon.draw_circle(center + Vector2(3.5, -2.5), 6.0, Color(0.04, 0.05, 0.08))
	else:
		var sun := Color(1.0, 0.82, 0.35)
		for i in 8:
			var dir := Vector2.RIGHT.rotated(i * TAU / 8.0)
			_icon.draw_line(center + dir * 6.0, center + dir * 8.5, sun, 1.6)
		_icon.draw_circle(center, 4.5, sun)
