class_name WorldStreamer
extends Node3D
## Carrega em segundo plano os blocos do mapa em volta de cada jogador e descarrega os longe.
## - Host (ou offline): em volta de TODOS os jogadores, porque ele simula o mundo inteiro.
## - Cliente: só em volta dos jogadores desta máquina (o resto ele não precisa desenhar).
## Interiores (masmorras) carregam quando alguém está dentro deles.
##
## Borda do mapa: lado de bloco sem vizinho ganha uma parede invisível alta ao carregar.
## Assim os blocos não guardam borda nenhuma, e o mapa cresce só criando blocos novos ao lado.
##
## Garantia: o bloco onde um jogador está fica pronto antes da física rodar nele.
## O primeiro carregamento e o destino de um teleporte são carregados na hora (load_now);
## os vizinhos chegam em segundo plano antes de alguém andar até eles.

signal chunk_loaded(key: String)
signal chunk_unloaded(key: String)

## Blocos em volta de cada jogador que ficam carregados (1 = 3x3).
const LOAD_RADIUS := 1
## Só descarrega quando passa disso (folga para não carregar e descarregar na borda).
const UNLOAD_RADIUS := 2
const EDGE_WALL_HEIGHT := 6.0

@export var world_map: WorldMap

var _loaded := {}   # chave -> Node3D
var _loading := {}  # chave -> caminho sendo carregado em segundo plano


static func of(node: Node) -> WorldStreamer:
	return node.get_tree().get_first_node_in_group("world_streamer") if node.is_inside_tree() else null


func _ready() -> void:
	add_to_group("world_streamer")


func loaded_keys() -> Array:
	return _loaded.keys()


func is_loaded(key: String) -> bool:
	return _loaded.has(key)


## Tem chão carregado embaixo de `position`?
func is_ready_at(position: Vector3) -> bool:
	return _loaded.has(_key_at(position))


func region_at(position: Vector3) -> RegionDef:
	return world_map.region_at(position) if world_map else null


## Carrega já (sem esperar) o que existe em volta de `position`. Usado no começo e antes
## de teleportar alguém para longe (entrada de masmorra).
func load_now(position: Vector3) -> void:
	for key in _wanted_around(position, 0):
		_load_sync(key)
	for key in _wanted_around(position, LOAD_RADIUS):
		_request(key)


func _physics_process(_delta: float) -> void:
	if world_map == null:
		return
	var anchors := _anchors()
	var wanted := {}
	for anchor in anchors:
		for key in _wanted_around(anchor, LOAD_RADIUS):
			wanted[key] = true
		# O bloco onde o jogador está não pode esperar o segundo plano.
		_load_sync(_key_at(anchor))
	for key: String in wanted:
		_request(key)
	_finish_loads()
	if anchors.is_empty():
		return
	for key: String in _loaded.keys():
		if not _within(key, anchors, UNLOAD_RADIUS):
			_unload(key)


func _anchors() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for player: Player in get_tree().get_nodes_in_group("players"):
		if multiplayer.is_server() or player.is_local():
			result.append(player.global_position)
	return result


## Chaves: "x,z" para blocos do mapa de fora, "i:<id>" para interiores.
func _key_at(position: Vector3) -> String:
	var interior := world_map.interior_at(position)
	if interior:
		return "i:" + interior
	var c := world_map.chunk_at(position)
	return "%d,%d" % [c.x, c.y]


func _wanted_around(position: Vector3, radius: int) -> Array[String]:
	var keys: Array[String] = []
	var interior := world_map.interior_at(position)
	if interior:
		keys.append("i:" + interior)
		return keys
	var center := world_map.chunk_at(position)
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			var coords := center + Vector2i(dx, dz)
			if world_map.chunks.has(coords):
				keys.append("%d,%d" % [coords.x, coords.y])
	return keys


func _within(key: String, anchors: Array[Vector3], radius: int) -> bool:
	for anchor in anchors:
		if key.begins_with("i:"):
			if _key_at(anchor) == key:
				return true
			continue
		var parts := key.split(",")
		var coords := Vector2i(int(parts[0]), int(parts[1]))
		if world_map.interior_at(anchor) == "":
			var d := (coords - world_map.chunk_at(anchor)).abs()
			if maxi(d.x, d.y) <= radius:
				return true
	return false


func _path_and_origin(key: String) -> Array:
	if key.begins_with("i:"):
		var info: Dictionary = world_map.interiors.get(key.substr(2), {})
		return [info.get("path", ""), info.get("origin", Vector3.ZERO)]
	var parts := key.split(",")
	var coords := Vector2i(int(parts[0]), int(parts[1]))
	return [world_map.chunks.get(coords, ""), world_map.chunk_origin(coords)]


func _request(key: String) -> void:
	if _loaded.has(key) or _loading.has(key):
		return
	var path: String = _path_and_origin(key)[0]
	if path.is_empty():
		return
	ResourceLoader.load_threaded_request(path)
	_loading[key] = path


func _finish_loads() -> void:
	for key: String in _loading.keys():
		var status := ResourceLoader.load_threaded_get_status(_loading[key])
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_spawn(key, ResourceLoader.load_threaded_get(_loading[key]))
			_loading.erase(key)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Bloco do mundo não carregou: %s" % _loading[key])
			_loading.erase(key)


func _load_sync(key: String) -> void:
	if _loaded.has(key):
		return
	var info := _path_and_origin(key)
	if info[0] == "":
		return
	if _loading.has(key):
		# Já pedido em segundo plano: espera terminar (load_threaded_get bloqueia até ficar pronto).
		_spawn(key, ResourceLoader.load_threaded_get(_loading[key]))
		_loading.erase(key)
	else:
		_spawn(key, load(info[0]))


func _spawn(key: String, scene: PackedScene) -> void:
	if scene == null or _loaded.has(key):
		return
	var chunk := scene.instantiate() as Node3D
	chunk.name = "Chunk_" + key.replace(",", "_").replace(":", "_")
	# Posição antes de entrar na cena: o que nasce no bloco já nasce no lugar certo.
	chunk.position = _path_and_origin(key)[1]
	if not key.begins_with("i:"):
		_add_edge_walls(chunk, key)
	add_child(chunk)
	_loaded[key] = chunk
	for entry: Dictionary in NetService.edits_for(key):
		WorldEdits.spawn(chunk, entry)
	bake_navigation(chunk)
	if batch_static:
		StaticBatcher.batch(chunk, reaction_targets())
	chunk_loaded.emit(key)


## Junta a decoração parada dos blocos em poucas malhas (StaticBatcher). O editor de mapa do
## dono (/editar) desliga enquanto está aberto, para mexer nas peças.
var batch_static := true


func set_batching(enabled: bool) -> void:
	batch_static = enabled
	for chunk in _loaded.values():
		if not is_instance_valid(chunk):
			continue
		if enabled:
			StaticBatcher.batch(chunk, reaction_targets())
		else:
			StaticBatcher.unbatch(chunk)


## Nomes de peças que as missões fazem sumir/aparecer: não entram na junção.
static func reaction_targets() -> Dictionary:
	var names := {}
	for quest: QuestDef in Quests.defs().values():
		for objective: QuestObjective in quest.objectives:
			if objective and objective.reaction != "nenhuma" and not objective.reaction_target.is_empty():
				names[objective.reaction_target] = true
	return names


## Navegação das criaturas: calculada aqui, ao carregar o bloco (a leitura das peças é rápida;
## o cálculo roda em outra thread). Assim o mapa não guarda a malha (sem a "película" azul no
## editor) e o que for colocado no jogo (modo construtor) entra é só recalcular.
## `force`: recalcula mesmo se já tiver (mudou alguma peça).
static func bake_navigation(chunk: Node, force := false) -> void:
	var nav := chunk.get_node_or_null("Navigation") as NavigationRegion3D
	if nav == null or nav.navigation_mesh == null or nav.has_meta("baking"):
		return
	if not force and nav.navigation_mesh.get_polygon_count() > 0:
		return
	nav.set_meta("baking", true)
	var nav_mesh := nav.navigation_mesh
	# Referência fraca: o bloco pode descarregar antes do cálculo terminar.
	var nav_ref: WeakRef = weakref(nav)
	NavigationServer3D.bake_from_source_geometry_data_async(nav_mesh, navigation_source(nav), func() -> void:
		var region: NavigationRegion3D = nav_ref.get_ref()
		if region:
			region.remove_meta("baking")
			region.set_deferred("navigation_mesh", nav_mesh))


## Calcula na hora, na mesma thread (editor de mapa e testes).
static func bake_navigation_now(nav: NavigationRegion3D) -> int:
	NavigationServer3D.bake_from_source_geometry_data(nav.navigation_mesh, navigation_source(nav))
	return nav.navigation_mesh.get_polygon_count()


## O que bloqueia as criaturas: só as colisões do mundo (bem mais rápido que ler as malhas, que
## teriam de voltar da placa de vídeo; telhado e enfeites atravessáveis ficam de fora) mais as
## paredes pintadas na grade, que o Godot não entrega como colisão para a navegação.
static func navigation_source(nav: NavigationRegion3D) -> NavigationMeshSourceGeometryData3D:
	var nav_mesh := nav.navigation_mesh
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	# Criaturas sobem degrau de piso/calçada/laje como os heróis (Enemy/Player.STEP_HEIGHT).
	nav_mesh.agent_max_climb = maxf(nav_mesh.agent_max_climb, 0.5)
	nav_mesh.geometry_collision_mask = GameConfig.LAYER_WORLD
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav_mesh, source, nav)
	var to_nav := nav.global_transform.affine_inverse()
	for grid: GridMap in nav.find_children("*", "GridMap", true, false):
		if grid.mesh_library == null:
			continue
		var faces_of := {}
		for cell in grid.get_used_cells():
			var item := grid.get_cell_item(cell)
			if not faces_of.has(item):
				faces_of[item] = _item_faces(grid.mesh_library, item)
			if faces_of[item].is_empty():
				continue
			var cell_xform := Transform3D(grid.get_cell_item_basis(cell), grid.map_to_local(cell))
			source.add_faces(faces_of[item], to_nav * grid.global_transform * cell_xform)
	return source


static func _item_faces(library: MeshLibrary, item: int) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var shapes := library.get_item_shapes(item)
	for i in range(0, shapes.size() - 1, 2):
		var shape := shapes[i] as Shape3D
		if shape == null:
			continue
		var xform: Transform3D = shapes[i + 1]
		for v in shape.get_debug_mesh().get_faces():
			faces.append(xform * v)
	return faces


func _add_edge_walls(chunk: Node3D, key: String) -> void:
	var parts := key.split(",")
	var coords := Vector2i(int(parts[0]), int(parts[1]))
	var size := world_map.chunk_size
	var sides := {
		Vector2i(-1, 0): [Vector3(-0.5, 0, size / 2), Vector3(1, 0, size)],
		Vector2i(1, 0): [Vector3(size + 0.5, 0, size / 2), Vector3(1, 0, size)],
		Vector2i(0, -1): [Vector3(size / 2, 0, -0.5), Vector3(size, 0, 1)],
		Vector2i(0, 1): [Vector3(size / 2, 0, size + 0.5), Vector3(size, 0, 1)],
	}
	for side: Vector2i in sides:
		if world_map.chunks.has(coords + side):
			continue
		var shape := BoxShape3D.new()
		shape.size = sides[side][1] + Vector3(0, EDGE_WALL_HEIGHT, 0)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		var wall := StaticBody3D.new()
		wall.name = "MapEdge_%d_%d" % [side.x, side.y]
		wall.position = sides[side][0] + Vector3(0, EDGE_WALL_HEIGHT / 2, 0)
		wall.add_child(collision)
		chunk.add_child(wall)


## Peça do modo construtor: entra no bloco se ele estiver carregado (senão, entra quando carregar).
func apply_edit(entry: Dictionary) -> void:
	var chunk: Node3D = _loaded.get(String(entry.get("key", "")))
	if chunk and WorldEdits.spawn(chunk, entry):
		bake_navigation(chunk, true)


func remove_edit(id: String) -> void:
	for chunk: Node3D in _loaded.values():
		var node := WorldEdits.parent_in(chunk).get_node_or_null(NodePath(id))
		if node:
			node.queue_free()
			bake_navigation.call_deferred(chunk, true)


## Bloco (carregado) que contém o ponto, e a chave dele. [null, ""] se não estiver carregado.
func chunk_at(position: Vector3) -> Array:
	var key := _key_at(position)
	return [_loaded.get(key), key]


## Chave de um bloco carregado ("" se não for um bloco daqui).
func key_of(chunk: Node) -> String:
	for key: String in _loaded:
		if _loaded[key] == chunk:
			return key
	return ""


## Arquivo da cena do bloco.
func scene_path_of(key: String) -> String:
	return _path_and_origin(key)[0]


func _unload(key: String) -> void:
	var chunk: Node3D = _loaded[key]
	_loaded.erase(key)
	chunk.queue_free()
	chunk_unloaded.emit(key)
