extends SceneTree
## Pinta uma ruína de demonstração na grade do bloco (1, 0) (Planície Verde), usando as peças
## da biblioteca: chão de pedra, muro com vão de porta e colunas. Exemplo do que se faz à mão
## no editor (selecionar o nó Tiles do bloco e pintar com a paleta do GridMap).
## Rodar: godot --headless --path coop-dungeon -s tools/paint_demo_ruin.gd

const PATH := "res://world/chunks/chunk_1_0.tscn"
const CENTER := Vector2i(30, 44)
const HALF := 6

var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	var tools: Script = load("res://addons/map_editor/map_tools.gd")
	var scene: Node3D = tools.open_scene(PATH)
	var tiles: GridMap = scene.get_node("Navigation/Tiles")
	tiles.clear()
	var along_z := tiles.get_orthogonal_index_from_basis(Basis(Vector3.UP, PI / 2))
	for x in range(CENTER.x - HALF, CENTER.x + HALF + 1):
		for z in range(CENTER.y - HALF, CENTER.y + HALF + 1):
			tiles.set_cell_item(Vector3i(x, 0, z), 0)
	for i in range(-HALF, HALF + 1):
		tiles.set_cell_item(Vector3i(CENTER.x + i, 0, CENTER.y - HALF), 11)
		if absi(i) > 1:
			tiles.set_cell_item(Vector3i(CENTER.x + i, 0, CENTER.y + HALF), 11)
		tiles.set_cell_item(Vector3i(CENTER.x - HALF, 0, CENTER.y + i), 11, along_z)
		tiles.set_cell_item(Vector3i(CENTER.x + HALF, 0, CENTER.y + i), 11, along_z)
	for corner: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		tiles.set_cell_item(Vector3i(CENTER.x + corner.x * (HALF + 1), 0, CENTER.y + corner.y * (HALF + 1)), 14)
	print("Ruína pintada: ", tiles.get_used_cells().size(), " peças; salvar: ", error_string(tools.save_scene(scene, PATH, root)))
	quit()
	return false
