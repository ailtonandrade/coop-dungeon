extends Node3D
## Arena de teste em grid de 1 m, gerada em código. Será trocada por salas modulares
## (tiles 1x1 montados no editor) quando entrarmos na geração de fases.

const ARENA_SIZE := 32
const WALL_HEIGHT := 1.0
const PILLARS: Array[Rect2i] = [
	Rect2i(-8, -8, 2, 2), Rect2i(-10, 4, 3, 1), Rect2i(10, 0, 1, 1),
]
## Ambientação provisória (Quaternius, CC0): [cena, posição no grid (x, z), rotação Y em graus].
## Trocar o visual é só trocar o .glb; a colisão sai da caixa do modelo.
const PROPS := [
	["res://assets/props/Container_Red.glb", Vector2(7, -9), 90.0],
	["res://assets/props/Vehicle_Pickup.glb", Vector2(-3, 9), 70.0],
	["res://assets/props/Barrel.glb", Vector2(4, 5), 0.0],
	["res://assets/props/Barrel.glb", Vector2(5, 5.8), 0.0],
	["res://assets/props/Wheels_Stack.glb", Vector2(-6, -3), 0.0],
	["res://assets/props/Pallet.glb", Vector2(2, -4), 20.0],
	["res://assets/props/PlasticBarrier.glb", Vector2(-1, -12), 0.0],
	["res://assets/props/PlasticBarrier.glb", Vector2(1, -12), 0.0],
	["res://assets/props/TrafficCone_1.glb", Vector2(-4, 4), 0.0],
	["res://assets/props/TrafficCone_1.glb", Vector2(-5, 5), 0.0],
	["res://assets/props/TrashBag_1.glb", Vector2(11, 6), 0.0],
	["res://assets/props/CinderBlock.glb", Vector2(-12, -10), 30.0],
	["res://assets/props/Chest.glb", Vector2(0, 2), 180.0],
	["res://assets/props/StreetLights.glb", Vector2(-14, -14), 45.0],
	["res://assets/props/StreetLights.glb", Vector2(14, 14), 225.0],
]

var _materials: Dictionary = {}  # Color -> StandardMaterial3D
## Toda a geometria sólida fica aqui dentro, para a malha de navegação dos inimigos.
var _nav := NavigationRegion3D.new()


func _ready() -> void:
	add_child(_nav)
	_build_environment()
	_build_floor()
	_build_walls()
	for rect in PILLARS:
		_add_block(Vector3(rect.position.x, 0.0, rect.position.y), Vector3(rect.size.x, 2.0, rect.size.y), Color(0.45, 0.42, 0.4))
	for prop: Array in PROPS:
		_add_prop(load(prop[0]), Vector3(prop[1].x, 0.0, prop[1].y), prop[2])
	_bake_navigation()


func _bake_navigation() -> void:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = 0.25
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	_nav.navigation_mesh = nav_mesh
	_nav.bake_navigation_mesh(false)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.08, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60.0, 30.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)


func _build_floor() -> void:
	var half := ARENA_SIZE / 2.0
	_add_block(Vector3(-half, -1.0, -half), Vector3(ARENA_SIZE, 1.0, ARENA_SIZE), Color.WHITE, false)

	# Xadrez de 1 tile para ler a escala na tela.
	var image := Image.create(2, 2, false, Image.FORMAT_RGB8)
	image.fill(Color(0.32, 0.36, 0.3))
	image.set_pixel(0, 0, Color(0.36, 0.4, 0.33))
	image.set_pixel(1, 1, Color(0.36, 0.4, 0.33))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.uv1_scale = Vector3(half, half, 1.0)
	var plane := PlaneMesh.new()
	plane.size = Vector2(ARENA_SIZE, ARENA_SIZE)
	plane.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = plane
	mesh.position.y = 0.001
	add_child(mesh)


func _build_walls() -> void:
	var half := ARENA_SIZE / 2
	var color := Color(0.3, 0.28, 0.27)
	_add_block(Vector3(-half - 1, 0, -half - 1), Vector3(ARENA_SIZE + 2, WALL_HEIGHT, 1), color)
	_add_block(Vector3(-half - 1, 0, half), Vector3(ARENA_SIZE + 2, WALL_HEIGHT, 1), color)
	_add_block(Vector3(-half - 1, 0, -half), Vector3(1, WALL_HEIGHT, ARENA_SIZE), color)
	_add_block(Vector3(half, 0, -half), Vector3(1, WALL_HEIGHT, ARENA_SIZE), color)


## Cria um bloco estático alinhado ao grid. `corner` é o canto mínimo (x, y, z).
func _add_block(corner: Vector3, size: Vector3, color: Color, visible_mesh := true) -> void:
	var body := StaticBody3D.new()
	body.position = corner + size / 2.0
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	if visible_mesh:
		var box := BoxMesh.new()
		box.size = size
		var mesh := MeshInstance3D.new()
		mesh.mesh = box
		mesh.material_override = _material(color)
		body.add_child(mesh)
	_nav.add_child(body)


## Coloca um modelo .glb com colisão em caixa calculada a partir das malhas dele.
func _add_prop(scene: PackedScene, pos: Vector3, rotation_y_deg: float) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees.y = rotation_y_deg
	var model := scene.instantiate() as Node3D
	body.add_child(model)
	var bounds := _mesh_bounds(model, Transform3D.IDENTITY)
	if bounds.size != Vector3.ZERO:
		var shape := BoxShape3D.new()
		shape.size = bounds.size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = bounds.get_center()
		body.add_child(collision)
	_nav.add_child(body)


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
