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
var _preview: SubViewportContainer
var _ficha: ConfirmationDialog
var _file_dialog: EditorFileDialog
var _pending_import := ""
var _pending_category := ""
## Importação de pasta inteira: [[caminho res://, categoria]] esperando o Godot importar.
var _pending_batch: Array = []
var _category_filter: OptionButton
var _dir_dialog: EditorFileDialog
var _stamp_button: Button
var _vary: CheckBox
var _report: RichTextLabel

## Modo carimbo: cada clique na vista 3D coloca a peça escolhida ali (o plugin repassa o clique).
var stamping := false


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
	_category_filter = OptionButton.new()
	_category_filter.tooltip_text = "Categorias = subpastas de world/prefabs (mova as peças no FileSystem para organizar)."
	_category_filter.item_selected.connect(func(_i: int) -> void: _refresh_prefabs())
	box.add_child(_category_filter)
	_prefabs = ItemList.new()
	_prefabs.custom_minimum_size = Vector2(0, 220)
	_prefabs.max_columns = 0
	_prefabs.same_column_width = true
	_prefabs.fixed_column_width = 84
	_prefabs.icon_mode = ItemList.ICON_MODE_TOP
	_prefabs.fixed_icon_size = Vector2i(64, 64)
	_prefabs.item_activated.connect(func(_i: int) -> void: _insert_prefab())
	_prefabs.item_selected.connect(func(i: int) -> void: _preview.show_scene(_prefabs.get_item_metadata(i)))
	box.add_child(_prefabs)
	_preview = preload("res://addons/map_editor/prop_preview.gd").new()
	box.add_child(_preview)
	var prop_row := HBoxContainer.new()
	box.add_child(prop_row)
	_button(prop_row, "Importar objeto 3D…", _ask_import)
	_button(prop_row, "Ficha da peça…", _open_ficha)
	var import_dir := _button(box, "Importar pasta inteira… (cada pasta vira categoria)", func() -> void: _dir_dialog.popup_file_dialog())
	import_dir.tooltip_text = "Importa todos os .obj/.glb/.gltf/.fbx da pasta e das subpastas como peças fixas, cada pasta virando uma categoria. Depois ajuste a ficha das que forem físicas, contêineres ou enfeites."
	_ficha = preload("res://addons/map_editor/prop_ficha.gd").new()
	_ficha.saved.connect(_on_ficha_saved)
	add_child(_ficha)
	_file_dialog = EditorFileDialog.new()
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	_file_dialog.title = "Escolha um modelo 3D (.obj, .glb, .gltf, .fbx)"
	_file_dialog.add_filter("*.obj, *.glb, *.gltf, *.fbx", "Modelos 3D")
	_file_dialog.file_selected.connect(_import_model)
	add_child(_file_dialog)
	_dir_dialog = EditorFileDialog.new()
	_dir_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	_dir_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	_dir_dialog.title = "Escolha a pasta com os modelos 3D"
	_dir_dialog.dir_selected.connect(_import_folder)
	add_child(_dir_dialog)
	_stamp_button = _button(box, "Colocar clicando na vista (carimbo)", func() -> void: set_stamping(not stamping))
	_stamp_button.toggle_mode = true
	_stamp_button.tooltip_text = "Cada clique esquerdo na vista 3D coloca a peça escolhida no chão (ou em cima do que estiver lá). Clique direito ou este botão de novo para parar."
	_vary = CheckBox.new()
	_vary.text = "Variar giro e tamanho (mato, pedras, lixo)"
	_vary.button_pressed = true
	box.add_child(_vary)
	_button(box, "Inserir no centro da vista", _insert_prefab)

	_header(box, "Manutenção")
	_button(box, "Validar mapa", _validate)
	_button(box, "Tirar a película azul (navegação salva)", _clear_baked_all)
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
	_refresh_prefabs()
	_on_cell_selected(_grid.selected)


func _refresh_prefabs(select_path := "") -> void:
	var catalog := PropBuilder.catalog()
	# Filtro de categoria: mantém a escolhida (ou vai para a da peça recém-salva).
	var wanted := _category_filter.get_item_text(_category_filter.selected) if _category_filter.selected > 0 else ""
	if select_path:
		wanted = PropBuilder.category_of(select_path)
	_category_filter.clear()
	_category_filter.add_item("Todas as categorias")
	for category in PropBuilder.categories(catalog):
		_category_filter.add_item(category)
		if category == wanted:
			_category_filter.select(_category_filter.item_count - 1)
	_prefabs.clear()
	for entry: Dictionary in catalog:
		if _category_filter.selected > 0 and entry.category != _category_filter.get_item_text(_category_filter.selected):
			continue
		var label: String = entry.name
		if entry.kind:
			label += "\n(%s)" % {"fixo": "fixo", "conteiner": "contêiner", "fisico": "físico", "atravessavel": "enfeite"}[entry.kind]
		var index := _prefabs.add_item(label)
		_prefabs.set_item_metadata(index, entry.path)
		_prefabs.set_item_tooltip(index, "%s\n%s" % [entry.path, entry.def.kind_name() if entry.def else "peça montada à mão"])
		EditorInterface.get_resource_previewer().queue_resource_preview(entry.path, self, "_on_prefab_preview", index)
		if entry.path == select_path:
			_prefabs.select(index)
			_preview.show_scene(entry.path)


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

func _on_prefab_preview(_path: String, preview: Texture2D, _thumbnail: Texture2D, index: int) -> void:
	if preview and index < _prefabs.item_count:
		_prefabs.set_item_icon(index, preview)


## Objetos 3D próprios

func _ask_import() -> void:
	_file_dialog.popup_file_dialog()


## Traz o modelo para dentro do projeto (com .mtl/texturas/.bin ao lado), espera o Godot
## importar e abre a ficha.
func _import_model(file: String) -> void:
	var res_path := ProjectSettings.localize_path(file)
	if not res_path.begins_with("res://"):
		res_path = PropImport.copy_into_project(file)
		if res_path.is_empty():
			_say("[color=red]Não deu para copiar o modelo para dentro do projeto.[/color]")
			return
	_pending_import = res_path
	_pending_category = PropImport.category_from(file)
	_say("Importando %s..." % res_path.get_file())
	EditorInterface.get_resource_filesystem().scan()
	_wait_import()


func _wait_import(tries := 0) -> void:
	if _pending_import.is_empty():
		return
	var model: Resource = load(_pending_import) if ResourceLoader.exists(_pending_import) else null
	if model == null:
		if tries > 60:
			_say("[color=red]O Godot não conseguiu importar %s.[/color]" % _pending_import.get_file())
			_pending_import = ""
			return
		get_tree().create_timer(0.5).timeout.connect(_wait_import.bind(tries + 1))
		return
	var stem := _pending_import.get_file().get_basename()
	_pending_import = ""
	var def := PropDef.new()
	def.model = model
	def.display_name = stem.replace("_", " ")
	def.id = PropImport.free_id(PropBuilder.id_from(stem))
	def.scale = PropImport.suggest_scale(def)
	_ficha.edit(def, _pending_category)
	_say("Modelo importado. Preencha a ficha e salve: a peça aparece na lista.")


## Importa todos os modelos da pasta (e subpastas) como peças fixas, cada pasta virando categoria.
func _import_folder(dir: String) -> void:
	var models := PropImport.models_in(dir)
	if models.is_empty():
		_say("[color=orange]Nenhum .obj/.glb/.gltf/.fbx nessa pasta.[/color]")
		return
	_pending_batch = []
	for pair: Array in models:
		var res_path := ProjectSettings.localize_path(pair[0])
		if not res_path.begins_with("res://"):
			res_path = PropImport.copy_into_project(pair[0])
		if not res_path.is_empty():
			_pending_batch.append([res_path, pair[1]])
	_say("Importando %d modelos..." % _pending_batch.size())
	EditorInterface.get_resource_filesystem().scan()
	_wait_batch()


func _wait_batch(tries := 0) -> void:
	var missing := _pending_batch.filter(func(pair: Array) -> bool: return not ResourceLoader.exists(pair[0]))
	if not missing.is_empty() and tries < 120:
		get_tree().create_timer(0.5).timeout.connect(_wait_batch.bind(tries + 1))
		return
	var made := 0
	var last := ""
	for pair: Array in _pending_batch:
		var model: Resource = load(pair[0]) if ResourceLoader.exists(pair[0]) else null
		if model == null:
			continue
		var stem: String = pair[0].get_file().get_basename()
		var def := PropDef.new()
		def.model = model
		def.display_name = stem.replace("_", " ")
		def.id = PropImport.free_id(PropBuilder.id_from(stem))
		def.scale = PropImport.suggest_scale(def)
		var saved := PropBuilder.save(def, pair[1])
		if saved:
			made += 1
			last = saved
	_pending_batch = []
	EditorInterface.get_resource_filesystem().scan()
	_refresh_prefabs(last)
	_say("%d peças criadas (fixas), cada pasta virou uma categoria. Ajuste a ficha das que forem físicas, contêineres ou enfeites." % made)


func _open_ficha() -> void:
	var picked := _prefabs.get_selected_items()
	if picked.is_empty():
		_say("[color=orange]Escolha uma peça na lista.[/color]")
		return
	var path: String = _prefabs.get_item_metadata(picked[0])
	var def := PropImport.def_for_prefab(path)
	if def == null:
		_say("[color=orange]Esta peça é montada por partes (casa, árvore, NPC...): não tem ficha. Fichas valem para peças de um modelo só.[/color]")
		return
	_ficha.edit(def)


func _on_ficha_saved(prefab_path: String) -> void:
	if prefab_path.is_empty():
		_say("[color=red]Não deu para salvar a peça (falta nome ou modelo).[/color]")
		return
	EditorInterface.get_resource_filesystem().scan()
	_reload_open_scenes_using(prefab_path)
	_refresh_prefabs(prefab_path)
	_say("Peça salva: %s. Já dá para carimbar no mapa (e no modo construtor do jogo)." % prefab_path)


## Cenas abertas que usam a peça recarregam para mostrar a versão nova.
func _reload_open_scenes_using(prefab_path: String) -> void:
	for path in EditorInterface.get_open_scenes():
		if FileAccess.file_exists(path) and FileAccess.get_file_as_string(path).contains(prefab_path):
			EditorInterface.reload_scene_from_path(path)


func set_stamping(on: bool) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if on and (root == null or _prefabs.get_selected_items().is_empty()):
		_say("[color=orange]Abra um bloco e escolha uma peça para carimbar.[/color]")
		on = false
	stamping = on
	_stamp_button.set_pressed_no_signal(on)
	_stamp_button.text = "Parar de carimbar (clique direito)" if on else "Colocar clicando na vista (carimbo)"
	if on:
		# O editor só repassa os cliques da vista para o plugin com algo selecionado.
		EditorInterface.get_selection().clear()
		EditorInterface.get_selection().add_node(root)
		_say("Carimbo ligado: clique na vista 3D para colocar \"%s\"." % _prefabs.get_item_text(_prefabs.get_selected_items()[0]))


## Carimbo: coloca a peça escolhida onde o clique bate (no que tiver colisão, ou no chão y = 0).
func stamp_at(camera: Camera3D, screen_point: Vector2) -> void:
	var root := EditorInterface.get_edited_scene_root() as Node3D
	if root == null or _prefabs.get_selected_items().is_empty():
		set_stamping(false)
		return
	var point: Variant = _ground_hit(camera, camera.project_ray_origin(screen_point), camera.project_ray_normal(screen_point), root)
	if point == null:
		return
	var local: Vector3 = root.global_transform.affine_inverse() * point
	_place_prefab(root, local.snapped(Vector3(0.1, 0.05, 0.1)), _vary.button_pressed)


## Onde um raio bate: no que tiver colisão (chão com relevo, caixas) ou no plano do chão do bloco.
func _ground_hit(camera: Camera3D, from: Vector3, direction: Vector3, root: Node3D, reach := 500.0) -> Variant:
	var space := camera.get_world_3d().direct_space_state
	if space:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + direction * reach))
		if not hit.is_empty():
			return hit.position
	var point: Variant = Plane(Vector3.UP, root.global_position.y).intersects_ray(from, direction)
	if point != null and from.distance_to(point) > reach:
		return null
	return point


func _insert_prefab() -> void:
	var root := EditorInterface.get_edited_scene_root() as Node3D
	if _prefabs.get_selected_items().is_empty() or root == null:
		_say("[color=orange]Abra um bloco e escolha uma peça.[/color]")
		return
	var camera := _editor_camera()
	if camera == null:
		_say("[color=orange]Abra a vista 3D do bloco.[/color]")
		return
	var point := _insert_point(camera, root)
	var local: Vector3 = root.global_transform.affine_inverse() * point
	# De frente para quem está olhando (de 15 em 15 graus).
	var to_camera := camera.global_position - point
	var yaw := snappedf(atan2(to_camera.x, to_camera.z), deg_to_rad(15.0)) if Vector2(to_camera.x, to_camera.z).length() > 0.01 else 0.0
	_place_prefab(root, local.snapped(Vector3(0.1, 0.05, 0.1)), false, yaw - root.global_rotation.y)


func _place_prefab(root: Node3D, position: Vector3, vary: bool, yaw := 0.0) -> void:
	var picked := _prefabs.get_selected_items()
	var instance: Node3D = (load(_prefabs.get_item_metadata(picked[0])) as PackedScene).instantiate()
	# Sólidos entram na navegação das criaturas; NPCs e geradores podem ficar fora, mas não atrapalha.
	var parent: Node = root.get_node_or_null("Navigation") if root.has_node("Navigation") else root
	instance.position = position
	instance.rotation.y = yaw
	if vary:
		instance.rotation.y = randf() * TAU
		# NPC, baú, gerador e entrada não mudam de tamanho.
		if not (instance is WorldNpc or instance is LootContainer or instance is Entrance or instance.get("respawn_time") != null):
			instance.scale = Vector3.ONE * randf_range(0.85, 1.2)
	var undo := plugin.get_undo_redo()
	undo.create_action("Inserir peça pronta")
	undo.add_do_method(parent, "add_child", instance, true)
	undo.add_do_property(instance, "owner", root)
	undo.add_do_reference(instance)
	undo.add_undo_method(parent, "remove_child", instance)
	undo.commit_action()
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(instance)
	if not stamping:
		_say("Peça colocada em (%.1f, %.1f, %.1f). Depois de arrumar o bloco: Ctrl+S (a navegação das criaturas o jogo calcula sozinho)." % [position.x, position.y, position.z])


## Até onde o centro da vista vale; mais longe que isso (ou olhando para o céu), a peça cai no
## chão abaixo desse ponto da linha do centro, ainda na tela. A câmera do editor gira em volta de um ponto fixo: girar e dar zoom não
## mudam o centro, então só o centro levaria a peça para longe de onde se está olhando.
const INSERT_REACH := 15.0


func _editor_camera() -> Camera3D:
	var viewport := EditorInterface.get_editor_viewport_3d(0)
	return viewport.get_camera_3d() if viewport else null


## Onde "Inserir no centro da vista" põe a peça (coordenadas globais): o chão no centro da vista,
## se estiver perto; senão, o chão abaixo da linha do centro, a INSERT_REACH da câmera.
func _insert_point(camera: Camera3D, root: Node3D) -> Vector3:
	var center := camera.get_viewport().get_visible_rect().size / 2.0
	var from := camera.project_ray_origin(center)
	var hit: Variant = _ground_hit(camera, from, camera.project_ray_normal(center), root, INSERT_REACH)
	if hit != null:
		return hit
	# Anda pela linha do centro da vista até INSERT_REACH e desce dali até o chão (com relevo).
	var ahead := from + camera.project_ray_normal(center) * INSERT_REACH
	var top := Vector3(ahead.x, maxf(camera.global_position.y, root.global_position.y) + 50.0, ahead.z)
	var ground: Variant = _ground_hit(camera, top, Vector3.DOWN, root, 200.0)
	return ground if ground != null else Vector3(ahead.x, root.global_position.y, ahead.z)


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


## O jogo calcula a navegação das criaturas ao carregar cada bloco; malha salva na cena só
## deixa a película azul por cima no editor.
func _clear_baked_all() -> void:
	EditorInterface.save_all_scenes()
	var cleared := 0
	for path: String in MapTools.scenes_of(_map):
		if MapTools.clear_baked(path):
			cleared += 1
	_reload_open_scenes()
	_say("Navegação salva tirada de %d cena(s). O jogo calcula sozinho ao carregar cada bloco." % cleared)


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
