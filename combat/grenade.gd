class_name Grenade
extends Node3D
## Granada caseira (lata com pólvora e pavio): voa em arco, quica no chão e nas paredes e
## explode quando o pavio acaba, ferindo e empurrando as criaturas em volta (menos quanto mais
## longe; parede no meio protege). Não fere os heróis (co-op).
##
## Nasce pelo NetReplicator em todas as máquinas e cada uma simula o voo sozinha; quem decide a
## explosão (dano) é o host, que avisa todo mundo para mostrar o estouro no mesmo lugar.

const GRAVITY := 20.0
const FUSE := 1.7
const RADIUS := 4.5
const BOUNCE := 0.42
const KNOCKBACK := 11.0

var velocity := Vector3.ZERO
var damage := 60.0

var _from := Vector3.ZERO
var _fuse := FUSE
var _resting := false
var _exploded := false
var _spark: MeshInstance3D
var _spark_light: OmniLight3D
var _body: Node3D
var _time := 0.0


## Joga (só o host chama).
static func throw(thrower: Node, from: Vector3, p_velocity: Vector3, p_damage: float) -> void:
	NetReplicator.of(thrower).spawn("grenade", {
		"from": from, "velocity": p_velocity, "damage": p_damage,
	})


static func build(data: Dictionary) -> Grenade:
	var grenade := Grenade.new()
	grenade._from = data.from
	grenade.velocity = data.velocity
	grenade.damage = float(data.get("damage", 60.0))
	return grenade


func _ready() -> void:
	global_position = _from
	_body = ItemVisuals.build({"id": "granada"})
	_body.scale = Vector3.ONE * 1.6
	add_child(_body)
	# Pavio aceso: faísca piscando.
	_spark = MeshInstance3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.025
	dot.height = 0.05
	_spark.mesh = dot
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.albedo_color = Color(1.0, 0.75, 0.3)
	_spark.material_override = hot
	_spark.position = Vector3(0.02, 0.27, 0)
	add_child(_spark)
	_spark_light = OmniLight3D.new()
	_spark_light.light_color = Color(1.0, 0.6, 0.25)
	_spark_light.omni_range = 1.6
	_spark_light.light_energy = 0.8
	_spark_light.position = _spark.position
	add_child(_spark_light)


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_time += delta
	_fuse -= delta
	# Faísca pisca mais rápido perto do fim.
	var blink := 0.5 + 0.5 * sin(_time * lerpf(18.0, 50.0, 1.0 - _fuse / FUSE))
	_spark.scale = Vector3.ONE * (0.7 + blink * 0.8)
	_spark_light.light_energy = 0.4 + blink * 0.9
	if not _resting:
		_fly(delta)
	if _fuse <= 0.0 and multiplayer.is_server():
		_explode()


func _fly(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	var step := velocity * delta
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + step, GameConfig.LAYER_SOLID)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		global_position += step
		_body.rotation += Vector3(7.0, 3.0, 0.0) * delta
		return
	var normal: Vector3 = hit.normal
	var speed := velocity.length()
	global_position = (hit.position as Vector3) + normal * 0.05
	velocity = velocity.bounce(normal) * BOUNCE
	if speed > 2.5:
		Sound.play("grenade_bounce", global_position)
	# Parou no chão: fica quietinha esperando o pavio.
	if normal.y > 0.7 and velocity.length() < 1.4:
		velocity = Vector3.ZERO
		_resting = true
		_body.rotation = Vector3(0, _body.rotation.y, 0)


## Host: dano e empurrão em quem está perto (sem parede no meio) e avisa todo mundo.
func _explode() -> void:
	_exploded = true
	var center := global_position + Vector3.UP * 0.3
	var space := get_world_3d().direct_space_state
	for node in get_tree().get_nodes_in_group("enemies"):
		var target := node as Node3D
		if target == null or not target.has_method("take_hit"):
			continue
		var aim := target.global_position + Vector3.UP * 1.0
		var distance := center.distance_to(aim)
		if distance > RADIUS:
			continue
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(center, aim, GameConfig.LAYER_WORLD))
		if not wall.is_empty():
			continue
		var falloff := 1.0 - 0.65 * distance / RADIUS
		var push := Combat.flat(aim - center).normalized() * KNOCKBACK * falloff
		target.take_hit(damage * falloff, push)
	# Peças soltas (cone, barril) voam.
	for node in get_tree().get_nodes_in_group("physics_props"):
		var body := node as RigidBody3D
		if body and body.global_position.distance_to(center) < RADIUS:
			var away := body.global_position - center
			body.apply_central_impulse((away.normalized() + Vector3.UP * 0.6) * 9.0 * (1.0 - away.length() / RADIUS) * body.mass)
	var replicator := NetReplicator.of(self)
	if replicator:
		replicator.broadcast_fx(self, "fx_explode", [global_position])
	else:
		fx_explode(global_position)
	queue_free.call_deferred()


## Estouro (todas as máquinas): som, clarão, bola de fogo, fumaça subindo, faíscas, marca no
## chão e tremida de câmera de quem está perto.
func fx_explode(at: Vector3) -> void:
	_exploded = true
	visible = false
	var parent := get_parent()
	if parent == null:
		return
	Sound.play("explosion", at)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.4)
	light.light_energy = 9.0
	light.omni_range = 10.0
	parent.add_child(light)
	light.global_position = at + Vector3.UP * 0.8
	var fire := _sphere(parent, at + Vector3.UP * 0.5, 0.45, Color(1.0, 0.72, 0.35), false)
	var core := _sphere(parent, at + Vector3.UP * 0.5, 0.3, Color(1.0, 0.95, 0.8), false)
	var tween := parent.create_tween().set_parallel(true)
	tween.tween_property(light, "light_energy", 0.0, 0.45).set_ease(Tween.EASE_OUT)
	tween.tween_property(fire, "scale", Vector3.ONE * 6.0, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(fire.material_override, "albedo_color", Color(0.6, 0.25, 0.1, 0.0), 0.32)
	tween.tween_property(core, "scale", Vector3.ONE * 4.0, 0.12)
	tween.tween_property(core.material_override, "albedo_color:a", 0.0, 0.14)
	tween.chain().tween_callback(func() -> void:
		light.queue_free()
		fire.queue_free()
		core.queue_free())
	# Fumaça: bolas cinzentas que crescem, sobem e somem devagar.
	for i in 7:
		var offset := Vector3(randf_range(-0.9, 0.9), randf_range(0.2, 0.9), randf_range(-0.9, 0.9))
		var puff := _sphere(parent, at + offset, randf_range(0.35, 0.6), Color(0.32, 0.3, 0.28, 0.55), true)
		var drift := parent.create_tween().set_parallel(true)
		var life := randf_range(1.4, 2.2)
		drift.tween_property(puff, "scale", Vector3.ONE * randf_range(3.0, 4.5), life).set_ease(Tween.EASE_OUT)
		drift.tween_property(puff, "global_position", puff.global_position + Vector3(offset.x, randf_range(1.5, 2.6), offset.z), life)
		drift.tween_property(puff.material_override, "albedo_color:a", 0.0, life).set_ease(Tween.EASE_IN)
		drift.chain().tween_callback(puff.queue_free)
	HitFx.sparks(self, at + Vector3.UP * 0.4, Color(1.0, 0.65, 0.3), 36, 11.0)
	_scorch(parent, at)
	# Treme a câmera conforme a distância do herói desta tela mais perto.
	var closest := INF
	for player: Node3D in get_tree().get_nodes_in_group("players"):
		if player.has_method("is_local") and player.is_local():
			closest = minf(closest, player.global_position.distance_to(at))
	if closest < 18.0:
		Combat.shake_camera(self, lerpf(0.9, 0.15, closest / 18.0))


func _sphere(parent: Node, at: Vector3, radius: float, color: Color, smoke: bool) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	mesh.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if not smoke else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	mesh.global_position = at
	return mesh


## Marca preta no chão que some em alguns segundos.
func _scorch(parent: Node, at: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 1.5, GameConfig.LAYER_SOLID))
	if hit.is_empty():
		return
	var mark := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.4
	disc.bottom_radius = 1.4
	disc.height = 0.01
	disc.radial_segments = 16
	mark.mesh = disc
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.05, 0.04, 0.035, 0.75)
	material.roughness = 1.0
	mark.material_override = material
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mark)
	mark.global_position = (hit.position as Vector3) + Vector3.UP * 0.012
	var fade := mark.create_tween()
	fade.tween_interval(6.0)
	fade.tween_property(material, "albedo_color:a", 0.0, 3.0)
	fade.tween_callback(mark.queue_free)
