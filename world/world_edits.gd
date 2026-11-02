class_name WorldEdits
extends RefCounted
## Peças colocadas pelo modo construtor (GodMode). Cada uma é um registro:
##   {"id": "god_...", "key": "x,z" ou "i:<id>", "prefab": "res://world/prefabs/...", "xform": [12 números]}
## com a posição relativa ao bloco.
##
## Onde ficam guardadas:
## - Rodando pelo editor do Godot (o dono criando o mapa): direto na cena do bloco, como se
##   tivesse sido colocada no editor de mapa. Fica no mapa oficial e aparece no editor.
## - No jogo exportado (res:// é só leitura): no save do mundo (chave "placed"), só naquele mundo.

const ID_PREFIX := "god_"


## Testes ligam "world_edits_to_save" para nunca mexer nas cenas de verdade.
static func saves_in_map_files() -> bool:
	return OS.has_feature("editor") and not Engine.has_meta("world_edits_to_save")


static func new_id() -> String:
	return "%s%d_%04d" % [ID_PREFIX, int(Time.get_unix_time_from_system()), randi() % 10000]


static func pack_xform(xform: Transform3D) -> Array:
	var b := xform.basis
	return [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z, xform.origin.x, xform.origin.y, xform.origin.z]


static func unpack_xform(data: Array) -> Transform3D:
	if data.size() != 12:
		return Transform3D.IDENTITY
	return Transform3D(Vector3(data[0], data[1], data[2]), Vector3(data[3], data[4], data[5]),
			Vector3(data[6], data[7], data[8]), Vector3(data[9], data[10], data[11]))


## Onde as peças entram dentro do bloco: no nó da navegação (sólidos desviam as criaturas).
static func parent_in(chunk: Node) -> Node:
	return chunk.get_node_or_null("Navigation") if chunk.has_node("Navigation") else chunk


## Cria a peça do registro dentro do bloco já carregado. Null se já existe ou a peça sumiu.
static func spawn(chunk: Node3D, entry: Dictionary) -> Node3D:
	var parent := parent_in(chunk)
	if parent.has_node(NodePath(String(entry.id))) or not ResourceLoader.exists(String(entry.prefab)):
		return null
	var scene := load(String(entry.prefab)) as PackedScene
	var node := scene.instantiate() as Node3D if scene else null
	if node == null:
		return null
	node.name = String(entry.id)
	if node is LootContainer:
		node.container_id = String(entry.id)
		apply_loot(node, entry)
	node.transform = (parent as Node3D).transform.affine_inverse() * unpack_xform(entry.xform) if parent != chunk else unpack_xform(entry.xform)
	parent.add_child(node)
	return node


## Conteúdo de contêiner escolhido no modo construtor: entry["loot"] = [[item, quantidade]...]
## e entry["gold"]. Sem essas chaves, fica o da ficha.
static func apply_loot(container: Node, entry: Dictionary) -> void:
	if entry.has("loot"):
		var lines: Array[ContainerItem] = []
		for pair: Array in entry.loot:
			var line := ContainerItem.new()
			line.item_id = String(pair[0])
			line.count = int(pair[1])
			lines.append(line)
		container.contents = lines
	if entry.has("gold"):
		container.gold = int(entry.gold)


## Grava o conteúdo novo de um contêiner do construtor na cena do bloco. True se gravou.
static func save_loot_to_scene(scene_path: String, entry: Dictionary) -> bool:
	var root := _open(scene_path)
	if root == null:
		return false
	var node := parent_in(root).get_node_or_null(NodePath(String(entry.id)))
	if node == null or not node is LootContainer:
		root.free()
		return false
	apply_loot(node, entry)
	return _save(root, scene_path)


## Grava a peça na cena do bloco (só rodando pelo editor). True se gravou.
static func save_to_scene(scene_path: String, entry: Dictionary) -> bool:
	var root := _open(scene_path)
	if root == null:
		return false
	var parent := parent_in(root)
	var scene := load(String(entry.prefab)) as PackedScene
	if scene == null:
		root.free()
		return false
	var node := scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	node.name = String(entry.id)
	if node is LootContainer:
		node.container_id = String(entry.id)
		apply_loot(node, entry)
	node.transform = (parent as Node3D).transform.affine_inverse() * unpack_xform(entry.xform) if parent != root else unpack_xform(entry.xform)
	parent.add_child(node)
	node.owner = root
	return _save(root, scene_path)


## Tira a peça da cena do bloco (desfazer). True se tirou.
static func remove_from_scene(scene_path: String, id: String) -> bool:
	var root := _open(scene_path)
	if root == null:
		return false
	var node := parent_in(root).get_node_or_null(NodePath(id))
	if node == null:
		root.free()
		return false
	node.get_parent().remove_child(node)
	node.free()
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
