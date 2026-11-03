@tool
class_name LoreGate
extends StaticBody3D
## Portão (grade com cadeado eletrônico) que só abre para quem já sabe os fatos de `requires`.
## Fechado: sólido, luz vermelha. Aberto: a grade some, luz verde, e as criaturas passam a
## achar caminho por ali. Roda no editor (@tool) só para mostrar o visual.

@export var requires: Array[String] = []
@export var size := Vector2(2.0, 2.4):
	set(value):
		size = value
		if is_inside_tree():
			_build()

var open := false
var _bars: Node3D
var _light: MeshInstance3D
var _collision: CollisionShape3D


func _ready() -> void:
	collision_layer = GameConfig.LAYER_WORLD
	_build()
	if Engine.is_editor_hint():
		return
	add_to_group("lore_gates")
	get_node("/root/Lore").facts_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var now: bool = get_node("/root/Lore").knows_all(requires)
	if now == open:
		return
	open = now
	_bars.visible = not open
	_collision.set_deferred("disabled", open)
	(_light.material_override as StandardMaterial3D).albedo_color = Color(0.2, 1.0, 0.4) if open else Color(1.0, 0.15, 0.1)
	(_light.material_override as StandardMaterial3D).emission = (_light.material_override as StandardMaterial3D).albedo_color
	# Pelo nó (e não pelo nome WorldStreamer): esta classe roda também no editor.
	var chunk := _chunk()
	var streamer := get_tree().get_first_node_in_group("world_streamer")
	if chunk and streamer:
		streamer.bake_navigation.call_deferred(chunk, true)


func _chunk() -> Node:
	var node: Node = self
	while node and not node.has_node("Navigation"):
		node = node.get_parent()
	return node


func _build() -> void:
	for child in get_children():
		if child.has_meta("gate_part"):
			child.free()
	_collision = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, size.y, 0.2)
	_collision.shape = shape
	_collision.position.y = size.y / 2.0
	_part(_collision)
	_bars = Node3D.new()
	_part(_bars)
	var metal := Color(0.32, 0.33, 0.35)
	var count := maxi(int(size.x / 0.25), 2)
	for i in count + 1:
		_bar(Vector3(0.05, size.y, 0.05), Vector3(-size.x / 2.0 + size.x * i / count, size.y / 2.0, 0), metal)
	_bar(Vector3(size.x, 0.08, 0.08), Vector3(0, size.y * 0.85, 0), metal)
	_bar(Vector3(size.x, 0.08, 0.08), Vector3(0, size.y * 0.15, 0), metal)
	_bar(Vector3(0.22, 0.3, 0.12), Vector3(0, size.y * 0.5, 0.06), Color(0.15, 0.15, 0.16))
	_light = MeshInstance3D.new()
	var dot := BoxMesh.new()
	dot.size = Vector3(0.08, 0.08, 0.04)
	_light.mesh = dot
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.15, 0.1)
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 3.0
	_light.material_override = material
	_light.position = Vector3(0, size.y * 0.55, 0.13)
	_part(_light)


func _bar(bar_size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = bar_size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.6
	mesh.material_override = material
	mesh.position = pos
	_bars.add_child(mesh)


func _part(node: Node) -> void:
	node.set_meta("gate_part", true)
	add_child(node)
