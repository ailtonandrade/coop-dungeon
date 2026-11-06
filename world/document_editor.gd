extends CanvasLayer
## Editor de DOCUMENTOS da história dentro do jogo (só o dono do jogo, rodando pelo editor do
## Godot): diário, ofício, carta, terminal... o texto que aparece ao ler. Liga e desliga com
## COMMAND no chat. Fica de fora do jogo exportado (filtro de exportação), sem class_name.
##
## Grava em world/lore/lore.tres (o livro da história). Para pôr o documento no mapa: /editar,
## categoria Historia, "documento da historia"; ao colocar (ou F em cima) escolhe qual documento
## e o visual (livro, caderno, terminal, foto, troféu). Missão "ler" com o id do documento conta
## quando alguém lê.

const COMMAND := "/documentos"
const BOOK_PATH := "res://world/lore/lore.tres"

var active := false
var slot := -1

var _list: ItemList
var _status: Label
var _id: LineEdit
var _title: LineEdit
var _author: LineEdit
var _text: TextEdit
var _teaches: LineEdit
var _editing := ""


func _ready() -> void:
	add_to_group("document_editor")
	layer = 60
	visible = false
	_build()


static func allowed() -> bool:
	return OS.has_feature("editor") and NetService.mode != NetService.Mode.CLIENT


static func is_command(text: String) -> bool:
	var clean := text.strip_edges().to_lower().replace("\\", "/")
	return clean == COMMAND or clean == "/documento"


func toggle(p_slot: int) -> void:
	if active:
		stop()
	else:
		start(p_slot)


func start(p_slot: int) -> void:
	if not allowed():
		return
	slot = p_slot
	active = true
	visible = true
	Player.set_editor_shield("documentos", true)
	InputService.set_blocked(slot, true)
	InputService.screen_menu_open = true
	_refresh_list()
	if _editing.is_empty():
		_new_document()
	Chat.local_note("Editor de documentos ligado (%s de novo para sair)." % COMMAND)


func stop() -> void:
	active = false
	visible = false
	Player.set_editor_shield("documentos", false)
	if slot >= 0:
		InputService.set_blocked(slot, false)
	InputService.screen_menu_open = false
	Chat.local_note("Editor de documentos desligado.")


func _exit_tree() -> void:
	Player.set_editor_shield("documentos", false)


func _build() -> void:
	var back := PanelContainer.new()
	back.add_theme_stylebox_override("panel", UiSkin.panel())
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.offset_left = 24
	back.offset_top = 24
	back.offset_right = -24
	back.offset_bottom = -24
	add_child(back)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	back.add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(280, 0)
	left.add_theme_constant_override("separation", 8)
	columns.add_child(left)
	left.add_child(UiSkin.label("DOCUMENTOS DA HISTÓRIA", 22, UiSkin.NEON, "Bold", 3))
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(index: int) -> void: _load(String(_list.get_item_metadata(index))))
	left.add_child(_list)
	var buttons := HBoxContainer.new()
	left.add_child(buttons)
	_button(buttons, "Novo", _new_document)
	_button(buttons, "Apagar", _delete)
	var help := UiSkin.label("No mapa, fixo: /editar, categoria\nHistoria, documento da historia\n(F escolhe documento e visual).\nColetável (vai pra mochila, lê\npelo inventário): \"Criar item para\nler\" e depois /editar, Missoes,\nitem de missao (F escolhe o item).\nMissão: objetivo \"ler\" com o id.", 13, UiSkin.DIM, "Regular", 2)
	left.add_child(help)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	columns.add_child(right)
	_id = _line(right, "Id (sem espaço, ex.: oficio_lab4)")
	_title = _line(right, "Título (aparece no alto da leitura)")
	_author = _line(right, "Autor / de onde é (linha menor embaixo do título)")
	right.add_child(UiSkin.label("Texto ({nome} vira o nome do herói que lê)", 14, UiSkin.TEXT, "Regular", 2))
	_text = TextEdit.new()
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(0, 260)
	right.add_child(_text)
	_teaches = _line(right, "Ler ensina (fatos, vírgula; vazio = o próprio id)")
	var hint := UiSkin.label("Fato = etiqueta livre: escreveu, existe. Use para liberar falas, portões e missões (\"Só aparece se o grupo já sabe\"). Começando com visitou_, gatilho_, abriu_, item_ ou conheceu_ não aparece na tela de Conhecimento.", 12, UiSkin.DIM, "Regular", 2)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(hint)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	right.add_child(bottom)
	_button(bottom, "Salvar", save)
	_button(bottom, "Criar item para ler", make_item)
	_button(bottom, "Fechar (%s)" % COMMAND, stop)
	_status = UiSkin.label("", 14, UiSkin.DIM, "Regular", 2)
	bottom.add_child(_status)


func _line(parent: Control, label: String) -> LineEdit:
	parent.add_child(UiSkin.label(label, 14, UiSkin.TEXT, "Regular", 2))
	var edit := LineEdit.new()
	parent.add_child(edit)
	return edit


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _book() -> LoreBook:
	return ResourceLoader.load(BOOK_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as LoreBook


func _refresh_list() -> void:
	_list.clear()
	var book := _book()
	if book == null:
		return
	for doc in book.documents:
		if doc and not doc.id.is_empty():
			var index := _list.add_item("%s  (%s)" % [doc.title if doc.title else doc.id, doc.id])
			_list.set_item_metadata(index, doc.id)


func _new_document() -> void:
	_editing = ""
	_id.text = "documento_%d" % (int(Time.get_unix_time_from_system()) % 100000)
	_title.text = ""
	_author.text = ""
	_text.text = ""
	_teaches.text = ""
	_status.text = "(novo, ainda não salvo)"


func _load(id: String) -> void:
	var book := _book()
	var doc := book.document(id) if book else null
	if doc == null:
		return
	_editing = id
	_id.text = doc.id
	_title.text = doc.title
	_author.text = doc.author
	_text.text = doc.text
	_teaches.text = ", ".join(doc.teaches)
	_status.text = id


## Grava no livro da história (novo ou por cima do que estava aberto). Retorna o id ("" se não deu).
func save() -> String:
	var id := PropBuilder.id_from(_id.text)
	if id.is_empty() or _title.text.strip_edges().is_empty():
		_status.text = "Falta id ou título."
		Sound.play("ui_error")
		return ""
	var book := _book()
	if book == null:
		book = LoreBook.new()
	var doc: LoreDocument = book.document(_editing) if not _editing.is_empty() else null
	if doc == null:
		doc = book.document(id)
	if doc == null:
		doc = LoreDocument.new()
		var docs := book.documents
		docs.append(doc)
		book.documents = docs
	elif _editing.is_empty():
		_status.text = "Já existe um documento com o id %s." % id
		Sound.play("ui_error")
		return ""
	doc.id = id
	doc.title = _title.text.strip_edges()
	doc.author = _author.text.strip_edges()
	doc.text = _text.text
	var facts: Array[String] = []
	for part in _teaches.text.split(",", false):
		if not part.strip_edges().is_empty():
			facts.append(part.strip_edges())
	doc.teaches = facts
	if ResourceSaver.save(book, BOOK_PATH) != OK:
		_status.text = "Não deu para salvar."
		Sound.play("ui_error")
		return ""
	book.take_over_path(BOOK_PATH)
	_editing = id
	Lore.reload_book()
	_refresh_list()
	_status.text = "Salvo: %s" % id
	Sound.play("ui_confirm")
	return id


## Cria (ou atualiza) o item que abre este documento: casa "missao" (fica na mochila, não se
## vende), visual de livro, mesmo id do documento. Retorna o id do item ("" se não deu).
func make_item() -> String:
	var id := save()
	if id.is_empty():
		return ""
	var path := "res://items/defs/%s.tres" % id
	var item: ItemDef = load(path) as ItemDef if ResourceLoader.exists(path) else ItemDef.new()
	item.id = id
	item.display_name = _title.text.strip_edges()
	item.slot = "missao"
	item.look = "book"
	item.color = Color(0.45, 0.16, 0.12)
	item.price = 0
	item.random_loot = false
	item.document = id
	if ResourceSaver.save(item, path) != OK:
		_status.text = "Não deu para criar o item."
		Sound.play("ui_error")
		return ""
	item.take_over_path(path)
	ItemDB.reload()
	_status.text = "Item criado: %s (ponha no mapa: /editar, Missoes, item de missao, F escolhe)" % id
	Sound.play("ui_confirm")
	return id


func _delete() -> void:
	if _editing.is_empty():
		return
	var book := _book()
	var doc := book.document(_editing) if book else null
	if doc == null:
		return
	var docs := book.documents
	docs.erase(doc)
	book.documents = docs
	ResourceSaver.save(book, BOOK_PATH)
	book.take_over_path(BOOK_PATH)
	Lore.reload_book()
	_status.text = "Apagado: %s" % _editing
	_refresh_list()
	_new_document()
