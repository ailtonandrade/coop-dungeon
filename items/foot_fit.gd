class_name FootFit
extends Node3D
## Bota que acompanha o SAPATO DO MODELO, não um osso. No esqueleto dos personagens o pé é um
## controlador preso na raiz e a pele do sapato segue pé e canela misturados: uma peça presa
## num osso só ficava torta andando. Aqui, a cada pose nova (skeleton_updated), calcula onde
## estão o calcanhar, a ponta e os dois lados da sola do sapato (a mesma conta da pele do
## Godot: pesos dos ossos × pose) e põe a bota em cima.


var skeleton: Skeleton3D
## Por ponto: [vértice no espaço da pele, [[osso, pose de ligação, peso], ...]].
var _points: Array = []
var _mesh_to_skeleton := Transform3D.IDENTITY
## Medidas do sapato (para a bota ter o tamanho dele).
var length := 0.3
var width := 0.14


## Monta a bota do lado `side` ("L"/"R") a partir da malha dos pés do modelo (nome terminando
## em "Feet"). Null se o modelo não tem essa malha (aí a bota vai presa no osso do pé).
static func make(p_skeleton: Skeleton3D, side: String) -> FootFit:
	var feet: MeshInstance3D = null
	for mesh: MeshInstance3D in p_skeleton.find_children("*", "MeshInstance3D", true, false):
		if String(mesh.name).ends_with("Feet") and mesh.skin != null and mesh.mesh != null:
			feet = mesh
			break
	if feet == null:
		return null
	var skin := feet.skin
	var wanted_bone := "Foot." + side
	# Vértices da sola (bem baixos) que a pele liga ao pé deste lado.
	var sole: Array = []
	var min_y := INF
	for surface in feet.mesh.get_surface_count():
		var arrays := feet.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: Variant = arrays[Mesh.ARRAY_BONES]
		var weights: Variant = arrays[Mesh.ARRAY_WEIGHTS]
		if bones == null or weights == null:
			continue
		var per := (bones as Array).size() / maxi(vertices.size(), 1) if bones is Array else (bones as PackedInt32Array).size() / maxi(vertices.size(), 1)
		for i in vertices.size():
			var influences: Array = []
			var on_side := false
			for k in per:
				var weight: float = weights[i * per + k]
				if weight <= 0.0:
					continue
				var bind: int = bones[i * per + k]
				var bone := p_skeleton.find_bone(String(skin.get_bind_name(bind)))
				if bone == -1:
					continue
				influences.append([bone, skin.get_bind_pose(bind), weight])
				if String(skin.get_bind_name(bind)) == wanted_bone and weight > 0.5:
					on_side = true
			if on_side:
				sole.append([vertices[i], influences])
				min_y = minf(min_y, vertices[i].y)
	if sole.size() < 4:
		return null
	sole = sole.filter(func(entry: Array) -> bool: return (entry[0] as Vector3).y <= min_y + 0.03)
	var pick := func(score: Callable) -> Array:
		var best: Array = sole[0]
		for entry: Array in sole:
			if score.call(entry[0]) > score.call(best[0]):
				best = entry
		return best
	var heel: Array = pick.call(func(v: Vector3) -> float: return -v.z)
	var toe: Array = pick.call(func(v: Vector3) -> float: return v.z)
	# Lados da sola pelo X do modelo (o +X fica sempre à direita da bota: cima sai para cima).
	var plus_x: Array = pick.call(func(v: Vector3) -> float: return v.x)
	var minus_x: Array = pick.call(func(v: Vector3) -> float: return -v.x)
	var fit := FootFit.new()
	fit.skeleton = p_skeleton
	fit._points = [heel, toe, plus_x, minus_x]
	fit._mesh_to_skeleton = p_skeleton.global_transform.affine_inverse() * feet.global_transform \
			if p_skeleton.is_inside_tree() and feet.is_inside_tree() else feet.transform
	fit.length = (toe[0] as Vector3).distance_to(heel[0])
	fit.width = absf((plus_x[0] as Vector3).x - (minus_x[0] as Vector3).x)
	return fit


func _ready() -> void:
	if skeleton and not skeleton.skeleton_updated.is_connected(_follow):
		skeleton.skeleton_updated.connect(_follow)
	_follow()


## Onde o ponto da pele está agora (espaço do esqueleto).
func _skinned(point: Array) -> Vector3:
	var out := Vector3.ZERO
	for influence: Array in point[1]:
		out += float(influence[2]) * (skeleton.get_bone_global_pose(influence[0]) * (influence[1] as Transform3D) * (point[0] as Vector3))
	return _mesh_to_skeleton * out


func _follow() -> void:
	if skeleton == null or _points.size() < 4:
		return
	var heel := _skinned(_points[0])
	var toe := _skinned(_points[1])
	var across := _skinned(_points[2]) - _skinned(_points[3])
	var forward := toe - heel
	if forward.length() < 0.001 or across.length() < 0.001:
		return
	forward = forward.normalized()
	var right := (across - forward * across.dot(forward)).normalized()
	var up := forward.cross(right)
	transform = Transform3D(Basis(right, up, forward).orthonormalized(), (heel + toe) / 2.0)
