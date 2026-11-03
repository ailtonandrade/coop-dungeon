extends SceneTree
## Troca as barras de neon da vila por letreiros de neon (world/neon_sign.gd) e põe letreiros
## em pé nas barracas da rua. Rodar uma vez: godot --headless --path . -s tools/letreiros_vila.gd

const CHUNK := "res://world/chunks/chunk_0_0.tscn"
const SIGN := "res://world/prefabs/letreiro_neon.tscn"
## [nome, texto, cor, pisca, em pé, ícone]. Posição e giro: os que já estão no bloco (se você
## mudou de lugar, fica onde você deixou); os novos entram em NEW_AT.
const SIGNS := [
	["Letreiro_Cofre", "COFRE", Color(0.2, 0.95, 1.0), false, false, "cofre"],
	["Letreiro_Bar", "BAR", Color(1.0, 0.25, 0.8), true, false, "copo"],
	["Letreiro_Lanches", "LANCHES", Color(1.0, 0.8, 0.2), false, false, "lanche"],
	["Letreiro_Oficina", "OFICINA", Color(1.0, 0.3, 0.2), false, false, "chave"],
	["Letreiro_Mercado", "MERCADO", Color(0.35, 1.0, 0.5), false, true, "carrinho"],
	["Letreiro_Mods", "MODS", Color(0.7, 0.4, 1.0), true, true, "chip"],
]
const NEW_AT := {
	"Letreiro_Cofre": Vector3(14, 2.75, 18.35), "Letreiro_Bar": Vector3(50, 2.75, 17.85),
	"Letreiro_Lanches": Vector3(14, 2.75, 53.85), "Letreiro_Oficina": Vector3(50, 2.75, 54.35),
	"Letreiro_Mercado": Vector3(25, 2.3, 28.4), "Letreiro_Mods": Vector3(39, 2.3, 28.4),
}


func _initialize() -> void:
	var tools: Script = load("res://addons/map_editor/map_tools.gd")
	var scene: Node3D = tools.open_scene(CHUNK)
	var group := scene.get_node_or_null("Neon")
	if group == null:
		group = Node3D.new()
		group.name = "Neon"
		scene.add_child(group)
		group.owner = scene
	for entry: Array in SIGNS:
		var sign: Node3D = group.get_node_or_null(NodePath(entry[0]))
		if sign == null:
			sign = (load(SIGN) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
			sign.name = entry[0]
			sign.position = NEW_AT[entry[0]]
			group.add_child(sign)
			sign.owner = scene
		sign.text = entry[1]
		sign.color = entry[2]
		sign.flicker = entry[3]
		sign.stand = entry[4]
		sign.icon = entry[5]
	print("Letreiros: ", tools.save_scene(scene, CHUNK, null))
	quit()
