extends SceneTree
## Peças de capricho da vila, montadas com caixas (estilo low-poly do jogo):
##   mesa_de_bar.tscn  mesa de plástico de boteco com cadeiras e garrafas
##   caixotes.tscn     pilha de caixotes de madeira (com engradado de cerveja em cima)
##   banca.tscn        banca de camelô (balcão com mercadoria)
## godot --headless --path . -s tools/build_vila_props.gd

const OUT := "res://world/prefabs/"


func _initialize() -> void:
	_save(_bar_table(), "mesa_de_bar")
	_save(_crates(), "caixotes")
	_save(_stall(), "banca")
	print("peças da vila prontas")
	quit()


func _save(root: Node3D, file: String) -> void:
	for node in root.find_children("*", "", true, false):
		node.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, OUT + file + ".tscn")
	root.free()


func _material(color: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = rough
	material.metallic = metal
	return material


func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material, turn := 0.0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	mesh.rotation.y = turn
	parent.add_child(mesh)
	return mesh


func _cylinder(parent: Node3D, radius: float, height: float, at: Vector3, material: Material, sides := 10) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = sides
	cylinder.rings = 1
	mesh.mesh = cylinder
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	return mesh


func _solid(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Solido"
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)


## Mesa de boteco: plástico vermelho de cerveja, quatro cadeiras e garrafas.
func _bar_table() -> Node3D:
	var root := Node3D.new()
	root.name = "MesaDeBar"
	var plastic := _material(Color(0.78, 0.12, 0.1), 0.55)
	var top := _box(root, Vector3(0.8, 0.04, 0.8), Vector3(0, 0.72, 0), plastic)
	top.name = "Tampo"
	for x: float in [-0.34, 0.34]:
		for z: float in [-0.34, 0.34]:
			_box(root, Vector3(0.05, 0.7, 0.05), Vector3(x, 0.35, z), plastic)
	var chair := _material(Color(0.9, 0.9, 0.88), 0.6)
	var spots := [[Vector3(0, 0, 0.72), 0.0], [Vector3(0, 0, -0.72), PI], [Vector3(0.72, 0, 0), PI / 2.0], [Vector3(-0.74, 0, 0.1), -PI / 2.0 + 0.3]]
	for spot: Array in spots:
		var seat := Node3D.new()
		seat.name = "Cadeira"
		seat.position = spot[0]
		seat.rotation.y = spot[1]
		root.add_child(seat)
		_box(seat, Vector3(0.42, 0.04, 0.42), Vector3(0, 0.44, 0), chair)
		_box(seat, Vector3(0.42, 0.4, 0.04), Vector3(0, 0.66, 0.2), chair)
		for x: float in [-0.18, 0.18]:
			for z: float in [-0.18, 0.18]:
				_box(seat, Vector3(0.035, 0.44, 0.035), Vector3(x, 0.22, z), chair)
	var glass := _material(Color(0.18, 0.4, 0.15), 0.15)
	var amber := _material(Color(0.45, 0.24, 0.06), 0.15)
	_cylinder(root, 0.035, 0.26, Vector3(0.12, 0.87, 0.05), glass)
	_cylinder(root, 0.035, 0.26, Vector3(-0.1, 0.87, -0.12), amber)
	_cylinder(root, 0.045, 0.1, Vector3(0.0, 0.79, 0.18), _material(Color(0.85, 0.85, 0.8), 0.1))
	_solid(root, Vector3(0.8, 0.75, 0.8), Vector3(0, 0.375, 0))
	return root


## Pilha de caixotes de madeira, com um engradado de cerveja amarelo em cima.
func _crates() -> Node3D:
	var root := Node3D.new()
	root.name = "Caixotes"
	var wood := _material(Color(0.55, 0.38, 0.2), 0.9)
	var dark := _material(Color(0.36, 0.24, 0.12), 0.9)
	var crates := [[Vector3(0, 0.3, 0), 0.0], [Vector3(0.66, 0.3, 0.05), 0.15], [Vector3(0.3, 0.9, 0.02), -0.1]]
	for crate: Array in crates:
		var box := Node3D.new()
		box.name = "Caixote"
		box.position = crate[0]
		box.rotation.y = crate[1]
		root.add_child(box)
		_box(box, Vector3(0.6, 0.6, 0.6), Vector3.ZERO, wood)
		# Ripas escuras nas bordas.
		for y: float in [-0.28, 0.28]:
			_box(box, Vector3(0.62, 0.05, 0.62), Vector3(0, y, 0), dark)
		for x: float in [-0.28, 0.28]:
			for z: float in [-0.28, 0.28]:
				_box(box, Vector3(0.05, 0.6, 0.05), Vector3(x, 0, z), dark)
	var crate_plastic := _material(Color(0.95, 0.72, 0.1), 0.6)
	var beer := Node3D.new()
	beer.name = "Engradado"
	beer.position = Vector3(0.68, 0.72, 0.05)
	beer.rotation.y = 0.4
	root.add_child(beer)
	_box(beer, Vector3(0.5, 0.06, 0.34), Vector3(0, -0.1, 0), crate_plastic)
	for side: Vector3 in [Vector3(0, 0, 0.16), Vector3(0, 0, -0.16)]:
		_box(beer, Vector3(0.5, 0.2, 0.03), side, crate_plastic)
	for side: Vector3 in [Vector3(0.24, 0, 0), Vector3(-0.24, 0, 0)]:
		_box(beer, Vector3(0.03, 0.2, 0.34), side, crate_plastic)
	var amber := _material(Color(0.4, 0.22, 0.05), 0.15)
	for i in 6:
		_cylinder(beer, 0.03, 0.22, Vector3(-0.16 + (i % 3) * 0.16, 0.02, -0.07 + (i / 3) * 0.14), amber, 8)
	_solid(root, Vector3(1.3, 1.2, 0.7), Vector3(0.33, 0.6, 0.02))
	return root


## Banca de camelô: balcão de madeira com lona por cima e mercadoria (caixinhas, rádio, peças).
func _stall() -> Node3D:
	var root := Node3D.new()
	root.name = "Banca"
	var wood := _material(Color(0.48, 0.33, 0.18), 0.9)
	var cloth := _material(Color(0.15, 0.32, 0.55), 0.85)
	_box(root, Vector3(2.0, 0.08, 0.7), Vector3(0, 0.9, 0), wood)
	_box(root, Vector3(2.0, 0.86, 0.04), Vector3(0, 0.44, 0.33), cloth)
	for x: float in [-0.95, 0.95]:
		_box(root, Vector3(0.06, 0.9, 0.6), Vector3(x, 0.45, 0), wood)
	var colors := [Color(0.85, 0.2, 0.15), Color(0.2, 0.6, 0.85), Color(0.9, 0.8, 0.2), Color(0.3, 0.3, 0.32), Color(0.85, 0.85, 0.8)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 9:
		var size := Vector3(rng.randf_range(0.12, 0.3), rng.randf_range(0.08, 0.22), rng.randf_range(0.1, 0.25))
		var at := Vector3(-0.85 + i * 0.21, 0.94 + size.y / 2.0, rng.randf_range(-0.15, 0.15))
		_box(root, size, at, _material(colors[i % colors.size()], 0.6, 0.2 if i % 3 == 0 else 0.0), rng.randf_range(-0.4, 0.4))
	# Radinho de pilha com antena.
	var radio := _box(root, Vector3(0.3, 0.18, 0.1), Vector3(0.55, 1.03, -0.2), _material(Color(0.12, 0.12, 0.13), 0.5, 0.3))
	radio.name = "Radinho"
	_box(root, Vector3(0.01, 0.3, 0.01), Vector3(0.65, 1.25, -0.2), _material(Color(0.7, 0.7, 0.72), 0.3, 0.8))
	_solid(root, Vector3(2.0, 0.95, 0.7), Vector3(0, 0.475, 0))
	return root
