@tool
extends RefCounted
## "Ajustar no 3D": em vez de digitar números, encaixa a arma (ou peça) no herói com as setas do
## próprio Godot. Monta uma cena com o herói na pose de referência segurando o item ("Arma", no
## osso da mão) e, se for arma, a cópia guardada no coldre ("ArmaGuardada"). Mover (W), girar (E)
## e escalar (R) esses nós e salvar (Ctrl+S) grava na ficha: encaixe na mão, tamanho do modelo e
## ajuste do coldre.

const PATH := "res://addons/item_editor/ajuste_no_3d.tscn"
const HERO := "res://assets/characters/Adventurer.glb"
const POSE_SCRIPT := "res://addons/item_editor/fit_pose.gd"


## Monta e salva a cena do item. `host`: nó do editor para a pose rodar antes de salvar.
static func build(def: ItemDef, host: Node) -> String:
	var root := Node3D.new()
	root.name = "AjusteNo3D"
	root.set_script(load(POSE_SCRIPT))
	root.set_meta("item_id", def.id)
	var hero := (load(HERO) as PackedScene).instantiate() as Node3D
	hero.name = "Heroi"
	root.add_child(hero)
	hero.owner = root
	# Os encaixes ficam dentro do esqueleto do herói (cena instanciada): sem "filhos editáveis"
	# o Godot não grava nós postos lá dentro.
	root.set_editable_instance(hero, true)
	host.add_child(root)
	var skeleton: Skeleton3D = hero.find_children("*", "Skeleton3D", true, false)[0]
	var pose := ItemVisuals._reference_pose(hero, skeleton)
	var entry := {"id": def.id, "rarity": "common", "power": 1}
	var item := ItemDB.def(entry)
	# Pose de referência de cada osso usado (é dela que saem posição e giro do encaixe).
	var refs := {}
	var mount := ItemVisuals.mount_of(item)
	if mount.is_empty():
		mount = ["Wrist.R", Vector3.ZERO, Vector3.ZERO]
	_place(root, skeleton, pose, refs, "Mao", "Arma", mount, ItemVisuals.build(entry))
	if WeaponCarry.WEAPON_SLOTS.has(item.get("slot", "")):
		var holster := WeaponCarry.holster_of(item)
		if not holster.is_empty():
			var stowed := ItemVisuals.build(entry)
			var fix := WeaponCarry.axis_fix(item)
			if fix != Vector3.ZERO:
				for child in stowed.get_children():
					(child as Node3D).transform = Transform3D(Basis.from_euler(fix * PI / 180.0), Vector3.ZERO) * (child as Node3D).transform
			_place(root, skeleton, pose, refs, "Coldre", "ArmaGuardada", holster, stowed)
	root.set_meta("refs", refs)
	host.remove_child(root)
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	ResourceSaver.save(packed, PATH)
	packed.take_over_path(PATH)
	return PATH


static func _place(root: Node, skeleton: Skeleton3D, pose: Array[Transform3D], refs: Dictionary,
		attachment_name: String, piece_name: String, mount: Array, piece: Node3D) -> void:
	var index := skeleton.find_bone(mount[0])
	if index == -1:
		piece.free()
		return
	var rest := pose[index]
	refs[attachment_name] = rest
	var attachment := BoneAttachment3D.new()
	attachment.name = attachment_name
	attachment.bone_name = mount[0]
	skeleton.add_child(attachment)
	attachment.owner = root
	var holder := Node3D.new()
	holder.name = piece_name
	holder.transform = rest.affine_inverse() * Transform3D(Basis.from_euler(mount[2] * PI / 180.0), rest.origin + mount[1])
	attachment.add_child(holder)
	holder.owner = root
	piece.name = "Modelo"
	holder.add_child(piece)
	_own(piece, root)


## Grava a peça inteira na cena (cenas instanciadas dentro dela continuam instâncias).
static func _own(node: Node, root: Node) -> void:
	node.owner = root
	if node.scene_file_path.is_empty():
		for child in node.get_children():
			_own(child, root)


## Lê o que foi ajustado na cena aberta e grava na ficha. Retorna o que mudou ("" se nada).
static func apply(def: ItemDef, root: Node) -> String:
	if root == null or root.get_meta("item_id", "") != def.id:
		return ""
	var refs: Dictionary = root.get_meta("refs", {})
	var report := PackedStringArray()
	var hand := root.find_child("Mao", true, false) as BoneAttachment3D
	var arma := hand.get_node_or_null("Arma") as Node3D if hand else null
	if arma and refs.has("Mao"):
		var wanted: Transform3D = refs["Mao"] * arma.transform
		var grow := arma.transform.basis.get_scale()
		var factor := (grow.x + grow.y + grow.z) / 3.0
		if absf(factor - 1.0) > 0.001:
			def.model_scale = snappedf(def.model_scale * factor, 0.001)
			report.append("tamanho x%.2f" % factor)
		def.custom_mount = true
		def.mount_bone = hand.bone_name
		def.mount_position = _round((wanted.origin - (refs["Mao"] as Transform3D).origin))
		def.mount_rotation = _round(wanted.basis.orthonormalized().get_euler() * 180.0 / PI)
		report.append("encaixe na mão")
	var holster_node := root.find_child("Coldre", true, false) as BoneAttachment3D
	var stowed := holster_node.get_node_or_null("ArmaGuardada") as Node3D if holster_node else null
	if stowed and refs.has("Coldre"):
		var wanted: Transform3D = refs["Coldre"] * stowed.transform
		var base_def := ItemDB.def({"id": def.id}).duplicate()
		base_def.erase("holster_adjust")
		var base := WeaponCarry.holster_of(base_def)
		if not base.is_empty():
			def.holster_position = _round(wanted.origin - (refs["Coldre"] as Transform3D).origin - base[1])
			def.holster_rotation = _round(wanted.basis.orthonormalized().get_euler() * 180.0 / PI - base[2])
			report.append("coldre")
	return ", ".join(report)


static func _round(v: Vector3) -> Vector3:
	return Vector3(snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001))
