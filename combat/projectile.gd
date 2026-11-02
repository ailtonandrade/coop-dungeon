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

const COLUMN_RADIUS := 0.55
const COLUMN_BELOW := 1.6
const COLUMN_ABOVE := 4.0


## Dispara (só o host chama). `shooter` é qualquer nó dentro da fase.
static func fire(shooter: Node, from: Vector3, direction: Vector3, speed: float, p_damage: float,
		target_layer: int, color: Color, size := Vector3(0.1, 0.1, 0.7), column := false) -> void:
	NetReplicator.of(shooter).spawn("projectile", {
		"shooter": shooter.get_meta("net_id", -1),
		"from": from, "velocity": direction.normalized() * speed, "damage": p_damage,
		"target_layer": target_layer, "color": color, "size": size, "column": column,
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


func _ready() -> void:
	global_transform = Transform3D(Basis.looking_at(velocity.normalized()), _from)
	reset_physics_interpolation()
	# Nasce em todas as máquinas: o disparo soa em todas.
	Sound.play("shot" if _from_player else "enemy_shot", _from)
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
	if is_queued_for_deletion():
		return
	if not multiplayer.is_server():
		visible = false
		return
	if body.has_method("take_hit"):
		body.take_hit(damage, velocity.normalized() * knockback)
		# Tiro de herói que acertou: treina a habilidade à distância dele.
		var replicator := NetReplicator.of(self)
		var shooter: Node = replicator.get_entity(_shooter) if replicator and _shooter != -1 else null
		if shooter and shooter.has_method("on_ranged_hit"):
			shooter.on_ranged_hit()
	queue_free()
