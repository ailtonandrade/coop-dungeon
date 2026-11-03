extends SceneTree
## Muda a história de lugar:
##  - O barraco com portão na vila (casa do canto sudoeste) vira ESCOMBROS: o prédio foi
##    demolido por ordem do governo; no meio do entulho fica o ofício de transferência.
##  - O LABORATÓRIO 4 da Sinapse (Dra. Helena) fica longe, no Lixão Alto (bloco 2,2): prédio de
##    concreto sem teto, portão de serviço com teclado (a chave do caderno da Helena), salão
##    cheio de androides de segurança, o terminal do Rafael e a sala do servidor trancada por
##    senha (minigame de invasão) com um baú.
## Tudo vira peça normal do mapa (dá para mexer no editor). Rodar uma vez:
##   godot --headless --path . -s tools/laboratorio_helena.gd

const VILA := "res://world/chunks/chunk_0_0.tscn"
const LIXAO := "res://world/chunks/chunk_2_2.tscn"
const HISTORIA_VILA := "res://world/lore/historia_vila.tscn"
const SIGN := "res://world/prefabs/letreiro_neon.tscn"
const CHEST := "res://world/prefabs/bau_de_saque.tscn"
const NOTE_SCRIPT := "res://world/lore/lore_note.gd"
const GATE_SCRIPT := "res://world/lore/lore_gate.gd"
const SPAWNER_SCRIPT := "res://world/creature_spawner.gd"
const WALL_MAT := "res://world/materials/parede.tres"
const FLOOR_MAT := "res://world/materials/contrapiso.tres"

## Laboratório: centro, largura (x), fundo (z), altura das paredes, espessura.
const LAB_CENTER := Vector3(24, 0, 40)
const LAB_SIZE := Vector2(22, 16)
const H := 3.6
const T := 0.35
const ANDROID := 3

var _concrete: StandardMaterial3D


func _initialize() -> void:
	_concrete = StandardMaterial3D.new()
	_concrete.albedo_texture = load("res://world/textures/contrapiso.png")
	_concrete.albedo_color = Color(0.85, 0.86, 0.84)
	_concrete.uv1_triplanar = true
	_concrete.uv1_world_triplanar = true
	_concrete.uv1_scale = Vector3.ONE / 3.0
	_concrete.roughness = 0.95
	var tools: Script = load("res://addons/map_editor/map_tools.gd")
	_build_lab(tools)
	_ruin_village(tools)
	_fix_story_scene()
	print("Laboratório da Helena: pronto")
	quit()


## Laboratório no Lixão Alto

func _build_lab(tools: Script) -> void:
	var scene: Node3D = tools.open_scene(LIXAO)
	var nav := scene.get_node("Navigation")
	# Tira o que estava no meio do terreno do prédio.
	for old in ["Rock_1", "Barrel_33_40", "CinderBlock_35_47"]:
		var node := nav.get_node_or_null(old)
		if node:
			nav.remove_child(node)
			node.free()
	for old in ["Laboratorio4", "Lab4_Coisas"]:
		for parent in [nav, scene]:
			var node: Node = parent.get_node_or_null(old)
			if node:
				parent.remove_child(node)
				node.free()
	var lab := Node3D.new()
	lab.name = "Laboratorio4"
	lab.position = LAB_CENTER
	nav.add_child(lab)
	lab.owner = scene
	var w := LAB_SIZE.x
	var d := LAB_SIZE.y
	var front := d / 2.0
	# Paredes externas (porta de 2,6 m no meio da frente).
	_wall(lab, scene, "ParedeFundo", Vector3(0, H / 2, -front), Vector3(w, H, T))
	_wall(lab, scene, "ParedeEsq", Vector3(-w / 2, H / 2, 0), Vector3(T, H, d))
	_wall(lab, scene, "ParedeDir", Vector3(w / 2, H / 2, 0), Vector3(T, H, d))
	var side := (w - 2.6) / 2.0
	_wall(lab, scene, "FrenteEsq", Vector3(-w / 2 + side / 2, H / 2, front), Vector3(side, H, T))
	_wall(lab, scene, "FrenteDir", Vector3(w / 2 - side / 2, H / 2, front), Vector3(side, H, T))
	_wall(lab, scene, "Verga", Vector3(0, H - 0.45, front), Vector3(2.6, 0.9, T))
	# Hall de entrada separado do salão (vão de 2 m aberto).
	var hall := front - 4.0
	var inner := (w - 2.0) / 2.0
	_wall(lab, scene, "HallEsq", Vector3(-w / 2 + inner / 2, H / 2, hall), Vector3(inner, H, T))
	_wall(lab, scene, "HallDir", Vector3(w / 2 - inner / 2, H / 2, hall), Vector3(inner, H, T))
	# Sala do servidor (fundo à esquerda), com porta de grade trancada por senha.
	var server_w := 7.0
	var server_d := 5.5
	_wall(lab, scene, "ServidorLado", Vector3(-w / 2 + server_w, H / 2, -front + server_d / 2), Vector3(T, H, server_d))
	var gap := 2.0
	var left_part := (server_w - gap) / 2.0
	_wall(lab, scene, "ServidorFrenteA", Vector3(-w / 2 + left_part / 2, H / 2, -front + server_d), Vector3(left_part, H, T))
	_wall(lab, scene, "ServidorFrenteB", Vector3(-w / 2 + server_w - left_part / 2, H / 2, -front + server_d), Vector3(left_part, H, T))
	# Vigas do teto que caiu (dá para ver de cima o que tem dentro).
	for x: float in [-6.0, 1.5, 7.5]:
		_box(lab, scene, "Viga", Vector3(x, H + 0.15, 0), Vector3(0.4, 0.3, d + 0.4), _concrete, false)
	_box(lab, scene, "LajeQuebrada", Vector3(-w / 2 + 3.5, H + 0.1, front - 2.0), Vector3(7, 0.25, 4), _concrete, false)
	# Piso.
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Piso"
	var plane := PlaneMesh.new()
	plane.size = LAB_SIZE - Vector2(0.4, 0.4)
	floor_mesh.mesh = plane
	floor_mesh.position.y = 0.02
	floor_mesh.material_override = load(FLOOR_MAT)
	lab.add_child(floor_mesh)
	floor_mesh.owner = scene
	# Bancadas com monitores (o que sobrou do laboratório).
	var bench_spots := [Vector3(2, 0, -2), Vector3(7.5, 0, -2), Vector3(2, 0, 1.8), Vector3(7.5, 0, 1.8), Vector3(-3, 0, 1.8)]
	for i in bench_spots.size():
		_bench(lab, scene, "Bancada_%d" % i, bench_spots[i], i)
	# Entulho e lixo dentro.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 14:
		var at := Vector3(rng.randf_range(-w / 2 + 1, w / 2 - 1), 0, rng.randf_range(-front + 1, front - 1))
		var size := Vector3(rng.randf_range(0.3, 1.0), rng.randf_range(0.15, 0.5), rng.randf_range(0.3, 0.9))
		var chunk := _box(lab, scene, "Entulho", at + Vector3(0, size.y / 2.0, 0), size, _concrete if i % 3 else load(WALL_MAT), size.x > 0.7)
		chunk.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0, TAU), rng.randf_range(-0.3, 0.3))

	# Coisas da história (fora da Navigation: não entram no cálculo do caminho).
	var stuff := Node3D.new()
	stuff.name = "Lab4_Coisas"
	stuff.position = LAB_CENTER
	scene.add_child(stuff)
	stuff.owner = scene
	var gate: Node3D = StaticBody3D.new()
	gate.set_script(load(GATE_SCRIPT))
	gate.name = "PortaoLab4"
	gate.position = Vector3(0, 0, front)
	gate.set("size", Vector2(2.6, 2.7))
	gate.set("lock", "codigo")
	gate.set("code", "70-R-ALFA-9")
	gate.set("unlock_fact", "lab4_portao")
	stuff.add_child(gate)
	gate.owner = scene
	var server_gate: Node3D = StaticBody3D.new()
	server_gate.set_script(load(GATE_SCRIPT))
	server_gate.name = "PortaoServidor"
	server_gate.position = Vector3(-w / 2 + server_w / 2, 0, -front + server_d)
	server_gate.set("size", Vector2(2.0, 2.5))
	server_gate.set("lock", "invasao")
	server_gate.set("unlock_fact", "lab4_servidor")
	stuff.add_child(server_gate)
	server_gate.owner = scene
	var terminal: Node3D = Node3D.new()
	terminal.set_script(load(NOTE_SCRIPT))
	terminal.name = "TerminalRafael"
	terminal.position = Vector3(6, 0, -front + 0.8)
	terminal.set("document_id", "log_rafael")
	terminal.set("look", "terminal")
	stuff.add_child(terminal)
	terminal.owner = scene
	var record: Node3D = Node3D.new()
	record.set_script(load(NOTE_SCRIPT))
	record.name = "RegistroServidor"
	record.position = Vector3(-w / 2 + 1.2, 0, -front + 1.0)
	record.set("document_id", "registro_lab4")
	record.set("look", "terminal")
	stuff.add_child(record)
	record.owner = scene
	var chest: Node3D = (load(CHEST) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	chest.name = "BauServidor"
	chest.position = Vector3(-w / 2 + 4.2, 0, -front + 1.0)
	chest.set("container_id", "lab4_bau_servidor")
	stuff.add_child(chest)
	chest.owner = scene
	var sign: Node3D = (load(SIGN) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	sign.name = "LetreiroLab4"
	sign.position = Vector3(0, H + 0.1, front + 0.25)
	sign.set("text", "SINAPSE · LAB 4")
	sign.set("color", Color(0.25, 0.85, 1.0))
	sign.set("icon", "chip")
	sign.set("flicker", true)
	sign.set("letter_height", 0.36)
	stuff.add_child(sign)
	sign.owner = scene
	# Androides de segurança: salão e sala do servidor.
	_spawner(stuff, scene, "AndroidesSalao", Vector3(4, 0, -1), PackedInt32Array([ANDROID, ANDROID]), 4)
	_spawner(stuff, scene, "AndroidesFundo", Vector3(-4, 0, 1), PackedInt32Array([ANDROID, ANDROID, 2]), 3)
	_spawner(stuff, scene, "AndroideServidor", Vector3(-w / 2 + 3.5, 0, -front + 2.6), PackedInt32Array([ANDROID]), 1)
	# Luzes frias que sobraram.
	for at: Vector3 in [Vector3(4, 3.0, -2), Vector3(-6, 3.0, 2), Vector3(0, 2.8, front - 2)]:
		var light := OmniLight3D.new()
		light.name = "LuzFria"
		light.position = at
		light.light_color = Color(0.7, 0.85, 1.0)
		light.light_energy = 0.9
		light.omni_range = 7.0
		stuff.add_child(light)
		light.owner = scene
	tools.save_scene(scene, LIXAO, null)


func _wall(parent: Node3D, scene: Node, node_name: String, center: Vector3, size: Vector3) -> void:
	_box(parent, scene, node_name, center, size, _concrete, true)


func _box(parent: Node3D, scene: Node, node_name: String, center: Vector3, size: Vector3, material: Material, solid: bool) -> Node3D:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	root.name = node_name
	root.position = center
	parent.add_child(root, true)
	root.owner = scene
	if solid:
		var shape := CollisionShape3D.new()
		shape.name = "Collision"
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		root.add_child(shape)
		shape.owner = scene
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	root.add_child(mesh)
	mesh.owner = scene
	return root


func _bench(parent: Node3D, scene: Node, node_name: String, at: Vector3, index: int) -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.32, 0.34, 0.36)
	metal.metallic = 0.6
	metal.roughness = 0.6
	var bench := _box(parent, scene, node_name, at + Vector3(0, 0.45, 0), Vector3(3.2, 0.9, 0.9), metal, true)
	var screen := StandardMaterial3D.new()
	screen.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen.albedo_color = Color(0.2, 0.8, 0.4) if index % 2 == 0 else Color(0.06, 0.08, 0.07)
	for x: float in [-0.8, 0.7]:
		var monitor := _box(bench, scene, "Monitor", Vector3(x, 0.72, -0.15), Vector3(0.6, 0.42, 0.06), screen, false)
		monitor.rotation.y = randf_range(-0.3, 0.3)


func _spawner(parent: Node3D, scene: Node, node_name: String, at: Vector3, kinds: PackedInt32Array, count: int) -> void:
	var spawner: Node3D = Marker3D.new()
	spawner.set_script(load(SPAWNER_SCRIPT))
	spawner.name = node_name
	spawner.position = at
	spawner.set("kinds", kinds)
	spawner.set("count", count)
	spawner.set("spread", 2.5)
	spawner.set("aggro_radius", 9.0)
	spawner.set("leash_radius", 13.0)
	spawner.set("power", 7)
	spawner.set("respawn_time", 240.0)
	parent.add_child(spawner)
	spawner.owner = scene


## Escombros na vila

func _ruin_village(tools: Script) -> void:
	var scene: Node3D = tools.open_scene(VILA)
	var house := scene.get_node_or_null("Navigation/House_14_50")
	if house:
		# Demolido: sem teto, a frente e a lateral direita no chão.
		for gone in ["Roof", "FrontWalls/WallRight", "FrontWalls/Lintel", "FrontWalls/WallFrontR"]:
			var node := house.get_node_or_null(gone)
			if node:
				node.get_parent().remove_child(node)
				node.free()
	# A lanchonete não existe mais (o lugar é entulho).
	for gone in ["Neon/Letreiro_Lanches", "Capricho/Toldo_Lanches", "Capricho/Mesa_Lanches", "Capricho/Ar_Lanches"]:
		var node := scene.get_node_or_null(gone)
		if node:
			node.get_parent().remove_child(node)
			node.free()
	var old := scene.get_node_or_null("Navigation/Escombros")
	if old:
		old.get_parent().remove_child(old)
		old.free()
	var pile := Node3D.new()
	pile.name = "Escombros"
	pile.position = Vector3(14, 0, 50)
	scene.get_node("Navigation").add_child(pile)
	pile.owner = scene
	var brick: Material = load(WALL_MAT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 50
	# Montes de parede caída (pedaços grandes, sólidos) onde ficavam a frente e a lateral.
	for i in 18:
		var at := Vector3(rng.randf_range(-1.0, 5.5), 0, rng.randf_range(-2.5, 4.8))
		if i < 7:
			at = Vector3(rng.randf_range(0.5, 5.5), 0, rng.randf_range(3.0, 5.2))
		var size := Vector3(rng.randf_range(0.6, 2.2), rng.randf_range(0.2, 0.7), rng.randf_range(0.4, 1.4))
		var piece := _box(pile, scene, "Pedaco", at + Vector3(0, size.y / 2.0 - 0.05, 0), size, brick if i % 2 == 0 else _concrete, size.x > 1.2)
		piece.rotation = Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(0, TAU), rng.randf_range(-0.35, 0.35))
	# Tijolos soltos.
	for i in 26:
		var at := Vector3(rng.randf_range(-3.0, 6.0), 0.06, rng.randf_range(-2.0, 6.0))
		var loose := _box(pile, scene, "Tijolo", at, Vector3(0.24, 0.1, 0.12), brick, false)
		loose.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0, TAU), rng.randf_range(-0.4, 0.4))
	tools.save_scene(scene, VILA, null)


## Cena da história da vila: sai o portão e o terminal do Rafael (foram para o laboratório);
## entra o ofício de transferência no meio do entulho.
func _fix_story_scene() -> void:
	var root: Node3D = (load(HISTORIA_VILA) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	for gone in ["PortaoRafael", "TerminalRafael", "OficioTransferencia"]:
		var node := root.get_node_or_null(gone)
		if node:
			root.remove_child(node)
			node.free()
	var note: Node3D = Node3D.new()
	note.set_script(load(NOTE_SCRIPT))
	note.name = "OficioTransferencia"
	note.position = Vector3(13.2, 0, 49.4)
	note.set("document_id", "ordem_transferencia")
	note.set("look", "caderno")
	root.add_child(note)
	note.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, HISTORIA_VILA)
	root.free()
