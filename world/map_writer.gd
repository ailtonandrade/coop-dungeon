extends RefCounted
## Grava e tira peças do modo construtor direto nas cenas dos blocos (o mapa oficial).
## Só existe no projeto: fica de fora do jogo exportado (filtro de exportação), junto com o
## modo construtor (world/god_mode.gd). Sem class_name de propósito: ninguém do jogo cita.


## Grava a peça na cena do bloco (só rodando pelo editor). True se gravou.
static func save_to_scene(scene_path: String, entry: Dictionary) -> bool:
	var root := _open(scene_path)
	if root == null:
		return false
	var parent := WorldEdits.parent_in(root)
	var scene := load(String(entry.prefab)) as PackedScene
	if scene == null:
		root.free()
		return false
	var node := scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	node.name = String(entry.id)
	if node is LootContainer:
		node.container_id = String(entry.id)
		WorldEdits.apply_loot(node, entry)
	node.transform = (parent as Node3D).transform.affine_inverse() * WorldEdits.unpack_xform(entry.xform) if parent != root else WorldEdits.unpack_xform(entry.xform)
	parent.add_child(node)
	node.owner = root
	return _save(root, scene_path)


## Tira a peça da cena do bloco (desfazer). True se tirou.
static func remove_from_scene(scene_path: String, id: String) -> bool:
	var root := _open(scene_path)
	if root == null:
		return false
	var node := WorldEdits.parent_in(root).get_node_or_null(NodePath(id))
	if node == null:
		root.free()
		return false
	node.get_parent().remove_child(node)
	node.free()
	return _save(root, scene_path)


## Tira da cena do bloco um nó qualquer (peça do mapa), pelo caminho dentro do bloco.
static func remove_path(scene_path: String, node_path: NodePath) -> bool:
	var root := _open(scene_path)
	if root == null:
		return false
	var node := root.get_node_or_null(node_path)
	if node == null or node == root:
		root.free()
		return false
	node.get_parent().remove_child(node)
	node.free()
	return _save(root, scene_path)


## Muda de lugar, na cena do bloco, um nó qualquer (peça do mapa). `local` é relativo ao pai.
static func move_path(scene_path: String, node_path: NodePath, local: Transform3D) -> bool:
	var root := _open(scene_path)
	if root == null:
		return false
	var node := root.get_node_or_null(node_path) as Node3D
	if node == null or node == root:
		root.free()
		return false
	node.transform = local
	return _save(root, scene_path)


static func _open(scene_path: String) -> Node3D:
	var scene := ResourceLoader.load(scene_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	return scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D if scene else null


static func _save(root: Node3D, scene_path: String) -> bool:
	# A malha de navegação não vai junto (o jogo calcula ao carregar).
	var nav := root.get_node_or_null("Navigation") as NavigationRegion3D
	if nav and nav.navigation_mesh:
		nav.navigation_mesh = nav.navigation_mesh.duplicate()
		nav.navigation_mesh.clear()
	var packed := PackedScene.new()
	var err := packed.pack(root)
	root.free()
	if err != OK or ResourceSaver.save(packed, scene_path) != OK:
		return false
	packed.take_over_path(scene_path)
	return true


## Grava o conteúdo novo de um contêiner do construtor na cena do bloco. True se gravou.
static func save_loot_to_scene(scene_path: String, entry: Dictionary) -> bool:
	var root := _open(scene_path)
	if root == null:
		return false
	var node := WorldEdits.parent_in(root).get_node_or_null(NodePath(String(entry.id)))
	if node == null or not node is LootContainer:
		root.free()
		return false
	WorldEdits.apply_loot(node, entry)
	return _save(root, scene_path)
