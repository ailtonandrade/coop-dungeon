extends SceneTree
## Gera as peças prontas da paleta do editor de mapa (world/prefabs): casas, árvore, rochas,
## boca de caverna, poço, gerador de criaturas e NPCs de serviço. São cenas normais: dá para
## abrir e mudar cada uma no Godot, e todos os lugares do mapa que usam a peça mudam juntos.
## Rodar de novo SOBRESCREVE as peças (use só para recriar as originais).
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
	var packed := PackedScene.new()
	packed.pack(root)
	var path := "%s/%s.tscn" % [DIR, file_name]
	print("  ", path, ": ", error_string(ResourceSaver.save(packed, path)))
	root.free()
