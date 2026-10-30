extends SceneTree
## Gera as peças prontas da paleta do editor de mapa (world/prefabs): casas, árvore, rochas,
## boca de caverna, poço, gerador de criaturas, NPCs de serviço, baús com saque, sucata de rua
## (poste, carro quebrado, pneus, barril...), mato e morros (relevo). São cenas normais: dá para
## abrir e mudar cada uma no Godot, e todos os lugares do mapa que usam a peça mudam juntos.
## Rodar de novo só cria as que faltam; com "-- --recriar" sobrescreve todas (volta às originais).
##
## Rodar: godot --headless --path coop-dungeon -s tools/build_prefabs.gd

const DIR := "res://world/prefabs"

var _materials := {}
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	DirAccess.make_dir_recursive_absolute(DIR)
	_save(_house(Vector2(8, 6)), "casa_pequena")
	_save(_house(Vector2(11, 8)), "casa_grande")
	_save(_tree(), "arvore")
	_save(_rock(Vector3(1.6, 1.2, 1.6), "RochaBaixa"), "rocha_baixa")
	_save(_rock(Vector3(2.4, 2.4, 2.2), "RochaAlta"), "rocha_alta")
	_save(_cave_mouth(), "boca_de_caverna")
	_save(_well(), "poco")
	_save(_spawner(), "gerador_de_criaturas")
	_save(_neon_sign(Color(0.2, 0.95, 1.0)), "placa_neon")
	for entry: Array in [[0, "Comerciante", "Beach"], [1, "Ferreiro", "Worker"], [2, "Encantador", "King"], [3, "Banco", "Suit"]]:
		_save(_npc(entry[0], entry[2]), "npc_" + String(entry[1]).to_lower())

	# Baús e contêineres com saque (conteúdo no Inspector de cada um no mapa).
	_save(_loot_container("Bau", "Baú", "Chest", 1.7, 2.2, 25, 2), "bau_de_saque")
	_save(_loot_container("ConteinerDeSaque", "Contêiner", "Container_Red", 1.0, 3.6, 60, 4), "conteiner_de_saque")

	# Sucata de rua (modelos CC0 da Quaternius em assets/props).
	_save(_prop("Conteiner", "Container_Red", true, true), "conteiner")
	_save(_street_light(), "poste_de_luz")
	_save(_prop("CarroQuebrado", "Vehicle_Pickup", true, true), "carro_quebrado")
	_save(_prop("PilhaDePneus", "Wheels_Stack", true), "pilha_de_pneus")
	_save(_prop("Barril", "Barrel", true), "barril")
	_save(_prop("Cone", "TrafficCone_1", false), "cone")
	_save(_prop("SacoDeLixo", "TrashBag_1", false), "saco_de_lixo")
	_save(_prop("Pallet", "Pallet", false), "pallet")
	_save(_prop("BlocoDeConcreto", "CinderBlock", false), "bloco_de_concreto")
	_save(_prop("Barreira", "PlasticBarrier", true), "barreira")

	# Mato (atravessável) e relevo (morros com rampa suave, dá para subir andando).
	_save(_bush("Arbusto", Color(0.16, 0.36, 0.14)), "arbusto")
	_save(_bush("ArbustoSeco", Color(0.42, 0.34, 0.16)), "arbusto_seco")
	_save(_mound("MorroBaixo", 2.5, 6.0, 1.2, 1.0), "morro_baixo")
	_save(_mound("MorroAlto", 3.0, 8.5, 2.6, 1.0), "morro_alto")
	_save(_mound("Barranco", 2.0, 5.0, 1.5, 2.2), "barranco")
	print("Peças prontas salvas em ", DIR)
	quit()
	return false


## Casa com porta na frente (+Z, lado da câmera): ao entrar, o telhado some e as paredes da
## frente e da direita ficam translúcidas.
func _house(size: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "Casa"
	var inside := AABB(Vector3(-size.x / 2 + 0.2, 0, -size.y / 2 + 0.2), Vector3(size.x - 0.4, 3.0, size.y - 0.4))
	var wall := Color(0.75, 0.68, 0.55)
	var h := 3.2
	var t := 0.3
	_static(root, root, "WallBack", Vector3(0, h / 2, -size.y / 2), Vector3(size.x, h, t), wall)
	_static(root, root, "WallLeft", Vector3(-size.x / 2, h / 2, 0), Vector3(t, h, size.y), wall)
	var front := _occluder(root, root, "FrontWalls", inside, 0.65, 0.65)
	_static(front, root, "WallRight", Vector3(size.x / 2, h / 2, 0), Vector3(t, h, size.y), wall)
	var side := (size.x - 2.0) / 2.0
	_static(front, root, "WallFrontL", Vector3(-size.x / 2 + side / 2, h / 2, size.y / 2), Vector3(side, h, t), wall)
	_static(front, root, "WallFrontR", Vector3(size.x / 2 - side / 2, h / 2, size.y / 2), Vector3(side, h, t), wall)
	_static(front, root, "Lintel", Vector3(0, h - 0.4, size.y / 2), Vector3(2.0, 0.8, t), wall)
	var roof := _occluder(root, root, "Roof", inside, 0.75, 1.0)
	for part: Array in [["RoofSlab", Vector3(0, h + 0.25, 0), Vector3(size.x + 1, 0.5, size.y + 1), Color(0.6, 0.25, 0.18)],
			["RoofTop", Vector3(0, h + 0.8, 0), Vector3(size.x * 0.6, 0.6, size.y * 0.6), Color(0.5, 0.2, 0.15)]]:
		var body := _static(roof, root, part[0], part[1], part[2], part[3])
		body.collision_layer = GameConfig.LAYER_OCCLUDER
		body.collision_mask = 0
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	var plane := PlaneMesh.new()
	plane.size = size - Vector2(0.4, 0.4)
	floor_mesh.mesh = plane
	floor_mesh.position.y = 0.02
	floor_mesh.material_override = _material(Color(0.45, 0.32, 0.2))
	root.add_child(floor_mesh)
	floor_mesh.owner = root
	return root


func _tree() -> Node3D:
	var root := FadeOccluder.new()
	root.name = "Arvore"
	root.see_through = 0.6
	_static(root, root, "Trunk", Vector3(0, 1.2, 0), Vector3(0.45, 2.4, 0.45), Color(0.4, 0.27, 0.16))
	var crown := _static(root, root, "Crown", Vector3(0, 3.3, 0), Vector3(2.0, 1.6, 2.0), Color(0.16, 0.43, 0.16))
	crown.collision_layer = GameConfig.LAYER_OCCLUDER
	crown.collision_mask = 0
	return root


func _rock(size: Vector3, node_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	_static(root, root, "Stone", Vector3(0, size.y / 2, 0), size, Color(0.5, 0.5, 0.52))
	return root


## Boca de caverna virada para +Z. Ponha uma entrada ("Ligar entradas") no meio da abertura.
func _cave_mouth() -> Node3D:
	var root := Node3D.new()
	root.name = "BocaDeCaverna"
	var rock := Color(0.38, 0.36, 0.36)
	_static(root, root, "Left", Vector3(-3.2, 2.0, -1.5), Vector3(2.4, 4.0, 4.0), rock)
	_static(root, root, "Right", Vector3(3.2, 2.0, -1.5), Vector3(2.4, 4.0, 4.0), rock)
	_static(root, root, "Top", Vector3(0, 4.4, -1.5), Vector3(8.8, 1.2, 4.0), rock)
	_static(root, root, "Back", Vector3(0, 2.0, -3.8), Vector3(8.8, 4.0, 0.6), Color(0.05, 0.05, 0.06))
	return root


func _well() -> Node3D:
	var root := Node3D.new()
	root.name = "Poco"
	_static(root, root, "Stone", Vector3(0, 0.5, 0), Vector3(2.2, 1.0, 2.2), Color(0.45, 0.45, 0.5))
	return root


## Placa de neon (barra acesa + luz colorida). Sem colisão: é decoração de parede.
static func _neon_sign(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "PlacaNeon"
	var box := BoxMesh.new()
	box.size = Vector3(1.6, 0.35, 0.08)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	var bar := MeshInstance3D.new()
	bar.name = "Barra"
	bar.mesh = box
	bar.material_override = material
	root.add_child(bar)
	bar.owner = root
	var light := OmniLight3D.new()
	light.name = "Luz"
	light.light_color = color
	light.light_energy = 1.5
	light.omni_range = 6.0
	light.position = Vector3(0, 0, 0.6)
	root.add_child(light)
	light.owner = root
	return root


func _spawner() -> Node3D:
	var spawner: Marker3D = load("res://world/creature_spawner.gd").new()
	spawner.name = "GeradorDeCriaturas"
	return spawner


func _npc(service: int, model: String) -> Node3D:
	var npc := WorldNpc.new()
	npc.name = "Npc"
	npc.service = service
	npc.model = load("res://assets/characters/%s.glb" % model)
	return npc


## Baú/contêiner com saque (LootContainer); o modelo aparece no editor e no jogo.
func _loot_container(node_name: String, title: String, model: String, model_scale: float, reach: float,
		gold: int, random_items: int) -> Node3D:
	var container := LootContainer.new()
	container.name = node_name
	container.title = title
	container.model = load("res://assets/props/%s.glb" % model)
	container.model_scale = model_scale
	container.open_range = reach
	container.gold = gold
	container.random_items = random_items
	var box := _model_bounds(container.model)
	_collider(container, container, "Solido", box.get_center() * model_scale, box.size * model_scale)
	return container


## Peça de cenário de um modelo .glb, com colisão do tamanho dele (ou sem, se dá para passar
## por cima). `fades`: fica translúcida quando tapa o herói (coisas altas).
func _prop(node_name: String, model: String, solid: bool, fades := false) -> Node3D:
	var root: Node3D = FadeOccluder.new() if fades else Node3D.new()
	root.name = node_name
	if fades:
		root.see_through = 0.55
	var scene: PackedScene = load("res://assets/props/%s.glb" % model)
	var instance := scene.instantiate()
	instance.name = "Modelo"
	root.add_child(instance)
	instance.owner = root
	if solid:
		var box := _model_bounds(scene)
		var body := _collider(root, root, "Solido", box.get_center(), box.size)
		if fades:
			body.collision_layer = GameConfig.LAYER_WORLD | GameConfig.LAYER_OCCLUDER
	return root


## Poste com a luz acesa na ponta do braço (o braço aponta para +Z). O modelo original tem
## 6,6 m; reduzido para a escala dos heróis na câmera de cima.
func _street_light() -> Node3D:
	var size := 0.6
	var root := _prop("PosteDeLuz", "StreetLights", false)
	root.get_node("Modelo").scale = Vector3.ONE * size
	_collider(root, root, "Solido", Vector3(0, 3.3 * size, 0), Vector3(0.36, 6.6, 0.36) * size)
	var light := OmniLight3D.new()
	light.name = "Luz"
	light.light_color = Color(1.0, 0.78, 0.45)
	light.light_energy = 2.2
	light.omni_range = 11.0
	light.position = Vector3(0, 6.0, 2.5) * size
	root.add_child(light)
	light.owner = root
	return root


## Moita: bolas de folhagem, sem colisão (dá para atravessar).
func _bush(node_name: String, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	var rng := RandomNumberGenerator.new()
	rng.seed = node_name.hash()
	for i in 4:
		var sphere := SphereMesh.new()
		var radius := rng.randf_range(0.35, 0.6)
		sphere.radius = radius
		sphere.height = radius * 1.6
		sphere.radial_segments = 10
		sphere.rings = 5
		var mesh := MeshInstance3D.new()
		mesh.name = "Folhas%d" % i
		mesh.mesh = sphere
		mesh.position = Vector3(rng.randf_range(-0.45, 0.45), radius * 0.6, rng.randf_range(-0.45, 0.45))
		mesh.material_override = _material(color.lightened(rng.randf_range(-0.1, 0.12)))
		root.add_child(mesh)
		mesh.owner = root
	return root


## Morro: tronco de cone achatado com colisão no formato dele. A rampa (topo - base) fica
## suave para subir andando; `stretch` alonga num barranco.
func _mound(node_name: String, top: float, bottom: float, height: float, stretch: float) -> Node3D:
	var root := StaticBody3D.new()
	root.name = node_name
	var cone := CylinderMesh.new()
	cone.top_radius = top
	cone.bottom_radius = bottom
	cone.height = height
	cone.radial_segments = 20
	cone.rings = 1
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = cone
	mesh.position.y = height / 2.0
	mesh.scale = Vector3(stretch, 1, 1)
	mesh.material_override = _material(Color(0.33, 0.27, 0.19))
	root.add_child(mesh)
	mesh.owner = root
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = cone.create_convex_shape()
	collision.position = mesh.position
	collision.scale = mesh.scale
	root.add_child(collision)
	collision.owner = root
	return root


## Caixa que envolve as malhas de um modelo (no espaço dele).
func _model_bounds(scene: PackedScene) -> AABB:
	var instance: Node3D = scene.instantiate()
	get_root().add_child(instance)
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in instance.find_children("*", "MeshInstance3D", true, false):
		var part := instance.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	instance.free()
	return box


## Só colisão (sem malha), dentro de `parent`.
func _collider(parent: Node, root: Node, node_name: String, center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	parent.add_child(body)
	body.owner = root
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	body.add_child(collision)
	collision.owner = root
	return body


func _occluder(parent: Node, root: Node, node_name: String, zone: AABB, see_through: float, inside_fade: float) -> FadeOccluder:
	var occluder := FadeOccluder.new()
	occluder.name = node_name
	occluder.zone = zone
	occluder.see_through = see_through
	occluder.inside_fade = inside_fade
	parent.add_child(occluder)
	occluder.owner = root
	return occluder


func _static(parent: Node, root: Node, node_name: String, center: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	parent.add_child(body)
	if body != root:
		body.owner = root
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	body.add_child(collision)
	collision.owner = root
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = box
	mesh.material_override = _material(color)
	body.add_child(mesh)
	mesh.owner = root
	return body


func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		_materials[color] = material
	return _materials[color]


func _save(root: Node, file_name: String) -> void:
	var path := "%s/%s.tscn" % [DIR, file_name]
	if FileAccess.file_exists(path) and not OS.get_cmdline_user_args().has("--recriar"):
		root.free()
		return
	var packed := PackedScene.new()
	packed.pack(root)
	print("  ", path, ": ", error_string(ResourceSaver.save(packed, path)))
	root.free()
