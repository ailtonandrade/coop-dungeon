@tool
class_name MapGridView
extends Control
## Grade do mapa inteiro no painel do editor: cada bloco na cor da região, mais uma volta de
## espaços vazios em torno (onde dá para criar blocos novos). Clique seleciona; clique duplo abre.

signal cell_selected(coords: Vector2i)
signal cell_activated(coords: Vector2i)

const CELL := 30.0

var map: WorldMap
var selected := Vector2i(0, 0)

var _min := Vector2i.ZERO
var _max := Vector2i.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func refresh() -> void:
	_min = Vector2i.ZERO
	_max = Vector2i.ZERO
	if map and not map.chunks.is_empty():
		var first := true
		for coords: Vector2i in map.chunks:
			_min = coords if first else Vector2i(mini(_min.x, coords.x), mini(_min.y, coords.y))
			_max = coords if first else Vector2i(maxi(_max.x, coords.x), maxi(_max.y, coords.y))
			first = false
	_min -= Vector2i.ONE
	_max += Vector2i.ONE
	custom_minimum_size = Vector2(_max - _min + Vector2i.ONE) * CELL + Vector2(2, 2)
	queue_redraw()


func _draw() -> void:
	if map == null:
		return
	var font := get_theme_default_font()
	for x in range(_min.x, _max.x + 1):
		for z in range(_min.y, _max.y + 1):
			var coords := Vector2i(x, z)
			var rect := Rect2(_to_screen(coords), Vector2(CELL, CELL)).grow(-1)
			if map.chunks.has(coords):
				var region := map.region(map.chunk_regions.get(coords, ""))
				var color := region.color.darkened(0.45) if region else Color(0.4, 0.1, 0.1)
				draw_rect(rect, color)
				if region and region.safe:
					draw_rect(rect.grow(-4), Color(1, 1, 1, 0.35), false, 1.0)
			else:
				draw_rect(rect, Color(1, 1, 1, 0.06))
				draw_rect(rect, Color(1, 1, 1, 0.15), false, 1.0)
			draw_string(font, rect.position + Vector2(2, 11), "%d,%d" % [x, z], HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
					Color(1, 1, 1, 0.7))
			if coords == selected:
				draw_rect(rect, Color.WHITE, false, 2.0)
	# Ponto de partida do grupo.
	if map:
		var spawn := map.chunk_at(map.spawn_point)
		draw_circle(_to_screen(spawn) + Vector2(CELL, CELL) / 2.0, 4.0, Color(1.0, 0.9, 0.3))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var coords := Vector2i((event.position / CELL).floor()) + _min
		selected = coords
		queue_redraw()
		if event.double_click:
			cell_activated.emit(coords)
		else:
			cell_selected.emit(coords)


func _to_screen(coords: Vector2i) -> Vector2:
	return Vector2(coords - _min) * CELL
