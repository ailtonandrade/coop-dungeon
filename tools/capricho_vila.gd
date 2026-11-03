extends SceneTree
## Capricho na vila: mesas de boteco na frente do bar, toldos listrados, caixotes, sofá velho,
## ar-condicionado nas paredes, pneus e canos na oficina, bancas de camelô na rua e vasos no
## cofre. Tudo peça normal do mapa (grupo "Capricho" no bloco da vila): arraste no editor ou
## mova/apague pelo /construir. Rodar de novo só acrescenta o que faltar (o que você mudou de
## lugar fica onde está).
## godot --headless --path . -s tools/capricho_vila.gd

const CHUNK := "res://world/chunks/chunk_0_0.tscn"
const PACK_MODELS := {
	"couch": ["res://assets/props/packs/Zombie/Environment/glTF/Couch.gltf", "Zombie"],
	"wheels_stack": ["res://assets/props/packs/Zombie/Environment/glTF/Wheels_Stack.gltf", "Zombie"],
	"pipes": ["res://assets/props/packs/Zombie/Environment/glTF/Pipes.gltf", "Zombie"],
	"prop_acunit": ["res://assets/props/packs/DownTown/Prop_ACUnit.gltf", "DownTown"],
	"prop_planter_single": ["res://assets/props/packs/DownTown/Prop_Planter_Single.gltf", "DownTown"],
}
## [nome, peça (arquivo em world/prefabs ou id de modelo do pack), posição, giro (graus), campos]
const PIECES := [
	["Toldo_Bar", "toldo", Vector3(50, 2.3, 17.67), 0.0, {"color_a": Color(0.32, 0.14, 0.13), "color_b": Color(0.55, 0.52, 0.45)}],
	["Toldo_Lanches", "toldo", Vector3(14, 2.3, 53.67), 0.0, {"color_a": Color(0.48, 0.4, 0.22), "color_b": Color(0.36, 0.2, 0.16)}],
	["Mesa_Bar_1", "mesa_de_bar", Vector3(47.0, 0, 21.8), 17.0, {}],
	["Mesa_Bar_2", "mesa_de_bar", Vector3(53.2, 0, 22.4), -23.0, {}],
	["Caixotes_Bar", "caixotes", Vector3(54.0, 0, 18.05), 0.0, {}],
	["Sofa_Bar", "couch", Vector3(45.3, 0, 19.0), 160.0, {"scale": Vector3.ONE * 0.8}],
	["Mesa_Lanches", "mesa_de_bar", Vector3(11.0, 0, 56.2), 35.0, {}],
	["Caixotes_Lanches", "caixotes", Vector3(17.6, 0, 54.05), 0.0, {}],
	["Pneus_Oficina", "wheels_stack", Vector3(53.9, 0, 55.4), 20.0, {}],
	["Canos_Oficina", "pipes", Vector3(46.0, 0, 55.8), 80.0, {}],
	["Caixotes_Oficina", "caixotes", Vector3(54.3, 0, 54.55), 90.0, {}],
	["Ar_Cofre", "prop_acunit", Vector3(17.6, 2.2, 18.2), 0.0, {}],
	["Ar_Lanches", "prop_acunit", Vector3(10.3, 2.2, 53.7), 0.0, {}],
	["Ar_Oficina", "prop_acunit", Vector3(46.4, 2.2, 54.2), 0.0, {}],
	["Vaso_Cofre_1", "prop_planter_single", Vector3(11.8, 0, 18.6), 0.0, {"scale": Vector3.ONE * 0.42}],
	["Vaso_Cofre_2", "prop_planter_single", Vector3(16.2, 0, 18.6), 0.0, {"scale": Vector3.ONE * 0.42}],
	["Banca_Mercado", "banca", Vector3(25, 0, 30.95), 0.0, {}],
	["Banca_Mods", "banca", Vector3(39, 0, 30.95), 0.0, {}],
]


## Nomes para tirar e pôr de novo (correção de tamanho); rodar com: -- refazer Vaso_Cofre_1 ...
func _redo() -> PackedStringArray:
	var args := OS.get_cmdline_user_args()
	return args.slice(1) if not args.is_empty() and args[0] == "refazer" else PackedStringArray()


func _initialize() -> void:
	var tools: Script = load("res://addons/map_editor/map_tools.gd")
	var builder: Script = load("res://props/prop_builder.gd")
	var scene: Node3D = tools.open_scene(CHUNK)
	var group := scene.get_node_or_null("Capricho")
	if group == null:
		group = Node3D.new()
		group.name = "Capricho"
		scene.add_child(group)
		group.owner = scene
	var added := 0
	for redo: String in _redo():
		var old := group.get_node_or_null(NodePath(redo))
		if old:
			group.remove_child(old)
			old.free()
	for entry: Array in PIECES:
		if group.has_node(NodePath(entry[0])):
			continue
		var path := "res://world/prefabs/%s.tscn" % entry[1]
		if not ResourceLoader.exists(path):
			path = builder.prefab_path_of(entry[1])
			if path.is_empty() and PACK_MODELS.has(entry[1]):
				path = builder.make_from_model(PACK_MODELS[entry[1]][0], PACK_MODELS[entry[1]][1])
		if path.is_empty():
			push_warning("Peça não encontrada: %s" % entry[1])
			continue
		var piece: Node3D = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		piece.name = entry[0]
		piece.position = entry[2]
		piece.rotation.y = deg_to_rad(entry[3])
		for key: String in entry[4]:
			piece.set(key, entry[4][key])
		group.add_child(piece)
		piece.owner = scene
		added += 1
	print("Capricho: +%d peças, " % added, tools.save_scene(scene, CHUNK, null))
	quit()
