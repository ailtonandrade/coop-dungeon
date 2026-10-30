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


## Dispara (só o host chama). `shooter` é qualquer nó dentro da fase.
static func fire(shooter: Node, from: Vector3, direction: Vector3, speed: float, p_damage: float,
		target_layer: int, color: Color, size := Vector3(0.1, 0.1, 0.7)) -> void:
	NetReplicator.of(shooter).spawn("projectile", {
		"shooter": shooter.get_meta("net_id", -1),
		"from": from, "velocity": direction.normalized() * speed, "damage": p_damage,
		"target_layer": target_layer, "color": color, "size": size,
	})


static func build(data: Dictionary) -> Projectile:
	var projectile := Projectile.new()
	projectile._from = data.from
	projectile.velocity = data.velocity
	projectile.damage = data.damage
	projectile.collision_layer = 0
	projectile.collision_mask = GameConfig.LAYER_WORLD | int(data.target_layer)
	projectile._from_player = int(data.target_layer) & GameConfig.LAYER_ENEMIES != 0
	projectile._shooter = int(data.get("shooter", -1))
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
	global_position += velocity * delta
	_life -= delta
	if _life <= 0.0 and multiplayer.is_server():
		queue_free()


func _on_body_entered(body: Node3D) -> void:
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
