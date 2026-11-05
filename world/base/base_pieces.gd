class_name BasePieces
extends RefCounted
## Visual e colisão das peças da base do jogador, montados em blocos (estilo low-poly do jogo).
## Origem no chão, no meio da casa da grade (BaseCatalog.GRID). Parede e porta ficam na borda
## da casa: comprimento no eixo X local, espessura em Z.
## Materiais: madeira (tábuas), metal (chapa ondulada enferrujada), fibra de vidro (placas
## translúcidas esverdeadas com moldura de metal).
## Paredes e teto são FadeOccluder: o teto some com alguém dentro, a parede fica transparente
## na frente da câmera (como as casas do mapa).

const G := BaseCatalog.GRID
const H := BaseCatalog.WALL_HEIGHT
const T := 0.14
const FLOOR_T := BaseCatalog.FLOOR_HEIGHT

const WOOD := Color(0.5, 0.34, 0.2)
const METAL := Color(0.55, 0.57, 0.6)
const FIBER := Color(0.55, 0.8, 0.7, 0.55)
const FRAME := Color(0.3, 0.31, 0.33)


## A peça montada. `ghost`: sem colisão nem script, para o fantasma do modo de construção.
static func build(kind: String, material: String, ghost := false) -> Node3D:
	var root: Node3D
	match kind:
		"wall", "door":
			root = _occluder(false)
			_wall(root, material, kind == "door")
		"roof":
			root = _occluder(true)
			_roof(root, material)
		"floor":
			root = Node3D.new()
			_floor(root, material)
		"bed":
			root = Node3D.new()
			_bed(root)
		"lamp":
			root = Node3D.new()
			_lamp(root, ghost)
		"chest":
			root = Node3D.new()
			if not ghost:
				# O baú abre o cofre (o mesmo do banco): é um "NPC" de cofre sem corpo.
				root.set_script(load("res://world/world_npc.gd"))
				root.set("service", 3)
				root.set("npc_name", "Baú")
				root.set_meta("base_chest", true)
			_chest(root)
		"terminal":
			root = Node3D.new()
			_terminal(root, ghost)
		_:
			root = Node3D.new()
	if ghost:
		for body in root.find_children("*", "CollisionObject3D", true, false):
			body.free()
	return root


static func _occluder(roof: bool) -> Node3D:
	var occluder := FadeOccluder.new()
	if roof:
		occluder.zone = AABB(Vector3(-G / 2.0, 0.0, -G / 2.0), Vector3(G, H, G))
		occluder.inside_fade = 1.0
	occluder.see_through = 0.75
	return occluder


static func _material(color: Color, kind: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	match kind:
		"madeira":
			m.albedo_texture = load("res://world/textures/sujeira.png")
			m.roughness = 0.9
		"metal":
			m.albedo_texture = load("res://world/textures/cano_enferrujado.png")
			m.metallic = 0.4
			m.roughness = 0.7
		"fibra":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.4
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_:
			m.roughness = 0.8
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 1.5
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = pos
	mesh.rotation_degrees = rot
	parent.add_child(mesh)
	return mesh


static func _body(parent: Node3D, layer: int, shapes: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	for entry: Array in shapes:
		var shape := BoxShape3D.new()
		shape.size = entry[0]
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = entry[1]
		body.add_child(collision)
	parent.add_child(body)
	return body


## Pedaço de parede de `width` x `height` com o centro da base em (x, y): tábuas, chapa ou placa.
static func _panel(parent: Node3D, material: String, x: float, y: float, width: float, height: float) -> void:
	match material:
		"madeira":
			var planks := maxi(1, roundi(width / 0.3))
			var plank := width / planks
			for i in planks:
				var shade := WOOD.lightened(0.06) if i % 2 == 0 else WOOD.darkened(0.08)
				_box(parent, Vector3(plank - 0.015, height, T), Vector3(x - width / 2.0 + plank * (i + 0.5), y + height / 2.0, 0), _material(shade, "madeira"))
			_box(parent, Vector3(width, 0.1, T + 0.04), Vector3(x, y + height * 0.3, 0), _material(WOOD.darkened(0.25), "madeira"))
			_box(parent, Vector3(width, 0.1, T + 0.04), Vector3(x, y + height * 0.78, 0), _material(WOOD.darkened(0.25), "madeira"))
		"metal":
			# Chapa ondulada: nervuras verticais alternando para fora e para dentro.
			var ribs := maxi(2, roundi(width / 0.15))
			var rib := width / ribs
			for i in ribs:
				var out := 0.02 if i % 2 == 0 else -0.02
				_box(parent, Vector3(rib, height, T - 0.06), Vector3(x - width / 2.0 + rib * (i + 0.5), y + height / 2.0, out), _material(METAL if i % 2 == 0 else METAL.darkened(0.12), "metal"))
		_:
			_box(parent, Vector3(width - 0.08, height - 0.08, 0.04), Vector3(x, y + height / 2.0, 0), _material(FIBER, "fibra"))
			for side: float in [-1.0, 1.0]:
				_box(parent, Vector3(0.06, height, T), Vector3(x + side * (width / 2.0 - 0.03), y + height / 2.0, 0), _material(FRAME, "metal"))
			_box(parent, Vector3(width, 0.06, T), Vector3(x, y + 0.03, 0), _material(FRAME, "metal"))
			_box(parent, Vector3(width, 0.06, T), Vector3(x, y + height - 0.03, 0), _material(FRAME, "metal"))


## Parede (3 m) ou parede com vão de porta no meio (1,2 m x 2,2 m).
static func _wall(root: Node3D, material: String, door: bool) -> void:
	if door:
		var side := (G - 1.2) / 2.0
		_panel(root, material, -G / 2.0 + side / 2.0, 0.0, side, H)
		_panel(root, material, G / 2.0 - side / 2.0, 0.0, side, H)
		_panel(root, material, 0.0, 2.2, 1.2, H - 2.2)
		_body(root, GameConfig.LAYER_WORLD, [
			[Vector3(side, H, T), Vector3(-G / 2.0 + side / 2.0, H / 2.0, 0)],
			[Vector3(side, H, T), Vector3(G / 2.0 - side / 2.0, H / 2.0, 0)],
			[Vector3(1.2, H - 2.2, T), Vector3(0, 2.2 + (H - 2.2) / 2.0, 0)],
		])
	else:
		_panel(root, material, 0.0, 0.0, G, H)
		_body(root, GameConfig.LAYER_WORLD, [[Vector3(G, H, T), Vector3(0, H / 2.0, 0)]])


static func _floor(root: Node3D, material: String) -> void:
	match material:
		"madeira":
			for i in 10:
				var shade := WOOD.lightened(0.05) if i % 2 == 0 else WOOD.darkened(0.06)
				_box(root, Vector3(G, FLOOR_T, G / 10.0 - 0.01), Vector3(0, FLOOR_T / 2.0, -G / 2.0 + G / 10.0 * (i + 0.5)), _material(shade, "madeira"))
		"metal":
			_box(root, Vector3(G, FLOOR_T, G), Vector3(0, FLOOR_T / 2.0, 0), _material(METAL.darkened(0.1), "metal"))
			for i in 6:
				_box(root, Vector3(G - 0.1, 0.012, 0.04), Vector3(0, FLOOR_T + 0.006, -G / 2.0 + G / 6.0 * (i + 0.5)), _material(METAL.lightened(0.05), "metal"))
		_:
			_box(root, Vector3(G, FLOOR_T, G), Vector3(0, FLOOR_T / 2.0, 0), _material(Color(0.5, 0.62, 0.56), "metal"))
	_body(root, GameConfig.LAYER_WORLD, [[Vector3(G, FLOOR_T, G), Vector3(0, FLOOR_T / 2.0, 0)]])


## Teto na altura da parede: chapa de zinco ondulada, tábuas ou fibra translúcida (claraboia).
static func _roof(root: Node3D, material: String) -> void:
	var y := H + 0.06
	match material:
		"madeira":
			for i in 10:
				_box(root, Vector3(G + 0.2, 0.08, G / 10.0 - 0.01), Vector3(0, y, -G / 2.0 + G / 10.0 * (i + 0.5)), _material(WOOD.darkened(0.1 if i % 2 == 0 else 0.2), "madeira"))
		"metal":
			for i in 20:
				_box(root, Vector3(G / 20.0, 0.06, G + 0.2), Vector3(-G / 2.0 + G / 20.0 * (i + 0.5), y + (0.02 if i % 2 == 0 else -0.01), 0), _material(METAL if i % 2 == 0 else METAL.darkened(0.15), "metal"))
		_:
			_box(root, Vector3(G + 0.2, 0.05, G + 0.2), Vector3(0, y, 0), _material(FIBER, "fibra"))
			for i in 3:
				_box(root, Vector3(0.06, 0.08, G + 0.2), Vector3(-G / 2.0 + G / 3.0 * (i + 0.5), y + 0.03, 0), _material(FRAME, "metal"))
	_body(root, GameConfig.LAYER_ROOF | GameConfig.LAYER_OCCLUDER, [[Vector3(G, 0.12, G), Vector3(0, y, 0)]])


static func _bed(root: Node3D) -> void:
	var wood := _material(WOOD.darkened(0.1), "madeira")
	_box(root, Vector3(1.0, 0.3, 2.0), Vector3(0, 0.15, 0), wood)
	_box(root, Vector3(0.95, 0.16, 1.9), Vector3(0, 0.38, 0), _material(Color(0.62, 0.6, 0.55), ""))
	_box(root, Vector3(0.95, 0.05, 1.3), Vector3(0, 0.48, 0.3), _material(Color(0.32, 0.38, 0.45), ""))
	_box(root, Vector3(0.6, 0.12, 0.35), Vector3(0, 0.52, -0.72), _material(Color(0.8, 0.78, 0.72), ""))
	_box(root, Vector3(1.0, 0.7, 0.08), Vector3(0, 0.35, -1.0), wood)
	_body(root, GameConfig.LAYER_WORLD, [[Vector3(1.0, 0.5, 2.0), Vector3(0, 0.25, 0)]])


## Luminária: poste de cano com lâmpada quente acesa.
static func _lamp(root: Node3D, ghost: bool) -> void:
	_box(root, Vector3(0.3, 0.06, 0.3), Vector3(0, 0.03, 0), _material(FRAME, "metal"))
	_box(root, Vector3(0.05, 1.7, 0.05), Vector3(0, 0.88, 0), _material(METAL, "metal"))
	_box(root, Vector3(0.32, 0.12, 0.32), Vector3(0, 1.75, 0), _material(FRAME, "metal"))
	var bulb := StandardMaterial3D.new()
	bulb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb.albedo_color = Color(1.0, 0.85, 0.55)
	_box(root, Vector3(0.18, 0.1, 0.18), Vector3(0, 1.65, 0), bulb)
	if not ghost:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.78, 0.5)
		light.light_energy = 1.6
		light.omni_range = 8.0
		light.position = Vector3(0, 1.55, 0)
		root.add_child(light)
	_body(root, GameConfig.LAYER_WORLD, [[Vector3(0.3, 1.8, 0.3), Vector3(0, 0.9, 0)]])


static func _chest(root: Node3D) -> void:
	var wood := _material(WOOD, "madeira")
	var band := _material(FRAME, "metal")
	_box(root, Vector3(1.0, 0.5, 0.6), Vector3(0, 0.25, 0), wood)
	_box(root, Vector3(1.02, 0.14, 0.62), Vector3(0, 0.57, 0), _material(WOOD.darkened(0.15), "madeira"))
	for x: float in [-0.35, 0.35]:
		_box(root, Vector3(0.06, 0.66, 0.64), Vector3(x, 0.33, 0), band)
	_box(root, Vector3(0.12, 0.12, 0.04), Vector3(0, 0.45, 0.31), _material(Color(0.75, 0.6, 0.3), "metal"))
	_body(root, GameConfig.LAYER_WORLD, [[Vector3(1.0, 0.64, 0.6), Vector3(0, 0.32, 0)]])


## Terminal de base: console de sucata num pedestal, tela acesa e antena.
static func _terminal(root: Node3D, ghost: bool) -> void:
	var frame := _material(FRAME, "metal")
	_box(root, Vector3(0.7, 0.9, 0.5), Vector3(0, 0.45, 0), _material(METAL.darkened(0.2), "metal"))
	_box(root, Vector3(0.75, 0.55, 0.12), Vector3(0, 1.15, -0.05), frame, Vector3(-15, 0, 0))
	var screen := StandardMaterial3D.new()
	screen.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen.albedo_color = Color(0.3, 1.0, 0.85)
	_box(root, Vector3(0.6, 0.4, 0.02), Vector3(0, 1.16, 0.02), screen, Vector3(-15, 0, 0))
	_box(root, Vector3(0.03, 0.9, 0.03), Vector3(0.28, 1.6, -0.15), frame)
	var tip := StandardMaterial3D.new()
	tip.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tip.albedo_color = Color(1.0, 0.3, 0.2)
	_box(root, Vector3(0.06, 0.06, 0.06), Vector3(0.28, 2.06, -0.15), tip)
	if not ghost:
		var light := OmniLight3D.new()
		light.light_color = Color(0.3, 1.0, 0.85)
		light.light_energy = 0.8
		light.omni_range = 3.0
		light.position = Vector3(0, 1.2, 0.4)
		root.add_child(light)
	_body(root, GameConfig.LAYER_WORLD, [[Vector3(0.7, 1.4, 0.5), Vector3(0, 0.7, 0)]])
