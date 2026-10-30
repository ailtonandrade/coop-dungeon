class_name ItemVisuals
extends RefCounted
## Peças visuais dos itens, montadas com blocos (provisórias, trocáveis por modelos .glb).
## O mesmo modelo serve para o item no chão (loot) e preso no esqueleto do herói.
## Peito, pernas e pés pintam as próprias malhas do personagem (encaixa em qualquer modelo);
## elmo, ombreiras, armas, amuleto e bolsas são peças presas nos ossos.
##
## Para prender no herói, cada tipo diz em qual osso vai e onde fica em relação ao corpo
## parado (1º quadro da animação "Idle"). A conta converte isso para o espaço do osso,
## então funciona com qualquer personagem que use o mesmo esqueleto (os Quaternius atuais).

const METAL := Color(0.72, 0.74, 0.78)
const WOOD := Color(0.5, 0.33, 0.18)
const ATTACH_META := "equipment_piece"

## Onde cada tipo vai no corpo: [osso, posição relativa ao osso com o corpo parado, rotação em graus].
## O corpo olha para +Z (frente) e +Y é para cima.
const MOUNTS := {
	"sword": ["Wrist.R", Vector3(0.0, -0.06, 0.04), Vector3(80, 0, 0)],
	"dagger": ["Wrist.R", Vector3(0.0, -0.06, 0.04), Vector3(80, 0, 0)],
	"axe": ["Wrist.R", Vector3(0.0, -0.06, 0.04), Vector3(80, 0, 0)],
	"hammer": ["Wrist.R", Vector3(0.0, -0.06, 0.04), Vector3(80, 0, 0)],
	"bow": ["Wrist.L", Vector3(0.0, -0.06, 0.02), Vector3(0, 0, 0)],
	"longbow": ["Wrist.L", Vector3(0.0, -0.06, 0.02), Vector3(0, 0, 0)],
	"crossbow": ["Wrist.L", Vector3(0.0, -0.08, 0.06), Vector3(0, 0, 0)],
	"hood": ["Head", Vector3(0.0, 0.15, 0.05), Vector3.ZERO],
	"helmet": ["Head", Vector3(0.0, 0.16, 0.05), Vector3.ZERO],
	"plate": ["Chest", Vector3(0.0, 0.06, 0.03), Vector3.ZERO],
	"amulet": ["Neck", Vector3(0.0, -0.1, 0.13), Vector3.ZERO],
	"pouch": ["Hips", Vector3(0.2, -0.02, 0.0), Vector3.ZERO],
	"backpack": ["Chest", Vector3(0.0, 0.04, -0.22), Vector3.ZERO],
}
## Tipos que pintam uma malha do personagem (pelo fim do nome da malha no modelo).
const PAINTS := {"vest": "body", "plate": "body", "legs": "legs", "boots": "feet"}


## Modelo 3D do item (centrado na origem; armas com o cabo na origem e a ponta para +Y).
static func build(item: Dictionary) -> Node3D:
	var def := ItemDB.def(item)
	var look: String = def.get("look", "")
	var color: Color = def.get("color", METAL)
	var shine := ItemDB.rarity_color(item) if item.get("rarity", "common") != "common" else Color.BLACK
	var root := Node3D.new()
	match look:
		"sword":
			_box(root, Vector3(0.07, 0.72, 0.02), Vector3(0, 0.5, 0), METAL, shine)
			_box(root, Vector3(0.24, 0.04, 0.06), Vector3(0, 0.13, 0), WOOD.darkened(0.3))
			_box(root, Vector3(0.045, 0.2, 0.045), Vector3(0, 0.02, 0), WOOD)
		"dagger":
			_box(root, Vector3(0.06, 0.36, 0.02), Vector3(0, 0.3, 0), METAL, shine)
			_box(root, Vector3(0.16, 0.035, 0.05), Vector3(0, 0.11, 0), WOOD.darkened(0.3))
			_box(root, Vector3(0.04, 0.16, 0.04), Vector3(0, 0.02, 0), WOOD)
		"axe":
			_box(root, Vector3(0.05, 0.8, 0.05), Vector3(0, 0.3, 0), WOOD)
			_box(root, Vector3(0.28, 0.24, 0.035), Vector3(0.12, 0.6, 0), METAL, shine)
		"hammer":
			_box(root, Vector3(0.05, 0.8, 0.05), Vector3(0, 0.3, 0), WOOD)
			_box(root, Vector3(0.34, 0.18, 0.18), Vector3(0, 0.66, 0), METAL.darkened(0.15), shine)
		"bow", "longbow":
			var s := 1.3 if look == "longbow" else 1.0
			_box(root, Vector3(0.05, 0.16, 0.05), Vector3.ZERO, WOOD)
			_box(root, Vector3(0.04, 0.38 * s, 0.04), Vector3(0, 0.24 * s, 0.06), WOOD, shine, Vector3(-25, 0, 0))
			_box(root, Vector3(0.04, 0.38 * s, 0.04), Vector3(0, -0.24 * s, 0.06), WOOD, shine, Vector3(25, 0, 0))
			_box(root, Vector3(0.01, 0.78 * s, 0.01), Vector3(0, 0, 0.14), Color(0.9, 0.9, 0.85))
		"crossbow":
			_box(root, Vector3(0.07, 0.07, 0.55), Vector3(0, 0, 0.12), WOOD)
			_box(root, Vector3(0.6, 0.05, 0.05), Vector3(0, 0, 0.32), METAL.darkened(0.2), shine)
		"hood":
			_box(root, Vector3(0.27, 0.19, 0.31), Vector3.ZERO, color, shine)
			_box(root, Vector3(0.27, 0.16, 0.04), Vector3(0, -0.12, -0.14), color.darkened(0.15))
		"helmet":
			_box(root, Vector3(0.27, 0.2, 0.31), Vector3.ZERO, color, shine)
			_box(root, Vector3(0.29, 0.04, 0.33), Vector3(0, -0.08, 0), color.darkened(0.15))
		"vest":
			_box(root, Vector3(0.31, 0.36, 0.21), Vector3.ZERO, color, shine)
		"plate":
			# No herói só as ombreiras são peça; o resto pinta o corpo.
			_box(root, Vector3(0.14, 0.08, 0.2), Vector3(0.2, 0.0, 0), color.darkened(0.1), shine)
			_box(root, Vector3(0.14, 0.08, 0.2), Vector3(-0.2, 0.0, 0), color.darkened(0.1), shine)
		"legs":
			_box(root, Vector3(0.11, 0.34, 0.11), Vector3.ZERO, color, shine)
		"boots":
			_box(root, Vector3(0.12, 0.1, 0.2), Vector3(0, 0.04, 0.05), color, shine)
		"amulet":
			_box(root, Vector3(0.09, 0.09, 0.03), Vector3.ZERO, color, color)
		"ring":
			_box(root, Vector3(0.08, 0.08, 0.02), Vector3.ZERO, color, color)
		"pouch":
			_box(root, Vector3(0.16, 0.18, 0.12), Vector3.ZERO, color, shine)
		"coins":
			for i in 3:
				_box(root, Vector3(0.14, 0.03, 0.14), Vector3(0.03 * i, 0.035 * i, 0.0), color, color)
		"backpack":
			var size: float = 1.15 if def.get("capacity", 0) > 12 else 1.0
			_box(root, Vector3(0.36, 0.4, 0.2) * size, Vector3.ZERO, color, shine)
			_box(root, Vector3(0.38, 0.1, 0.22) * size, Vector3(0, 0.18, 0.01) * size, color.darkened(0.2))
	return root


## Veste o modelo com os itens de `visual` ([{id, rarity}]), trocando o que havia antes.
static func dress(model: Node, visual: Array) -> void:
	var skeletons := model.find_children("*", "Skeleton3D", true, false) if model else []
	if skeletons.is_empty():
		return
	var skeleton: Skeleton3D = skeletons[0]
	var pose := _reference_pose(model, skeleton)
	for child in skeleton.get_children():
		if child.has_meta(ATTACH_META):
			child.queue_free()
	# A mochila do próprio modelo dá lugar à mochila equipada.
	for mesh: MeshInstance3D in skeleton.find_children("*", "MeshInstance3D", false, false):
		if mesh.name.to_lower().contains("backpack"):
			mesh.visible = false
	var paints := {}  # parte do corpo -> material
	for entry: Dictionary in visual:
		if not ItemDB.DEFS.has(entry.get("id", "")):
			continue
		var def: Dictionary = ItemDB.DEFS[entry.id]
		var look: String = def.get("look", "")
		if PAINTS.has(look):
			paints[PAINTS[look]] = _paint_material(def.get("color", METAL), entry)
		if MOUNTS.has(look):
			var mount: Array = MOUNTS[look]
			_attach(skeleton, pose, mount[0], build(entry), mount[1], mount[2])
	for mesh: MeshInstance3D in skeleton.find_children("*", "MeshInstance3D", false, false):
		var part := ""
		for key in ["body", "legs", "feet"]:
			if mesh.name.to_lower().ends_with(key):
				part = key
		if part:
			mesh.material_overlay = paints.get(part)


static func _paint_material(color: Color, entry: Dictionary) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, 0.85)
	material.roughness = 0.6
	if entry.get("rarity", "common") != "common":
		material.emission_enabled = true
		material.emission = ItemDB.RARITIES[entry.rarity].color
		material.emission_energy_multiplier = 0.25
	return material


## Pose de cada osso no 1º quadro da animação "Idle" (a pose em que as peças foram ajustadas).
## Sem "Idle", usa a pose de descanso do esqueleto.
static func _reference_pose(model: Node, skeleton: Skeleton3D) -> Array[Transform3D]:
	var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var previous := ""
	var position := 0.0
	var use_idle := anim != null and anim.has_animation("Idle") and anim.is_inside_tree()
	if use_idle:
		previous = anim.current_animation
		position = anim.current_animation_position if previous else 0.0
		anim.play("Idle")
		anim.seek(0.0, true)
	var pose: Array[Transform3D] = []
	for i in skeleton.get_bone_count():
		pose.append(skeleton.get_bone_global_pose(i) if use_idle else skeleton.get_bone_global_rest(i))
	if use_idle:
		if previous:
			anim.play(previous)
			anim.seek(position, true)
		else:
			anim.stop()
	return pose


static func _attach(skeleton: Skeleton3D, pose: Array[Transform3D], bone: String, piece: Node3D,
		offset: Vector3, rotation_deg: Vector3) -> void:
	var index := skeleton.find_bone(bone)
	if index == -1:
		piece.free()
		return
	var rest := pose[index]
	var wanted := Transform3D(Basis.from_euler(rotation_deg * PI / 180.0), rest.origin + offset)
	_mount(skeleton, bone, piece, rest.affine_inverse() * wanted)


static func _mount(skeleton: Skeleton3D, bone: String, piece: Node3D, local: Transform3D) -> void:
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone
	attachment.set_meta(ATTACH_META, true)
	skeleton.add_child(attachment)
	piece.transform = local
	attachment.add_child(piece)


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, glow := Color.BLACK,
		rotation_deg := Vector3.ZERO) -> void:
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if glow != Color.BLACK:
		material.emission_enabled = true
		material.emission = glow
		material.emission_energy_multiplier = 0.6
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = pos
	mesh.rotation_degrees = rotation_deg
	parent.add_child(mesh)
