extends SceneTree
## Teste das ferramentas do editor de mapa (MapTools), numa cópia do mapa em tests/tmp:
## criar bloco, pintar paredes (navegação desvia), criar masmorra, ligar e sincronizar
## entradas, validar. No fim valida o mapa de verdade (sem mexer nele).
## Rodar: godot --headless --path coop-dungeon -s tests/map_tools_test.gd

const TMP := "res://tests/tmp"

var _failed := false
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	_run()
	print("EDITOR DE MAPA: ", "FALHOU" if _failed else "OK")
	quit(1 if _failed else 0)
	return false


func _run() -> void:
	var tools: Script = load("res://addons/map_editor/map_tools.gd")
	DirAccess.make_dir_recursive_absolute(TMP)
	_clean()
	tools.chunk_dir = TMP
	tools.interior_dir = TMP
	var map: Resource = load("res://world/test_world.tres").duplicate(true)
	var map_path := TMP + "/map.tres"
	ResourceSaver.save(map, map_path)

	# Bloco novo ao lado do mapa.
	var chunk_path: String = tools.create_chunk(map, map_path, Vector2i(3, 0), "planicie", root)
	_check(FileAccess.file_exists(chunk_path) and map.chunks.has(Vector2i(3, 0)), "bloco novo criado e registrado")
	var scene: Node3D = tools.open_scene(chunk_path)
	var empty_polygons: int = scene.get_node("Navigation").navigation_mesh.get_polygon_count()
	_check(empty_polygons > 0, "navegação do bloco novo calculada (%d)" % empty_polygons)
	_check(scene.get_node("Navigation/Tiles") is GridMap, "bloco novo tem grade de pintura")

	# Pinta um muro em L: a navegação das criaturas tem que desviar dele.
	var tiles: GridMap = scene.get_node("Navigation/Tiles")
	for x in range(10, 40):
		tiles.set_cell_item(Vector3i(x, 0, 20), 10)
	for z in range(20, 45):
		tiles.set_cell_item(Vector3i(40, 0, z), 10, tiles.get_orthogonal_index_from_basis(Basis(Vector3.UP, PI / 2)))
	tools.save_scene(scene, chunk_path, root)
	scene = tools.open_scene(chunk_path)
	var walled_polygons: int = scene.get_node("Navigation").navigation_mesh.get_polygon_count()
	_check(walled_polygons != empty_polygons, "paredes pintadas mudam a navegação (%d -> %d polígonos)" % [empty_polygons, walled_polygons])
	_check(not _nav_has_point_near(scene.get_node("Navigation").navigation_mesh, Vector3(25, 0, 20), 0.3), "criaturas não andam por dentro do muro pintado")
	scene.free()

	# Masmorra nova longe do mapa e das outras.
	var cave_path: String = tools.create_interior(map, map_path, "teste_masmorra", "caverna", Vector2i(30, 30), root)
	var info: Dictionary = map.interiors["teste_masmorra"]
	_check(FileAccess.file_exists(cave_path), "masmorra nova criada")
	_check(info.origin.distance_to(map.interiors["caverna_velha"].origin) >= 150.0, "masmorra nova não encosta na Caverna Velha (%s)" % info.origin)
	var cave: Node3D = tools.open_scene(cave_path)
	var walls: int = cave.get_node("Navigation/Tiles").get_used_cells().size()
	_check(walls == 30 * 2 + 28 * 2, "masmorra nova já vem com paredes em volta (%d peças)" % walls)
	cave.free()

	# Ligar entradas: cada uma leva para a frente da outra.
	var report: PackedStringArray = tools.add_entrance_pair(map, chunk_path, Vector3(20, 0, 30), "Teste",
			cave_path, Vector3(15, 0, 26), "Saída", "teste_link")
	_check(report.has("ok: 'teste_link' ligada (chunk_3_0.tscn <-> teste_masmorra.tscn)"), "par de entradas ligado")
	var outside: Node = tools.open_scene(chunk_path).find_child("Entrance_teste_link", true, false)
	var expected: Vector3 = info.origin + Vector3(15, 0, 23.5)
	_check(outside.target_point.is_equal_approx(expected), "entrada de fora leva para dentro, na frente da saída (%s)" % outside.target_point)
	outside.get_owner().free()

	# Mover a entrada de fora deixa o destino da de dentro desatualizado até sincronizar.
	scene = tools.open_scene(chunk_path)
	scene.find_child("Entrance_teste_link", true, false).position = Vector3(8, 0, 8)
	tools.save_scene(scene, chunk_path, null)
	_check(_has_issue(tools.validate(map), "desatualizada"), "validação acusa entrada desatualizada depois de mover")
	tools.sync_entrances(map)
	_check(not _has_issue(tools.validate(map), "desatualizada"), "sincronizar acerta o destino")
	var inside: Node = tools.open_scene(cave_path).find_child("Entrance_teste_link", true, false)
	_check(inside.target_point.is_equal_approx(Vector3(3 * 64 + 8, 0, 8 + 2.5)), "saída leva para a frente da nova posição (%s)" % inside.target_point)
	inside.get_owner().free()

	# O mapa de verdade tem que estar limpo.
	var real: Resource = load("res://world/test_world.tres")
	var errors: Array = tools.validate(real).filter(func(i: Dictionary) -> bool: return i.level == "erro")
	for issue in errors:
		print("    ", issue.text)
	_check(errors.is_empty(), "mapa de verdade passa na validação (%d erros)" % errors.size())
	tools.chunk_dir = tools.CHUNK_DIR
	tools.interior_dir = tools.INTERIOR_DIR
	_clean()


func _nav_has_point_near(nav_mesh: NavigationMesh, point: Vector3, radius: float) -> bool:
	for v in nav_mesh.get_vertices():
		if Vector3(v.x, 0, v.z).distance_to(point) < radius:
			return true
	return false


func _has_issue(issues: Array, text: String) -> bool:
	return issues.any(func(i: Dictionary) -> bool: return i.text.contains(text))


func _clean() -> void:
	for file in DirAccess.get_files_at(TMP):
		DirAccess.remove_absolute(TMP.path_join(file))


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	_failed = _failed or not ok
