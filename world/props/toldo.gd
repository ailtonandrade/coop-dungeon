@tool
class_name Awning
extends Node3D
## Toldo listrado de lona, preso na parede em cima da porta (o nó fica na parede, na altura de
## cima; a lona desce para a frente, +Z). Mexa no Inspector: cores, largura, quanto avança.

@export var color_a := Color(0.72, 0.12, 0.1):
	set(value):
		color_a = value
		_rebuild()
@export var color_b := Color(0.92, 0.88, 0.78):
	set(value):
		color_b = value
		_rebuild()
@export_range(0.8, 8.0, 0.1) var width := 2.6:
	set(value):
		width = value
		_rebuild()
@export_range(0.4, 3.0, 0.05) var depth := 1.1:
	set(value):
		depth = value
		_rebuild()
## Listras de quantos centímetros.
@export_range(0.1, 1.0, 0.01) var stripe := 0.32:
	set(value):
		stripe = value
		_rebuild()

const DROP := 0.35


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_node_ready():
		return
	for child in get_children():
		if child.has_meta("awning_part"):
			remove_child(child)
			child.queue_free()
	var count := maxi(roundi(width / stripe), 1)
	var real := width / count
	var slope := atan2(DROP, depth)
	var length := sqrt(depth * depth + DROP * DROP)
	var materials: Array[StandardMaterial3D] = []
	for c: Color in [color_a, color_b]:
		var material := StandardMaterial3D.new()
		material.albedo_color = c
		material.roughness = 0.85
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		materials.append(material)
	for i in count:
		var x := -width / 2.0 + real * (i + 0.5)
		var material := materials[i % 2]
		# Lona inclinada.
		var cloth := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(real, 0.02, length)
		cloth.mesh = box
		cloth.material_override = material
		cloth.position = Vector3(x, -DROP / 2.0, depth / 2.0)
		cloth.rotation.x = slope
		_part(cloth)
		# Barrado na frente (a franja que cai).
		var valance := MeshInstance3D.new()
		var flap := BoxMesh.new()
		flap.size = Vector3(real, 0.18, 0.02)
		valance.mesh = flap
		valance.material_override = material
		valance.position = Vector3(x, -DROP - 0.09, depth)
		_part(valance)
	# Duas mãos-francesas de ferro segurando.
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.15, 0.15, 0.16)
	iron.metallic = 0.6
	for side: float in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(0.03, 0.03, length)
		arm.mesh = bar
		arm.material_override = iron
		arm.position = Vector3(side * (width / 2.0 - 0.05), -DROP / 2.0 - 0.03, depth / 2.0)
		arm.rotation.x = slope
		_part(arm)


func _part(node: Node3D) -> void:
	node.set_meta("awning_part", true)
	(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(node)
