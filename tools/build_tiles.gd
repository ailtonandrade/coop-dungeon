extends SceneTree
## Gera a biblioteca de peças de pintura do mapa (world/tiles/tiles.meshlib), usada pela grade
## de pintura (GridMap) de cada bloco. Cada peça tem 1 m de base e já vem com colisão.
## Paredes usam o material que abre buraco em volta do herói (wall_cutout.gdshader).
## Rodar de novo atualiza as peças sem mexer no que já foi pintado (os ids continuam).
##
## Rodar: godot --headless --path coop-dungeon -s tools/build_tiles.gd

## id -> [nome na paleta, tipo, cor]
const TILES := {
	0: ["Chão: pedra", "floor", Color(0.38, 0.36, 0.33)],
	1: ["Chão: grama", "floor", Color(0.22, 0.34, 0.16)],
	2: ["Chão: terra", "floor", Color(0.32, 0.24, 0.15)],
	3: ["Chão: madeira", "floor", Color(0.38, 0.26, 0.15)],
	4: ["Chão: areia", "floor", Color(0.55, 0.48, 0.32)],
	5: ["Chão: caverna", "floor", Color(0.2, 0.19, 0.2)],
	10: ["Parede", "wall", Color(0.75, 0.68, 0.55)],
	11: ["Parede de pedra", "wall", Color(0.36, 0.35, 0.37)],
	12: ["Parede de caverna", "wall_tall", Color(0.3, 0.28, 0.3)],
	13: ["Mureta", "low_wall", Color(0.55, 0.53, 0.5)],
	14: ["Coluna", "pillar", Color(0.6, 0.58, 0.55)],
	15: ["Cerca", "fence", Color(0.45, 0.3, 0.17)],
	20: ["Bloco de pedra", "block", Color(0.5, 0.5, 0.52)],
	21: ["Bloco de terra", "block", Color(0.4, 0.3, 0.2)],
	22: ["Rampa", "ramp", Color(0.5, 0.5, 0.52)],
}


func _initialize() -> void:
	var shader: Shader = load("res://world/tiles/wall_cutout.gdshader")
	var library := MeshLibrary.new()
	for id: int in TILES:
		var info: Array = TILES[id]
		var color: Color = info[2]
		library.create_item(id)
		library.set_item_name(id, info[0])
		var mesh: Mesh
		var shapes := []
		match info[1]:
			"floor":
				mesh = _box(Vector3(1, 0.04, 1), _plain(color))
				library.set_item_mesh_transform(id, Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0)))
			"wall", "wall_tall", "low_wall":
				var height: float = {"wall": 3.0, "wall_tall": 4.0, "low_wall": 1.0}[info[1]]
				var material := ShaderMaterial.new()
				material.shader = shader
				material.set_shader_parameter("albedo", color)
				ResourceSaver.save(material, "res://world/tiles/wall_%d.tres" % id)
				mesh = _box(Vector3(1, height, 0.3), load("res://world/tiles/wall_%d.tres" % id))
				library.set_item_mesh_transform(id, Transform3D(Basis.IDENTITY, Vector3(0, height / 2, 0)))
				shapes = [_box_shape(Vector3(1, height, 0.3)), Transform3D(Basis.IDENTITY, Vector3(0, height / 2, 0))]
			"pillar":
				mesh = _box(Vector3(0.5, 3, 0.5), _plain(color))
				library.set_item_mesh_transform(id, Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 0)))
				shapes = [_box_shape(Vector3(0.5, 3, 0.5)), Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 0))]
			"fence":
				mesh = _box(Vector3(1, 0.9, 0.12), _plain(color))
				library.set_item_mesh_transform(id, Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 0)))
				shapes = [_box_shape(Vector3(1, 0.9, 0.12)), Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 0))]
			"block":
				mesh = _box(Vector3(1, 1, 1), _plain(color))
				library.set_item_mesh_transform(id, Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)))
				shapes = [_box_shape(Vector3(1, 1, 1)), Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0))]
			"ramp":
				var prism := PrismMesh.new()
				prism.left_to_right = 0.0
				prism.size = Vector3(1, 1, 1)
				prism.material = _plain(color)
				mesh = prism
				library.set_item_mesh_transform(id, Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)))
				var convex := ConvexPolygonShape3D.new()
				convex.points = prism.get_faces()
				shapes = [convex, Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0))]
		library.set_item_mesh(id, mesh)
		library.set_item_shapes(id, shapes)
	var err := ResourceSaver.save(library, "res://world/tiles/tiles.meshlib")
	print("Peças salvas: ", error_string(err), " (", TILES.size(), " peças)")
	quit()


func _box(size: Vector3, material: Material) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	return box


func _box_shape(size: Vector3) -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	return shape


func _plain(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
