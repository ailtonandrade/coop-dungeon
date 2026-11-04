class_name Projectile
extends Area3D
## Projétil reto. Some ao bater em parede ou ao acertar alguém da camada alvo.
## Nasce pelo NetReplicator; como anda em linha reta, os clientes só precisam do disparo
## e simulam o voo sozinhos. O dano é aplicado só no host.

const LIFETIME := 3.0

var velocity := Vector3.ZERO
var damage := 0.0
var knockback := 2.0

var _life := LIFETIME
var _from := Vector3.ZERO
var _from_player := false
var _shooter := -1
## Tiro da câmera isométrica: acerta quem estiver embaixo ou em cima da reta dele no chão
## (de COLUMN_BELOW abaixo até COLUMN_ABOVE acima), não só na altura exata do tiro.
var _column := false
var _target_group := "enemies"
var _nail := false

const COLUMN_RADIUS := 0.55
const COLUMN_BELOW := 1.6
const COLUMN_ABOVE := 4.0


## Dispara (só o host chama). `shooter` é qualquer nó dentro da fase.
static func fire(shooter: Node, from: Vector3, direction: Vector3, speed: float, p_damage: float,
		target_layer: int, color: Color, size := Vector3(0.1, 0.1, 0.7), column := false, style := "") -> void:
	NetReplicator.of(shooter).spawn("projectile", {
		"shooter": shooter.get_meta("net_id", -1),
		"from": from, "velocity": direction.normalized() * speed, "damage": p_damage,
		"target_layer": target_layer, "color": color, "size": size, "column": column, "style": style,
	})


static func build(data: Dictionary) -> Projectile:
	var projectile := Projectile.new()
	projectile._from = data.from
	projectile.velocity = data.velocity
	projectile.damage = data.damage
	projectile.collision_layer = 0
	projectile.collision_mask = GameConfig.LAYER_SOLID | int(data.target_layer)
	projectile._from_player = int(data.target_layer) & GameConfig.LAYER_ENEMIES != 0
	projectile._shooter = int(data.get("shooter", -1))
	projectile._column = bool(data.get("column", false))
	projectile._target_group = "enemies" if projectile._from_player else "players"
	var color: Color = data.color

	var sphere := SphereShape3D.new()
	sphere.radius = 0.2
	var collision := CollisionShape3D.new()
	collision.shape = sphere
	projectile.add_child(collision)

	projectile._nail = data.get("style", "") == "nail"
	if projectile._nail:
		projectile._build_nail(color)
		return projectile
	var box := BoxMesh.new()
	box.size = data.size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.material_override = material
	projectile.add_child(mesh)
	return projectile


## Prego: haste fina de aço com cabeça e ponta quente, e um rastro de ar bem fraco atrás
## (sem brilho de laser).
func _build_nail(color: Color) -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = color
	steel.metallic = 0.8
	steel.roughness = 0.35
	steel.emission_enabled = true
	steel.emission = color
	steel.emission_energy_multiplier = 0.35
	# A frente do projétil é -Z (Basis.looking_at).
	_mesh_part(Vector3(0.022, 0.022, 0.2), Vector3(0, 0, 0), steel)
	_mesh_part(Vector3(0.05, 0.05, 0.012), Vector3(0, 0, 0.1), steel)
	var hot := StandardMaterial3D.new()
	hot.albedo_color = Color(1.0, 0.75, 0.4)
	hot.emission_enabled = true
	hot.emission = Color(1.0, 0.6, 0.25)
	hot.emission_energy_multiplier = 1.5
	_mesh_part(Vector3(0.018, 0.018, 0.04), Vector3(0, 0, -0.11), hot)
	var trail := StandardMaterial3D.new()
	trail.albedo_color = Color(0.85, 0.85, 0.82, 0.18)
	trail.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh_part(Vector3(0.012, 0.012, 0.7), Vector3(0, 0, 0.45), trail)


func _mesh_part(size: Vector3, pos: Vector3, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = pos
	add_child(mesh)


## Clarão do bico (rápido, pequeno) e uma baforada de ar/poeira que sobe e some. Só visual,
## em cada máquina.
func _muzzle_flash() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var dir := velocity.normalized()
	var spot := _from - dir * 0.05
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.5)
	light.light_energy = 1.6
	light.omni_range = 2.5
	light.shadow_enabled = false
	parent.add_child(light)
	light.global_position = spot
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.1
	flash.mesh = sphere
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.albedo_color = Color(1.0, 0.85, 0.55)
	flash.material_override = hot
	parent.add_child(flash)
	flash.global_position = spot + dir * 0.04
	var puff := MeshInstance3D.new()
	var cloud := SphereMesh.new()
	cloud.radius = 0.09
	cloud.height = 0.18
	puff.mesh = cloud
	var smoke := StandardMaterial3D.new()
	smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke.albedo_color = Color(0.75, 0.73, 0.68, 0.35)
	puff.material_override = smoke
	parent.add_child(puff)
	puff.global_position = spot
	var tween := parent.create_tween().set_parallel(true)
	tween.tween_property(light, "light_energy", 0.0, 0.07)
	tween.tween_property(flash, "scale", Vector3.ONE * 0.2, 0.05)
	tween.tween_property(puff, "scale", Vector3.ONE * 2.6, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(puff, "global_position", spot + dir * 0.25 + Vector3.UP * 0.18, 0.45)
	tween.tween_property(smoke, "albedo_color:a", 0.0, 0.45)
	tween.chain().tween_callback(func() -> void:
		light.queue_free()
		flash.queue_free()
		puff.queue_free())


func _ready() -> void:
	global_transform = Transform3D(Basis.looking_at(velocity.normalized()), _from)
	reset_physics_interpolation()
	# Nasce em todas as máquinas: o disparo soa em todas.
	Sound.play("shot" if _from_player else "enemy_shot", _from)
	if _nail:
		_muzzle_flash()
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var before := global_position
	global_position += velocity * delta
	if _column and multiplayer.is_server():
		var hit := _column_hit(before, global_position)
		if hit:
			_on_body_entered(hit)
			return
	_life -= delta
	if _life <= 0.0 and multiplayer.is_server():
		queue_free()


## Alvo cuja posição no chão passa perto do trecho percorrido neste quadro, em qualquer altura
## dentro da coluna.
func _column_hit(from: Vector3, to: Vector3) -> Node3D:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	for node in get_tree().get_nodes_in_group(_target_group):
		var target := node as Node3D
		if target == null or not target.has_method("take_hit") or not target.call("is_targetable"):
			continue
		var height := target.global_position.y - to.y
		if height < -COLUMN_BELOW - 1.0 or height > COLUMN_ABOVE:
			continue
		var point := Vector2(target.global_position.x, target.global_position.z)
		var closest := Geometry2D.get_closest_point_to_segment(point, a, b)
		if closest.distance_to(point) <= COLUMN_RADIUS:
			return target
	return null


func _on_body_entered(body: Node3D) -> void:
	# Cliente: depois do primeiro acerto o prego some e segue invisível até o host apagar.
	if is_queued_for_deletion() or not visible:
		return
	# Bateu em parede/chão (não em alguém): "tok" abafado, em cada máquina. Quem leva o tiro toca
	# o próprio som de acerto (avisado pelo host).
	if not body.has_method("take_hit"):
		Sound.play("projectile_hit", global_position)
	if not multiplayer.is_server():
		visible = false
		return
	if body.has_method("take_hit"):
		body.take_hit(damage, velocity.normalized() * knockback, true)
		# Tiro de herói que acertou: treina a habilidade à distância dele.
		var replicator := NetReplicator.of(self)
		var shooter: Node = replicator.get_entity(_shooter) if replicator and _shooter != -1 else null
		if shooter and shooter.has_method("on_ranged_hit"):
			shooter.on_ranged_hit()
	queue_free()
