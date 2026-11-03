extends SceneTree
## Espalha poças d'água pela vila (perto dos letreiros e na rua). Cada uma é uma peça normal do
## mapa: dá para arrastar no editor ou mover/apagar pelo /construir.
## godot --headless --path . -s tools/pocas_vila.gd

const CHUNK := "res://world/chunks/chunk_0_0.tscn"
const PUDDLE := "res://world/prefabs/poca_dagua.tscn"
## [posição, giro em graus, tamanho]
const PUDDLES := [
	[Vector3(14.5, 0, 20.8), 15.0, 1.1], [Vector3(49.2, 0, 20.4), -30.0, 1.3], [Vector3(13.4, 0, 56.6), 70.0, 1.0],
	[Vector3(51.0, 0, 57.0), 5.0, 1.2], [Vector3(26.5, 0, 32.6), 40.0, 1.4], [Vector3(37.6, 0, 32.2), -60.0, 1.1],
	[Vector3(31.5, 0, 38.0), 100.0, 1.6], [Vector3(21.0, 0, 25.5), -10.0, 0.9], [Vector3(44.0, 0, 26.0), 55.0, 1.0],
	[Vector3(32.0, 0, 24.0), 20.0, 1.2],
]


func _initialize() -> void:
	var tools: Script = load("res://addons/map_editor/map_tools.gd")
	var scene: Node3D = tools.open_scene(CHUNK)
	var group := scene.get_node_or_null("Pocas")
	if group == null:
		group = Node3D.new()
		group.name = "Pocas"
		scene.add_child(group)
		group.owner = scene
	for child in group.get_children():
		group.remove_child(child)
		child.free()
	for i in PUDDLES.size():
		var entry: Array = PUDDLES[i]
		var puddle: Node3D = (load(PUDDLE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		puddle.name = "Poca_%d" % i
		puddle.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(entry[1])).scaled(Vector3.ONE * entry[2]), entry[0])
		group.add_child(puddle)
		puddle.owner = scene
	print("Poças: ", tools.save_scene(scene, CHUNK, null))
	quit()
