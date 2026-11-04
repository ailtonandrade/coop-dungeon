class_name Crosshair
extends Control
## Mira no meio da tela, só na câmera atrás do herói: um círculo pequeno com um ponto no meio
## (contorno escuro para aparecer em qualquer fundo). Fica vermelha em cima de uma criatura.

const RADIUS := 9.0
const NORMAL := Color(1.0, 1.0, 1.0, 0.9)
const ENEMY := Color(1.0, 0.3, 0.25, 0.95)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	var show := InputService.behind_view and not InputService.screen_menu_open
	if show != visible:
		visible = show
	if visible:
		queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var color := ENEMY if InputService.aim_on_enemy else NORMAL
	draw_arc(center, RADIUS, 0.0, TAU, 32, Color(0, 0, 0, 0.6), 4.0, true)
	draw_arc(center, RADIUS, 0.0, TAU, 32, color, 2.0, true)
	draw_circle(center, 2.6, Color(0, 0, 0, 0.6))
	draw_circle(center, 1.6, color)
