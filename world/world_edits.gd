class_name WorldEdits
extends RefCounted
## Peças colocadas pelo modo construtor (GodMode). Cada uma é um registro:
##   {"id": "god_...", "key": "x,z" ou "i:<id>", "prefab": "res://world/prefabs/...", "xform": [12 números]}
## com a posição relativa ao bloco.
##
## Este arquivo vai no jogo exportado: é o que põe as peças já colocadas no mundo (inclusive
## nos convidados). Gravar nas cenas do mapa fica em MapWriter (world/map_writer.gd), que, como
## o próprio modo construtor, nem vai no jogo exportado (filtro de exportação).

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
