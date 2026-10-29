class_name ProceduralAnims
extends RefCounted
## Animações que o pacote de modelos não tem (pulo, queda, escalada), montadas por código
## girando ossos a partir da pose parada do esqueleto. Se o modelo já tiver uma animação
## com o mesmo nome, a dele vence e esta não é criada.
##
## Cada pose diz quantos graus cada osso gira em torno do eixo lateral do corpo:
## negativo leva para a frente (levantar o braço, a coxa), positivo para trás (dobrar o joelho).
##
## Nesse esqueleto os pés são controladores presos na raiz (não na canela). Por isso, depois de
## girar a perna, o pé é levado para o fim dela; senão a malha da perna estica até o chão.

const CROUCH := {
	"Torso": -12.0, "UpperLeg.L": -35.0, "UpperLeg.R": -35.0, "LowerLeg.L": 65.0, "LowerLeg.R": 65.0,
	"UpperArm.L": 20.0, "UpperArm.R": 20.0,
}
const LEAP := {
	"Torso": 4.0, "UpperLeg.L": -20.0, "UpperLeg.R": 8.0, "LowerLeg.L": 25.0, "LowerLeg.R": 35.0,
	"UpperArm.L": -125.0, "UpperArm.R": -125.0, "LowerArm.L": -25.0, "LowerArm.R": -25.0,
}
const AIR := {
	"Torso": -6.0, "UpperLeg.L": -55.0, "UpperLeg.R": -20.0, "LowerLeg.L": 85.0, "LowerLeg.R": 60.0,
	"UpperArm.L": -80.0, "UpperArm.R": -80.0, "LowerArm.L": -35.0, "LowerArm.R": -35.0,
}
const HANG := {
	"UpperArm.L": -165.0, "UpperArm.R": -165.0, "LowerArm.L": -10.0, "LowerArm.R": -10.0,
	"UpperLeg.L": -40.0, "LowerLeg.L": 70.0, "UpperLeg.R": -10.0, "LowerLeg.R": 30.0,
}
const PULL := {
	"Torso": -25.0, "UpperArm.L": -70.0, "UpperArm.R": -70.0, "LowerArm.L": -80.0, "LowerArm.R": -80.0,
	"UpperLeg.L": -75.0, "LowerLeg.L": 95.0, "UpperLeg.R": -30.0, "LowerLeg.R": 50.0,
}

## Ossos que seguem outro como se fossem filhos dele (o pé segue a canela).
const FOLLOW := {"Foot.L": "LowerLeg.L", "Foot.R": "LowerLeg.R"}

## nome -> [[tempo, pose], ...]. A última pose fica parada até outra animação começar.
const ANIMS := {
	"Jump": [[0.0, CROUCH], [0.1, LEAP], [0.42, AIR]],
	"Fall": [[0.0, AIR], [1.0, AIR]],
	"Climb": [[0.0, HANG], [0.55, PULL], [1.0, CROUCH]],
}


static func install(anim: AnimationPlayer, skeleton: Skeleton3D, skeleton_path: NodePath) -> void:
	var library := anim.get_animation_library("")
	if library == null:
		return
	for anim_name: String in ANIMS:
		if not anim.has_animation(anim_name):
			library.add_animation(anim_name, _build(ANIMS[anim_name], skeleton, skeleton_path))


static func _build(keys: Array, skeleton: Skeleton3D, skeleton_path: NodePath) -> Animation:
	var animation := Animation.new()
	animation.length = keys[-1][0]
	var bones := {}
	for key: Array in keys:
		for bone: String in key[1]:
			bones[bone] = true
	for bone: String in bones:
		var index := skeleton.find_bone(bone)
		if index == -1:
			continue
		var track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, "%s:%s" % [skeleton_path, bone])
		for key: Array in keys:
			animation.rotation_track_insert_key(track, key[0], _rotated(skeleton, index, key[1].get(bone, 0.0)))

	for follower: String in FOLLOW:
		var index := skeleton.find_bone(follower)
		var leader := skeleton.find_bone(FOLLOW[follower])
		if index == -1 or leader == -1:
			continue
		var position_track := animation.add_track(Animation.TYPE_POSITION_3D)
		var rotation_track := animation.add_track(Animation.TYPE_ROTATION_3D)
		for track in [position_track, rotation_track]:
			animation.track_set_path(track, "%s:%s" % [skeleton_path, follower])
		# Onde o pé fica em relação à canela na pose parada.
		var offset := skeleton.get_bone_global_rest(leader).affine_inverse() * skeleton.get_bone_global_rest(index)
		var parent := skeleton.get_bone_parent(index)
		var parent_global := skeleton.get_bone_global_rest(parent) if parent != -1 else Transform3D.IDENTITY
		for key: Array in keys:
			var leader_global := _posed_global(skeleton, leader, key[1])
			var local := parent_global.affine_inverse() * (leader_global * offset)
			animation.position_track_insert_key(position_track, key[0], local.origin)
			animation.rotation_track_insert_key(rotation_track, key[0], Quaternion(local.basis.orthonormalized()))
	return animation


## Transformação global de um osso numa pose (cinemática direta pela cadeia de pais).
static func _posed_global(skeleton: Skeleton3D, index: int, pose: Dictionary) -> Transform3D:
	var chain: Array[int] = []
	var bone := index
	while bone != -1:
		chain.push_front(bone)
		bone = skeleton.get_bone_parent(bone)
	var global := Transform3D.IDENTITY
	for b in chain:
		var rest := skeleton.get_bone_rest(b)
		var local := Transform3D(Basis(_rotated(skeleton, b, pose.get(skeleton.get_bone_name(b), 0.0))), rest.origin)
		global = global * local
	return global


## Rotação local do osso girado `degrees` em torno do eixo lateral do corpo.
static func _rotated(skeleton: Skeleton3D, index: int, degrees: float) -> Quaternion:
	var rest := skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
	if degrees == 0.0:
		return rest
	var parent := skeleton.get_bone_parent(index)
	var parent_basis := skeleton.get_bone_global_rest(parent).basis if parent != -1 else Basis.IDENTITY
	var axis := (parent_basis.inverse() * Vector3.RIGHT).normalized()
	return (Quaternion(axis, deg_to_rad(degrees)) * rest).normalized()
