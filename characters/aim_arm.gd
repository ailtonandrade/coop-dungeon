class_name AimArm
extends SkeletonModifier3D
## Braço da arma esticado por cima de qualquer animação: copia o braço direito (ombro até os
## dedos) do 1º quadro do "Idle_Gun_Pointing" e aplica depois da animação. Assim, correndo de
## costas ou de lado atirando (Run_Back, Run_Left...), o braço continua apontando a arma.
## Quem liga e desliga é o herói, pelo `influence` (entra e sai suave).

const SOURCE := "Idle_Gun_Pointing"
const ROOT_BONE := "Shoulder.R"

var _pose := {}  # índice do osso -> rotação local (Quaternion)
var _root := -1
## Giro do ombro no espaço do modelo, na pose de mira: o ombro segue isso (não o tronco, que as
## corridas torcem), e o resto do braço segue os giros locais.
var _root_global := Quaternion.IDENTITY


## Lê a pose do braço da animação de mira. false = o modelo não tem essa animação.
func setup(anim: AnimationPlayer, skeleton: Skeleton3D) -> bool:
	if anim == null or not anim.has_animation(SOURCE):
		return false
	var root := skeleton.find_bone(ROOT_BONE)
	if root == -1:
		return false
	var arm := {}
	var pending: Array[int] = [root]
	while not pending.is_empty():
		var bone: int = pending.pop_back()
		arm[bone] = true
		for child in skeleton.get_bone_children(bone):
			pending.append(child)
	var clip := anim.get_animation(SOURCE)
	for track in clip.get_track_count():
		if clip.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := skeleton.find_bone(String(clip.track_get_path(track)).get_slice(":", 1))
		if arm.has(bone):
			_pose[bone] = clip.rotation_track_interpolate(track, 0.0)
	# Giro do ombro no espaço do modelo, montando a pose do clipe pela cadeia de pais.
	var locals: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		locals.append(skeleton.get_bone_rest(bone))
	for track in clip.get_track_count():
		var bone := skeleton.find_bone(String(clip.track_get_path(track)).get_slice(":", 1))
		if bone == -1:
			continue
		if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			locals[bone].basis = Basis(clip.rotation_track_interpolate(track, 0.0))
		elif clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
			locals[bone].origin = clip.position_track_interpolate(track, 0.0)
	var chain: Array[int] = []
	var current := root
	while current != -1:
		chain.push_front(current)
		current = skeleton.get_bone_parent(current)
	var global := Transform3D.IDENTITY
	for bone in chain:
		global = global * locals[bone]
	_root = root
	_root_global = global.basis.orthonormalized().get_rotation_quaternion()
	influence = 0.0
	return not _pose.is_empty()


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	for bone: int in _pose:
		skeleton.set_bone_pose_rotation(bone, _pose[bone])
	var parent := skeleton.get_bone_parent(_root)
	if parent != -1:
		var parent_rotation := skeleton.get_bone_global_pose(parent).basis.orthonormalized().get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(_root, (parent_rotation.inverse() * _root_global).normalized())
