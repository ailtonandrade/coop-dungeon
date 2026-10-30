@tool
extends ScrollContainer
## Painel "Mapa do Mundo" do editor: grade do mapa, blocos e masmorras, peças prontas,
## ligação de entradas, validação, navegação e "jogar a partir daqui".
## Toda a lógica fica no MapTools; aqui só a interface.

const DEFAULT_MAP := "res://world/test_world.tres"
const PREFAB_DIR := "res://world/prefabs"
const WORLD_SCENE := "res://world/world.tscn"
const DEBUG_SPAWN_FILE := "user://debug_spawn.json"

var plugin: EditorPlugin

var _map_path := DEFAULT_MAP
var _map: WorldMap
var _grid: MapGridView
var _info: Label
var _region: OptionButton
var _open_button: Button
var _create_button: Button
var _interiors: ItemList
var _interior_id: LineEdit
var _link_id: LineEdit
var _prefabs: ItemList
var _report: RichTextLabel


func _ready() -> void:
	custom_minimum_size = Vector2(280, 0)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	_header(box, "Mapa do mundo")
	_grid = MapGridView.new()
	_grid.cell_selected.connect(_on_cell_selected)
	_grid.cell_activated.connect(func(coords: Vector2i) -> void: _open_chunk(coords))
	box.add_child(_grid)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_info)
	_region = OptionButton.new()
	_region.item_selected.connect(_on_region_chosen)
	box.add_child(_region)
	var row := HBoxContainer.new()
	box.add_child(row)
	_open_button = _button(row, "Abrir bloco", func() -> void: _open_chunk(_grid.selected))
	_create_button = _button(row, "Criar bloco aqui", _create_chunk)
	_button(box, "Jogar a partir deste bloco", func() -> void: _play_from(_map.chunk_origin(_grid.selected) + Vector3(_map.chunk_size / 2, 0, _map.chunk_size / 2)))
	_button(box, "Regiões e ponto de partida (Inspetor)", func() -> void: EditorInterface.inspect_object(_map))

	_header(box, "Masmorras e interiores")
	_interiors = ItemList.new()
	_interiors.custom_minimum_size = Vector2(0, 90)
	_interiors.item_activated.connect(func(_i: int) -> void: _open_interior())
	box.add_child(_interiors)
	var interior_row := HBoxContainer.new()
	box.add_child(interior_row)
	_button(interior_row, "Abrir", _open_interior)
	_button(interior_row, "Jogar lá dentro", _play_inside)
	var new_row := HBoxContainer.new()
	box.add_child(new_row)
	_interior_id = LineEdit.new()
	_interior_id.placeholder_text = "id_da_masmorra"
	_interior_id.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_row.add_child(_interior_id)
	_button(new_row, "Nova masmorra", _create_interior)

	_header(box, "Entradas")
	var link_row := HBoxContainer.new()
	box.add_child(link_row)
	_link_id = LineEdit.new()
	_link_id.placeholder_text = "id da ligação"
	_link_id.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	link_row.add_child(_link_id)
	_button(link_row, "Ligar bloco ↔ masmorra", _link_entrances)
	_button(box, "Sincronizar entradas (depois de mover)", _sync_entrances)

	_header(box, "Peças prontas")
	_prefabs = ItemList.new()
	_prefabs.custom_minimum_size = Vector2(0, 140)
	_prefabs.item_activated.connect(func(_i: int) -> void: _insert_prefab())
	box.add_child(_prefabs)
	_button(box, "Inserir na cena aberta (centro da vista)", _insert_prefab)

	_header(box, "Manutenção")
	_button(box, "Validar mapa", _validate)
	_button(box, "Assar navegação de tudo", _bake_all)
	_report = RichTextLabel.new()
	_report.bbcode_enabled = true
	_report.fit_content = true
	_report.selection_enabled = true
	box.add_child(_report)

	_load_map()


## Mapa

func _load_map() -> void:
	_map = load(_map_path) as WorldMap
	_grid.map = _map
	_grid.refresh()
	_region.clear()
	for region in _map.regions:
		_region.add_item("%s (perigo %d)%s" % [region.display_name, region.danger, " · segura" if region.safe else ""])
		_region.set_item_metadata(_region.item_count - 1, region.id)
	_interiors.clear()
	for id: String in _map.interiors:
		_interiors.add_item(id)
	_prefabs.clear()
	for file in ResourceLoader.list_directory(PREFAB_DIR):
		if file.ends_with(".tscn"):
			_prefabs.add_item(file.get_basename().replace("_", " "))
			_prefabs.set_item_metadata(_prefabs.item_count - 1, PREFAB_DIR.path_join(file))
	_on_cell_selected(_grid.selected)


func _save_map() -> void:
	ResourceSaver.save(_map, _map_path)
	_grid.refresh()


func _on_cell_selected(coords: Vector2i) -> void:
	var exists := _map.chunks.has(coords)
	_open_button.disabled = not exists
	_create_button.disabled = exists
	if exists:
		var region := _map.region(_map.chunk_regions.get(coords, ""))
		_info.text = "Bloco %d, %d · %s" % [coords.x, coords.y, region.display_name if region else "sem região"]
		_select_region(_map.chunk_regions.get(coords, ""))
	else:
		_info.text = "Espaço vazio %d, %d: escolha a região e crie o bloco" % [coords.x, coords.y]


func _select_region(id: String) -> void:
	for i in _region.item_count:
		if _region.get_item_metadata(i) == id:
			_region.select(i)


func _on_region_chosen(index: int) -> void:
	if _map.chunks.has(_grid.selected):
		_map.chunk_regions[_grid.selected] = _region.get_item_metadata(index)
		_save_map()
		_on_cell_selected(_grid.selected)


func _create_chunk() -> void:
	if _region.selected < 0:
		_say("[color=orange]Escolha a região do bloco novo.[/color]")
		return
	var path := MapTools.create_chunk(_map, _map_path, _grid.selected, _region.get_item_metadata(_region.selected), self)
	EditorInterface.get_resource_filesystem().scan()
	_load_map()
	_say("Bloco criado: %s" % path)
	EditorInterface.open_scene_from_path(path)


func _open_chunk(coords: Vector2i) -> void:
	if _map.chunks.has(coords):
		EditorInterface.open_scene_from_path(_map.chunks[coords])


## Interiores

func _selected_interior() -> String:
	var picked := _interiors.get_selected_items()
	return _interiors.get_item_text(picked[0]) if not picked.is_empty() else ""


func _open_interior() -> void:
	var id := _selected_interior()
	if id:
		EditorInterface.open_scene_from_path(_map.interiors[id].path)


func _create_interior() -> void:
	var id := _interior_id.text.strip_edges().to_snake_case()
	if id.is_empty() or _region.selected < 0:
		_say("[color=orange]Dê um id e escolha a região da masmorra (lista de regiões acima).[/color]")
		return
	var path := MapTools.create_interior(_map, _map_path, id, _region.get_item_metadata(_region.selected), Vector2i(40, 40), self)
	EditorInterface.get_resource_filesystem().scan()
	_load_map()
	_say("Masmorra criada: %s" % path)
	EditorInterface.open_scene_from_path(path)


## Entradas

func _link_entrances() -> void:
	var id := _selected_interior()
	var link := _link_id.text.strip_edges().to_snake_case()
	if not _map.chunks.has(_grid.selected) or id.is_empty() or link.is_empty():
		_say("[color=orange]Selecione um bloco na grade, uma masmorra na lista e dê um id para a ligação.[/color]")
		return
	EditorInterface.save_all_scenes()
	var size: Vector3 = _map.interiors[id].size
	var center := Vector3(_map.chunk_size / 2, 0, _map.chunk_size / 2)
	var report := MapTools.add_entrance_pair(_map, _map.chunks[_grid.selected], center, link.capitalize(),
			_map.interiors[id].path, Vector3(size.x / 2, 0, size.z - 4), "Saída", link)
	_reload_open_scenes()
	_say("\n".join(report) + "\nAs entradas nasceram no meio do bloco e perto da parede da masmorra: mova cada uma para o lugar certo (o eixo azul aponta para onde o grupo sai) e clique em Sincronizar entradas.")


func _sync_entrances() -> void:
	EditorInterface.save_all_scenes()
	var report := MapTools.sync_entrances(_map)
	_reload_open_scenes()
	_say("\n".join(report) if not report.is_empty() else "Nenhuma entrada ligada no mapa.")


## Peças prontas

func _insert_prefab() -> void:
	var picked := _prefabs.get_selected_items()
	var root := EditorInterface.get_edited_scene_root()
	if picked.is_empty() or root == null:
		_say("[color=orange]Abra um bloco e escolha uma peça.[/color]")
		return
	var instance: Node3D = (load(_prefabs.get_item_metadata(picked[0])) as PackedScene).instantiate()
	# Sólidos entram na navegação das criaturas; NPCs e geradores podem ficar fora, mas não atrapalha.
	var parent: Node = root.get_node_or_null("Navigation") if root.has_node("Navigation") else root
	instance.position = _view_center_on_ground(root)
	var undo := plugin.get_undo_redo()
	undo.create_action("Inserir peça pronta")
	undo.add_do_method(parent, "add_child", instance, true)
	undo.add_do_property(instance, "owner", root)
	undo.add_do_reference(instance)
	undo.add_undo_method(parent, "remove_child", instance)
	undo.commit_action()
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(instance)


## Ponto do chão (y = 0) no centro da vista 3D do editor, em coordenadas da cena, em metros inteiros.
func _view_center_on_ground(root: Node3D) -> Vector3:
	var viewport := EditorInterface.get_editor_viewport_3d(0)
	var camera := viewport.get_camera_3d()
	if camera == null:
		return Vector3.ZERO
	var center := viewport.get_visible_rect().size / 2.0
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(center), camera.project_ray_normal(center))
	var point: Vector3 = hit if hit != null else Vector3.ZERO
	return (root.global_transform.affine_inverse() * point).round() * Vector3(1, 0, 1)


## Manutenção

func _validate() -> void:
	EditorInterface.save_all_scenes()
	var issues := MapTools.validate(_map)
	if issues.is_empty():
		_say("[color=green]Mapa sem problemas.[/color]")
		return
	var lines := PackedStringArray()
	for issue in issues:
		var color := "red" if issue.level == "erro" else "orange"
		lines.append("[color=%s]%s:[/color] %s" % [color, issue.level, issue.text])
	_say("\n".join(lines))


func _bake_all() -> void:
	EditorInterface.save_all_scenes()
	var lines := PackedStringArray()
	for path: String in MapTools.scenes_of(_map):
		lines.append("%s: %d polígonos" % [path.get_file(), MapTools.bake_scene(path, self)])
	_reload_open_scenes()
	_say("Navegação recalculada:\n" + "\n".join(lines))


## Jogar

func _play_inside() -> void:
	var id := _selected_interior()
	if id:
		var info: Dictionary = _map.interiors[id]
		_play_from(info.origin + Vector3(info.size.x / 2, 0, info.size.z / 2))


func _play_from(point: Vector3) -> void:
	EditorInterface.save_all_scenes()
	var file := FileAccess.open(DEBUG_SPAWN_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify([point.x, point.y, point.z]))
	file.close()
	EditorInterface.play_custom_scene(WORLD_SCENE)


## Peças de interface

func _reload_open_scenes() -> void:
	var scenes := MapTools.scenes_of(_map)
	for path in EditorInterface.get_open_scenes():
		if scenes.has(path):
			EditorInterface.reload_scene_from_path(path)


func _say(text: String) -> void:
	_report.text = text


func _header(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	parent.add_child(label)


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button
