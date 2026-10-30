extends SceneTree
## Migração única do mapa de teste para o fluxo do editor de mapa (M7.5): tira as bordas
## fixas dos blocos, acrescenta a grade de pintura, dá as cores de chão às regiões e liga a
## entrada da Caverna Velha à saída dela. Pode rodar de novo sem estragar nada.
##
## Rodar: godot --headless --path coop-dungeon -s tools/migrate_map.gd

const MAP_PATH := "res://world/test_world.tres"
const GROUND := {
	"vila": [Color(0.4, 0.38, 0.34), Color(0.48, 0.45, 0.4)],
	"planicie": [Color(0.27, 0.4, 0.2), Color(0.34, 0.48, 0.25)],
	"bosque": [Color(0.15, 0.27, 0.14), Color(0.21, 0.34, 0.18)],
	"colinas": [Color(0.44, 0.38, 0.25), Color(0.52, 0.45, 0.3)],
	"caverna": [Color(0.13, 0.12, 0.13), Color(0.2, 0.18, 0.18)],
}

var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	var tools: Script = load("res://addons/map_editor/map_tools.gd")
	var map: Resource = load(MAP_PATH)
	for region in map.regions:
		if GROUND.has(region.id):
			region.ground_colors = PackedColorArray(GROUND[region.id])
	ResourceSaver.save(map, MAP_PATH)
	var changed := 0
	for path: String in tools.scenes_of(map):
		if tools.ensure_paintable(path, root):
			changed += 1
	print("Blocos preparados para pintura: ", changed)
	# Navegação lendo também as malhas (paredes pintadas na grade entram).
	for path: String in tools.scenes_of(map):
		tools.bake_scene(path, root)
	print("Navegação recalculada em todos os blocos")
	# Nomes automáticos (@CollisionShape3D@123) viram nomes legíveis para editar à mão.
	var renamed := 0
	for path: String in tools.scenes_of(map):
		var scene: Node3D = tools.open_scene(path)
		var count := _clean_names(scene, scene)
		renamed += count
		if count > 0:
			tools.save_scene(scene, path, null)
		else:
			scene.free()
	print("Nós renomeados: ", renamed)
	_link("res://world/chunks/chunk_2_1.tscn", "Entrance_Caverna", false)
	_link("res://world/interiors/caverna_velha.tscn", "Exit", true)
	for line in tools.sync_entrances(map):
		print("  ", line)
	quit()
	return false


## Renomeia nós com nome automático (começa com "@") para "Collision", "Mesh" etc.
func _clean_names(node: Node, scene_root: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child.owner == scene_root and String(child.name).begins_with("@"):
			var base: String = {"CollisionShape3D": "Collision", "MeshInstance3D": "Mesh"}.get(child.get_class(), child.get_class())
			var new_name: String = base
			var n := 2
			while node.has_node(NodePath(new_name)) and node.get_node(NodePath(new_name)) != child:
				new_name = "%s%d" % [base, n]
				n += 1
			child.name = new_name
			count += 1
		count += _clean_names(child, scene_root)
	return count


## Põe o id de ligação na entrada; `face_inside` gira a saída para o grupo chegar para dentro.
func _link(path: String, node_name: String, face_inside: bool) -> void:
	var tools: Script = load("res://addons/map_editor/map_tools.gd")
	var scene: Node3D = tools.open_scene(path)
	var entrance: Node3D = scene.find_child(node_name, true, false)
	entrance.set("link_id", "caverna_velha")
	if face_inside:
		entrance.rotation_degrees.y = 180.0
	tools.save_scene(scene, path, null)
