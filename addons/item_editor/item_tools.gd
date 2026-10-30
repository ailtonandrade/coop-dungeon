@tool
extends RefCounted
## Lógica do painel "Itens" (sem tela), usada pelo painel e pelos testes:
## criar, duplicar, salvar e apagar fichas, trazer modelos 3D de fora do projeto,
## gerar o ícone, achar as lojas do mapa e conferir a ficha.

const DEFS_DIR := "res://items/defs/"
const MODELS_DIR := "res://assets/items/"
const ICONS_DIR := "res://items/icons/"
const MODEL_EXTENSIONS := ["glb", "gltf", "fbx", "obj", "blend"]

## Os testes trocam para uma pasta própria.
static var defs_dir := DEFS_DIR
static var models_dir := MODELS_DIR
static var icons_dir := ICONS_DIR


## "Facão de Serra!" -> "facao_de_serra"
static func slugify(text: String) -> String:
	var plain := text.strip_edges().to_lower()
	var from := "áàâãäéèêëíìîïóòôõöúùûüçñ"
	var to := "aaaaaeeeeiiiiooooouuuucn"
	for i in from.length():
		plain = plain.replace(from[i], to[i])
	var result := ""
	for c in plain:
		result += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "_"
	while result.contains("__"):
		result = result.replace("__", "_")
	return result.trim_prefix("_").trim_suffix("_")


static func path_of(id: String) -> String:
	return defs_dir.path_join(id + ".tres")


## Ficha nova (ou cópia de `template`), já salva. Devolve null se o id já existe ou é inválido.
static func create_item(id: String, display_name: String, slot := "melee", template: ItemDef = null) -> ItemDef:
	if id.is_empty() or id == "gold" or ItemDB.has(id) or FileAccess.file_exists(path_of(id)):
		return null
	var item: ItemDef
	if template:
		item = template.duplicate(true)
	else:
		item = ItemDef.new()
		item.slot = slot
		item.look = default_look(slot)
	item.id = id
	item.display_name = display_name
	if save_item(item) != OK:
		return null
	return item


static func save_item(item: ItemDef) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(defs_dir))
	var path := item.resource_path if item.resource_path else path_of(item.id)
	var err := ResourceSaver.save(item, path)
	if err == OK:
		item.take_over_path(path)
		ItemDB.reload()
	return err


static func delete_item(id: String) -> Error:
	var path := path_of(id)
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	ItemDB.reload()
	return err


## Tipo de desenho padrão para cada casa do corpo.
static func default_look(slot: String) -> String:
	return {"melee": "sword", "ranged": "crossbow", "head": "helmet", "chest": "vest", "legs": "legs",
			"feet": "boots", "amulet": "amulet", "ring": "ring", "bag": "backpack"}.get(slot, "sword")


## Copia um modelo 3D de qualquer pasta do computador para assets/items/<id>/ e devolve o
## caminho res:// (o editor importa sozinho em seguida). Texturas soltas ao lado de um .gltf
## ou .obj vão junto. Vazio se o arquivo não for de modelo.
static func import_model(source_path: String, id: String) -> String:
	var extension := source_path.get_extension().to_lower()
	if not MODEL_EXTENSIONS.has(extension) or not FileAccess.file_exists(source_path):
		return ""
	var target_dir := models_dir.path_join(id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_dir))
	var target := target_dir.path_join(source_path.get_file())
	if DirAccess.copy_absolute(source_path, ProjectSettings.globalize_path(target)) != OK:
		return ""
	if extension in ["gltf", "obj"]:
		var folder := source_path.get_base_dir()
		for file in DirAccess.get_files_at(folder):
			if file.get_extension().to_lower() in ["bin", "png", "jpg", "jpeg", "mtl", "webp", "tga"]:
				DirAccess.copy_absolute(folder.path_join(file), ProjectSettings.globalize_path(target_dir.path_join(file)))
	return target


## Tamanho típico (maior medida, em metros) de cada tipo de desenho, para o ajuste automático.
const TYPICAL_SIZE := {
	"sword": 0.9, "dagger": 0.45, "axe": 0.95, "hammer": 0.95, "bow": 1.0, "longbow": 1.3,
	"crossbow": 0.75, "hood": 0.32, "helmet": 0.32, "vest": 0.55, "plate": 0.6, "legs": 0.5,
	"boots": 0.28, "amulet": 0.1, "ring": 0.08, "pouch": 0.22, "backpack": 0.48,
}


## Ajuste automático da correção do modelo: põe no tamanho típico do tipo e, nas armas, deita a
## maior medida no eixo de cima (+Y) com o cabo (a ponta de baixo) na origem; nas outras peças,
## centraliza. Devolve false se não há modelo.
static func auto_fit(item: ItemDef) -> bool:
	if item.model == null:
		return false
	var holder := Node3D.new()
	var model: Node3D = item.model.instantiate()
	holder.add_child(model)
	var raw := _local_bounds(holder)
	var weapon := item.slot in ["melee", "ranged"]
	var rotation := Vector3.ZERO
	if weapon:
		var size := raw.size
		if size.x >= size.y and size.x >= size.z:
			rotation = Vector3(0, 0, 90)
		elif size.z >= size.y and size.z >= size.x:
			rotation = Vector3(-90, 0, 0)
	model.rotation_degrees = rotation
	var rotated := _local_bounds(holder)
	var longest := maxf(rotated.size.x, maxf(rotated.size.y, rotated.size.z))
	var scale: float = TYPICAL_SIZE.get(item.look, 0.5) / maxf(longest, 0.0001)
	var center := rotated.get_center() * scale
	var offset := -center
	if weapon:
		offset.y = -rotated.position.y * scale
	holder.free()
	item.model_scale = snappedf(scale, 0.0001)
	item.model_rotation = rotation
	item.model_offset = offset.snapped(Vector3.ONE * 0.001)
	return true


## Caixa das malhas de `root` (fora da árvore de cena: soma as transformações na mão).
static func _local_bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var transform := Transform3D.IDENTITY
		var node: Node = mesh
		while node and node != root:
			if node is Node3D:
				transform = (node as Node3D).transform * transform
			node = node.get_parent()
		var part := transform * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


## Encaixe padrão do tipo (para começar a ajustar a partir dele).
static func default_mount(look: String) -> Array:
	return ItemVisuals.MOUNTS.get(look, ["Wrist.R", Vector3.ZERO, Vector3.ZERO])


## Caixa que envolve todas as malhas de `root` (no espaço de `root`).
static func bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var local := root.global_transform.affine_inverse() * mesh.global_transform
		var part := local * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


## Salva o ícone (já renderizado) como recurso pronto, sem precisar importar.
static func save_icon(image: Image, id: String) -> Texture2D:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(icons_dir))
	var texture := ImageTexture.create_from_image(image)
	var path := icons_dir.path_join(id + ".res")
	if ResourceSaver.save(texture, path) != OK:
		return null
	var texture_loaded: Texture2D = load(path)
	if texture_loaded is ImageTexture:
		(texture_loaded as ImageTexture).set_image(image)
	return texture_loaded


## Lojas (NPCs comerciantes) do mapa: [{key, name, scene}], lendo as cenas sem abrir.
static func list_shops(map: WorldMap) -> Array[Dictionary]:
	var shops: Array[Dictionary] = []
	var paths: Array = map.chunks.values()
	for id: String in map.interiors:
		paths.append(map.interiors[id].path)
	for path: String in paths:
		var scene := load(path) as PackedScene
		if scene == null:
			continue
		var state := scene.get_state()
		for i in state.get_node_count():
			var props := _npc_properties(state, i)
			if props.is_empty() or int(props.get("service", 0)) != WorldNpc.Service.MERCHANT:
				continue
			var npc_name: String = props.get("npc_name", "")
			var key: String = props.get("shop_id", "") if props.get("shop_id", "") else npc_name
			if key and not shops.any(func(s: Dictionary) -> bool: return s.key == key):
				shops.append({"key": key, "name": npc_name, "scene": path})
	return shops


## Propriedades de um NPC de serviço no nó `i` (as do nó por cima das da peça pronta), ou {}.
static func _npc_properties(state: SceneState, i: int) -> Dictionary:
	var props := {}
	var is_npc := false
	var instance := state.get_node_instance(i)
	if instance:
		var base := instance.get_state()
		for p in base.get_node_property_count(0):
			props[base.get_node_property_name(0, p)] = base.get_node_property_value(0, p)
	for p in state.get_node_property_count(i):
		props[state.get_node_property_name(i, p)] = state.get_node_property_value(i, p)
	var script: Variant = props.get("script")
	is_npc = script is Script and (script as Script).resource_path == "res://world/world_npc.gd"
	return props if is_npc else {}


## Problemas da ficha (vazio = tudo certo).
static func validate(item: ItemDef) -> PackedStringArray:
	var issues := PackedStringArray()
	if item.id.is_empty():
		issues.append("Sem id.")
	elif item.id != slugify(item.id):
		issues.append("O id deve ter só letras minúsculas, números e _ (sugestão: %s)." % slugify(item.id))
	if item.display_name.strip_edges().is_empty():
		issues.append("Sem nome.")
	if not ItemDB.EQUIP_SLOTS.has(item.slot):
		issues.append("Casa do corpo inválida: %s." % item.slot)
	if item.slot in ["melee", "ranged"] and item.damage <= 0.0:
		issues.append("Arma sem dano.")
	if item.slot == "bag" and item.capacity <= 0:
		issues.append("Bolsa sem espaços (capacidade).")
	if item.slot != "bag" and item.capacity > 0:
		issues.append("Só bolsa tem capacidade.")
	for shop in item.sold_by:
		if not ItemDef.known_shops().is_empty() and not ItemDef.known_shops().has(shop):
			issues.append("Loja \"%s\" não existe no mapa." % shop)
	for rule: ItemDrop in item.drops:
		if rule == null:
			issues.append("Regra de loot vazia (clique nela e escolha Novo ItemDrop).")
			continue
		if not GameConfig.CREATURES.has(rule.creature):
			issues.append("Criatura desconhecida no loot: %s." % rule.creature)
		if rule.chance <= 0.0:
			issues.append("Loot de %s com chance 0%%." % rule.creature)
		if rule.max_count < rule.min_count:
			issues.append("Loot de %s: máximo menor que o mínimo." % rule.creature)
	if item.sold_by.is_empty() and item.drops.is_empty() and not item.random_loot:
		issues.append("Ninguém vende e nada deixa cair: o item não aparece no jogo.")
	if item.custom_mount and ItemDef.BONES.find(item.mount_bone) == -1:
		issues.append("Osso de encaixe desconhecido: %s." % item.mount_bone)
	return issues


## Resumo de onde o item aparece, para o painel.
static func where_text(item: ItemDef) -> String:
	var lines := PackedStringArray()
	if not item.sold_by.is_empty():
		lines.append("À venda: " + ", ".join(item.sold_by))
	for rule: ItemDrop in item.drops:
		if rule:
			lines.append("Cai de: " + rule.summary())
	if item.random_loot:
		lines.append("Sorteio geral de loot: sim")
	return "\n".join(lines) if not lines.is_empty() else "Não aparece no jogo ainda."
