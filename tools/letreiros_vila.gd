extends SceneTree
## Troca as barras de neon da vila por letreiros de neon (world/neon_sign.gd) e põe letreiros
## em pé nas barracas da rua. Rodar uma vez: godot --headless --path . -s tools/letreiros_vila.gd

const CHUNK := "res://world/chunks/chunk_0_0.tscn"
const SIGN := "res://world/prefabs/letreiro_neon.tscn"
## [nome, posição, texto, cor, pisca, em pé]
const SIGNS := [
	["Letreiro_Cofre", Vector3(14, 2.75, 18.35), "COFRE", Color(0.2, 0.95, 1.0), false, false],
	["Letreiro_Bar", Vector3(50, 2.75, 17.85), "BAR", Color(1.0, 0.25, 0.8), true, false],
	["Letreiro_Lanches", Vector3(14, 2.75, 53.85), "LANCHES", Color(1.0, 0.8, 0.2), false, false],
	["Letreiro_Oficina", Vector3(50, 2.75, 54.35), "OFICINA", Color(1.0, 0.3, 0.2), false, false],
	["Letreiro_Mercado", Vector3(25, 2.3, 28.4), "MERCADO", Color(0.35, 1.0, 0.5), false, true],
	["Letreiro_Mods", Vector3(39, 2.3, 28.4), "MODS", Color(0.7, 0.4, 1.0), true, true],
]


func _initialize() -> void:
	var tools: Script = load("res://addons/map_editor/map_tools.gd")
	var scene: Node3D = tools.open_scene(CHUNK)
	var group := scene.get_node_or_null("Neon")
	if group == null:
		group = Node3D.new()
		group.name = "Neon"
		scene.add_child(group)
		group.owner = scene
	for child in group.get_children():
		group.remove_child(child)
		child.free()
	for entry: Array in SIGNS:
		var sign: Node3D = (load(SIGN) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		sign.name = entry[0]
		sign.position = entry[1]
		sign.text = entry[2]
		sign.color = entry[3]
		sign.flicker = entry[4]
		sign.stand = entry[5]
		group.add_child(sign)
		sign.owner = scene
	print("Letreiros: ", tools.save_scene(scene, CHUNK, null))
	quit()
