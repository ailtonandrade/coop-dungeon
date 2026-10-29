class_name Minimap
extends Control
## Minimapa: uma câmera de cima (ortográfica) desenha o terreno num SubViewport,
## e por cima vão os marcadores (heróis com a cor de cada um, inimigos em vermelho).
## Modo fixo: norte pra cima. Modo rotativo: gira para a frente do herói ficar pra cima.
## Segue o centro dos jogadores desta máquina, como a câmera principal.

const SIZE := 260
## Metros mostrados de uma borda à outra.
const RANGE := 44.0
## Camada de render só para o mundo; o rótulo P1-P4 dos heróis fica fora do minimapa.
const WORLD_LAYER := 1
const ENEMY_COLOR := Color(1.0, 0.25, 0.2)

var _viewport: SubViewport
var _camera: Camera3D
var _markers: Control
var _focus := Vector3.ZERO
var _yaw := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame := Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	style.border_color = Color(1, 1, 1, 0.7)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	frame.add_theme_stylebox_override("panel", style)
	add_child(frame)

	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	container.stretch = true
	container.modulate = Color(1, 1, 1, 0.85)
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIZE - 8, SIZE - 8)
	_viewport.positional_shadow_atlas_size = 0
	container.add_child(_viewport)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = RANGE
	_camera.far = 200.0
	_camera.cull_mask = WORLD_LAYER
	_viewport.add_child(_camera)

	_markers = Control.new()
	_markers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_markers.draw.connect(_draw_markers)
	add_child(_markers)


func _process(delta: float) -> void:
	var local := _local_players()
	if not local.is_empty():
		var center := Vector3.ZERO
		for player in local:
			center += player.global_position
		_focus = _focus.lerp(center / local.size(), 1.0 - exp(-8.0 * delta))
	var target_yaw := 0.0
	if Settings.minimap_mode == "rotating" and not local.is_empty():
		target_yaw = local[0].rotation.y
	_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-10.0 * delta))
	# Olhando reto pra baixo; girar em Y define o que fica "pra cima" no mapa.
	_camera.rotation = Vector3(-PI / 2.0, _yaw, 0.0)
	_camera.global_position = _focus + Vector3.UP * 80.0
	_markers.queue_redraw()


## Posição no mapa (pixels) de um ponto do mundo.
func _to_map(world_pos: Vector3) -> Vector2:
	var rel := world_pos - _focus
	var basis := _camera.global_basis
	var scale_px := (SIZE - 8) / RANGE
	return Vector2(SIZE, SIZE) / 2.0 + Vector2(rel.dot(basis.x), -rel.dot(basis.y)) * scale_px


func _direction_on_map(world_dir: Vector3) -> Vector2:
	var basis := _camera.global_basis
	return Vector2(world_dir.dot(basis.x), -world_dir.dot(basis.y)).normalized()


func _draw_markers() -> void:
	var inner := Rect2(Vector2(6, 6), Vector2(SIZE - 12, SIZE - 12))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var point := _to_map(enemy.global_position)
		if inner.has_point(point):
			_markers.draw_circle(point, 4.0, ENEMY_COLOR)
	for player: Player in get_tree().get_nodes_in_group("players"):
		var point := _to_map(player.global_position).clamp(inner.position, inner.end)
		var color := GameConfig.PLAYER_COLORS[player.index]
		if not player.is_targetable():
			_markers.draw_arc(point, 7.0, 0.0, TAU, 16, color, 2.0)
			continue
		var forward := _direction_on_map(-player.global_basis.z)
		var side := Vector2(-forward.y, forward.x)
		var tip := point + forward * 11.0
		var points := PackedVector2Array([tip, point - forward * 6.0 + side * 7.0, point - forward * 6.0 - side * 7.0])
		_markers.draw_colored_polygon(points, color)
		_markers.draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color.BLACK, 1.5)
	# Norte: fixo no topo no modo fixo; gira junto no modo rotativo.
	var north := _direction_on_map(Vector3.FORWARD)
	var n_pos := Vector2(SIZE, SIZE) / 2.0 + north * (SIZE / 2.0 - 18.0)
	_markers.draw_string(get_theme_default_font(), n_pos + Vector2(-6, 7), "N",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)


func _local_players() -> Array[Player]:
	var local: Array[Player] = []
	for player: Player in get_tree().get_nodes_in_group("players"):
		if player.is_local():
			local.append(player)
	return local
