extends SceneTree
## Aplica a identidade (cyberpunk de ferro-velho, ver docs/IDENTIDADE.md) no mapa de teste:
## nomes e cores das regiões, chão de cada bloco, nomes de NPCs, título da entrada do metrô,
## Corrompidos no metrô e na Mata dos Cabos e placas de neon no assentamento. Roda uma vez.
##
## Rodar: godot --headless --path coop-dungeon -s tools/apply_identity.gd

const MAP_PATH := "res://world/test_world.tres"
## id -> [nome, cor do nome, cores do chão]
const REGIONS := {
	"vila": ["Ferro-Velho", Color(1.0, 0.8, 0.45), [Color(0.3, 0.27, 0.24), Color(0.38, 0.33, 0.28)]],
	"planicie": ["Pátio dos Contêineres", Color(0.7, 0.85, 1.0), [Color(0.34, 0.35, 0.36), Color(0.42, 0.43, 0.43)]],
	"bosque": ["Mata dos Cabos", Color(0.5, 1.0, 0.6), [Color(0.14, 0.24, 0.14), Color(0.2, 0.3, 0.17)]],
	"colinas": ["Lixão Alto", Color(1.0, 0.7, 0.35), [Color(0.4, 0.33, 0.2), Color(0.5, 0.42, 0.26)]],
	"caverna": ["Túnel do Metrô", Color(1.0, 0.35, 0.45), [Color(0.12, 0.12, 0.14), Color(0.18, 0.17, 0.2)]],
}
const NPC_NAMES := {"Mestre Ivo": "Zé Gato", "Sr. Gouveia": "Seu Gouveia"}
## Fachadas das casas do assentamento (bloco 0,0): [posição, cor do neon]
const SIGNS := [
	[Vector3(14, 2.7, 18.35), Color(0.2, 0.95, 1.0)], [Vector3(50, 2.7, 17.85), Color(1.0, 0.25, 0.8)],
	[Vector3(14, 2.7, 53.85), Color(1.0, 0.85, 0.2)], [Vector3(50, 2.7, 54.35), Color(0.2, 0.95, 1.0)],
]

var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	var tools: Script = load("res://addons/map_editor/map_tools.gd")
	var map: Resource = load(MAP_PATH)
	for region in map.regions:
		if REGIONS.has(region.id):
			region.display_name = REGIONS[region.id][0]
			region.color = REGIONS[region.id][1]
			region.ground_colors = PackedColorArray(REGIONS[region.id][2])
	ResourceSaver.save(map, MAP_PATH)

	var regions_of := {}
	for coords: Vector2i in map.chunks:
		regions_of[map.chunks[coords]] = map.chunk_regions[coords]
	for id: String in map.interiors:
		regions_of[map.interiors[id].path] = map.interiors[id].region
	for path: String in regions_of:
		var scene: Node3D = tools.open_scene(path)
		var region_id: String = regions_of[path]
		var colors: Array = REGIONS[region_id][2]
		for ground_name in ["Navigation/Ground/Mesh", "Navigation/Floor/Mesh"]:
			if scene.has_node(ground_name):
				scene.get_node(ground_name).material_override = tools.ground_material(colors[0], colors[1])
		for npc in scene.find_children("Npc_*", "", true, false):
			if NPC_NAMES.has(npc.npc_name):
				npc.npc_name = NPC_NAMES[npc.npc_name]
		for entrance in scene.find_children("Entrance_Caverna", "", true, false):
			entrance.title = "Túnel do Metrô · perigo 4"
		# Corrompidos (tipo 2) no metrô e na mata.
		for spawner in scene.find_children("Spawner_*", "", true, false):
			if region_id == "caverna":
				spawner.kinds = PackedInt32Array([2, 2, 1])
			elif region_id == "bosque":
				spawner.kinds = PackedInt32Array([0, 2, 1])
		if region_id == "vila" and not scene.has_node("Neon"):
			var group := Node3D.new()
			group.name = "Neon"
			scene.add_child(group)
			group.owner = scene
			for i in SIGNS.size():
				var sign: Node3D = load("res://tools/build_prefabs.gd")._neon_sign(SIGNS[i][1])
				sign.name = "Placa_%d" % i
				sign.position = SIGNS[i][0]
				group.add_child(sign)
				_own(sign, scene)
		tools.save_scene(scene, path, null)
	print("Identidade aplicada em ", regions_of.size(), " cenas")
	quit()
	return false


func _own(node: Node, scene: Node) -> void:
	node.owner = scene
	for child in node.get_children():
		_own(child, scene)
