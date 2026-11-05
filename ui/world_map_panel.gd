class_name WorldMapPanel
extends Control
## Mapa completo (M no teclado, direcional ◀ no controle): a região inteira vista de cima, com
## norte para cima. Por cima: blocos com o nome da região, heróis, para onde ir nas missões do
## questLog, NPCs (com o serviço), abrigos dos jogadores (casinha) e a área deles.
## O terreno desenhado é o que está carregado em volta do grupo; o resto aparece como os blocos
## do mapa com o nome da região. Zoom: rodinha / gatilhos. Mover a vista: WASD / analógico.
## Fechar: M, Esc / B, ou direcional ◀ de novo.

const WORLD_LAYER := 1
const ZOOMS := [60.0, 110.0, 180.0, 280.0]
const QUEST_COLOR := Color(1.0, 0.8, 0.28)
const BASE_COLOR := Color(0.45, 1.0, 0.85)
const NPC_COLOR := Color(0.75, 1.0, 0.75)

var slot := -1
var _zoom := 1
var _center := Vector3.ZERO
var _viewport: SubViewport
var _camera: Camera3D
var _markers: Control
var _map_rect := Rect2()


func open_for(p_slot: int) -> void:
	slot = p_slot
	InputService.set_blocked(slot, true)
	var player := _player()
	if player:
		_center = player.global_position
	Sound.play("ui_confirm")


func close() -> void:
	InputService.set_blocked(slot, false)
	Sound.play("ui_back")
	queue_free()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.025, 0.035, 0.92)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.positional_shadow_atlas_size = 0
	container.add_child(_viewport)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.far = 400.0
	_camera.cull_mask = WORLD_LAYER
	_viewport.add_child(_camera)
	_markers = Control.new()
	_markers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_markers.draw.connect(_draw_markers)
	add_child(_markers)
	resized.connect(_layout)
	_layout.call_deferred()


func _layout() -> void:
	var side := minf(size.x - 80.0, size.y - 140.0)
	_map_rect = Rect2((size - Vector2(side, side)) / 2.0 + Vector2(0, 20), Vector2(side, side))
	var container := _viewport.get_parent() as Control
	container.position = _map_rect.position
	container.size = _map_rect.size
	_viewport.size = Vector2i(_map_rect.size)


func _process(delta: float) -> void:
	var range_m: float = ZOOMS[_zoom]
	var move := InputService.raw_move(slot)
	_center += Vector3(move.x, 0.0, move.y) * range_m * 0.6 * delta
	if InputService.back_just_pressed(slot) or InputService.raw_just_pressed(slot, InputService.Action.PAUSE):
		close()
		return
	if InputService.raw_just_pressed(slot, InputService.Action.RANGED) or InputService.raw_just_pressed(slot, InputService.Action.ARTIFACT):
		_zoom = maxi(_zoom - 1, 0)
	if InputService.raw_just_pressed(slot, InputService.Action.SPRINT) or InputService.raw_just_pressed(slot, InputService.Action.POTION):
		_zoom = mini(_zoom + 1, ZOOMS.size() - 1)
	_camera.size = ZOOMS[_zoom]
	_camera.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	_camera.global_position = _center + Vector3.UP * 150.0
	_markers.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxi(_zoom - 1, 0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = mini(_zoom + 1, ZOOMS.size() - 1)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var meters_per_px: float = ZOOMS[_zoom] / _map_rect.size.x
		_center -= Vector3(event.relative.x, 0.0, event.relative.y) * meters_per_px


## Ponto do mundo -> tela (norte para cima: -Z do mundo é para cima).
func _to_screen(world_pos: Vector3) -> Vector2:
	var scale_px: float = _map_rect.size.x / ZOOMS[_zoom]
	return _map_rect.get_center() + Vector2(world_pos.x - _center.x, world_pos.z - _center.z) * scale_px


func _draw_markers() -> void:
	var font := UiSkin.font("Bold")
	var regular := UiSkin.font("Regular")
	var inner := _map_rect
	# Blocos do mapa com o nome da região (aparece até onde o terreno não está carregado).
	var streamer := get_tree().get_first_node_in_group("world_streamer")
	var world_map: WorldMap = streamer.world_map if streamer else null
	if world_map:
		for coords: Vector2i in world_map.chunks.keys():
			var origin := world_map.chunk_origin(coords) if world_map.has_method("chunk_origin") else Vector3(coords.x, 0, coords.y) * world_map.chunk_size
			var a := _to_screen(origin)
			var b := _to_screen(origin + Vector3(world_map.chunk_size, 0, world_map.chunk_size))
			var cell := Rect2(a, b - a)
			if not cell.intersects(inner):
				continue
			cell = cell.intersection(inner)
			_markers.draw_rect(cell, Color(1, 1, 1, 0.08), false, 1.0)
			var region: RegionDef = world_map.region(world_map.chunk_regions.get(coords, ""))
			if region and cell.size.x > 60:
				var color := Color(region.color, 0.55)
				_markers.draw_string_outline(regular, cell.position + Vector2(6, 18), Txt.t(region.display_name), HORIZONTAL_ALIGNMENT_LEFT, cell.size.x - 8, 14, 4, UiSkin.INK)
				_markers.draw_string(regular, cell.position + Vector2(6, 18), Txt.t(region.display_name), HORIZONTAL_ALIGNMENT_LEFT, cell.size.x - 8, 14, color)
	# Abrigos: área e casinha.
	for key: String in BaseManager.bases():
		var base: Dictionary = BaseManager.bases()[key]
		var center := BaseManager.center_of(base)
		var point := _to_screen(center)
		var radius: float = BaseCatalog.BASE_RADIUS * _map_rect.size.x / ZOOMS[_zoom]
		if inner.grow(radius).has_point(point):
			_markers.draw_arc(point, radius, 0.0, TAU, 48, Color(BASE_COLOR, 0.6), 2.0)
		if inner.has_point(point):
			draw_house(_markers, point, 11.0, BASE_COLOR)
			var label := Txt.t("Abrigo de %s") % String(base.get("name", ""))
			_markers.draw_string_outline(font, point + Vector2(-80, 26), label, HORIZONTAL_ALIGNMENT_CENTER, 160, 13, 4, UiSkin.INK)
			_markers.draw_string(font, point + Vector2(-80, 26), label, HORIZONTAL_ALIGNMENT_CENTER, 160, 13, BASE_COLOR)
	# NPCs (de todos os blocos, mesmo os não carregados).
	var places: Dictionary = Quests._places_map()
	for npc_name: String in places.get("npcs", {}):
		var point := _to_screen(places.npcs[npc_name])
		if inner.has_point(point):
			_markers.draw_circle(point, 5.0, UiSkin.INK)
			_markers.draw_circle(point, 3.5, NPC_COLOR)
			_markers.draw_string_outline(regular, point + Vector2(-70, -9), npc_name, HORIZONTAL_ALIGNMENT_CENTER, 140, 12, 4, UiSkin.INK)
			_markers.draw_string(regular, point + Vector2(-70, -9), npc_name, HORIZONTAL_ALIGNMENT_CENTER, 140, 12, NPC_COLOR)
	# Para onde ir nas missões.
	var player := _player()
	var from := player.global_position if player else _center
	for quest in Quests.tracked():
		var target: Variant = Quests.target_of(quest, from)
		if not target is Vector3:
			continue
		var point := _to_screen(target).clamp(inner.position + Vector2(10, 10), inner.end - Vector2(10, 10))
		var r := 8.0
		var diamond := PackedVector2Array([point + Vector2(0, -r), point + Vector2(r, 0), point + Vector2(0, r), point + Vector2(-r, 0)])
		_markers.draw_colored_polygon(diamond, QUEST_COLOR)
		_markers.draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color.BLACK, 1.5)
		_markers.draw_string_outline(regular, point + Vector2(-90, 22), Txt.t(quest.title), HORIZONTAL_ALIGNMENT_CENTER, 180, 12, 4, UiSkin.INK)
		_markers.draw_string(regular, point + Vector2(-90, 22), Txt.t(quest.title), HORIZONTAL_ALIGNMENT_CENTER, 180, 12, QUEST_COLOR)
	# Heróis.
	for hero: Player in get_tree().get_nodes_in_group("players"):
		var point := _to_screen(hero.global_position)
		if not inner.has_point(point):
			continue
		var color := GameConfig.PLAYER_COLORS[hero.index]
		var forward := Vector2(-hero.global_basis.z.x, -hero.global_basis.z.z).normalized()
		var side := Vector2(-forward.y, forward.x)
		var points := PackedVector2Array([point + forward * 12.0, point - forward * 7.0 + side * 8.0, point - forward * 7.0 - side * 8.0])
		_markers.draw_colored_polygon(points, color)
		_markers.draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color.BLACK, 1.5)
	# Moldura, título e dicas.
	_markers.draw_rect(inner, UiSkin.BRASS.darkened(0.2), false, 3.0)
	var title := Txt.t("MAPA")
	_markers.draw_string_outline(font, Vector2(0, inner.position.y - 18), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, 6, UiSkin.INK)
	_markers.draw_string(font, Vector2(0, inner.position.y - 18), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, UiSkin.AMBER)
	var keyboard := InputService.device_of(slot) == InputService.KEYBOARD
	var hint := Txt.t("WASD / arrastar move · rodinha zoom · M ou Esc fecha") if keyboard else Txt.t("analógico move · RT / LB zoom · ◀ ou B fecha")
	_markers.draw_string(regular, Vector2(0, inner.end.y + 26), hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, UiSkin.DIM)


## Casinha (abrigo) no mapa e no minimapa.
static func draw_house(canvas: CanvasItem, at: Vector2, r: float, color: Color) -> void:
	var body := Rect2(at + Vector2(-r * 0.7, -r * 0.1), Vector2(r * 1.4, r * 0.9))
	var roof := PackedVector2Array([at + Vector2(-r, -r * 0.05), at + Vector2(0, -r), at + Vector2(r, -r * 0.05)])
	canvas.draw_rect(body.grow(1.5), UiSkin.INK)
	canvas.draw_colored_polygon(PackedVector2Array([roof[0] + Vector2(-1.5, 1), roof[1] + Vector2(0, -2), roof[2] + Vector2(1.5, 1)]), UiSkin.INK)
	canvas.draw_rect(body, color)
	canvas.draw_colored_polygon(roof, color.darkened(0.25))
	canvas.draw_rect(Rect2(at + Vector2(-r * 0.18, r * 0.3), Vector2(r * 0.36, r * 0.5)), UiSkin.INK)


func _player() -> Player:
	for candidate: Player in get_tree().get_nodes_in_group("players"):
		if candidate.is_local() and candidate.slot == slot:
			return candidate
	return null
