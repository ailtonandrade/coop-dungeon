@tool
class_name PropBuilder
extends RefCounted
## Monta a peça pronta (world/prefabs/<id>.tscn) a partir da ficha (PropDef) e lista as peças
## que o editor de mapa e o modo construtor oferecem.
##
## Categorias são as subpastas de world/prefabs (world/prefabs/arvores/pinheiro.tscn fica em
## "Arvores"); as soltas na raiz ficam em "Geral". Para reorganizar, mova os arquivos no
## FileSystem do Godot (ele atualiza os blocos que usam a peça).

const PREFAB_DIR := "res://world/prefabs"
const DEF_DIR := "res://world/props"
## Malhas (.obj) viram uma cena pequena aqui, para todas as peças usarem cena como modelo.
const MESH_SCENE_DIR := "res://world/props/models"


const GENERAL := "Geral"
## Packs de modelos soltos (DownTown, Survival, Zombie...): cada subpasta é uma categoria do
## construtor, com todos os modelos dela (também nas sub-subpastas). O modelo vira peça pronta
## (fixa) na primeira vez que é carimbado (make_from_model), em world/prefabs/<pack>/.
static var pack_dirs: Array = ["res://assets/props/packs", "res://props/packs"]
const MODEL_EXTENSIONS := ["glb", "gltf", "fbx", "obj"]


## Todas as peças prontas, agrupadas por categoria ("Geral" primeiro) e por nome:
## [{path, name, kind, def, category}] (def é a ficha, ou null nas montadas à mão).
## Com `include_packs`, entram também os modelos dos packs que ainda não viraram peça:
## {path = o modelo, raw = true, pack = pasta do pack}.
static func catalog(include_packs := false) -> Array[Dictionary]:
	var defs := {}
	for file in DirAccess.get_files_at(DEF_DIR):
		file = file.trim_suffix(".remap")
		if file.ends_with(".tres"):
			var def := load(DEF_DIR.path_join(file)) as PropDef
			if def and not def.id.is_empty():
				defs[def.id] = def
	var entries: Array[Dictionary] = []
	for path in prefab_files():
		var id := path.get_file().get_basename()
		var def: PropDef = defs.get(id)
		entries.append({
			"path": path,
			"name": def.display_name if def and def.display_name else id.replace("_", " "),
			"kind": def.kind if def else "",
			"def": def,
			"category": category_of(path),
		})
	if include_packs:
		var used := {}
		for def: PropDef in defs.values():
			if def.model:
				used[def.model.resource_path] = true
		for pack: Array in pack_models():
			if not used.has(pack[0]):
				entries.append({"path": pack[0], "name": String(pack[0]).get_file().get_basename().replace("_", " "),
						"kind": "estrutura" if PropDef.looks_structural(String(pack[0]).get_file().get_basename()) else "fixo", "def": null, "category": id_from(pack[1]).capitalize(), "raw": true, "pack": pack[1]})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.category != b.category:
			return a.category == GENERAL or (b.category != GENERAL and a.category.naturalnocasecmp_to(b.category) < 0)
		return String(a.name).naturalnocasecmp_to(b.name) < 0)
	return entries


## Categorias na ordem do catálogo (sem repetir).
static func categories(entries: Array[Dictionary]) -> PackedStringArray:
	var result := PackedStringArray()
	for entry in entries:
		if not result.has(entry.category):
			result.append(entry.category)
	return result


## Modelos dos packs: [[caminho, nome da pasta do pack]]. O mesmo modelo em vários formatos
## (pack com FBX, OBJ e glTF) entra uma vez só, no melhor formato (glb > gltf > fbx > obj).
static func pack_models() -> Array:
	var found := []
	for root: String in pack_dirs:
		if not DirAccess.dir_exists_absolute(root):
			continue
		for pack in DirAccess.get_directories_at(root):
			var best := {}  # nome sem extensão -> caminho
			for path in _models_under(root.path_join(pack)):
				var stem := path.get_file().get_basename().to_lower()
				if not best.has(stem) or MODEL_EXTENSIONS.find(path.get_extension().to_lower()) < MODEL_EXTENSIONS.find(String(best[stem]).get_extension().to_lower()):
					best[stem] = path
			for path: String in best.values():
				found.append([path, pack])
	return found


static func _models_under(dir: String) -> PackedStringArray:
	var result := PackedStringArray()
	for file in DirAccess.get_files_at(dir):
		if MODEL_EXTENSIONS.has(file.get_extension().to_lower()) and ResourceLoader.exists(dir.path_join(file)):
			result.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		if not sub.begins_with("."):
			result.append_array(_models_under(dir.path_join(sub)))
	return result


## Transforma um modelo de pack em peça pronta fixa (com caixa de colisão), na pasta do pack.
## Retorna o caminho da peça, ou "".
static func make_from_model(model_path: String, pack: String) -> String:
	var model: Resource = load(model_path)
	if model == null:
		return ""
	var def := PropDef.new()
	def.model = model
	def.display_name = model_path.get_file().get_basename().replace("_", " ")
	var base := id_from(model_path.get_file().get_basename())
	def.id = free_id(base if prefab_path_of(base).is_empty() else "%s_%s" % [id_from(pack), base])
	def.kind = "estrutura" if PropDef.looks_structural(model_path.get_file().get_basename()) else "fixo"
	def.scale = suggest_scale(def)
	return save(def, pack)


## Id ainda não usado por nenhuma peça.
static func free_id(base: String) -> String:
	if base.is_empty():
		base = "peca"
	var id := base
	var n := 2
	while not prefab_path_of(id).is_empty():
		id = "%s_%d" % [base, n]
		n += 1
	return id


## Modelos exportados em centímetros chegam 100x maiores: sugere um tamanho que caiba.
static func suggest_scale(def: PropDef) -> float:
	var node := model_node(def.model)
	if node == null:
		return 1.0
	var size := _bounds(node).size
	node.free()
	var biggest := maxf(size.x, maxf(size.y, size.z))
	if biggest > 40.0:
		return 0.01
	if biggest < 0.05 and biggest > 0.0:
		return 1.0 / biggest
	return 1.0


## O modelo montado como nó (cena ou malha), sem gravar nada. Null se não der.
static func model_node(model: Resource) -> Node3D:
	if model is PackedScene:
		return (model as PackedScene).instantiate() as Node3D
	if model is Mesh:
		var mesh := MeshInstance3D.new()
		mesh.mesh = model
		return mesh
	return null


## Prévia de um modelo de pack: base no chão e no tamanho sugerido (para o fantasma).
static func preview_from_model(model_path: String) -> Node3D:
	var def := PropDef.new()
	def.model = load(model_path)
	var node := model_node(def.model)
	if node == null:
		return null
	node.scale = Vector3.ONE * suggest_scale(def)
	var box := _bounds(node)
	var holder := Node3D.new()
	node.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
	holder.add_child(node)
	return holder


## Todas as cenas de peça, inclusive nas subpastas (categorias).
static func prefab_files(dir := PREFAB_DIR) -> PackedStringArray:
	var result := PackedStringArray()
	for file in DirAccess.get_files_at(dir):
		file = file.trim_suffix(".remap")
		if file.ends_with(".tscn") and not result.has(dir.path_join(file)):
			result.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		if not sub.begins_with("."):
			result.append_array(prefab_files(dir.path_join(sub)))
	return result


## "Geral" para as soltas em world/prefabs; senão o nome da pasta ("arvores_altas" -> "Arvores Altas").
static func category_of(prefab_path: String) -> String:
	var folder := prefab_path.get_base_dir().trim_prefix(PREFAB_DIR).trim_prefix("/")
	if folder.is_empty():
		return GENERAL
	var parts := PackedStringArray()
	for part in folder.split("/"):
		parts.append(part.capitalize())
	return " / ".join(parts)


## Onde está a peça com esse id (em qualquer pasta), ou "".
static func prefab_path_of(id: String) -> String:
	for path in prefab_files():
		if path.get_file().get_basename() == id:
			return path
	return ""


## Id de arquivo a partir de um nome ("Caixa d'água 2" -> "caixa_dagua_2").
static func id_from(text: String) -> String:
	var plain := text.strip_edges().to_lower()
	for pair: Array in [["á", "a"], ["à", "a"], ["â", "a"], ["ã", "a"], ["é", "e"], ["ê", "e"], ["í", "i"],
			["ó", "o"], ["ô", "o"], ["õ", "o"], ["ú", "u"], ["ç", "c"]]:
		plain = plain.replace(pair[0], pair[1])
	var result := ""
	for character in plain:
		if (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			result += character
		elif character == " " or character == "_" or character == "-":
			if not result.ends_with("_"):
				result += "_"
	return result.trim_suffix("_").trim_prefix("_")


## Salva a ficha e (re)gera a peça pronta. Retorna o caminho da peça, ou "" se falhar.
## Peça que já existe é regerada onde estiver; peça nova vai para a pasta `folder` (categoria,
## dentro de world/prefabs; vazio = solta, em "Geral").
static func save(def: PropDef, folder := "") -> String:
	if def.id.is_empty() or def.model == null:
		return ""
	DirAccess.make_dir_recursive_absolute(DEF_DIR)
	var def_path := DEF_DIR.path_join(def.id + ".tres")
	if ResourceSaver.save(def, def_path) != OK:
		return ""
	def.take_over_path(def_path)
	var root := build(def)
	if root == null:
		return ""
	var packed := PackedScene.new()
	var err := packed.pack(root)
	root.free()
	if err != OK:
		return ""
	var path := prefab_path_of(def.id)
	if path.is_empty():
		var dir := PREFAB_DIR.path_join(id_from(folder)) if not id_from(folder).is_empty() else PREFAB_DIR
		DirAccess.make_dir_recursive_absolute(dir)
		path = dir.path_join(def.id + ".tscn")
	if ResourceSaver.save(packed, path) != OK:
		return ""
	packed.take_over_path(path)
	return path


## A peça montada (ainda fora da árvore), com dono em tudo para poder salvar.
static func build(def: PropDef) -> Node3D:
	var model_scene := model_scene_of(def)
	if model_scene == null:
		return null
	var model := model_scene.instantiate() as Node3D
	if model == null:
		return null
	model.name = "Modelo"
	model.scale = Vector3.ONE * def.scale
	model.rotation_degrees = def.rotation_deg
	# Base no chão e centro no meio da peça.
	var box := _bounds(model)
	model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
	box.position += model.position

	var root: Node3D
	match def.kind:
		"fisico":
			var body := PhysicsProp.new()
			body.mass = def.mass
			root = body
		"conteiner":
			var chest := LootContainer.new()
			chest.title = def.container_title
			chest.gold = def.gold
			chest.random_items = def.random_items
			chest.model = model_scene
			chest.model_scale = def.scale
			root = chest
		"fixo", "estrutura":
			root = StaticBody3D.new()
			(root as StaticBody3D).collision_layer = GameConfig.LAYER_WORLD
		_:
			root = Node3D.new()
	root.name = def.display_name.to_pascal_case() if def.display_name else def.id.to_pascal_case()
	root.set_meta("prop_def", def.resource_path)
	if def.kind != "conteiner":
		root.add_child(model)
		model.owner = root
	else:
		model.free()
	if def.kind in ["fixo", "fisico", "estrutura"]:
		var shape := BoxShape3D.new()
		shape.size = box.size.max(Vector3.ONE * 0.05)
		var collision := CollisionShape3D.new()
		collision.name = "Collision"
		collision.shape = shape
		collision.position = box.get_center()
		root.add_child(collision)
		collision.owner = root
	return root


## O modelo como cena: a própria (glb/gltf/fbx) ou uma cena gerada com a malha (.obj).
static func model_scene_of(def: PropDef) -> PackedScene:
	if def.model is PackedScene:
		return def.model
	if def.model is Mesh:
		var path := MESH_SCENE_DIR.path_join(def.id + "_modelo.tscn")
		var mesh := MeshInstance3D.new()
		mesh.name = "Malha"
		mesh.mesh = def.model
		var packed := PackedScene.new()
		packed.pack(mesh)
		mesh.free()
		DirAccess.make_dir_recursive_absolute(MESH_SCENE_DIR)
		ResourceSaver.save(packed, path)
		packed.take_over_path(path)
		return packed
	return null


## Caixa que envolve todas as malhas do nó (nas coordenadas do pai dele).
static func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var meshes := node.find_children("*", "VisualInstance3D", true, false)
	if node is VisualInstance3D:
		meshes.append(node)
	for mesh: VisualInstance3D in meshes:
		var xform := Transform3D.IDENTITY
		var current: Node = mesh
		while current:
			if current is Node3D:
				xform = (current as Node3D).transform * xform
			if current == node:
				break
			current = current.get_parent()
		var local := xform * mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box if not first else AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)
