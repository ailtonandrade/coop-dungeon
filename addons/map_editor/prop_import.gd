@tool
class_name PropImport
extends RefCounted
## Ajudas para trazer modelos 3D de fora para o projeto e montar fichas (PropDef).

const IMPORT_DIR := "res://assets/props/importados"
const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "tga", "webp", "bmp"]


const MODEL_EXTENSIONS := ["obj", "glb", "gltf", "fbx"]


## Categoria de um modelo: o nome da pasta onde ele está ("C:/Packs/Cidade/poste.obj" -> "cidade").
static func category_from(file: String) -> String:
	return PropBuilder.id_from(file.get_base_dir().get_file())


## Modelos 3D de uma pasta e das subpastas: [[caminho, categoria]] (categoria = pasta de cada um).
static func models_in(dir: String) -> Array:
	var found := []
	for file in DirAccess.get_files_at(dir):
		if MODEL_EXTENSIONS.has(file.get_extension().to_lower()):
			found.append([dir.path_join(file), category_from(dir.path_join(file))])
	for sub in DirAccess.get_directories_at(dir):
		if not sub.begins_with("."):
			found.append_array(models_in(dir.path_join(sub)))
	return found


## Copia o modelo (e o que ele usa: .mtl e texturas do .obj, .bin e imagens do .gltf) para
## assets/props/importados/<pasta de origem>/. Retorna o caminho res:// do modelo, ou "" se falhar.
static func copy_into_project(file: String) -> String:
	var category := category_from(file)
	if category.is_empty():
		category = "modelos"
	var folder := IMPORT_DIR.path_join(category)
	DirAccess.make_dir_recursive_absolute(folder)
	var source_dir := file.get_base_dir()
	var extras := PackedStringArray()
	match file.get_extension().to_lower():
		"obj":
			var mtl := file.get_basename() + ".mtl"
			for line in FileAccess.get_file_as_string(file).split("\n"):
				if line.begins_with("mtllib "):
					mtl = source_dir.path_join(line.substr(7).strip_edges())
			if FileAccess.file_exists(mtl):
				extras.append(mtl)
				for line in FileAccess.get_file_as_string(mtl).split("\n"):
					var parts := line.strip_edges().split(" ", false)
					if parts.size() >= 2 and parts[0].begins_with("map_"):
						extras.append(source_dir.path_join(parts[parts.size() - 1]))
		"gltf":
			var json: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
			if json is Dictionary:
				for key in ["buffers", "images"]:
					for entry: Variant in json.get(key, []):
						if entry is Dictionary and entry.has("uri") and not String(entry.uri).begins_with("data:"):
							extras.append(source_dir.path_join(String(entry.uri).uri_decode()))
		_:
			# .glb e .fbx: leva junto as imagens da mesma pasta (texturas soltas do .fbx).
			for other in DirAccess.get_files_at(source_dir):
				if IMAGE_EXTENSIONS.has(other.get_extension().to_lower()):
					extras.append(source_dir.path_join(other))
	if DirAccess.copy_absolute(file, ProjectSettings.globalize_path(folder.path_join(file.get_file()))) != OK:
		return ""
	for extra in extras:
		if FileAccess.file_exists(extra):
			var target := folder.path_join(extra.get_file())
			DirAccess.copy_absolute(extra, ProjectSettings.globalize_path(target))
	return folder.path_join(file.get_file())


## Id ainda não usado por nenhuma peça.
static func free_id(base: String) -> String:
	return PropBuilder.free_id(base)


## Modelos exportados em centímetros chegam 100x maiores: sugere um tamanho que caiba.
static func suggest_scale(def: PropDef) -> float:
	return PropBuilder.suggest_scale(def)


## Ficha da peça: a salva, ou uma nova a partir de uma peça antiga de um modelo só
## (nó "Modelo" com cena). Null se a peça é montada por partes.
static func def_for_prefab(prefab_path: String) -> PropDef:
	var id := prefab_path.get_file().get_basename()
	var def_path := PropBuilder.DEF_DIR.path_join(id + ".tres")
	if ResourceLoader.exists(def_path):
		return load(def_path) as PropDef
	var scene := load(prefab_path) as PackedScene
	if scene == null:
		return null
	var root := scene.instantiate()
	var model := root.get_node_or_null("Modelo")
	var def: PropDef = null
	if model and not model.scene_file_path.is_empty():
		def = PropDef.new()
		def.id = id
		def.display_name = id.replace("_", " ").capitalize()
		def.model = load(model.scene_file_path)
		def.scale = (model as Node3D).scale.x
		def.rotation_deg = (model as Node3D).rotation_degrees
		def.kind = "fixo" if root.find_children("*", "StaticBody3D", true, false).size() > 0 else "atravessavel"
	root.free()
	return def
