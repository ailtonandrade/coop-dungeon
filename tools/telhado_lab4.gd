extends SceneTree
## Põe a laje do Laboratório 4 (bloco 2,2): antes era "sem teto" e dava para escalar a parede e
## cair lá dentro, pulando o portão do teclado. A laje é sólida (anda-se em cima) e some quando
## alguém está dentro (FadeOccluder com a zona do salão), como nas casas. Tira as vigas soltas.
## godot --headless --path . -s tools/telhado_lab4.gd

const LIXAO := "res://world/chunks/chunk_2_2.tscn"
const LAB_SIZE := Vector2(22, 16)
const H := 3.6


func _initialize() -> void:
	var scene: Node = (load(LIXAO) as PackedScene).instantiate()
	var lab := scene.get_node_or_null("Navigation/Laboratorio4") as Node3D
	if lab == null:
		push_error("Laboratorio4 não encontrado")
		quit(1)
		return
	var concrete: Material = null
	for child in lab.get_children():
		var name := String(child.name)
		if name.begins_with("Viga") or name.begins_with("LajeQuebrada"):
			if concrete == null and child is MeshInstance3D:
				concrete = (child as MeshInstance3D).material_override
			lab.remove_child(child)
			child.free()
		elif name == "Telhado":
			lab.remove_child(child)
			child.free()
	if concrete == null:
		concrete = load("res://world/materials/contrapiso.tres")
	var roof := FadeOccluder.new()
	roof.name = "Telhado"
	roof.zone = AABB(Vector3(-LAB_SIZE.x / 2.0, 0.0, -LAB_SIZE.y / 2.0), Vector3(LAB_SIZE.x, H, LAB_SIZE.y))
	roof.inside_fade = 1.0
	lab.add_child(roof)
	var slab := MeshInstance3D.new()
	slab.name = "Laje"
	var box := BoxMesh.new()
	box.size = Vector3(LAB_SIZE.x + 0.5, 0.3, LAB_SIZE.y + 0.5)
	slab.mesh = box
	slab.material_override = concrete
	slab.position = Vector3(0, H + 0.15, 0)
	roof.add_child(slab)
	var body := StaticBody3D.new()
	body.name = "LajeColisao"
	body.collision_layer = GameConfig.LAYER_ROOF | GameConfig.LAYER_OCCLUDER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box.size
	shape.shape = box_shape
	shape.position = slab.position
	body.add_child(shape)
	roof.add_child(body)
	for node in [roof, slab, body, shape]:
		node.owner = scene
	var packed := PackedScene.new()
	packed.pack(scene)
	ResourceSaver.save(packed, LIXAO)
	scene.free()
	print("telhado do laboratório pronto")
	quit()
