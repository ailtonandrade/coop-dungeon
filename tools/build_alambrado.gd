extends SceneTree
## Alambrado (cerca de tela de aço com canos galvanizados enferrujados), na altura de um muro
## (~2 m), para cercar a vila. Três peças, todas "estrutura" (fixas, encaixam ponta com ponta):
##   alambrado_10m        inteiro, 10 m (5 vãos de 2,5 m)
##   alambrado_5m         inteiro, 5 m
##   alambrado_quebrado   5 m, rasgado em cima: tela arrebentada e dobrada para fora, poste do
##                        meio entortado e o cano de cima partido, pendurado.
## Saem a cena visual (world/props/models/<id>_modelo.tscn), a ficha (world/props/<id>.tres) e
## a peça pronta (world/prefabs/downtown/<id>.tscn). A origem fica no chão, no meio da cerca.
## Texturas: tools/gerar_texturas.py (alambrado.png, ferrugem_manchas.png, cano_enferrujado.png).
## godot --headless --path . -s tools/build_alambrado.gd

const PREFAB_DIR := "res://world/prefabs/downtown/"
const MODEL_DIR := "res://world/props/models/"
const DEF_DIR := "res://world/props/"

const HEIGHT := 2.0
const SPAN := 2.5
const POST_RADIUS := 0.035
const RAIL_RADIUS := 0.022
## Tela: do arame de baixo até o cano de cima. Uma repetição da textura = 0,5 m.
const MESH_BOTTOM := 0.06
const MESH_TOP := 1.96
const TILE := 0.5

var _pipe: StandardMaterial3D
var _mesh_material: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(MODEL_DIR)
	_pipe = StandardMaterial3D.new()
	_pipe.albedo_texture = load("res://world/textures/cano_enferrujado.png")
	_pipe.uv1_triplanar = true
	_pipe.uv1_world_triplanar = true
	_pipe.uv1_scale = Vector3.ONE / 0.8
	_pipe.metallic = 0.45
	_pipe.roughness = 0.72
	_mesh_material = StandardMaterial3D.new()
	_mesh_material.albedo_texture = load("res://world/textures/alambrado.png")
	# Transparência misturada (não recorte): de longe a tela vira um véu cinza em vez de moiré.
	_mesh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	_mesh_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh_material.vertex_color_use_as_albedo = true
	_mesh_material.metallic = 0.5
	_mesh_material.roughness = 0.55
	# Ferrugem em manchas grandes por cima (UV2 em metros), para não repetir a cada 50 cm.
	_mesh_material.detail_enabled = true
	_mesh_material.detail_albedo = load("res://world/textures/ferrugem_manchas.png")
	_mesh_material.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	_mesh_material.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	_build("alambrado_10m", "Alambrado 10 m", 10.0, false, 1)
	_build("alambrado_5m", "Alambrado 5 m", 5.0, false, 2)
	_build("alambrado_quebrado", "Alambrado quebrado", 5.0, true, 3)
	print("alambrados prontos")
	quit()


func _build(id: String, display: String, length: float, broken: bool, seed_value: int) -> void:
	_rng.seed = seed_value
	var model := Node3D.new()
	model.name = id.to_pascal_case()
	var half := length / 2.0
	var spans := int(round(length / SPAN))
	# Postes (o do meio do quebrado sai torto).
	for i in spans + 1:
		var x := -half + i * SPAN
		if broken and i == 1:
			_bent_post(model, x)
		else:
			_post(model, Vector3(x, 0, 0), HEIGHT + 0.05)
	# Cano de cima e arame de baixo.
	if broken:
		# Partido: inteiro até perto do poste torto; o resto cai pendurado na ponta direita.
		var cut := -half + SPAN * 0.7
		_rail(model, Vector3(-half, HEIGHT, 0), Vector3(cut, HEIGHT, 0), RAIL_RADIUS)
		_rail(model, Vector3(half, HEIGHT, 0), Vector3(-half + SPAN * 1.55, 1.25, 0.12), RAIL_RADIUS)
	else:
		_rail(model, Vector3(-half, HEIGHT, 0), Vector3(half, HEIGHT, 0), RAIL_RADIUS)
	_rail(model, Vector3(-half, MESH_BOTTOM + 0.01, 0), Vector3(half, MESH_BOTTOM + 0.01, 0), 0.006)
	_panel(model, length, broken)
	if broken:
		_flap(model, -half + SPAN * 0.65, -half + SPAN * 1.45)
	_save_scene(model, MODEL_DIR + id + "_modelo.tscn")

	var def := PropDef.new()
	def.id = id
	def.display_name = display
	def.model = load(MODEL_DIR + id + "_modelo.tscn")
	def.kind = "estrutura"
	ResourceSaver.save(def, DEF_DIR + id + ".tres")

	var body := StaticBody3D.new()
	body.name = id.to_pascal_case()
	body.collision_layer = GameConfig.LAYER_WORLD
	body.set_meta("prop_def", DEF_DIR + id + ".tres")
	var instance: Node3D = def.model.instantiate()
	instance.name = "Modelo"
	body.add_child(instance)
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, HEIGHT + 0.05, 0.1)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	collision.position = Vector3(0, (HEIGHT + 0.05) / 2.0, 0)
	body.add_child(collision)
	instance.owner = body
	collision.owner = body
	var packed := PackedScene.new()
	packed.pack(body)
	ResourceSaver.save(packed, PREFAB_DIR + id + ".tscn")
	body.free()


func _save_scene(root: Node3D, path: String) -> void:
	for node in root.find_children("*", "", true, false):
		node.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, path)
	root.free()


func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	return mesh


func _post(parent: Node3D, base: Vector3, height: float) -> void:
	var post := MeshInstance3D.new()
	post.mesh = _cylinder(POST_RADIUS, height)
	post.material_override = _pipe
	post.position = base + Vector3.UP * height / 2.0
	parent.add_child(post)
	# Tampa e braçadeira do cano de cima.
	var cap := MeshInstance3D.new()
	cap.mesh = _cylinder(POST_RADIUS + 0.012, 0.04)
	cap.material_override = _pipe
	cap.position = base + Vector3.UP * (height + 0.01)
	parent.add_child(cap)
	for y: float in [HEIGHT - 0.04, 0.9, 0.12]:
		var clamp := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.03, 0.035, POST_RADIUS * 2.0 + 0.03)
		clamp.mesh = box
		clamp.material_override = _pipe
		clamp.position = base + Vector3(0, y, 0)
		parent.add_child(clamp)


## Poste do meio entortado (batida de carro): reto até ~1 m, depois tomba para fora.
func _bent_post(parent: Node3D, x: float) -> void:
	var lower := MeshInstance3D.new()
	lower.mesh = _cylinder(POST_RADIUS, 1.05)
	lower.material_override = _pipe
	lower.position = Vector3(x, 0.525, 0)
	parent.add_child(lower)
	var upper_length := 1.0
	var tilt := deg_to_rad(28.0)
	var upper := MeshInstance3D.new()
	upper.mesh = _cylinder(POST_RADIUS, upper_length)
	upper.material_override = _pipe
	upper.rotation = Vector3(tilt, 0, deg_to_rad(-6.0))
	upper.position = Vector3(x, 1.05, 0) + upper.basis * Vector3(0, upper_length / 2.0, 0)
	parent.add_child(upper)


## Cano de `a` até `b`.
func _rail(parent: Node3D, a: Vector3, b: Vector3, radius: float) -> void:
	var rail := MeshInstance3D.new()
	rail.mesh = _cylinder(radius, a.distance_to(b))
	rail.material_override = _pipe if radius > 0.01 else _wire_material()
	var dir := (b - a).normalized()
	var side := dir.cross(Vector3.FORWARD if absf(dir.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	rail.basis = Basis(side, dir, side.cross(dir)).orthonormalized()
	rail.position = (a + b) / 2.0
	parent.add_child(rail)


func _wire_material() -> StandardMaterial3D:
	var wire := StandardMaterial3D.new()
	wire.albedo_color = Color(0.5, 0.48, 0.45)
	wire.metallic = 0.6
	wire.roughness = 0.5
	return wire


## Tela: faixas verticais de 25 cm (o quebrado tem a borda de cima rasgada e baixa no vão do
## poste torto). Embaixo a cor puxa para a ferrugem (água de chuva parada).
func _panel(parent: Node3D, length: float, broken: bool) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := length / 2.0
	var strip := 0.25
	var count := int(round(length / strip))
	var tops: Array[float] = []
	for i in count + 1:
		var x := -half + i * strip
		var top := MESH_TOP
		if broken:
			var torn_from := -half + SPAN * 0.6
			var torn_to := -half + SPAN * 1.5
			if x > torn_from and x < torn_to:
				var k := (x - torn_from) / (torn_to - torn_from)
				top = lerpf(MESH_TOP, 1.15, sin(k * PI)) + _rng.randf_range(-0.12, 0.08)
			elif x >= torn_to:
				# Depois do rasgo a tela fica frouxa, caindo um pouco.
				top = MESH_TOP - 0.08 - _rng.randf_range(0.0, 0.1) * clampf((half - x) / SPAN, 0.0, 1.0)
		tops.append(top)
	for i in count:
		var x0 := -half + i * strip
		var x1 := x0 + strip
		_quad(tool, Vector3(x0, MESH_BOTTOM, 0), Vector3(x1, MESH_BOTTOM, 0), Vector3(x1, tops[i + 1], 0), Vector3(x0, tops[i], 0))
	tool.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = tool.commit()
	mesh.material_override = _mesh_material
	# Sombra da tela sairia como um painel sólido; só os canos fazem sombra.
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)


func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v: Vector3 in [a, b, c, a, c, d]:
		var rust := clampf(1.0 - v.y / 0.7, 0.0, 1.0)
		tool.set_color(Color(1.0, 1.0, 1.0).lerp(Color(0.82, 0.62, 0.48), rust * 0.8))
		tool.set_uv(Vector2(v.x / TILE, -v.y / TILE))
		tool.set_uv2(Vector2(v.x / 3.0, -v.y / 2.0))
		tool.add_vertex(v)


## Pedaço de tela arrebentado em cima, dobrado para fora do lado da rua, com a borda irregular.
func _flap(parent: Node3D, from_x: float, to_x: float) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 4
	var hinge_y := 1.2
	for i in steps:
		var x0 := lerpf(from_x, to_x, float(i) / steps)
		var x1 := lerpf(from_x, to_x, float(i + 1) / steps)
		var h0 := 0.45 + _rng.randf_range(-0.12, 0.12)
		var h1 := 0.45 + _rng.randf_range(-0.12, 0.12)
		var fold := deg_to_rad(_rng.randf_range(50.0, 70.0))
		var up := Vector3(0, cos(fold), sin(fold))
		var a := Vector3(x0, hinge_y + 0.05, 0)
		var b := Vector3(x1, hinge_y + 0.05, 0)
		_quad(tool, a, b, b + up * h1, a + up * h0)
	tool.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = tool.commit()
	mesh.material_override = _mesh_material
	# Sombra da tela sairia como um painel sólido; só os canos fazem sombra.
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
