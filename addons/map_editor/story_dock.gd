@tool
extends ScrollContainer
## Painel "Histórias" do editor: conversas dos NPCs (world/lore/npcs), documentos (livro da
## história) e o mapa dos gatilhos: cada fato, quem ensina (documento, assunto, cumprimento) e
## quem exige (assuntos, portões, contêineres, entradas, documentos). Fato exigido que ninguém
## ensina aparece em laranja (o jogador ficaria preso).

const NPC_DIR := "res://world/lore/npcs"
const BOOK_PATH := "res://world/lore/lore.tres"
const SCENE_DIRS := ["res://world/chunks", "res://world/interiors", "res://world/lore"]

var _npcs: ItemList
var _new_npc: LineEdit
var _docs: ItemList
var _new_doc: LineEdit
var _facts: RichTextLabel


func _ready() -> void:
	custom_minimum_size = Vector2(280, 0)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	_header(box, "Conversas dos NPCs")
	_hint(box, "Clique para editar no Inspector: cumprimentos, puxar assunto e assuntos (palavras, resposta, gatilhos).")
	_npcs = ItemList.new()
	_npcs.custom_minimum_size = Vector2(0, 120)
	_npcs.item_selected.connect(func(i: int) -> void: EditorInterface.inspect_object(load(_npcs.get_item_metadata(i))))
	box.add_child(_npcs)
	var npc_row := HBoxContainer.new()
	box.add_child(npc_row)
	_new_npc = LineEdit.new()
	_new_npc.placeholder_text = "Nome do NPC (igual ao do mapa)"
	_new_npc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	npc_row.add_child(_new_npc)
	_button(npc_row, "Nova conversa", _create_npc)

	_header(box, "Documentos (diários, terminais...)")
	_docs = ItemList.new()
	_docs.custom_minimum_size = Vector2(0, 90)
	_docs.item_selected.connect(func(i: int) -> void: EditorInterface.inspect_object(_book().documents[i]))
	box.add_child(_docs)
	var doc_row := HBoxContainer.new()
	box.add_child(doc_row)
	_new_doc = LineEdit.new()
	_new_doc.placeholder_text = "id_do_documento"
	_new_doc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	doc_row.add_child(_new_doc)
	_button(doc_row, "Novo documento", _create_doc)
	_hint(box, "No mapa: peça \"Documento da história\" (escolha o id) e \"Portão trancado\"; contêiner e entrada têm o campo Requires.")

	_header(box, "Gatilhos (fatos)")
	_button(box, "Atualizar lista", refresh)
	_facts = RichTextLabel.new()
	_facts.bbcode_enabled = true
	_facts.fit_content = true
	_facts.selection_enabled = true
	box.add_child(_facts)
	refresh()


func refresh() -> void:
	_npcs.clear()
	for file in DirAccess.get_files_at(NPC_DIR):
		if file.ends_with(".tres"):
			var dialogue := load(NPC_DIR.path_join(file)) as NpcDialogue
			if dialogue:
				var index := _npcs.add_item("%s  ·  %d assuntos" % [dialogue.npc, dialogue.topics.size()])
				_npcs.set_item_metadata(index, NPC_DIR.path_join(file))
	_docs.clear()
	for doc in _book().documents:
		if doc:
			_docs.add_item("%s  ·  %s" % [doc.id, doc.title])
	_facts.text = _facts_report()


func _book() -> LoreBook:
	return load(BOOK_PATH) as LoreBook


func _create_npc() -> void:
	var npc_name := _new_npc.text.strip_edges()
	if npc_name.is_empty():
		return
	var dialogue := NpcDialogue.new()
	dialogue.npc = npc_name
	var hello := DialogueLine.new()
	hello.text = "Olá."
	dialogue.greetings = [hello] as Array[DialogueLine]
	var topic := DialogueTopic.new()
	topic.label = "Nome"
	topic.keywords = PackedStringArray(["nome", "quem"])
	topic.text = "Eu sou %s." % npc_name
	dialogue.topics = [topic] as Array[DialogueTopic]
	var path := NPC_DIR.path_join(PropBuilder.id_from(npc_name) + ".tres")
	ResourceSaver.save(dialogue, path)
	_new_npc.text = ""
	refresh()
	EditorInterface.inspect_object(load(path))


func _create_doc() -> void:
	var id := PropBuilder.id_from(_new_doc.text)
	if id.is_empty():
		return
	var book := _book()
	var doc := LoreDocument.new()
	doc.id = id
	doc.title = _new_doc.text.strip_edges()
	book.documents.append(doc)
	ResourceSaver.save(book, BOOK_PATH)
	_new_doc.text = ""
	refresh()
	EditorInterface.inspect_object(doc)


## Relatório: fato -> quem ensina / quem exige.
func _facts_report() -> String:
	var taught := {}  # fato -> [onde]
	var needed := {}
	var add := func(map: Dictionary, fact: String, where: String) -> void:
		if fact.is_empty():
			return
		if not map.has(fact):
			map[fact] = []
		map[fact].append(where)
	for doc in _book().documents:
		if doc:
			for fact in doc.facts():
				add.call(taught, fact, "documento %s" % doc.id)
	for file in DirAccess.get_files_at(NPC_DIR):
		var dialogue := load(NPC_DIR.path_join(file)) as NpcDialogue if file.ends_with(".tres") else null
		if dialogue == null:
			continue
		for line in dialogue.greetings + dialogue.approach:
			for fact in line.teaches:
				add.call(taught, fact, "%s (fala)" % dialogue.npc)
			for fact in line.requires:
				add.call(needed, fact, "%s (fala)" % dialogue.npc)
		for topic in dialogue.topics:
			for fact in topic.teaches:
				add.call(taught, fact, "%s · %s" % [dialogue.npc, topic.button_text()])
			for fact in topic.requires:
				add.call(needed, fact, "%s · %s" % [dialogue.npc, topic.button_text()])
			if topic.gives_item:
				add.call(taught, "item_%s_%s" % [PropBuilder.id_from(dialogue.npc), topic.gives_item], "%s dá %s" % [dialogue.npc, topic.gives_item])
	# Portões, contêineres, entradas e documentos no mapa: campo requires nas cenas.
	for dir: String in SCENE_DIRS:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".tscn"):
				continue
			var node := ""
			for line in FileAccess.get_file_as_string(dir.path_join(file)).split("\n"):
				if line.begins_with("[node name=\""):
					node = line.get_slice("\"", 1)
				elif line.begins_with("requires = Array[String]([") and not node.is_empty():
					for fact in line.trim_prefix("requires = Array[String]([").trim_suffix("])").split(","):
						add.call(needed, fact.strip_edges().trim_prefix("\"").trim_suffix("\""), "%s (%s)" % [node, file.get_basename()])
	var facts: Array = taught.keys()
	for fact in needed:
		if not facts.has(fact):
			facts.append(fact)
	facts.sort()
	var lines := PackedStringArray()
	for fact: String in facts:
		var color := "orange" if needed.has(fact) and not taught.has(fact) else ("gray" if not needed.has(fact) else "white")
		lines.append("[color=%s][b]%s[/b][/color]" % [color, fact])
		if taught.has(fact):
			lines.append("   ensina: " + ", ".join(taught[fact]))
		else:
			lines.append("   [color=orange]ninguém ensina este fato[/color]")
		if needed.has(fact):
			lines.append("   libera: " + ", ".join(needed[fact]))
	return "\n".join(lines) if not lines.is_empty() else "Nenhum fato ainda."


func _header(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	parent.add_child(label)


func _hint(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color(1, 1, 1, 0.6)
	parent.add_child(label)


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button
