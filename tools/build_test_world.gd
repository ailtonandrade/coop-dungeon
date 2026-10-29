extends SceneTree
## Gera a região de teste do mundo aberto: 4x4 blocos de 64 m (vila, planície, bosque,
## colinas) e uma masmorra, salvos como cenas normais em world/chunks e world/interiors,
## mais o mapa world/test_world.tres. Depois de gerado, tudo se edita no editor do Godot;
## rodar de novo SOBRESCREVE os blocos (use só para recriar a região de teste).
##
## Rodar: godot --headless --path coop-dungeon -s tools/build_test_world.gd
## (Gerador e entradas carregam com load(): os scripts que usam os serviços globais só
## compilam depois que eles existem.)

const CHUNK := 64.0
const COORDS := [-1, 0, 1, 2]
const WILD_PROPS := [
	"res://assets/props/Barrel.glb", "res://assets/props/Pallet.glb", "res://assets/props/Wheels_Stack.glb",
	"res://assets/props/CinderBlock.glb", "res://assets/props/Chest.glb",
]
const INTERIOR_ORIGIN := Vector3(4000, 0, 0)
const INTERIOR_SIZE := Vector3(48, 10, 48)
## Masmorra no bloco (2, 1): boca da caverna no meio do bloco.
const CAVE_CHUNK := Vector2i(2, 1)
const CAVE_LOCAL := Vector3(32, 0, 30)

var _materials := {}
var _done := false


func _process(_delta: float) -> bool:
	if not _done:
		_done = true
		_build()
	return false


func _build() -> void:
	var map := WorldMap.new()
	map.chunk_size = CHUNK
	map.regions = [
		_region("vila", "Vila de Pedra", 0, true, Color(1.0, 0.95, 0.75)),
		_region("planicie", "Planície Verde", 1, false, Color(0.7, 1.0, 0.6)),
		_region("bosque", "Bosque Norte", 2, false, Color(0.5, 0.85, 0.5)),
		_region("colinas", "Colinas do Leste", 3, false, Color(1.0, 0.75, 0.45)),
		_region("caverna", "Caverna Velha", 4, false, Color(1.0, 0.5, 0.4)),
	]
	map.spawn_point = Vector3(32, 0, 38)
	for x: int in COORDS:
		for z: int in COORDS:
			var coords := Vector2i(x, z)
			var region := _region_for(coords)
			var path := "res://world/chunks/chunk_%d_%d.tscn" % [x, z]
			var scene := _build_town() if region == "vila" else _build_wild(coords, map.region(region))
			_add_borders(scene, coords)
			_save(scene, path, AABB(Vector3(0, -5, 0), Vector3(CHUNK, 30, CHUNK)))
			map.chunks[coords] = path
			map.chunk_regions[coords] = region
	var cave_path := "res://world/interiors/caverna_velha.tscn"
	_save(_build_cave(), cave_path, AABB(Vector3(0, -5, 0), Vector3(INTERIOR_SIZE.x, 30, INTERIOR_SIZE.z)))
	map.interiors["caverna_velha"] = {
		"path": cave_path, "origin": INTERIOR_ORIGIN, "size": INTERIOR_SIZE, "region": "caverna",
	}
	var err := ResourceSaver.save(map, "res://world/test_world.tres")
	print("Mapa salvo: ", error_string(err), " (", map.chunks.size(), " blocos, ", map.interiors.size(), " interior)")
	quit()


func _region(id: String, display: String, danger: int, safe: bool, color: Color) -> RegionDef:
	var r := RegionDef.new()
	r.id = id
	r.display_name = display
	r.danger = danger
	r.safe = safe
	r.color = color
	return r


func _region_for(coords: Vector2i) -> String:
	if coords == Vector2i.ZERO:
		return "vila"
	if coords.x == 2:
		return "colinas"
	if coords.y == -1:
		return "bosque"
	return "planicie"


## Blocos

func _new_chunk(ground: Array) -> Node3D:
	var root := Node3D.new()
	root.name = "Chunk"
	var nav := NavigationRegion3D.new()
	nav.name = "Navigation"
	root.add_child(nav)
	_own(nav, root)
	var body := _static(nav, root, "Ground", Vector3(CHUNK / 2, -0.5, CHUNK / 2), Vector3(CHUNK, 1, CHUNK), Color.WHITE, false)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(CHUNK, CHUNK)
	mesh.mesh = plane
	mesh.position = Vector3(0, 0.5, 0)
	mesh.material_override = _ground_material(ground[0], ground[1])
	body.add_child(mesh)
	_own(mesh, root)
	return root


func _build_town() -> Node3D:
	var root := _new_chunk([Color(0.4, 0.38, 0.34), Color(0.48, 0.45, 0.4)])
	var nav: Node3D = root.get_node("Navigation")
	# Casas: entra-se pela porta da frente (lado da câmera) e o telhado some lá dentro.
	_house(nav, root, Vector3(14, 0, 14), Vector2(10, 8), "Banco")
	_house(nav, root, Vector3(50, 0, 14), Vector2(9, 7), "")
	_house(nav, root, Vector3(14, 0, 50), Vector2(9, 7), "")
	_house(nav, root, Vector3(50, 0, 50), Vector2(10, 8), "Ferreiro")
	# Praça: poço e barracas dos serviços.
	_static(nav, root, "Well", Vector3(32, 0.5, 26), Vector3(2.2, 1.0, 2.2), Color(0.45, 0.45, 0.5))
	_npc(root, WorldNpc.Service.MERCHANT, "Dona Alda", "res://assets/characters/Beach.glb", Vector3(25, 0, 30))
	_npc(root, WorldNpc.Service.ENCHANTER, "Mestre Ivo", "res://assets/characters/King.glb", Vector3(39, 0, 30))
	_prop(nav, root, "res://assets/props/Barrel.glb", Vector3(23, 0, 28), 0.0)
	_prop(nav, root, "res://assets/props/Chest.glb", Vector3(41, 0, 28), 0.0)
	return root


## Casa com porta na frente (lado da câmera). Ao entrar, o telhado some e as paredes da
## frente e da direita (as que ficam entre a câmera e o herói) ficam translúcidas, para a
## porta continuar à vista; fundo e esquerda continuam normais.
func _house(nav: Node3D, root: Node3D, center: Vector3, size: Vector2, npc_service: String) -> void:
	var house := Node3D.new()
	house.name = "House_%d_%d" % [int(center.x), int(center.z)]
	house.position = center
	nav.add_child(house)
	_own(house, root)
	var inside := AABB(Vector3(-size.x / 2 + 0.2, 0, -size.y / 2 + 0.2), Vector3(size.x - 0.4, 3.0, size.y - 0.4))
	var wall := Color(0.75, 0.68, 0.55)
	var h := 3.2
	var t := 0.3
	_static(house, root, "WallBack", Vector3(0, h / 2, -size.y / 2), Vector3(size.x, h, t), wall)
	_static(house, root, "WallLeft", Vector3(-size.x / 2, h / 2, 0), Vector3(t, h, size.y), wall)
	var front := _occluder(house, root, "FrontWalls", inside, 0.65, 0.65)
	_static(front, root, "WallRight", Vector3(size.x / 2, h / 2, 0), Vector3(t, h, size.y), wall)
	# Frente com vão de porta de 2 m no meio.
	var side := (size.x - 2.0) / 2.0
	_static(front, root, "WallFrontL", Vector3(-size.x / 2 + side / 2, h / 2, size.y / 2), Vector3(side, h, t), wall)
	_static(front, root, "WallFrontR", Vector3(size.x / 2 - side / 2, h / 2, size.y / 2), Vector3(side, h, t), wall)
	_static(front, root, "Lintel", Vector3(0, h - 0.4, size.y / 2), Vector3(2.0, 0.8, t), wall)
	# Telhado: só a câmera "vê" (camada de oclusão), ninguém colide nele.
	var roof_node := _occluder(house, root, "Roof", inside, 0.75, 1.0)
	var roof := _static(roof_node, root, "RoofSlab", Vector3(0, h + 0.25, 0), Vector3(size.x + 1.0, 0.5, size.y + 1.0), Color(0.6, 0.25, 0.18))
	roof.collision_layer = GameConfig.LAYER_OCCLUDER
	roof.collision_mask = 0
	var ridge := _static(roof_node, root, "RoofTop", Vector3(0, h + 0.8, 0), Vector3(size.x * 0.6, 0.6, size.y * 0.6), Color(0.5, 0.2, 0.15))
	ridge.collision_layer = GameConfig.LAYER_OCCLUDER
	ridge.collision_mask = 0
	var floor_mesh := MeshInstance3D.new()
	var floor_plane := PlaneMesh.new()
	floor_plane.size = size - Vector2(0.4, 0.4)
	floor_mesh.mesh = floor_plane
	floor_mesh.position.y = 0.02
	floor_mesh.material_override = _material(Color(0.45, 0.32, 0.2))
	house.add_child(floor_mesh)
	_own(floor_mesh, root)
	match npc_service:
		"Banco":
			_npc(root, WorldNpc.Service.BANK, "Sr. Gouveia", "res://assets/characters/Suit.glb", center + Vector3(0, 0, -1.5))
		"Ferreiro":
			_npc(root, WorldNpc.Service.BLACKSMITH, "Brando", "res://assets/characters/Worker.glb", center + Vector3(0, 0, -1.5))


func _occluder(parent: Node3D, root: Node3D, node_name: String, zone: AABB, see_through: float,
		inside_fade := 1.0) -> FadeOccluder:
	var occluder := FadeOccluder.new()
	occluder.name = node_name
	occluder.zone = zone
	occluder.see_through = see_through
	occluder.inside_fade = inside_fade
	parent.add_child(occluder)
	_own(occluder, root)
	return occluder


func _build_wild(coords: Vector2i, region: RegionDef) -> Node3D:
	var palette := {
		"planicie": [Color(0.27, 0.4, 0.2), Color(0.34, 0.48, 0.25)],
		"bosque": [Color(0.15, 0.27, 0.14), Color(0.21, 0.34, 0.18)],
		"colinas": [Color(0.44, 0.38, 0.25), Color(0.52, 0.45, 0.3)],
	}
	var root := _new_chunk(palette[region.id])
	var nav: Node3D = root.get_node("Navigation")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(coords)
	var reserved: Array = []  # [centro, raio] de áreas livres (geradores, caverna, bordas da vila)
	if coords == CAVE_CHUNK:
		_cave_mouth(nav, root)
		reserved.append([CAVE_LOCAL, 10.0])
	# Geradores de criaturas: mais perigo, mais criaturas, mais atiradores e loot melhor.
	var kinds := {1: [0, 0, 1], 2: [0, 1], 3: [0, 1, 1]}
	for i in 2:
		var spot := _free_spot(rng, reserved, 6.0)
		reserved.append([spot, 6.0])
		var spawner: Marker3D = load("res://world/creature_spawner.gd").new()
		spawner.name = "Spawner_%d" % i
		spawner.position = spot
		spawner.kinds = PackedInt32Array(kinds[region.danger])
		spawner.count = 2 + region.danger
		spawner.power = region.danger * 2
		spawner.respawn_time = 40.0
		root.add_child(spawner)
		_own(spawner, root)
	var trees := {"planicie": 10, "bosque": 26, "colinas": 6}
	for i in trees[region.id]:
		_tree(nav, root, _free_spot(rng, reserved, 2.0), rng)
	for i in 6 if region.id == "colinas" else 4:
		var spot := _free_spot(rng, reserved, 2.0)
		var size := Vector3(rng.randf_range(1.2, 3.0), rng.randf_range(0.8, 2.4), rng.randf_range(1.2, 3.0))
		_static(nav, root, "Rock_%d" % i, spot + Vector3(0, size.y / 2, 0), size, Color(0.5, 0.5, 0.52))
	for i in 3:
		_prop(nav, root, WILD_PROPS[rng.randi() % WILD_PROPS.size()], _free_spot(rng, reserved, 1.5), rng.randf_range(0, 360))
	return root


func _tree(nav: Node3D, root: Node3D, spot: Vector3, rng: RandomNumberGenerator) -> void:
	var tree := FadeOccluder.new()
	tree.name = "Tree_%d_%d" % [int(spot.x), int(spot.z)]
	tree.position = spot
	tree.see_through = 0.6
	nav.add_child(tree)
	_own(tree, root)
	var height := rng.randf_range(2.0, 2.8)
	var trunk := _static(tree, root, "Trunk", Vector3(0, height / 2, 0), Vector3(0.45, height, 0.45), Color(0.4, 0.27, 0.16))
	trunk.set_meta("tree", true)
	var crown := _static(tree, root, "Crown", Vector3(0, height + 0.9, 0), Vector3(2.0, 1.6, 2.0), Color(0.16, rng.randf_range(0.36, 0.5), 0.16))
	crown.collision_layer = GameConfig.LAYER_OCCLUDER
	crown.collision_mask = 0


func _cave_mouth(nav: Node3D, root: Node3D) -> void:
	var rock := Color(0.38, 0.36, 0.36)
	_static(nav, root, "CaveLeft", CAVE_LOCAL + Vector3(-3.2, 2.0, -1.5), Vector3(2.4, 4.0, 4.0), rock)
	_static(nav, root, "CaveRight", CAVE_LOCAL + Vector3(3.2, 2.0, -1.5), Vector3(2.4, 4.0, 4.0), rock)
	_static(nav, root, "CaveTop", CAVE_LOCAL + Vector3(0, 4.4, -1.5), Vector3(8.8, 1.2, 4.0), rock)
	_static(nav, root, "CaveBack", CAVE_LOCAL + Vector3(0, 2.0, -3.8), Vector3(8.8, 4.0, 0.6), Color(0.05, 0.05, 0.06))
	var entrance: Marker3D = load("res://world/entrance.gd").new()
	entrance.name = "Entrance_Caverna"
	entrance.title = "Caverna Velha · perigo 4"
	entrance.position = CAVE_LOCAL + Vector3(0, 0, -0.8)
	entrance.target_point = INTERIOR_ORIGIN + Vector3(24, 0, 36)
	root.add_child(entrance)
	_own(entrance, root)


func _build_cave() -> Node3D:
	var root := Node3D.new()
	root.name = "Interior"
	var nav := NavigationRegion3D.new()
	nav.name = "Navigation"
	root.add_child(nav)
	_own(nav, root)
	var size := Vector2(INTERIOR_SIZE.x, INTERIOR_SIZE.z)
	var floor_body := _static(nav, root, "Floor", Vector3(size.x / 2, -0.5, size.y / 2), Vector3(size.x, 1, size.y), Color(0.2, 0.19, 0.2))
	floor_body.get_child(1).material_override = _ground_material(Color(0.13, 0.12, 0.13), Color(0.2, 0.18, 0.18))
	# Paredes: cada uma some sozinha quando tapa o herói.
	var stone := Color(0.3, 0.28, 0.3)
	var walls := {
		"North": [Vector3(size.x / 2, 2, 0), Vector3(size.x, 4, 1)],
		"South": [Vector3(size.x / 2, 2, size.y), Vector3(size.x, 4, 1)],
		"West": [Vector3(0, 2, size.y / 2), Vector3(1, 4, size.y)],
		"East": [Vector3(size.x, 2, size.y / 2), Vector3(1, 4, size.y)],
		"Inner1": [Vector3(16, 2, 28), Vector3(18, 4, 1)],
		"Inner2": [Vector3(34, 2, 18), Vector3(1, 4, 20)],
		"Inner3": [Vector3(12, 2, 12), Vector3(1, 4, 14)],
	}
	for wall_name: String in walls:
		var occluder := _occluder(nav, root, "Wall" + wall_name, AABB(), 0.8)
		_static(occluder, root, "Stone", walls[wall_name][0], walls[wall_name][1], stone)
	for spot: Vector3 in [Vector3(10, 0, 38), Vector3(40, 0, 36), Vector3(24, 0, 8), Vector3(42, 0, 8)]:
		var light := OmniLight3D.new()
		light.position = spot + Vector3(0, 3, 0)
		light.light_color = Color(1.0, 0.6, 0.3)
		light.omni_range = 12.0
		light.light_energy = 2.0
		root.add_child(light)
		_own(light, root)
	var spots := [Vector3(10, 0, 18), Vector3(40, 0, 10), Vector3(24, 0, 20)]
	for i in spots.size():
		var spawner: Marker3D = load("res://world/creature_spawner.gd").new()
		spawner.name = "Spawner_%d" % i
		spawner.position = spots[i]
		spawner.kinds = PackedInt32Array([0, 1])
		spawner.count = 3
		spawner.power = 8
		spawner.aggro_radius = 9.0
		spawner.leash_radius = 16.0
		root.add_child(spawner)
		_own(spawner, root)
	var exit: Marker3D = load("res://world/entrance.gd").new()
	exit.name = "Exit"
	exit.title = "Saída"
	exit.position = Vector3(24, 0, 44)
	var cave_world := Vector3(CAVE_CHUNK.x * CHUNK, 0, CAVE_CHUNK.y * CHUNK) + CAVE_LOCAL
	exit.target_point = cave_world + Vector3(0, 0, 6)
	root.add_child(exit)
	_own(exit, root)
	return root


## Bordas do mapa: mureta visível e parede invisível alta (ninguém escala para fora).
func _add_borders(root: Node3D, coords: Vector2i) -> void:
	var nav: Node3D = root.get_node("Navigation")
	var edges := []
	if coords.x == COORDS.front():
		edges.append([Vector3(-0.5, 0, CHUNK / 2), Vector3(1, 0, CHUNK)])
	if coords.x == COORDS.back():
		edges.append([Vector3(CHUNK + 0.5, 0, CHUNK / 2), Vector3(1, 0, CHUNK)])
	if coords.y == COORDS.front():
		edges.append([Vector3(CHUNK / 2, 0, -0.5), Vector3(CHUNK, 0, 1)])
	if coords.y == COORDS.back():
		edges.append([Vector3(CHUNK / 2, 0, CHUNK + 0.5), Vector3(CHUNK, 0, 1)])
	for i in edges.size():
		var center: Vector3 = edges[i][0]
		var size: Vector3 = edges[i][1]
		_static(nav, root, "BorderLow_%d" % i, center + Vector3(0, 0.5, 0), size + Vector3(0, 1, 0), Color(0.35, 0.33, 0.32))
		_static(nav, root, "BorderHigh_%d" % i, center + Vector3(0, 3, 0), size + Vector3(0, 6, 0), Color.WHITE, false)


## Peças

func _static(parent: Node3D, root: Node3D, node_name: String, center: Vector3, size: Vector3, color: Color,
		visible := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	parent.add_child(body)
	_own(body, root)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	_own(collision, root)
	if visible:
		var box := BoxMesh.new()
		box.size = size
		var mesh := MeshInstance3D.new()
		mesh.mesh = box
		mesh.material_override = _material(color)
		body.add_child(mesh)
		_own(mesh, root)
	return body


func _prop(nav: Node3D, root: Node3D, path: String, spot: Vector3, rotation_deg: float) -> void:
	var body := StaticBody3D.new()
	body.name = path.get_file().get_basename() + "_%d_%d" % [int(spot.x), int(spot.z)]
	body.position = spot
	body.rotation_degrees.y = rotation_deg
	nav.add_child(body)
	_own(body, root)
	var model: Node3D = load(path).instantiate()
	body.add_child(model)
	_own(model, root)
	var bounds := _mesh_bounds(model, Transform3D.IDENTITY)
	if bounds.size != Vector3.ZERO:
		var shape := BoxShape3D.new()
		shape.size = bounds.size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = bounds.get_center()
		body.add_child(collision)
		_own(collision, root)


func _npc(root: Node3D, service: WorldNpc.Service, npc_name: String, model_path: String, spot: Vector3) -> void:
	var npc := WorldNpc.new()
	npc.name = "Npc_" + npc_name.replace(" ", "_").replace(".", "")
	npc.service = service
	npc.npc_name = npc_name
	npc.model = load(model_path)
	npc.position = spot
	root.add_child(npc)
	_own(npc, root)


func _free_spot(rng: RandomNumberGenerator, reserved: Array, radius: float) -> Vector3:
	for attempt in 40:
		var spot := Vector3(rng.randf_range(4, CHUNK - 4), 0, rng.randf_range(4, CHUNK - 4))
		var ok := true
		for area: Array in reserved:
			if spot.distance_to(area[0]) < area[1] + radius:
				ok = false
				break
		if ok:
			return spot
	return Vector3(rng.randf_range(4, CHUNK - 4), 0, rng.randf_range(4, CHUNK - 4))


func _mesh_bounds(node: Node, parent_xform: Transform3D) -> AABB:
	var xform := parent_xform
	if node is Node3D:
		xform = parent_xform * (node as Node3D).transform
	var bounds := AABB()
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		bounds = xform * (node as MeshInstance3D).mesh.get_aabb()
	for child in node.get_children():
		var child_bounds := _mesh_bounds(child, xform)
		if child_bounds.size != Vector3.ZERO:
			bounds = child_bounds if bounds.size == Vector3.ZERO else bounds.merge(child_bounds)
	return bounds


func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		_materials[color] = material
	return _materials[color]


## Chão: textura de ruído já pronta (gerada aqui e salva em world/textures), para o bloco
## aparecer com a cor certa assim que carrega. Repete a cada 16 m e emenda sem costura.
func _ground_material(a: Color, b: Color) -> StandardMaterial3D:
	var key := "ground_%s_%s" % [a.to_html(false), b.to_html(false)]
	if _materials.has(key):
		return _materials[key]
	var noise := FastNoiseLite.new()
	noise.frequency = 0.05
	noise.seed = 7
	var image := noise.get_seamless_image(128, 128)
	image.convert(Image.FORMAT_RGB8)
	for y in image.get_height():
		for x in image.get_width():
			image.set_pixel(x, y, a.lerp(b, image.get_pixel(x, y).r))
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	DirAccess.make_dir_recursive_absolute("res://world/textures")
	var path := "res://world/textures/%s.res" % key
	ResourceSaver.save(texture, path)
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(path)
	material.uv1_scale = Vector3(4, 4, 1)
	_materials[key] = material
	return material


## Salvar: assa a navegação das criaturas dentro do bloco e grava a cena.
func _save(root: Node3D, path: String, bake_area: AABB) -> void:
	get_root().add_child(root)
	var nav: NavigationRegion3D = root.get_node("Navigation")
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = GameConfig.LAYER_WORLD
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = 0.25
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	nav_mesh.filter_baking_aabb = bake_area
	nav.navigation_mesh = nav_mesh
	nav.bake_navigation_mesh(false)
	get_root().remove_child(root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	print("  ", path, ": ", error_string(err), " (navegação: ", nav_mesh.get_polygon_count(), " polígonos)")
	root.free()


func _own(node: Node, root: Node) -> void:
	node.owner = root
