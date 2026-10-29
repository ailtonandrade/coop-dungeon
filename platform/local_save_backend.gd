class_name LocalSaveBackend
extends SaveBackend
## Salva JSON em user://saves. Escreve num arquivo temporário e renomeia,
## para um crash no meio da escrita não corromper o save anterior.

var dir := "user://saves"


func write(key: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var path := _path(key)
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("Save falhou (%s): %s" % [key, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return DirAccess.rename_absolute(tmp, path) == OK


func read(key: String) -> Dictionary:
	var path := _path(key)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func list(prefix: String) -> PackedStringArray:
	var keys := PackedStringArray()
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".json") and file.begins_with(prefix):
			keys.append(file.trim_suffix(".json"))
	return keys


func delete(key: String) -> bool:
	return DirAccess.remove_absolute(_path(key)) == OK


func _path(key: String) -> String:
	return "%s/%s.json" % [dir, key.validate_filename()]
