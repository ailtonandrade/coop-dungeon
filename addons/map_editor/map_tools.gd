@tool
class_name MapTools
extends RefCounted
## Operações do editor de mapa, sem interface: o painel "Mapa do Mundo" só chama estas funções,
## e os testes automáticos também. Tudo trabalha em cima do WorldMap e das cenas dos blocos e
## interiores, salvando em disco.
##
## Convenções que o mapa segue:
## - Bloco: cena com conteúdo de 0 a chunk_size (local). Tudo que é sólido fica dentro do nó
##   `Navigation` (inclusive a grade de pintura `Tiles`), para entrar na navegação das criaturas.
## - Entrada: o ponto de chegada fica na FRENTE da entrada parceira, na direção do eixo azul
##   (+Z local) dela. Gire a entrada no editor para escolher para onde o grupo sai.
## - Borda do mapa: não vai nos blocos; o jogo põe parede invisível em lado sem vizinho.

const TILES_PATH := "res://world/tiles/tiles.meshlib"
const CHUNK_DIR := "res://world/chunks"
const INTERIOR_DIR := "res://world/interiors"
const TEXTURE_DIR := "res://world/textures"
const ENTRANCE_SCRIPT := "res://world/entrance.gd"
const NPC_SCRIPT := "res://world/world_npc.gd"
const INTERIOR_BASE := Vector3(4000, 0, 0)
const INTERIOR_SPACING := 300.0
const ARRIVAL_DISTANCE := 2.5
## Peça de parede usada nas bordas de uma masmorra nova (ver tools/build_tiles.gd).
const CAVE_WALL_TILE := 12
const DEFAULT_GROUND := [Color(0.3, 0.42, 0.22), Color(0.36, 0.5, 0.26)]

## Onde blocos e interiores novos são salvos (os testes trocam por uma pasta temporária).
static var chunk_dir := CHUNK_DIR
static var interior_dir := INTERIOR_DIR


## Criar

## Cria um bloco vazio (chão da região + grade de pintura) em `coords` e registra no mapa.
static func create_chunk(map: WorldMap, map_path: String, coords: Vector2i, region_id: String, host: Node) -> String:
	if map.chunks.has(coords):
		push_error("Já existe bloco em %s" % coords)
		return ""
	var root := Node3D.new()
	root.name = "Chunk"
	var nav := _navigation(root, AABB(Vector3(0, -5, 0), Vector3(map.chunk_size, 30, map.chunk_size)))
	_ground(nav, root, Vector2(map.chunk_size, map.chunk_size), _ground_colors(map, region_id))
	_tiles(nav, root)
	var path := "%s/chunk_%d_%d.tscn" % [chunk_dir, coords.x, coords.y]
	save_scene(root, path, host)
	map.chunks[coords] = path
	map.chunk_regions[coords] = region_id
	ResourceSaver.save(map, map_path)
	return path


## Cria uma masmorra vazia (chão, paredes pintadas em volta, duas luzes) longe do mapa de fora.
static func create_interior(map: WorldMap, map_path: String, id: String, region_id: String, size: Vector2i,
		host: Node) -> String:
	if map.interiors.has(id):
		push_error("Já existe interior '%s'" % id)
		return ""
	var origin := INTERIOR_BASE
	while _interior_origin_used(map, origin):
		origin.x += INTERIOR_SPACING
	var root := Node3D.new()
	root.name = "Interior"
	var nav := _navigation(root, AABB(Vector3(0, -5, 0), Vector3(size.x, 30, size.y)))
	_ground(nav, root, Vector2(size), _ground_colors(map, region_id, [Color(0.13, 0.12, 0.13), Color(0.2, 0.18, 0.18)]))
	var tiles := _tiles(nav, root)
	var along_z := tiles.get_orthogonal_index_from_basis(Basis(Vector3.UP, PI / 2.0))
	for x in size.x:
		tiles.set_cell_item(Vector3i(x, 0, 0), CAVE_WALL_TILE)
		tiles.set_cell_item(Vector3i(x, 0, size.y - 1), CAVE_WALL_TILE)
	for z in size.y:
		tiles.set_cell_item(Vector3i(0, 0, z), CAVE_WALL_TILE, along_z)
		tiles.set_cell_item(Vector3i(size.x - 1, 0, z), CAVE_WALL_TILE, along_z)
	for spot: Vector3 in [Vector3(size.x * 0.3, 3, size.y * 0.5), Vector3(size.x * 0.7, 3, size.y * 0.5)]:
		var light := OmniLight3D.new()
		light.position = spot
		light.light_color = Color(1.0, 0.6, 0.3)
		light.omni_range = maxf(size.x, size.y) * 0.4
		light.light_energy = 2.0
		root.add_child(light)
		light.owner = root
	var path := "%s/%s.tscn" % [interior_dir, id]
	save_scene(root, path, host)
	map.interiors[id] = {"path": path, "origin": origin, "size": Vector3(size.x, 10, size.y), "region": region_id}
	ResourceSaver.save(map, map_path)
	return path


## Põe uma entrada em cada cena (mesmo `link_id`) e acerta os destinos das duas.
## A de dentro nasce virada para o interior (`inside_rotation_deg`), para o grupo chegar para dentro.
static func add_entrance_pair(map: WorldMap, outside_path: String, outside_local: Vector3, outside_title: String,
		inside_path: String, inside_local: Vector3, inside_title: String, link_id: String,
		inside_rotation_deg := 180.0) -> PackedStringArray:
	for entry: Array in [[outside_path, outside_local, outside_title, 0.0], [inside_path, inside_local, inside_title, inside_rotation_deg]]:
		var root := open_scene(entry[0])
		var entrance: Marker3D = load(ENTRANCE_SCRIPT).new()
		entrance.name = "Entrance_" + link_id
		entrance.link_id = link_id
		entrance.title = entry[2]
		entrance.position = entry[1]
		entrance.rotation_degrees.y = entry[3]
		root.add_child(entrance)
		entrance.owner = root
		save_scene(root, entry[0], null)
	return sync_entrances(map)


## Acerta o destino de cada par de entradas (mesmo `link_id`): cada uma leva para a frente
## da outra. Rode depois de mover entradas no editor. Retorna o que foi feito / problemas.
static func sync_entrances(map: WorldMap) -> PackedStringArray:
	var report := PackedStringArray()
	var scenes := scenes_of(map)
	var roots := {}
	var links := {}  # link_id -> [{path, node, world, forward}]
	for path: String in scenes:
		var root := open_scene(path)
		roots[path] = root
		for entrance in _entrances(root):
			if entrance.link_id.is_empty():
				continue
			var xform: Transform3D = entrance.transform
			links.get_or_add(entrance.link_id, []).append({
				"path": path, "node": entrance, "world": scenes[path] + xform.origin, "forward": xform.basis.z.normalized(),
			})
	var changed := {}
	for link: String in links:
		var pair: Array = links[link]
		if pair.size() != 2:
			report.append("ERRO: entrada '%s' tem %d ponta(s); precisa de 2" % [link, pair.size()])
			continue
		for i in 2:
			var me: Dictionary = pair[i]
			var other: Dictionary = pair[1 - i]
			var target: Vector3 = other.world + _flat(other.forward) * ARRIVAL_DISTANCE
			if not me.node.target_point.is_equal_approx(target):
				me.node.target_point = target
				changed[me.path] = true
		report.append("ok: '%s' ligada (%s <-> %s)" % [link, pair[0].path.get_file(), pair[1].path.get_file()])
	for path: String in roots:
		if changed.has(path):
			save_scene(roots[path], path, null)
		else:
			roots[path].free()
	return report


## Navegação e manutenção

## Recalcula a navegação das criaturas de uma cena (bloco ou interior) e salva.
static func bake_scene(path: String, host: Node) -> int:
	var root := open_scene(path)
	var nav := root.get_node_or_null("Navigation") as NavigationRegion3D
	if nav and nav.navigation_mesh:
		nav.navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_BOTH
	var polygons := _bake(root, host)
	save_scene(root, path, null)
	return polygons


## Prepara um bloco antigo para a pintura: tira as bordas fixas (agora o jogo cuida disso) e
## acrescenta a grade de pintura, se faltar. Retorna true se mudou algo.
static func ensure_paintable(path: String, host: Node) -> bool:
	var root := open_scene(path)
	var changed := false
	for node in root.find_children("Border*", "", true, false):
		node.get_parent().remove_child(node)
		node.free()
		changed = true
	var nav := root.get_node_or_null("Navigation")
	if nav and not nav.has_node("Tiles"):
		_tiles(nav, root)
		changed = true
	if changed:
		save_scene(root, path, host)
	else:
		root.free()
	return changed


## Validação

## Problemas do mapa: [{"level": "erro"|"aviso", "text": ..., "path": ...}]
static func validate(map: WorldMap) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var region_ids := map.regions.map(func(r: RegionDef) -> String: return r.id)
	for coords: Vector2i in map.chunks:
		var path: String = map.chunks[coords]
		if not ResourceLoader.exists(path):
			issues.append(_issue("erro", "bloco %s: cena não existe (%s)" % [coords, path], path))
			continue
		var region_id: String = map.chunk_regions.get(coords, "")
		if region_id not in region_ids:
			issues.append(_issue("erro", "bloco %s: região '%s' não existe" % [coords, region_id], path))
		var root := open_scene(path)
		_check_scene(root, path, Vector2(map.chunk_size, map.chunk_size), map.region(region_id), issues)
		root.free()
	var origins := []
	for id: String in map.interiors:
		var info: Dictionary = map.interiors[id]
		if not ResourceLoader.exists(info.get("path", "")):
			issues.append(_issue("erro", "interior '%s': cena não existe" % id, info.get("path", "")))
			continue
		if info.get("region", "") not in region_ids:
			issues.append(_issue("erro", "interior '%s': região '%s' não existe" % [id, info.get("region", "")], info.path))
		if map.chunks.has(map.chunk_at(info.origin)):
			issues.append(_issue("erro", "interior '%s' está em cima do mapa de fora" % id, info.path))
		for other: Vector3 in origins:
			if other.distance_to(info.origin) < INTERIOR_SPACING * 0.5:
				issues.append(_issue("erro", "interior '%s' encosta em outro interior" % id, info.path))
		origins.append(info.origin)
		var root := open_scene(info.path)
		_check_scene(root, info.path, Vector2(info.size.x, info.size.z), map.region(info.get("region", "")), issues)
		root.free()
	for line in _entrance_issues(map):
		issues.append(_issue("erro", line, ""))
	var npc_script: Script = load(NPC_SCRIPT)
	var has_merchant := false
	for coords: Vector2i in map.chunks:
		var root := open_scene(map.chunks[coords])
		for npc in root.find_children("*", "Node3D", true, false):
			if npc.get_script() == npc_script and npc.service == WorldNpc.Service.MERCHANT:
				has_merchant = true
		root.free()
	if not has_merchant:
		issues.append(_issue("aviso", "nenhum comerciante no mapa", ""))
	for line in container_issues(map):
		issues.append(line)
	return issues


## Baús/contêineres: id único no mapa inteiro (é o que fica salvo) e não vazio.
static func container_issues(map: WorldMap) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var seen := {}
	for path: String in scenes_of(map):
		var root := open_scene(path)
		for node in root.find_children("*", "Node3D", true, false):
			if not node is LootContainer:
				continue
			var container := node as LootContainer
			var where := "%s: %s '%s'" % [path.get_file(), container.title, container.name]
			if container.container_id.is_empty():
				issues.append(_issue("erro", "%s sem id (abra e salve o bloco)" % where, path))
			elif seen.has(container.container_id):
				issues.append(_issue("erro", "%s tem o mesmo id que %s (troque o id de um deles)" % [where, seen[container.container_id]], path))
			else:
				seen[container.container_id] = where
			if container.contents.is_empty() and container.gold <= 0 and container.random_items <= 0:
				issues.append(_issue("aviso", "%s está vazio" % where, path))
		root.free()
	return issues


static func _check_scene(root: Node, path: String, size: Vector2, region: RegionDef, issues: Array[Dictionary]) -> void:
	var nav := root.get_node_or_null("Navigation") as NavigationRegion3D
	if nav == null or nav.navigation_mesh == null or nav.navigation_mesh.get_polygon_count() == 0:
		issues.append(_issue("erro", "%s: navegação não calculada (Assar navegação)" % path.get_file(), path))
	for node in root.find_children("*", "Marker3D", true, false):
		if node.get("respawn_time") == null:
			continue
		var p: Vector3 = (node as Marker3D).position
		if p.x < 0 or p.z < 0 or p.x > size.x or p.z > size.y:
			issues.append(_issue("erro", "%s: gerador de criaturas '%s' fora do bloco" % [path.get_file(), node.name], path))
		if region and region.safe:
			issues.append(_issue("erro", "%s: criaturas em área segura ('%s')" % [path.get_file(), node.name], path))
	for entrance in _entrances(root):
		if entrance.link_id.is_empty() and entrance.target_point == Vector3.ZERO:
			issues.append(_issue("erro", "%s: entrada '%s' sem destino e sem par" % [path.get_file(), entrance.name], path))


static func _entrance_issues(map: WorldMap) -> PackedStringArray:
	var problems := PackedStringArray()
	var scenes := scenes_of(map)
	var links := {}
	for path: String in scenes:
		var root := open_scene(path)
		for entrance in _entrances(root):
			if not entrance.link_id.is_empty():
				links.get_or_add(entrance.link_id, []).append({
					"world": scenes[path] + entrance.transform.origin, "forward": entrance.transform.basis.z,
					"target": entrance.target_point,
				})
		root.free()
	for link: String in links:
		var pair: Array = links[link]
		if pair.size() != 2:
			problems.append("entrada '%s' tem %d ponta(s); precisa de 2" % [link, pair.size()])
			continue
		for i in 2:
			var expected: Vector3 = pair[1 - i].world + _flat(pair[1 - i].forward).normalized() * ARRIVAL_DISTANCE
			if pair[i].target.distance_to(expected) > 0.5:
				problems.append("entrada '%s' desatualizada (Sincronizar entradas)" % link)
				break
	return problems


## Cenas

## Cena -> origem no mundo, de todos os blocos e interiores do mapa.
static func scenes_of(map: WorldMap) -> Dictionary:
	var result := {}
	for coords: Vector2i in map.chunks:
		result[map.chunks[coords]] = map.chunk_origin(coords)
	for id: String in map.interiors:
		result[map.interiors[id].path] = map.interiors[id].origin
	return result


## Abre uma cena para editar (cópia nova do disco, preservando peças instanciadas).
static func open_scene(path: String) -> Node3D:
	var scene: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	return scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)


## Salva a cena (recalculando a navegação se `host` for dado) e libera os nós.
static func save_scene(root: Node3D, path: String, host: Node) -> Error:
	if host:
		_bake(root, host)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		err = ResourceSaver.save(packed, path)
		packed.take_over_path(path)
	root.free()
	return err


## Material do chão (textura de ruído pronta, salva em world/textures; repete a cada 16 m).
static func ground_material(a: Color, b: Color) -> StandardMaterial3D:
	var path := "%s/ground_%s_%s.res" % [TEXTURE_DIR, a.to_html(false), b.to_html(false)]
	if not ResourceLoader.exists(path):
		var noise := FastNoiseLite.new()
		noise.frequency = 0.05
		noise.seed = 7
		var image := noise.get_seamless_image(128, 128)
		image.convert(Image.FORMAT_RGB8)
		for y in image.get_height():
			for x in image.get_width():
				image.set_pixel(x, y, a.lerp(b, image.get_pixel(x, y).r))
		image.generate_mipmaps()
		DirAccess.make_dir_recursive_absolute(TEXTURE_DIR)
		ResourceSaver.save(ImageTexture.create_from_image(image), path)
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(path)
	material.uv1_scale = Vector3(4, 4, 1)
	return material


static func _navigation(root: Node3D, bake_area: AABB) -> NavigationRegion3D:
	var nav := NavigationRegion3D.new()
	nav.name = "Navigation"
	var nav_mesh := NavigationMesh.new()
	# Malhas + colisões: o Godot não lê as colisões da grade de pintura (GridMap) na navegação,
	# só as malhas dela; sem isso as criaturas atravessariam paredes pintadas.
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_BOTH
	nav_mesh.geometry_collision_mask = GameConfig.LAYER_WORLD
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = 0.25
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	nav_mesh.filter_baking_aabb = bake_area
	nav.navigation_mesh = nav_mesh
	root.add_child(nav)
	nav.owner = root
	return nav


static func _ground(nav: Node3D, root: Node3D, size: Vector2, colors: Array) -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.position = Vector3(size.x / 2, -0.5, size.y / 2)
	nav.add_child(body)
	body.owner = root
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 1, size.y)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	body.add_child(collision)
	collision.owner = root
	var plane := PlaneMesh.new()
	plane.size = size
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = plane
	mesh.position.y = 0.5
	mesh.material_override = ground_material(colors[0], colors[1])
	body.add_child(mesh)
	mesh.owner = root


## Grade de pintura: células de 1 m, origem de cada peça no chão da célula.
static func _tiles(nav: Node3D, root: Node3D) -> GridMap:
	var grid := GridMap.new()
	grid.name = "Tiles"
	grid.mesh_library = load(TILES_PATH)
	grid.cell_size = Vector3(1, 1, 1)
	grid.cell_center_y = false
	grid.collision_layer = GameConfig.LAYER_WORLD
	grid.collision_mask = 0
	nav.add_child(grid)
	grid.owner = root
	return grid


static func _bake(root: Node3D, host: Node) -> int:
	var nav := root.get_node_or_null("Navigation") as NavigationRegion3D
	if nav == null or nav.navigation_mesh == null:
		return 0
	host.add_child(root)
	nav.bake_navigation_mesh(false)
	host.remove_child(root)
	return nav.navigation_mesh.get_polygon_count()


static func _entrances(root: Node) -> Array:
	var script: Script = load(ENTRANCE_SCRIPT)
	return root.find_children("*", "Marker3D", true, false).filter(func(n: Node) -> bool: return n.get_script() == script)


static func _ground_colors(map: WorldMap, region_id: String, fallback := DEFAULT_GROUND) -> Array:
	var region := map.region(region_id)
	if region and region.ground_colors.size() >= 2:
		return [region.ground_colors[0], region.ground_colors[1]]
	return fallback


static func _interior_origin_used(map: WorldMap, origin: Vector3) -> bool:
	for id: String in map.interiors:
		if (map.interiors[id].origin as Vector3).distance_to(origin) < INTERIOR_SPACING * 0.5:
			return true
	return false


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _issue(level: String, text: String, path: String) -> Dictionary:
	return {"level": level, "text": text, "path": path}
