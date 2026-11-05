extends SceneTree
## Junta todos os textos do jogo em locale/textos.csv (chave = texto em português, uma coluna por
## idioma), mantendo as traduções que já existem. Rode depois de escrever textos novos:
##   godot --headless --path . -s tools/extrair_textos.gd
## Pega: textos do código (.gd, menos testes/ferramentas/addons), nomes dos itens, regiões,
## documentos, conversas e fichas de fatos da história, e textos das cenas da interface.

const CSV := "res://locale/textos.csv"
const LANGS := ["en"]

var _keys := {}


func _initialize() -> void:
	_scan_code("res://")
	for file in DirAccess.get_files_at("res://items/defs"):
		if file.ends_with(".tres"):
			_add(load("res://items/defs/" + file).get("display_name"))
	var world_map: Resource = load("res://world/test_world.tres")
	for region in world_map.regions:
		_add(region.display_name)
	var book: Resource = load("res://world/lore/lore.tres")
	for doc in book.documents:
		_add(doc.title)
		_add(doc.author)
		_add(doc.text)
	for file in DirAccess.get_files_at("res://world/lore/npcs"):
		if not file.ends_with(".tres"):
			continue
		var dialogue: Resource = load("res://world/lore/npcs/" + file)
		for line in dialogue.greetings + dialogue.approach:
			_add(line.text)
		for topic in dialogue.topics:
			_add(topic.label)
			_add(topic.text)
			for keyword in topic.keywords:
				_keys[keyword] = true
		_add(dialogue.unknown)
		_add(dialogue.farewell)
		_add(dialogue.service_button)
	for file in DirAccess.get_files_at("res://world/lore/facts"):
		if file.ends_with(".tres"):
			var fact: Resource = load("res://world/lore/facts/" + file)
			_add(fact.title)
			_add(fact.description)
			_add(fact.source)
	var old := _read_existing()
	var file := FileAccess.open(CSV, FileAccess.WRITE)
	file.store_csv_line(PackedStringArray(["keys"] + LANGS))
	# Linhas antigas que já têm tradução continuam (palavras soltas que o extrator não acha
	# sozinho, como nomes de cores, entram à mão no CSV e não se perdem).
	for key: String in old:
		if not _keys.has(key) and old[key].values().any(func(v: String) -> bool: return not v.is_empty()):
			_keys[key] = true
	var keys := _keys.keys()
	keys.sort()
	var missing := 0
	for key: String in keys:
		var row := PackedStringArray([key])
		for lang: String in LANGS:
			var value: String = old.get(key, {}).get(lang, "")
			if value.is_empty():
				missing += 1
			row.append(value)
		file.store_csv_line(row)
	file.close()
	print("textos: %d · sem tradução: %d" % [keys.size(), missing])
	quit()


func _add(text: Variant) -> void:
	if text is String and _is_text(text):
		_keys[text] = true


static func _is_text(s: String) -> bool:
	if s.length() < 2 or not RegEx.create_from_string("[A-Za-zÀ-ú]{2,}").search(s):
		return false
	if s.begins_with("res://") or s.begins_with("user://") or s.begins_with("http") or s.begins_with("uid://"):
		return false
	if RegEx.create_from_string("^[a-z0-9_./:%-]+$").search(s):
		return false
	return true


func _scan_code(dir: String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		if sub.begins_with(".") or sub in ["tests", "tools", "addons", "locale", "assets"]:
			continue
		_scan_code(dir.path_join(sub))
	var literal := RegEx.create_from_string("\"((?:[^\"\\\\\\n]|\\\\.)*)\"")
	for file in DirAccess.get_files_at(dir):
		if not (file.ends_with(".gd") or (file.ends_with(".tscn") and dir.begins_with("res://ui"))):
			continue
		for line in FileAccess.get_file_as_string(dir.path_join(file)).split("\n"):
			var code := line.strip_edges()
			if code.begins_with("#") or code.begins_with("push_") or code.contains("print("):
				continue
			if file.ends_with(".tscn") and not (code.begins_with("text =") or code.begins_with("placeholder_text =") or code.begins_with("tooltip_text =")):
				continue
			for found in literal.search_all(line):
				var text := found.get_string(1).c_unescape()
				# Frases, palavras com acento e palavras soltas com maiúscula (botões: "Jogo", "Sair").
				if text.contains(" ") or RegEx.create_from_string("[À-ú]").search(text) \
						or RegEx.create_from_string("^[A-ZÀ-Ú][a-zà-ú]{1,}$").search(text):
					_add(text)


func _read_existing() -> Dictionary:
	var result := {}
	if not FileAccess.file_exists(CSV):
		return result
	var file := FileAccess.open(CSV, FileAccess.READ)
	var header := file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2:
			continue
		var values := {}
		for i in range(1, mini(row.size(), header.size())):
			values[header[i]] = row[i]
		result[row[0]] = values
	return result
