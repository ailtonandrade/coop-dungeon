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
## Largura da moldura de metal em volta do mapa.
const FRAME := 9

var _viewport: SubViewport
var _camera: Camera3D
var _markers: Control
var _focus := Vector3.ZERO
var _yaw := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, FRAME)
	container.stretch = true
	container.modulate = Color(1, 1, 1, 0.85)
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIZE - FRAME * 2, SIZE - FRAME * 2)
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
	var scale_px := (SIZE - FRAME * 2) / RANGE
	return Vector2(SIZE, SIZE) / 2.0 + Vector2(rel.dot(basis.x), -rel.dot(basis.y)) * scale_px


func _direction_on_map(world_dir: Vector3) -> Vector2:
	var basis := _camera.global_basis
	return Vector2(world_dir.dot(basis.x), -world_dir.dot(basis.y)).normalized()


func _draw_markers() -> void:
	var inner := Rect2(Vector2(FRAME + 3, FRAME + 3), Vector2(SIZE - FRAME * 2 - 6, SIZE - FRAME * 2 - 6))
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
	_draw_frame()
	# Norte: fixo no topo no modo fixo; gira junto no modo rotativo.
	var north := _direction_on_map(Vector3.FORWARD)
	var n_pos := Vector2(SIZE, SIZE) / 2.0 + north * (SIZE / 2.0 - FRAME - 14.0)
	_markers.draw_circle(n_pos, 11.0, UiSkin.INK)
	_markers.draw_arc(n_pos, 11.0, 0.0, TAU, 20, UiSkin.BRASS, 2.0)
	_markers.draw_string(UiSkin.font("Bold"), n_pos + Vector2(-11, 6), "N", HORIZONTAL_ALIGNMENT_CENTER, 22, 16, UiSkin.AMBER)


## Moldura de metal rebitada por cima do mapa.
func _draw_frame() -> void:
	var outer := Rect2(Vector2.ZERO, Vector2(SIZE, SIZE))
	var band := outer.grow(-FRAME / 2.0)
	_markers.draw_rect(band, UiSkin.BRASS.darkened(0.3), false, FRAME)
	_markers.draw_rect(outer.grow(-1), UiSkin.INK, false, 2.0)
	_markers.draw_rect(outer.grow(-FRAME), UiSkin.INK, false, 2.0)
	_markers.draw_rect(outer.grow(-2.5), Color(UiSkin.BRASS.lightened(0.3), 0.7), false, 1.0)
	for corner: Vector2 in [Vector2(0, 0), Vector2(SIZE, 0), Vector2(SIZE, SIZE), Vector2(0, SIZE)]:
		var plate := Rect2(corner - Vector2(14, 14), Vector2(28, 28)).intersection(outer)
		_markers.draw_rect(plate, UiSkin.RUST.darkened(0.2))
		_markers.draw_rect(plate, UiSkin.INK, false, 1.5)
		var bolt := plate.get_center()
		_markers.draw_circle(bolt, 3.2, UiSkin.INK)
		_markers.draw_circle(bolt, 2.4, Color(0.85, 0.78, 0.62))
	# Filete de neon embaixo, como nos painéis.
	_markers.draw_line(Vector2(SIZE * 0.3, SIZE - 1.5), Vector2(SIZE * 0.7, SIZE - 1.5), UiSkin.NEON, 2.0)

func _local_players() -> Array[Player]:
	var local: Array[Player] = []
	for player: Player in get_tree().get_nodes_in_group("players"):
		if player.is_local():
			local.append(player)
	return local
