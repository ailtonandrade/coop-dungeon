class_name ProceduralAnims
extends RefCounted
## Animações que o pacote de modelos não tem (pulo, queda, escalada, pouso), montadas por código
## girando ossos a partir da pose PARADA do personagem (1º quadro do "Idle", não a pose de fábrica
## do esqueleto, que tem quadril e pernas tortos). Se o modelo já tiver uma animação com o mesmo
## nome, a dele vence e esta não é criada.
##
## Cada pose diz quantos graus cada osso gira em torno do eixo lateral do corpo:
## negativo leva para a frente (levantar o braço, a coxa), positivo para trás (dobrar o joelho).
## No tronco o sinal é o contrário (o osso aponta para o outro lado): positivo inclina para a frente.
##
## Nesse esqueleto os pés são controladores presos na raiz (não na canela). Por isso, depois de
## girar a perna, o pé é levado para o fim dela: no ar inclina junto com a canela (só frente/trás,
## com a ponta reta, sem pegar a torção da canela) (a bota é presa
## meio no pé, meio na canela, então pé parado com canela girada estica a bota); no chão fica reto
## e a pose deixa a canela quase em pé. Poses "no chão" (agachar, pousar) abaixam o quadril
## para os pés ficarem plantados em vez de subir.
##
## A animação grava TODOS os ossos (os que a pose não mexe ficam como no Idle): senão o que
## sobrasse da animação anterior (meio passo da corrida) ficava torto no ar.

const CROUCH := {
	"Torso": 14.0, "UpperLeg.L": -26.0, "UpperLeg.R": -26.0, "LowerLeg.L": 32.0, "LowerLeg.R": 32.0,
	"UpperArm.L": 14.0, "UpperArm.R": 14.0, "LowerArm.L": -10.0, "LowerArm.R": -10.0,
}
## Saindo do chão: uma perna puxa para a frente (joelho bem dobrado), a outra ainda empurra.
const LEAP := {
	"Torso": 8.0, "UpperLeg.L": -42.0, "LowerLeg.L": 72.0, "UpperLeg.R": -8.0, "LowerLeg.R": 45.0,
	"UpperArm.L": -12.0, "UpperArm.R": -8.0, "LowerArm.L": -18.0, "LowerArm.R": -18.0,
}
## No ar: pernas recolhidas (joelho entre 75° e 90°), uma um pouco à frente: dá a sensação de
## impulso. Braços baixos e soltos.
const AIR := {
	"Torso": 8.0, "UpperLeg.L": -52.0, "LowerLeg.L": 88.0, "UpperLeg.R": -40.0, "LowerLeg.R": 75.0,
	"UpperArm.L": -10.0, "UpperArm.R": -8.0, "LowerArm.L": -16.0, "LowerArm.R": -16.0,
}
const AIR_SWAY := {
	"Torso": 9.0, "UpperLeg.L": -48.0, "LowerLeg.L": 82.0, "UpperLeg.R": -44.0, "LowerLeg.R": 78.0,
	"UpperArm.L": -12.0, "UpperArm.R": -10.0, "LowerArm.L": -18.0, "LowerArm.R": -17.0,
}
## Pouso: amortece dobrando os joelhos (pés no chão).
const LANDING := {
	"Torso": 10.0, "UpperLeg.L": -22.0, "UpperLeg.R": -20.0, "LowerLeg.L": 27.0, "LowerLeg.R": 25.0,
	"UpperArm.L": -4.0, "UpperArm.R": -4.0, "LowerArm.L": -12.0, "LowerArm.R": -12.0,
}
const HANG := {
	"UpperArm.L": -165.0, "UpperArm.R": -165.0, "LowerArm.L": -10.0, "LowerArm.R": -10.0,
	"UpperLeg.L": -40.0, "LowerLeg.L": 70.0, "UpperLeg.R": -10.0, "LowerLeg.R": 30.0,
}
const PULL := {
	"Torso": 25.0, "UpperArm.L": -70.0, "UpperArm.R": -70.0, "LowerArm.L": -80.0, "LowerArm.R": -80.0,
	"UpperLeg.L": -75.0, "LowerLeg.L": 95.0, "UpperLeg.R": -30.0, "LowerLeg.R": 50.0,
}
const STAND := {}

## Ossos que seguem outro como se fossem filhos dele (o pé segue a canela).
const FOLLOW := {"Foot.L": "LowerLeg.L", "Foot.R": "LowerLeg.R"}
## Osso que desce para plantar os pés (pai das pernas).
const PELVIS := "Body"

## nome -> [[tempo, pose, pés no chão?], ...]. A última pose fica parada até outra começar.
const ANIMS := {
	"Jump": [[0.0, STAND, true], [0.07, CROUCH, true], [0.17, LEAP, false], [0.45, AIR, false]],
	"Fall": [[0.0, AIR, false], [0.6, AIR_SWAY, false], [1.2, AIR, false]],
	"Land": [[0.0, LANDING, true], [0.28, STAND, true]],
	"Climb": [[0.0, HANG, false], [0.55, PULL, false], [1.0, CROUCH, true]],
}


static func install(anim: AnimationPlayer, skeleton: Skeleton3D, skeleton_path: NodePath) -> void:
	var library := anim.get_animation_library("")
	if library == null:
		return
	straighten_stance_feet(anim, skeleton)
	var base := _base_pose(anim, skeleton)
	for anim_name: String in ANIMS:
		if not anim.has_animation(anim_name):
			library.add_animation(anim_name, _build(ANIMS[anim_name], skeleton, skeleton_path, base))


## Nas animações de ficar parado do pacote (Idle, Idle_Gun, Interact, Wave...) a perna esquerda
## vem girada para fora (o pé ~60° de lado) e, endireitando só o pé, a base ficava estreita e as
## pernas pareciam cruzar. O próprio pacote tem a "Idle_Neutral" com as pernas retas e os pés
## paralelos: essas animações passam a usar as pernas dela (paradas, na pose do 1º quadro). Tronco,
## braços e cabeça continuam os de cada animação. Uma vez por clipe (as animações são as mesmas
## para todos os personagens que usam o arquivo).
const STRAIGHT_META := "feet_straightened"
const LEGS_FROM := "Idle_Neutral"
## Pé mais virado que isto (graus, medido no sapato) com o pé no chão: a perna está torta.
const CROOKED_DEG := 15.0
const FLAT_MAX_PITCH_DEG := 25.0
const LEG_BONES := ["Body", "UpperLeg.L", "LowerLeg.L", "Foot.L", "UpperLeg.R", "LowerLeg.R", "Foot.R"]


static func straighten_stance_feet(anim: AnimationPlayer, skeleton: Skeleton3D) -> void:
	if not anim.has_animation(LEGS_FROM):
		return
	var source := anim.get_animation(LEGS_FROM)
	var skeleton_path := _skeleton_path_in(anim, skeleton)
	var fits := {}
	for side: String in ["L", "R"]:
		var fit := FootFit.make(skeleton, side, true)
		if fit:
			fits[side] = fit
	if fits.is_empty():
		return
	for anim_name: StringName in anim.get_animation_list():
		var clip := anim.get_animation(anim_name)
		if clip == null or clip == source or clip.has_meta(STRAIGHT_META):
			continue
		clip.set_meta(STRAIGHT_META, true)
		var crooked := false
		for side: String in fits:
			var heel := _skinned_in_clip(clip, anim, skeleton, fits[side]._points[0])
			var toe := _skinned_in_clip(clip, anim, skeleton, fits[side]._points[1])
			var flat := Vector2(toe.x - heel.x, toe.z - heel.z)
			if flat.length() > 0.05 and rad_to_deg(atan2(absf(toe.y - heel.y), flat.length())) <= FLAT_MAX_PITCH_DEG \
					and absf(rad_to_deg(atan2(flat.x, flat.y))) > CROOKED_DEG:
				crooked = true
		if crooked:
			_borrow_legs(clip, source, skeleton_path)
	for fit: Node in fits.values():
		fit.free()


## Troca as trilhas das pernas (e da bacia) de `clip` pela pose do 1º quadro de `source`, parada.
static func _borrow_legs(clip: Animation, source: Animation, skeleton_path: String) -> void:
	for bone: String in LEG_BONES:
		var path := NodePath("%s:%s" % [skeleton_path, bone])
		for type: int in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D]:
			var from := source.find_track(path, type)
			if from == -1:
				continue
			var value: Variant = source.rotation_track_interpolate(from, 0.0) if type == Animation.TYPE_ROTATION_3D \
					else source.position_track_interpolate(from, 0.0)
			var track := clip.find_track(path, type)
			if track == -1:
				track = clip.add_track(type)
				clip.track_set_path(track, path)
			while clip.track_get_key_count(track) > 0:
				clip.track_remove_key(track, 0)
			if type == Animation.TYPE_ROTATION_3D:
				clip.rotation_track_insert_key(track, 0.0, value)
			else:
				clip.position_track_insert_key(track, 0.0, value)


## Onde um ponto da pele fica no 1º quadro do clipe (a conta da pele, com a pose do clipe).
static func _skinned_in_clip(clip: Animation, anim: AnimationPlayer, skeleton: Skeleton3D, point: Array) -> Vector3:
	var out := Vector3.ZERO
	for influence: Array in point[1]:
		out += float(influence[2]) * (_clip_global(clip, anim, skeleton, int(influence[0])) * (influence[1] as Transform3D) * (point[0] as Vector3))
	return out


## Pose global (espaço do esqueleto) do osso no 1º quadro do clipe (sem trilha: a de descanso).
static func _clip_global(clip: Animation, anim: AnimationPlayer, skeleton: Skeleton3D, bone: int) -> Transform3D:
	var result := Transform3D.IDENTITY
	var path := _skeleton_path_in(anim, skeleton)
	while bone != -1:
		var bone_path := NodePath("%s:%s" % [path, skeleton.get_bone_name(bone)])
		var local := skeleton.get_bone_rest(bone)
		var rotation_track := clip.find_track(bone_path, Animation.TYPE_ROTATION_3D)
		if rotation_track != -1:
			local.basis = Basis(clip.rotation_track_interpolate(rotation_track, 0.0))
		var position_track := clip.find_track(bone_path, Animation.TYPE_POSITION_3D)
		if position_track != -1:
			local.origin = clip.position_track_interpolate(position_track, 0.0)
		result = local * result
		bone = skeleton.get_bone_parent(bone)
	return result


## Caminho do esqueleto como as trilhas das animações escrevem (relativo à raiz do player).
static func _skeleton_path_in(anim: AnimationPlayer, skeleton: Skeleton3D) -> String:
	var root := anim.get_node_or_null(anim.root_node)
	return String(root.get_path_to(skeleton)) if root else String(skeleton.name)


## Pose parada (local de cada osso): 1º quadro do Idle; osso sem trilha no Idle fica na de fábrica.
static func _base_pose(anim: AnimationPlayer, skeleton: Skeleton3D) -> Array[Transform3D]:
	var locals: Array[Transform3D] = []
	for i in skeleton.get_bone_count():
		locals.append(skeleton.get_bone_rest(i))
	if not anim.has_animation("Idle"):
		return locals
	var idle := anim.get_animation("Idle")
	for track in idle.get_track_count():
		var bone := skeleton.find_bone(String(idle.track_get_path(track)).get_slice(":", 1))
		if bone == -1:
			continue
		match idle.track_get_type(track):
			Animation.TYPE_ROTATION_3D:
				locals[bone].basis = Basis(idle.rotation_track_interpolate(track, 0.0))
			Animation.TYPE_POSITION_3D:
				locals[bone].origin = idle.position_track_interpolate(track, 0.0)
	return locals




static func _build(keys: Array, skeleton: Skeleton3D, skeleton_path: NodePath, base: Array[Transform3D]) -> Animation:
	var animation := Animation.new()
	animation.length = keys[-1][0]
	var count := skeleton.get_bone_count()
	var poses: Array = []
	for key: Array in keys:
		poses.append(_pose(skeleton, base, key[1], key[2]))
	var positioned := {skeleton.find_bone(PELVIS): true}
	for follower: String in FOLLOW:
		positioned[skeleton.find_bone(follower)] = true
	for bone in count:
		var path := NodePath("%s:%s" % [skeleton_path, skeleton.get_bone_name(bone)])
		var rotation_track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(rotation_track, path)
		var position_track := -1
		if positioned.has(bone):
			position_track = animation.add_track(Animation.TYPE_POSITION_3D)
			animation.track_set_path(position_track, path)
		for k in keys.size():
			var local: Transform3D = poses[k][bone]
			animation.rotation_track_insert_key(rotation_track, keys[k][0], Quaternion(local.basis.orthonormalized()))
			if position_track != -1:
				animation.position_track_insert_key(position_track, keys[k][0], local.origin)
	return animation


## Pose local de todos os ossos: a parada com os giros da pose, pés no fim das canelas e, se
## `planted`, quadril abaixado para os pés ficarem na altura de sempre.
static func _pose(skeleton: Skeleton3D, base: Array[Transform3D], pose: Dictionary, planted: bool) -> Array[Transform3D]:
	var locals := _posed_locals(skeleton, base, pose, planted)
	if planted:
		var lift := 0.0
		var base_globals := _globals(skeleton, base)
		var globals := _globals(skeleton, locals)
		for follower: String in FOLLOW:
			var foot := skeleton.find_bone(follower)
			if foot != -1:
				lift += globals[foot].origin.y - base_globals[foot].origin.y
		lift /= float(FOLLOW.size())
		var pelvis := skeleton.find_bone(PELVIS)
		if pelvis != -1 and absf(lift) > 0.001:
			var parent := skeleton.get_bone_parent(pelvis)
			var parent_basis := globals[parent].basis if parent != -1 else Basis.IDENTITY
			var shifted := base.duplicate()
			shifted[pelvis].origin -= parent_basis.inverse() * Vector3(0.0, lift, 0.0)
			locals = _posed_locals(skeleton, shifted, pose, planted)
	return locals


static func _posed_locals(skeleton: Skeleton3D, base: Array[Transform3D], pose: Dictionary, planted: bool) -> Array[Transform3D]:
	var count := skeleton.get_bone_count()
	var locals := base.duplicate()
	var globals: Array[Transform3D] = []
	globals.resize(count)
	for bone in _order(skeleton):
		var parent := skeleton.get_bone_parent(bone)
		var parent_global := globals[parent] if parent != -1 else Transform3D.IDENTITY
		var degrees: float = pose.get(skeleton.get_bone_name(bone), 0.0)
		if degrees != 0.0:
			# Eixo lateral do corpo visto do pai JÁ posado: o joelho dobra no plano da perna.
			var axis := (parent_global.basis.orthonormalized().inverse() * Vector3.RIGHT).normalized()
			locals[bone].basis = Basis(axis, deg_to_rad(degrees)) * locals[bone].basis
		globals[bone] = parent_global * locals[bone]
	var base_globals := _globals(skeleton, base)
	for follower: String in FOLLOW:
		var foot := skeleton.find_bone(follower)
		var leader := skeleton.find_bone(FOLLOW[follower])
		if foot == -1 or leader == -1:
			continue
		var offset := base_globals[leader].affine_inverse() * base_globals[foot]
		# No ar o pé vai junto com a canela (a bota é presa meio no pé, meio na canela: pé parado
		# com a canela girada estica a bota). No chão fica reto, e a pose deixa a canela quase em pé.
		var target := globals[leader] * offset
		if planted:
			target.basis = base_globals[foot].basis
		else:
			# Só inclina (frente/trás) junto com a canela, com a ponta reta: seguindo a canela por
			# inteiro o pé pegava a torção dela e virava de lado no ar (bem visível de costas).
			var before := base_globals[foot].origin - base_globals[leader].origin
			var after := target.origin - globals[leader].origin
			before.x = 0.0
			after.x = 0.0
			if before.length() > 0.001 and after.length() > 0.001:
				var pitch := atan2(before.cross(after).x, before.dot(after))
				target.basis = Basis(Vector3.RIGHT, pitch) * base_globals[foot].basis
		var parent := skeleton.get_bone_parent(foot)
		var parent_global := globals[parent] if parent != -1 else Transform3D.IDENTITY
		locals[foot] = parent_global.affine_inverse() * target
	return locals


static func _globals(skeleton: Skeleton3D, locals: Array[Transform3D]) -> Array[Transform3D]:
	var globals: Array[Transform3D] = []
	globals.resize(skeleton.get_bone_count())
	for bone in _order(skeleton):
		var parent := skeleton.get_bone_parent(bone)
		globals[bone] = (globals[parent] if parent != -1 else Transform3D.IDENTITY) * locals[bone]
	return globals


## Ossos com o pai sempre antes dos filhos.
static func _order(skeleton: Skeleton3D) -> Array[int]:
	var order: Array[int] = []
	var pending: Array[int] = []
	for bone in skeleton.get_bone_count():
		if skeleton.get_bone_parent(bone) == -1:
			pending.append(bone)
	while not pending.is_empty():
		var bone: int = pending.pop_front()
		order.append(bone)
		for child in skeleton.get_bone_children(bone):
			pending.append(child)
	return order
