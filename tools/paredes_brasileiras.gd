extends SceneTree
## Materiais da vila brasileira (parede de tijolo e reboco, contrapiso, sujeira) e aplica nas
## casas dos blocos e nas peças de casa. godot --headless --path . -s tools/paredes_brasileiras.gd

const WALL := "res://world/materials/parede.tres"
const FLOOR := "res://world/materials/contrapiso.tres"
const CHUNKS := "res://world/chunks/"
const HOUSE_PREFABS := ["res://world/prefabs/casa_pequena.tscn", "res://world/prefabs/casa_grande.tscn"]
const WALL_NAMES := ["WallBack", "WallLeft", "WallRight", "WallFrontL", "WallFrontR", "Lintel"]


func _initialize() -> void:
	var wall := ShaderMaterial.new()
	wall.shader = load("res://world/materials/parede.gdshader")
	wall.set_shader_parameter("wall_texture", load("res://world/textures/parede_tijolo_reboco.png"))
	wall.set_shader_parameter("grime", load("res://world/textures/sujeira.png"))
	ResourceSaver.save(wall, WALL)
	var floor := StandardMaterial3D.new()
	floor.albedo_texture = load("res://world/textures/contrapiso.png")
	floor.uv1_triplanar = true
	floor.uv1_world_triplanar = true
	floor.uv1_scale = Vector3.ONE / 4.0
	floor.roughness = 0.9
	ResourceSaver.save(floor, FLOOR)
	wall = load(WALL)
	floor = load(FLOOR)
	var tools: Script = load("res://addons/map_editor/map_tools.gd")
	var changed := 0
	for file in DirAccess.get_files_at(CHUNKS):
		if not file.ends_with(".tscn"):
			continue
		var path := CHUNKS + file
		var scene: Node3D = tools.open_scene(path)
		var count := _apply(scene, wall, floor)
		if count > 0:
			tools.save_scene(scene, path, null)
			changed += count
		else:
			scene.free()
	for path: String in HOUSE_PREFABS:
		var root: Node3D = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		changed += _apply(root, wall, floor, true)
		var packed := PackedScene.new()
		packed.pack(root)
		ResourceSaver.save(packed, path)
		root.free()
	print("Paredes brasileiras: %d peças" % changed)
	quit()


func _apply(scene: Node, wall: Material, floor: Material, is_prefab := false) -> int:
	var count := 0
	var houses := scene.find_children("House_*", "", true, false)
	if is_prefab:
		houses = [scene]
	for house: Node in houses:
		for name: String in WALL_NAMES:
			for body in house.find_children(name, "", true, false):
				var mesh := body.get_node_or_null("Mesh") as MeshInstance3D
				if mesh:
					mesh.material_override = wall
					count += 1
		# Piso: "Floor" nas peças, "Mesh" direto na casa nos blocos.
		for floor_name in ["Floor", "Mesh"]:
			var plane := house.get_node_or_null(floor_name) as MeshInstance3D
			if plane and plane.mesh is PlaneMesh:
				plane.material_override = floor
				count += 1
	return count
