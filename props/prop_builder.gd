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


## Todas as peças prontas, agrupadas por categoria ("Geral" primeiro) e por nome:
## [{path, name, kind, def, category}] (def é a ficha, ou null nas montadas à mão).
static func catalog() -> Array[Dictionary]:
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
		"fixo":
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
	if def.kind == "fixo" or def.kind == "fisico":
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
