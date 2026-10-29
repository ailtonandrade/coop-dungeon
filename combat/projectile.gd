class_name Projectile
extends Area3D
## Projétil reto. Some ao bater em parede ou ao acertar alguém da camada alvo.

const LIFETIME := 3.0

var velocity := Vector3.ZERO
var damage := 0.0
var knockback := 2.0

var _life := LIFETIME


static func spawn(parent: Node, from: Vector3, direction: Vector3, speed: float, p_damage: float,
		target_layer: int, color: Color, size := Vector3(0.1, 0.1, 0.7)) -> Projectile:
	var projectile := Projectile.new()
	projectile.velocity = direction.normalized() * speed
	projectile.damage = p_damage
	projectile.collision_layer = 0
	projectile.collision_mask = GameConfig.LAYER_WORLD | target_layer

	var sphere := SphereShape3D.new()
	sphere.radius = 0.2
	var collision := CollisionShape3D.new()
	collision.shape = sphere
	projectile.add_child(collision)

	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.material_override = material
	projectile.add_child(mesh)

	parent.add_child(projectile)
	projectile.global_transform = Transform3D(Basis.looking_at(direction), from)
	projectile.reset_physics_interpolation()
	return projectile


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_hit"):
		body.take_hit(damage, velocity.normalized() * knockback)
	queue_free()
