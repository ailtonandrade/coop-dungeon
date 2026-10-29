class_name Combat
extends RefCounted
## Consultas e efeitos de combate compartilhados por heróis e inimigos.
## Quem pode apanhar implementa `take_hit(amount, knockback)` e `is_targetable()`.


## Corpos da camada `mask` dentro de um leque de `arc_deg` graus à frente de `attacker`.
static func query_arc(attacker: Node3D, forward: Vector3, radius: float, arc_deg: float, mask: int) -> Array[Node3D]:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, attacker.global_position + Vector3.UP * 0.9)
	params.collision_mask = mask
	var min_dot := cos(deg_to_rad(arc_deg / 2.0))
	var hits: Array[Node3D] = []
	for result in attacker.get_world_3d().direct_space_state.intersect_shape(params, 32):
		var body := result.collider as Node3D
		if body == null or body == attacker or hits.has(body) or not body.has_method("take_hit"):
			continue
		var to := flat(body.global_position - attacker.global_position)
		if to.length() < 0.6 or to.normalized().dot(forward) >= min_dot:
			hits.append(body)
	return hits


## O alvo válido mais próximo dentro de um cone (mira assistida). Null se não houver.
static func nearest_in_cone(origin: Vector3, forward: Vector3, candidates: Array[Node], max_dist: float, cone_deg: float) -> Node3D:
	var min_dot := cos(deg_to_rad(cone_deg / 2.0))
	var best: Node3D = null
	var best_dist := max_dist
	for node in candidates:
		var target := node as Node3D
		if target == null or not target.call("is_targetable"):
			continue
		var to := flat(target.global_position - origin)
		var dist := to.length()
		if dist <= best_dist and (dist < 0.01 or to.normalized().dot(forward) >= min_dot):
			best = target
			best_dist = dist
	return best


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Pinta todas as malhas do modelo por cima (tinta de inimigo, piscada de dano).
static func set_overlay(model: Node, material: Material) -> void:
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = material


## Pisca o modelo numa cor e volta para `base` (pode ser null).
static func flash(model: Node, color: Color, base: Material, time := 0.1) -> void:
	set_overlay(model, overlay_material(color))
	model.get_tree().create_timer(time).timeout.connect(func() -> void:
		if is_instance_valid(model):
			set_overlay(model, base))


static func overlay_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	return material


static func shake_camera(node: Node, strength: float) -> void:
	node.get_tree().call_group("shared_camera", "shake", strength)
