class_name ItemVisuals
extends RefCounted
## Peças visuais dos itens: o modelo 3D da ficha (ItemDef.model) ou, sem ele, um modelo
## provisório de blocos pelo tipo (look).
## O mesmo modelo serve para o item no chão (loot) e preso no esqueleto do herói.
## Peito, pernas e pés pintam as próprias malhas do personagem (encaixa em qualquer modelo);
## elmo, ombreiras, armas, amuleto e bolsas são peças presas nos ossos.
##
## Para prender no herói, cada tipo diz em qual osso vai e onde fica em relação ao corpo
## parado (1º quadro da animação "Idle"). A conta converte isso para o espaço do osso,
## então funciona com qualquer personagem que use o mesmo esqueleto (os Quaternius atuais).

const METAL := Color(0.72, 0.74, 0.78)
## Tinta de ferramenta de obra, gasta, e peças das armas improvisadas.
const TOOL_YELLOW := Color(0.74, 0.58, 0.16)
const TOOL_RED := Color(0.62, 0.2, 0.12)
const RUBBER := Color(0.12, 0.12, 0.13)
const GUNMETAL := Color(0.3, 0.31, 0.33)
const BRASS := Color(0.72, 0.56, 0.28)
const TAPE := Color(0.22, 0.24, 0.27)
const WOOD := Color(0.5, 0.33, 0.18)
const ATTACH_META := "equipment_piece"

## Onde cada tipo vai no corpo: [osso, posição relativa ao osso com o corpo parado, rotação em graus].
## O corpo olha para +Z (frente) e +Y é para cima.
const MOUNTS := {
	"sword": ["Wrist.R", Vector3(0.0, -0.06, 0.04), Vector3(80, 0, 0)],
	"dagger": ["Wrist.R", Vector3(0.0, -0.06, 0.04), Vector3(80, 0, 0)],
	"axe": ["Wrist.R", Vector3(0.0, -0.06, 0.04), Vector3(80, 0, 0)],
	"hammer": ["Wrist.R", Vector3(0.0, -0.06, 0.04), Vector3(80, 0, 0)],
	# Armas de longe na mão direita, como pistola: as animações de tiro (Gun_Shoot, Run_Shoot,
	# Idle_Gun_Pointing) apontam o braço direito.
	"bow": ["Wrist.R", Vector3(0.0, -0.07, 0.03), Vector3(180, 0, 0)],
	"longbow": ["Wrist.R", Vector3(0.0, -0.07, 0.03), Vector3(180, 0, 0)],
	"crossbow": ["Wrist.R", Vector3(0.0, -0.07, 0.03), Vector3(180, 0, 0)],
	"pistol": ["Wrist.R", Vector3(0.0, -0.07, 0.03), Vector3(180, 0, 0)],
	"rifle": ["Wrist.R", Vector3(0.0, -0.07, 0.03), Vector3(180, 0, 0)],
	"shotgun": ["Wrist.R", Vector3(0.0, -0.07, 0.03), Vector3(180, 0, 0)],
	# Na pose de referência (Idle) o alto do crânio fica ~0,2 m acima do osso Head.
	"hood": ["Head", Vector3(0.0, 0.17, -0.01), Vector3.ZERO],
	"helmet": ["Head", Vector3(0.0, 0.17, -0.01), Vector3.ZERO],
	"amulet": ["Neck", Vector3(0.0, -0.1, 0.13), Vector3.ZERO],
	"pouch": ["Hips", Vector3(0.2, -0.02, 0.0), Vector3.ZERO],
	"backpack": ["Chest", Vector3(0.0, 0.04, -0.22), Vector3.ZERO],
}
## Tipos que pintam uma malha do personagem (pelo fim do nome da malha no modelo). As armaduras
## de corpo (ARMOR_LOOKS) agora são peças presas nos ossos; sobra o mapa para fichas antigas.
const PAINTS := {}
## Armaduras feitas de peças nos ossos (tronco, ombros, coxas, canelas, pés).
const ARMOR_LOOKS := ["vest", "plate", "legs", "boots"]


## Modelo 3D do item (centrado na origem; armas com o cabo na origem e a ponta para +Y).
static func build(item: Dictionary) -> Node3D:
	var def := ItemDB.def(item)
	var look: String = def.get("look", "")
	var color: Color = def.get("color", METAL)
	var shine := ItemDB.rarity_color(item) if item.get("rarity", "common") != "common" else Color.BLACK
	var root := Node3D.new()
	if def.get("model") is PackedScene:
		var model: Node3D = def.model.instantiate()
		model.scale = Vector3.ONE * float(def.get("model_scale", 1.0))
		model.rotation_degrees = def.get("model_rotation", Vector3.ZERO)
		model.position = def.get("model_offset", Vector3.ZERO)
		root.add_child(model)
		if shine != Color.BLACK:
			_glow(model, shine)
		return root
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
		# Armas de longe: ferramentas de obra viradas arma. Cabo (onde a mão segura) na origem,
		# cano para +Y e o cabo descendo para +Z (na mão, com o giro do encaixe, o cano aponta
		# para a frente e o cabo para baixo).
		"bow":
			_nail_gun(root, shine)
		"longbow":
			_rivet_rifle(root, shine)
		"crossbow":
			_nail_launcher(root, shine)
		"pistol":
			_pistol(root, shine)
		"rifle":
			_hunting_rifle(root, shine)
		"shotgun":
			_sawed_off(root, shine)
		"ammo_box":
			_ammo_box(root, color)
		"grenade":
			_grenade(root)
		"material":
			_material_pile(root, String(def.get("ammo_type", "metal")), color)
		"book":
			# Caderno de capa dura com as folhas aparecendo e um elástico.
			_box(root, Vector3(0.16, 0.035, 0.22), Vector3(0, 0.018, 0), color, shine)
			_box(root, Vector3(0.15, 0.025, 0.205), Vector3(0.006, 0.018, 0), Color(0.9, 0.86, 0.75))
			_box(root, Vector3(0.012, 0.04, 0.225), Vector3(0.06, 0.018, 0), Color(0.12, 0.1, 0.09))
		# Capuz e capacete por cima do crânio, sem cobrir o rosto (frente = +Z).
		"hood":
			_box(root, Vector3(0.23, 0.1, 0.26), Vector3.ZERO, color, shine)
			_box(root, Vector3(0.23, 0.17, 0.035), Vector3(0, -0.11, -0.12), color.darkened(0.15))
		"helmet":
			_box(root, Vector3(0.24, 0.11, 0.27), Vector3.ZERO, color, shine)
			_box(root, Vector3(0.27, 0.025, 0.3), Vector3(0, -0.05, 0.01), color.darkened(0.15))
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
			_coins(root, color, int(item.get("amount", 10)))
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
	hide_model_weapons(model)
	# A mochila do próprio modelo dá lugar à mochila equipada.
	for mesh: MeshInstance3D in skeleton.find_children("*", "MeshInstance3D", false, false):
		if mesh.name.to_lower().contains("backpack"):
			mesh.visible = false
	var paints := {}  # parte do corpo -> material
	var hidden := {}  # parte do corpo -> true (escondida por baixo de uma peça)
	for entry: Dictionary in visual:
		if not ItemDB.has(entry.get("id", "")):
			continue
		var def := ItemDB.def(entry)
		var look: String = def.get("look", "")
		# Armadura sem modelo próprio: peças de verdade presas nos ossos, por cima da roupa
		# (antes era uma pintura no corpo, que o piscar de dano apagava).
		if ARMOR_LOOKS.has(look) and not def.has("model"):
			_armor(skeleton, pose, look, def, entry)
			continue
		for part: String in def.get("hide_body", []):
			hidden[part] = true
		if def.get("wear", false) and def.get("model") is PackedScene:
			_wear(skeleton, def, entry)
			continue
		var mount := mount_of(def)
		# Armas: uma peça na mão e outra no coldre; só uma aparece (WeaponCarry.set_drawn).
		if not mount.is_empty() and WeaponCarry.WEAPON_SLOTS.has(def.get("slot", "")):
			var slot_name: String = def.slot
			var hand := _attach(skeleton, pose, mount[0], build(entry), mount[1], mount[2])
			var holster := WeaponCarry.holster_of(def)
			if hand:
				hand.set_meta("weapon_slot", slot_name)
				hand.set_meta("weapon_pose", "hand")
			if not holster.is_empty():
				var stowed := build(entry)
				var fix := WeaponCarry.axis_fix(def)
				if fix != Vector3.ZERO:
					for child in stowed.get_children():
						(child as Node3D).transform = Transform3D(Basis.from_euler(fix * PI / 180.0), Vector3.ZERO) * (child as Node3D).transform
				var back := _attach(skeleton, pose, holster[0], stowed, holster[1], holster[2])
				if back:
					back.set_meta("weapon_slot", slot_name)
					back.set_meta("weapon_pose", "holster")
			continue
		if not mount.is_empty():
			var piece := build(entry)
			# Chapéu importado sem encaixe próprio na ficha: cabe na cabeça, apoiado no topo.
			if def.get("slot", "") == "head" and def.has("model") and not def.has("mount"):
				_fit_on_head(piece)
			_attach(skeleton, pose, mount[0], piece, mount[1], mount[2])
	for mesh: MeshInstance3D in skeleton.find_children("*", "MeshInstance3D", false, false):
		if mesh.has_meta(ATTACH_META):
			continue
		var part := ""
		for key in ["body", "legs", "feet"]:
			if mesh.name.to_lower().ends_with(key):
				part = key
		if part:
			mesh.material_overlay = paints.get(part)
			mesh.visible = not hidden.has(part)
	WeaponCarry.set_drawn(model, model.get_meta("drawn_weapon", "melee"))


## Encaixe no corpo [osso, posição, rotação]: o da ficha, se ligado, senão o padrão do tipo.
## Vazio = não vai preso no corpo (só pinta, ou nem aparece, como anel).
static func mount_of(def: Dictionary) -> Array:
	if def.has("mount"):
		return def.mount
	var look: String = def.get("look", "")
	if MOUNTS.has(look) and not (def.has("model") and PAINTS.has(look) and look != "plate"):
		return MOUNTS[look]
	# Modelo próprio de peito/pernas/pés sem encaixe: vai no osso principal da parte.
	if def.has("model") and PAINTS.has(look):
		return {"vest": ["Chest", Vector3(0, 0, 0.02), Vector3.ZERO], "legs": ["Hips", Vector3(0, -0.2, 0), Vector3.ZERO],
				"boots": ["Foot.R", Vector3.ZERO, Vector3.ZERO]}[look]
	return []


## Veste uma peça com ossos: cada malha com pele (Skin) do modelo passa a seguir o esqueleto do
## personagem, ligada pelos nomes dos ossos, e dobra junto com as animações.
static func _wear(skeleton: Skeleton3D, def: Dictionary, entry: Dictionary) -> void:
	var source: Node = def.model.instantiate()
	var shine := ItemDB.rarity_color(entry) if entry.get("rarity", "common") != "common" else Color.BLACK
	for mesh: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin == null:
			continue
		var worn := MeshInstance3D.new()
		worn.name = "Veste_" + mesh.name
		worn.mesh = mesh.mesh
		worn.skin = mesh.skin
		for i in mesh.get_surface_override_material_count():
			worn.set_surface_override_material(i, mesh.get_surface_override_material(i))
		worn.set_meta(ATTACH_META, true)
		skeleton.add_child(worn)
		worn.skeleton = NodePath("..")
		if shine != Color.BLACK:
			_glow(worn, shine)
	source.free()


## Maior medida que um chapéu importado pode ter na cabeça (metros).
const HEAD_FIT := 0.32


## Encolhe (ou aumenta) o modelo para caber em HEAD_FIT e põe a base dele no ponto de encaixe.
static func _fit_on_head(piece: Node3D) -> void:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in piece.find_children("*", "MeshInstance3D", true, false):
		var local := _transform_to(piece, mesh) * mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	var biggest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if first or biggest <= 0.0001:
		return
	var factor := HEAD_FIT / biggest
	var holder := Node3D.new()
	for child in piece.get_children():
		piece.remove_child(child)
		holder.add_child(child)
	holder.scale = Vector3.ONE * factor
	holder.position = -Vector3(box.get_center().x, box.position.y + box.size.y * 0.25, box.get_center().z) * factor
	piece.add_child(holder)


static func _transform_to(ancestor: Node3D, node: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current: Node = node
	while current and current != ancestor:
		if current is Node3D:
			xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform


## Brilho da raridade por cima dos materiais do modelo.
static func _glow(root: Node, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(color, 0.18)
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for mesh: MeshInstance3D in meshes:
		mesh.material_overlay = material


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
		offset: Vector3, rotation_deg: Vector3) -> BoneAttachment3D:
	var index := skeleton.find_bone(bone)
	if index == -1:
		piece.free()
		return null
	var rest := pose[index]
	var wanted := Transform3D(Basis.from_euler(rotation_deg * PI / 180.0), rest.origin + offset)
	return _mount(skeleton, bone, piece, rest.affine_inverse() * wanted)


static func _mount(skeleton: Skeleton3D, bone: String, piece: Node3D, local: Transform3D) -> BoneAttachment3D:
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone
	attachment.set_meta(ATTACH_META, true)
	skeleton.add_child(attachment)
	piece.transform = local
	attachment.add_child(piece)
	return attachment


## Esconde armas que já vêm no modelo do personagem (WeaponCarry.MODEL_WEAPON_MESHES).
static func hide_model_weapons(model: Node) -> void:
	if model == null:
		return
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.has_meta(ATTACH_META) or mesh.get_parent() is BoneAttachment3D:
			continue
		var lower := String(mesh.name).to_lower()
		for word: String in WeaponCarry.MODEL_WEAPON_MESHES:
			if lower == word or lower.begins_with(word + "_") or lower.ends_with("_" + word):
				mesh.visible = false


## Montinho de parafusos (o dinheiro do jogo): mais moedas quanto maior a quantia, umas
## empilhadas e outras espalhadas em volta. Sempre igual para a mesma quantia.
static func _coins(root: Node3D, color: Color, amount: int) -> void:
	var count := clampi(3 + int(sqrt(float(maxi(amount, 1)))), 4, 14)
	var rng := RandomNumberGenerator.new()
	rng.seed = amount
	var coin := CylinderMesh.new()
	coin.top_radius = 0.055
	coin.bottom_radius = 0.055
	coin.height = 0.018
	coin.radial_segments = 14
	coin.rings = 1
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.9
	material.roughness = 0.3
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.25
	coin.material = material
	var stack := mini(count / 2, 5)
	for i in count:
		var mesh := MeshInstance3D.new()
		mesh.mesh = coin
		if i < stack:
			# Pilha no meio, meio torta.
			mesh.position = Vector3(rng.randf_range(-0.012, 0.012), 0.009 + i * 0.019, rng.randf_range(-0.012, 0.012))
			mesh.rotation = Vector3(rng.randf_range(-0.06, 0.06), 0, rng.randf_range(-0.06, 0.06))
		else:
			var angle := rng.randf() * TAU
			var radius := rng.randf_range(0.1, 0.2)
			mesh.position = Vector3(cos(angle) * radius, 0.012, sin(angle) * radius)
			mesh.rotation = Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
		root.add_child(mesh)


## Pistola 9mm velha: ferrolho escuro gasto, cabo com fita.
static func _pistol(root: Node3D, shine: Color) -> void:
	_part(root, Vector3(0.04, 0.2, 0.05), Vector3(0, 0.07, -0.06), GUNMETAL.darkened(0.2), shine)
	_part(root, Vector3(0.036, 0.19, 0.03), Vector3(0, 0.065, -0.025), GUNMETAL)
	_part(root, Vector3(0.016, 0.02, 0.016), Vector3(0, 0.175, -0.065), RUBBER)
	_part(root, Vector3(0.038, 0.05, 0.12), Vector3(0, -0.005, 0.03), RUBBER, Color.BLACK, -14.0)
	_part(root, Vector3(0.042, 0.025, 0.04), Vector3(0, -0.01, 0.06), TAPE, Color.BLACK, -14.0)
	_part(root, Vector3(0.01, 0.05, 0.035), Vector3(0, 0.035, 0.0), GUNMETAL.darkened(0.3))


## Rifle de caça: cano longo, ferrolho, luneta remendada e coronha de madeira.
static func _hunting_rifle(root: Node3D, shine: Color) -> void:
	_part(root, Vector3(0.05, 0.3, 0.06), Vector3(0, 0.08, -0.06), WOOD, shine)
	_part(root, Vector3(0.028, 0.46, 0.028), Vector3(0, 0.44, -0.08), GUNMETAL)
	_part(root, Vector3(0.045, 0.14, 0.05), Vector3(0, 0.1, -0.1), GUNMETAL.darkened(0.2))
	_part(root, Vector3(0.03, 0.16, 0.03), Vector3(0, 0.12, -0.15), RUBBER)
	_part(root, Vector3(0.012, 0.03, 0.03), Vector3(0.03, 0.06, -0.1), GUNMETAL)
	_part(root, Vector3(0.045, 0.05, 0.11), Vector3(0, -0.01, 0.02), WOOD.darkened(0.15), Color.BLACK, -12.0)
	_part(root, Vector3(0.05, 0.26, 0.08), Vector3(0, -0.18, -0.04), WOOD, Color.BLACK, -5.0)
	_part(root, Vector3(0.055, 0.03, 0.1), Vector3(0, -0.31, -0.03), RUBBER)
	_part(root, Vector3(0.035, 0.04, 0.035), Vector3(0, 0.3, -0.08), TAPE)


## Escopeta de cano serrado: dois canos curtos lado a lado, coronha cortada.
static func _sawed_off(root: Node3D, shine: Color) -> void:
	_part(root, Vector3(0.06, 0.12, 0.06), Vector3(0, 0.06, -0.06), GUNMETAL.darkened(0.15), shine)
	_part(root, Vector3(0.028, 0.3, 0.028), Vector3(0.015, 0.26, -0.075), GUNMETAL)
	_part(root, Vector3(0.028, 0.3, 0.028), Vector3(-0.015, 0.26, -0.075), GUNMETAL)
	_part(root, Vector3(0.05, 0.16, 0.035), Vector3(0, 0.2, -0.045), WOOD.darkened(0.1))
	_part(root, Vector3(0.045, 0.06, 0.12), Vector3(0, -0.02, 0.02), WOOD, Color.BLACK, -14.0)
	_part(root, Vector3(0.05, 0.1, 0.07), Vector3(0, -0.07, -0.03), WOOD.darkened(0.2), Color.BLACK, -8.0)
	_part(root, Vector3(0.06, 0.03, 0.065), Vector3(0, 0.13, -0.065), TAPE)


## Caixa de munição: caixinha de papelão/metal com a cor do tipo e uma faixa escura.
static func _ammo_box(root: Node3D, color: Color) -> void:
	_box(root, Vector3(0.2, 0.1, 0.13), Vector3(0, 0.05, 0), color)
	_box(root, Vector3(0.205, 0.03, 0.135), Vector3(0, 0.07, 0), color.darkened(0.45))
	_box(root, Vector3(0.06, 0.012, 0.04), Vector3(0.05, 0.105, 0), BRASS)


## Punhado de material da base: chapas tortas (metal), tábuas (madeira) ou placas
## esverdeadas (fibra de vidro).
static func _material_pile(root: Node3D, type: String, color: Color) -> void:
	match type:
		"madeira":
			_box(root, Vector3(0.42, 0.04, 0.09), Vector3(0, 0.02, -0.05), color, Color.BLACK, Vector3(0, 12, 0))
			_box(root, Vector3(0.4, 0.04, 0.08), Vector3(0, 0.06, 0.04), color.darkened(0.15), Color.BLACK, Vector3(0, -8, 0))
			_box(root, Vector3(0.38, 0.04, 0.08), Vector3(0.02, 0.1, 0.0), color.lightened(0.08), Color.BLACK, Vector3(0, 25, 0))
		"fibra":
			_box(root, Vector3(0.3, 0.02, 0.24), Vector3(0, 0.02, 0), color, Color.BLACK, Vector3(0, 10, 4))
			_box(root, Vector3(0.28, 0.02, 0.22), Vector3(0.02, 0.05, 0.02), color.lightened(0.1), Color.BLACK, Vector3(0, -15, -3))
		_:
			_box(root, Vector3(0.3, 0.015, 0.22), Vector3(0, 0.02, 0), color, Color.BLACK, Vector3(0, 0, 6))
			_box(root, Vector3(0.26, 0.015, 0.2), Vector3(0.02, 0.05, 0.01), color.darkened(0.2), Color.BLACK, Vector3(8, 30, -5))
			_box(root, Vector3(0.05, 0.05, 0.24), Vector3(-0.08, 0.08, 0), color.darkened(0.35))


## Granada caseira: lata verde com fita, pavio e anel.
static func _grenade(root: Node3D) -> void:
	_box(root, Vector3(0.08, 0.11, 0.08), Vector3(0, 0.055, 0), Color(0.3, 0.4, 0.25))
	_box(root, Vector3(0.085, 0.025, 0.085), Vector3(0, 0.05, 0), TAPE)
	_box(root, Vector3(0.03, 0.035, 0.03), Vector3(0, 0.125, 0), GUNMETAL)
	_box(root, Vector3(0.006, 0.05, 0.006), Vector3(0.012, 0.16, 0), Color(0.6, 0.5, 0.35))
	_box(root, Vector3(0.035, 0.035, 0.006), Vector3(-0.025, 0.135, 0), METAL)


## Armadura vestida: caixas presas nos ossos (seguem a animação), um pouco maiores que o
## corpo, no material do item (lona/couro/pneu, ou lata/aço quando a cor é cinza).
static func _armor(skeleton: Skeleton3D, pose: Array[Transform3D], look: String, def: Dictionary, entry: Dictionary) -> void:
	var color: Color = def.get("color", METAL)
	var metal := color.s < 0.2
	var shine := ItemDB.rarity_color(entry) if entry.get("rarity", "common") != "common" else Color.BLACK
	var main := _armor_material(color, metal, shine)
	var dark := _armor_material(color.darkened(0.3), metal, Color.BLACK)
	var strap := _armor_material(Color(0.2, 0.16, 0.12), false, Color.BLACK)
	match look:
		"vest", "plate":
			var plate := look == "plate"
			var span := 0.36 if plate else 0.33
			# Peito (no osso do peito) e barriga (no abdômen): dobram com o tronco.
			_segment(skeleton, pose, "Chest", "Torso", "Neck", 0.0, 0.92, Vector3(span, 0, 0.3 if plate else 0.28), main, Vector3(0, 0, 0.015))
			_segment(skeleton, pose, "Abdomen", "Abdomen", "Torso", 0.15, 1.05, Vector3(span - 0.03, 0, 0.27 if plate else 0.26), dark if plate else main, Vector3(0, 0, 0.01))
			if plate:
				# Faixas das placas e ombreiras.
				_segment(skeleton, pose, "Chest", "Torso", "Neck", 0.42, 0.5, Vector3(span + 0.01, 0, 0.31), dark, Vector3(0, 0, 0.015))
				for side: String in ["L", "R"]:
					_segment(skeleton, pose, "Shoulder." + side, "Shoulder." + side, "UpperArm." + side, 0.2, 1.6, Vector3(0.15, 0, 0.17), main, Vector3(0, 0.035, 0))
			else:
				# Alças por cima dos ombros.
				for side: String in ["L", "R"]:
					_segment(skeleton, pose, "Shoulder." + side, "Shoulder." + side, "UpperArm." + side, 0.0, 1.0, Vector3(0.07, 0, 0.29), strap, Vector3(0, 0.02, 0.0))
		"legs":
			for side: String in ["L", "R"]:
				var upper := "UpperLeg." + side
				var lower := "LowerLeg." + side
				var foot := "Foot." + side
				if metal:
					# Caneleiras e joelheiras de lata, coxa com uma placa na frente.
					_segment(skeleton, pose, upper, upper, lower, 0.25, 0.8, Vector3(0.15, 0, 0.06), main, Vector3(0, 0, 0.08))
					_segment(skeleton, pose, lower, lower, foot, -0.06, 0.12, Vector3(0.15, 0, 0.17), dark, Vector3(0, 0, 0.03))
					_segment(skeleton, pose, lower, lower, foot, 0.12, 0.82, Vector3(0.14, 0, 0.08), main, Vector3(0, 0, 0.06))
				else:
					# Calça de lona: coxa e canela cobertas, com remendo no joelho.
					_segment(skeleton, pose, upper, upper, lower, 0.0, 1.0, Vector3(0.19, 0, 0.19), main)
					_segment(skeleton, pose, lower, lower, foot, 0.0, 0.85, Vector3(0.155, 0, 0.16), main)
					_segment(skeleton, pose, lower, lower, foot, -0.04, 0.1, Vector3(0.16, 0, 0.17), dark, Vector3(0, 0, 0.01))
		"boots":
			for side: String in ["L", "R"]:
				var foot_bone := "Foot." + side
				var shin_bone := "LowerLeg." + side
				var index := skeleton.find_bone(foot_bone)
				if index == -1:
					continue
				var piece := Node3D.new()
				var sole_color := _armor_material(Color(0.12, 0.11, 0.1), false, Color.BLACK)
				# A bota encaixa no sapato do modelo (FootFit: segue a pele do sapato, que dobra
				# meio pé, meio canela). Origem no meio da sola, frente = +Z, cima = +Y.
				var fit := FootFit.make(skeleton, side)
				var length := fit.length + 0.05 if fit else 0.34
				var width := fit.width + 0.025 if fit else 0.145
				_material_box(piece, Vector3(width, 0.14, length), Vector3(0, 0.065, 0), main)
				_material_box(piece, Vector3(width + 0.005, 0.04, length + 0.01), Vector3(0, 0.0, 0), sole_color)
				if metal:
					_material_box(piece, Vector3(width + 0.005, 0.08, 0.09), Vector3(0, 0.06, length / 2.0 - 0.04), dark)
				if fit:
					fit.set_meta(ATTACH_META, true)
					fit.add_child(piece)
					skeleton.add_child(fit)
				else:
					# Modelo sem malha de pés: presa no osso do pé (como antes).
					var at := pose[index]
					var wanted := Transform3D(Basis.IDENTITY, Vector3(at.origin.x, at.origin.y, at.origin.z + 0.12))
					_mount(skeleton, foot_bone, piece, at.affine_inverse() * wanted)
				# Cano da bota subindo pela canela.
				if skeleton.find_bone(shin_bone) != -1:
					_segment(skeleton, pose, shin_bone, shin_bone, foot_bone, 0.72, 1.0, Vector3(0.15, 0, 0.16), _armor_material(color, metal, shine))


## Caixa ao longo do osso: de `from_t` a `to_t` do caminho entre os ossos `a` e `b` (na pose de
## referência), presa em `bone`. `size` = largura, (comprimento automático), profundidade.
static func _segment(skeleton: Skeleton3D, pose: Array[Transform3D], bone: String, a: String, b: String,
		from_t: float, to_t: float, size: Vector3, material: Material, offset := Vector3.ZERO) -> void:
	var bone_index := skeleton.find_bone(bone)
	var ia := skeleton.find_bone(a)
	var ib := skeleton.find_bone(b)
	if bone_index == -1 or ia == -1 or ib == -1:
		return
	var start := pose[ia].origin.lerp(pose[ib].origin, from_t)
	var end := pose[ia].origin.lerp(pose[ib].origin, to_t)
	var axis := end - start
	var length := maxf(axis.length(), 0.04)
	var up := axis.normalized() if axis.length() > 0.001 else Vector3.UP
	var forward := (Vector3.BACK - up * up.dot(Vector3.BACK)).normalized()
	if forward.length() < 0.1:
		forward = Vector3.FORWARD
	var right := up.cross(forward).normalized()
	var basis := Basis(right, up, right.cross(up)).orthonormalized()
	var center := (start + end) / 2.0 + offset
	var piece := Node3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x, length, size.z)
	mesh.mesh = box
	mesh.material_override = material
	piece.add_child(mesh)
	_mount(skeleton, bone, piece, pose[bone_index].affine_inverse() * Transform3D(basis, center))


static func _material_box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = pos
	parent.add_child(mesh)


static func _armor_material(color: Color, metal: bool, glow: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.45 if metal else 0.9
	material.metallic = 0.55 if metal else 0.0
	material.albedo_texture = load("res://world/textures/cano_enferrujado.png" if metal else "res://world/textures/sujeira.png")
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * 3.0
	if glow != Color.BLACK:
		material.emission_enabled = true
		material.emission = glow
		material.emission_energy_multiplier = 0.35
	return material


## Peça de arma no espaço dela: tamanho e posição em (lado, frente, baixo).
static func _part(root: Node3D, size: Vector3, pos: Vector3, color: Color, glow := Color.BLACK, tilt := 0.0) -> void:
	_box(root, size, pos, color, glow, Vector3(tilt, 0, 0))


## Pistola de pregos (pregador pneumático): corpo amarelo gasto, bico de aço, pente de pregos
## em fita e a mangueira de ar cortada atrás.
static func _nail_gun(root: Node3D, shine: Color) -> void:
	_part(root, Vector3(0.065, 0.24, 0.085), Vector3(0, 0.06, -0.075), TOOL_YELLOW, shine)
	_part(root, Vector3(0.07, 0.07, 0.07), Vector3(0, -0.06, -0.07), TOOL_YELLOW.darkened(0.25))
	_part(root, Vector3(0.04, 0.09, 0.045), Vector3(0, 0.22, -0.09), GUNMETAL)
	_part(root, Vector3(0.05, 0.02, 0.06), Vector3(0, 0.27, -0.08), GUNMETAL.darkened(0.3))
	_part(root, Vector3(0.05, 0.06, 0.13), Vector3(0, -0.01, 0.02), RUBBER, Color.BLACK, -12.0)
	_part(root, Vector3(0.055, 0.03, 0.05), Vector3(0, 0.0, 0.07), TAPE, Color.BLACK, -12.0)
	_part(root, Vector3(0.022, 0.2, 0.035), Vector3(0, 0.09, -0.015), BRASS, Color.BLACK, 8.0)
	_part(root, Vector3(0.012, 0.03, 0.04), Vector3(0, 0.035, -0.02), GUNMETAL)
	_part(root, Vector3(0.025, 0.07, 0.025), Vector3(0, -0.11, -0.06), RUBBER, Color.BLACK, 20.0)


## Rifle de rebites: rebitadeira com cano de cano d'água, coronha de madeira e fita isolante.
static func _rivet_rifle(root: Node3D, shine: Color) -> void:
	_part(root, Vector3(0.07, 0.26, 0.09), Vector3(0, 0.08, -0.08), TOOL_RED, shine)
	_part(root, Vector3(0.036, 0.34, 0.036), Vector3(0, 0.36, -0.1), GUNMETAL)
	_part(root, Vector3(0.05, 0.04, 0.05), Vector3(0, 0.5, -0.1), GUNMETAL.darkened(0.3))
	_part(root, Vector3(0.045, 0.05, 0.045), Vector3(0, 0.3, -0.1), TAPE)
	_part(root, Vector3(0.05, 0.06, 0.12), Vector3(0, -0.01, 0.02), RUBBER, Color.BLACK, -12.0)
	_part(root, Vector3(0.055, 0.24, 0.07), Vector3(0, -0.17, -0.06), WOOD, Color.BLACK, -6.0)
	_part(root, Vector3(0.06, 0.04, 0.1), Vector3(0, -0.29, -0.04), WOOD.darkened(0.3))
	_part(root, Vector3(0.024, 0.16, 0.04), Vector3(0, 0.12, -0.02), BRASS, Color.BLACK, 6.0)
	_part(root, Vector3(0.03, 0.06, 0.03), Vector3(0, 0.12, -0.14), GUNMETAL)


## Lança-pregos: pregador grande com cilindro de gás (botijão verde) amarrado embaixo do cano.
static func _nail_launcher(root: Node3D, shine: Color) -> void:
	_part(root, Vector3(0.085, 0.3, 0.1), Vector3(0, 0.08, -0.085), TOOL_YELLOW.darkened(0.15), shine)
	_part(root, Vector3(0.05, 0.16, 0.05), Vector3(0, 0.3, -0.1), GUNMETAL)
	_part(root, Vector3(0.065, 0.03, 0.065), Vector3(0, 0.38, -0.1), GUNMETAL.darkened(0.3))
	_part(root, Vector3(0.075, 0.22, 0.075), Vector3(0, 0.17, 0.0), Color(0.22, 0.4, 0.26))
	_part(root, Vector3(0.08, 0.025, 0.08), Vector3(0, 0.12, 0.0), TAPE)
	_part(root, Vector3(0.08, 0.025, 0.08), Vector3(0, 0.23, 0.0), TAPE)
	_part(root, Vector3(0.05, 0.06, 0.13), Vector3(0, -0.02, 0.03), RUBBER, Color.BLACK, -12.0)
	_part(root, Vector3(0.03, 0.16, 0.03), Vector3(0, -0.13, -0.06), GUNMETAL, Color.BLACK, -10.0)
	_part(root, Vector3(0.06, 0.03, 0.09), Vector3(0, -0.21, -0.05), RUBBER)


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
