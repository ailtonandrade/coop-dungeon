extends CanvasLayer
## Editor de missões DENTRO DO JOGO (só o dono do jogo, rodando pelo editor do Godot). Liga e
## desliga digitando COMMAND no chat (a mensagem não vai para a sala). Este arquivo fica de fora
## do jogo exportado (filtro de exportação), como o modo construtor: ninguém que baixar o jogo
## tem acesso. Sem class_name de propósito.
##
## Lista as missões de world/quests à esquerda; à direita, a ficha inteira (categoria, como
## começa, falas, objetivos, reações, recompensa). Os botões "perto" preenchem o campo com o que
## estiver perto do herói (NPC, área, gatilho, porta, contêiner, peça do mapa). Salvar grava o
## .tres em world/quests e já vale no jogo. Gatilhos e áreas se colocam pelo /construir
## (categoria Missoes); com o editor aberto, os marcadores aparecem.

const COMMAND := "/missoes"
const DIR := "res://world/quests/"
const PANEL_W := 760

var active := false
var slot := -1

var _list: ItemList
var _form: VBoxContainer
var _objectives_box: VBoxContainer
var _status: Label
var _fields := {}
var _objective_rows: Array[Dictionary] = []
var _editing_path := ""
var _item_ids: Array = []


func _ready() -> void:
	add_to_group("quest_editor")
	layer = 60
	visible = false
	_item_ids = ItemDB.ids()
	_item_ids.sort()
	_build()


## Só o dono do jogo: rodando pelo editor do Godot, mandando no mundo.
static func allowed() -> bool:
	return OS.has_feature("editor") and NetService.mode != NetService.Mode.CLIENT


static func is_command(text: String) -> bool:
	var clean := text.strip_edges().to_lower()
	return clean == COMMAND or clean == "/missões"


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
	QuestArea.show_markers = true
	InputService.set_blocked(slot, true)
	InputService.screen_menu_open = true
	_refresh_list()
	if _editing_path.is_empty():
		_new_quest()
	Chat.local_note(Txt.t("Editor de missões ligado (%s de novo para sair).") % COMMAND)


func stop() -> void:
	active = false
	visible = false
	QuestArea.show_markers = false
	if slot >= 0:
		InputService.set_blocked(slot, false)
	InputService.screen_menu_open = false
	Chat.local_note("Editor de missões desligado.")


## Montagem da tela

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
	left.add_child(UiSkin.label("EDITOR DE MISSÕES", 22, UiSkin.NEON, "Bold", 3))
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(index: int) -> void: _load(String(_list.get_item_metadata(index))))
	left.add_child(_list)
	var list_buttons := HBoxContainer.new()
	left.add_child(list_buttons)
	_small_button(list_buttons, "Nova", _new_quest)
	_small_button(list_buttons, "Duplicar", _duplicate)
	_small_button(list_buttons, "Apagar", _delete)
	left.add_child(UiSkin.label("Gatilhos e áreas: /construir,\ncategoria Missoes.", 13, UiSkin.DIM, "Regular", 2))

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	columns.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_theme_constant_override("separation", 6)
	scroll.add_child(_form)

	_section("Missão")
	_line("id", "Id (arquivo, sem espaço)")
	_line("title", "Título")
	_option("category", "Categoria", ["secundaria", "principal"])
	_line("summary", "Resumo (linha no questLog)")
	_section("Como começa")
	_option("start", "Começa por", ["npc", "area", "gatilho"])
	_line("start_target", "Id da área / gatilho", _pick_start)
	_line("giver", "NPC que dá / recebe", _pick_npc.bind("giver"))
	_check("return_to_giver", "Volta para entregar ao NPC")
	_item("start_item", "Item ao começar")
	_text("offer_text", "Fala ao oferecer / aviso ao começar")
	_text("progress_text", "Fala em andamento")
	_text("done_text", "Fala ao entregar")
	_line("requires", "Requer fatos (separe por vírgula)")
	_line("teaches", "Ensina fatos ao concluir")
	_section("Objetivos")
	_objectives_box = VBoxContainer.new()
	_objectives_box.add_theme_constant_override("separation", 10)
	_form.add_child(_objectives_box)
	_small_button(_form, "+ Objetivo", func() -> void: _add_objective(null))
	_section("Recompensa (cada um do grupo)")
	_spin("reward_gold", "Parafusos", 0, 100000)
	_spin("reward_xp", "Experiência", 0, 100000)
	_item("reward_item", "Item (para quem entrega)")
	_check("repeatable", "Repetível")

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	right.add_child(bottom)
	_small_button(bottom, "Salvar", save)
	_small_button(bottom, "Fechar (%s)" % COMMAND, stop)
	_status = UiSkin.label("", 14, UiSkin.DIM, "Regular", 2)
	bottom.add_child(_status)


func _section(text: String) -> void:
	_form.add_child(UiSkin.label(text.to_upper(), 16, UiSkin.AMBER, "Bold", 3))


func _row(label: String, field: Control, pick := Callable()) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label := UiSkin.label(label, 14, UiSkin.TEXT, "Regular", 2)
	name_label.custom_minimum_size = Vector2(250, 0)
	row.add_child(name_label)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	if pick.is_valid():
		_small_button(row, "perto", pick)
	return row


func _line(key: String, label: String, pick := Callable(), parent: Control = null, store := _fields) -> LineEdit:
	var edit := LineEdit.new()
	(parent if parent else _form).add_child(_row(label, edit, pick))
	store[key] = edit
	return edit


func _text(key: String, label: String, parent: Control = null, store := _fields) -> TextEdit:
	var edit := TextEdit.new()
	edit.custom_minimum_size = Vector2(0, 64)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	(parent if parent else _form).add_child(_row(label, edit))
	store[key] = edit
	return edit


func _option(key: String, label: String, values: Array, parent: Control = null, store := _fields) -> OptionButton:
	var option := OptionButton.new()
	for value: String in values:
		option.add_item(value)
		option.set_item_metadata(option.item_count - 1, value)
	(parent if parent else _form).add_child(_row(label, option))
	store[key] = option
	return option


func _item(key: String, label: String, parent: Control = null, store := _fields) -> OptionButton:
	return _option(key, label, [""] + _item_ids, parent, store)


func _check(key: String, label: String, parent: Control = null, store := _fields) -> CheckBox:
	var box := CheckBox.new()
	(parent if parent else _form).add_child(_row(label, box))
	store[key] = box
	return box


func _spin(key: String, label: String, low: int, high: int, parent: Control = null, store := _fields) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	(parent if parent else _form).add_child(_row(label, spin))
	store[key] = spin
	return spin


func _small_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button


## Objetivos

func _add_objective(objective: QuestObjective) -> void:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.04)
	style.set_content_margin_all(8)
	box.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	box.add_child(column)
	var row := {"box": box}
	_option("kind", "Tipo", QuestObjective.KINDS, column, row)
	_line("target", "Alvo (classe / id do gatilho / id da área)", _pick_objective_target.bind(row), column, row)
	_spin("amount", "Quantidade (matar)", 1, 999, column, row)
	_line("npc", "NPC (falar)", _pick_npc_into.bind(row, "npc"), column, row)
	_line("keywords", "Palavras em ordem (vírgula)", Callable(), column, row)
	_text("replies", "Respostas (uma por linha, na ordem)", column, row)
	_check("show_buttons", "Palavra vira botão (controle)", column, row)
	_line("label", "Nome no questLog (opcional)", Callable(), column, row)
	_item("gives_item", "Ao cumprir: dá item", column, row)
	_line("teaches", "Ao cumprir: ensina fatos", Callable(), column, row)
	_option("reaction", "Ao cumprir: reação", QuestObjective.REACTIONS, column, row)
	_line("reaction_target", "Objeto que reage (nome do nó)", _pick_object.bind(row), column, row)
	_small_button(column, "Tirar objetivo", func() -> void:
		_objective_rows.erase(row)
		box.queue_free())
	_objectives_box.add_child(box)
	_objective_rows.append(row)
	var o := objective if objective else QuestObjective.new()
	_select(row.kind, o.kind)
	row.target.text = o.target
	row.amount.value = o.amount
	row.npc.text = o.npc
	row.keywords.text = ", ".join(o.keywords)
	row.replies.text = "\n".join(o.replies)
	row.show_buttons.button_pressed = o.show_buttons
	row.label.text = o.label
	_select(row.gives_item, o.gives_item)
	row.teaches.text = ", ".join(o.teaches)
	_select(row.reaction, o.reaction)
	row.reaction_target.text = o.reaction_target


static func _select(option: OptionButton, value: String) -> void:
	for i in option.item_count:
		if String(option.get_item_metadata(i)) == value:
			option.select(i)
			return
	option.select(0)


static func _selected(option: OptionButton) -> String:
	return String(option.get_item_metadata(option.selected)) if option.selected >= 0 else ""


## Lista e ficha

func _refresh_list() -> void:
	_list.clear()
	var files := Array(DirAccess.get_files_at(DIR)).filter(func(f: String) -> bool: return f.ends_with(".tres"))
	files.sort()
	for file: String in files:
		var quest := ResourceLoader.load(DIR + file, "", ResourceLoader.CACHE_MODE_REPLACE) as QuestDef
		if quest == null:
			continue
		var tag := "★ " if quest.category == "principal" else ""
		_list.add_item("%s%s  (%s)" % [tag, quest.title if quest.title else quest.id, quest.start])
		_list.set_item_metadata(_list.item_count - 1, DIR + file)


func _new_quest() -> void:
	var quest := QuestDef.new()
	quest.id = "missao_%d" % (Time.get_unix_time_from_system() as int % 100000)
	quest.title = "Nova missão"
	_fill(quest, "")


func _duplicate() -> void:
	if _editing_path.is_empty():
		return
	var quest := build()
	quest.id += "_copia"
	quest.title += " (cópia)"
	_fill(quest, "")


func _delete() -> void:
	if _editing_path.is_empty() or not FileAccess.file_exists(_editing_path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_editing_path))
	_status.text = "Apagada: " + _editing_path.get_file()
	Quests.reload()
	_refresh_list()
	_new_quest()


func _load(path: String) -> void:
	var quest := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as QuestDef
	if quest:
		_fill(quest, path)


func _fill(quest: QuestDef, path: String) -> void:
	_editing_path = path
	_fields.id.text = quest.id
	_fields.title.text = quest.title
	_select(_fields.category, quest.category)
	_fields.summary.text = quest.summary
	_select(_fields.start, quest.start)
	_fields.start_target.text = quest.start_target
	_fields.giver.text = quest.giver
	_fields.return_to_giver.button_pressed = quest.return_to_giver
	_select(_fields.start_item, quest.start_item)
	_fields.offer_text.text = quest.offer_text
	_fields.progress_text.text = quest.progress_text
	_fields.done_text.text = quest.done_text
	_fields.requires.text = ", ".join(quest.requires)
	_fields.teaches.text = ", ".join(quest.teaches)
	_fields.reward_gold.value = quest.reward_gold
	_fields.reward_xp.value = quest.reward_xp
	_select(_fields.reward_item, quest.reward_item)
	_fields.repeatable.button_pressed = quest.repeatable
	for row in _objective_rows:
		row.box.queue_free()
	_objective_rows.clear()
	for objective in quest.objectives:
		_add_objective(objective)
	_status.text = path.get_file() if path else "(nova, ainda não salva)"


static func _list_of(text: String) -> Array[String]:
	var result: Array[String] = []
	for part in text.split(",", false):
		if not part.strip_edges().is_empty():
			result.append(part.strip_edges())
	return result


## Ficha a partir da tela.
func build() -> QuestDef:
	var quest := QuestDef.new()
	quest.id = PropBuilder.id_from(_fields.id.text)
	quest.title = _fields.title.text.strip_edges()
	quest.category = _selected(_fields.category)
	quest.summary = _fields.summary.text.strip_edges()
	quest.start = _selected(_fields.start)
	quest.start_target = _fields.start_target.text.strip_edges()
	quest.giver = _fields.giver.text.strip_edges()
	quest.return_to_giver = _fields.return_to_giver.button_pressed
	quest.start_item = _selected(_fields.start_item)
	quest.offer_text = _fields.offer_text.text
	quest.progress_text = _fields.progress_text.text
	quest.done_text = _fields.done_text.text
	quest.requires = _list_of(_fields.requires.text)
	quest.teaches = _list_of(_fields.teaches.text)
	quest.reward_gold = int(_fields.reward_gold.value)
	quest.reward_xp = int(_fields.reward_xp.value)
	quest.reward_item = _selected(_fields.reward_item)
	quest.repeatable = _fields.repeatable.button_pressed
	var objectives: Array[QuestObjective] = []
	for row in _objective_rows:
		var o := QuestObjective.new()
		o.kind = _selected(row.kind)
		o.target = row.target.text.strip_edges()
		o.amount = int(row.amount.value)
		o.npc = row.npc.text.strip_edges()
		o.keywords = PackedStringArray(_list_of(row.keywords.text))
		var replies := PackedStringArray()
		for line in String(row.replies.text).split("\n"):
			if not line.strip_edges().is_empty():
				replies.append(line.strip_edges())
		o.replies = replies
		o.show_buttons = row.show_buttons.button_pressed
		o.label = row.label.text.strip_edges()
		o.gives_item = _selected(row.gives_item)
		o.teaches = _list_of(row.teaches.text)
		o.reaction = _selected(row.reaction)
		o.reaction_target = row.reaction_target.text.strip_edges()
		objectives.append(o)
	quest.objectives = objectives
	return quest


## Grava em world/quests/<id>.tres e já vale no jogo. Retorna o caminho ("" se não deu).
func save() -> String:
	var quest := build()
	if quest.id.is_empty() or quest.title.is_empty():
		_status.text = "Falta id ou título."
		Sound.play("ui_error")
		return ""
	var path := DIR + quest.id + ".tres"
	if not _editing_path.is_empty() and _editing_path != path and FileAccess.file_exists(_editing_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_editing_path))
	if ResourceSaver.save(quest, path) != OK:
		_status.text = "Não deu para salvar."
		Sound.play("ui_error")
		return ""
	_editing_path = path
	_status.text = "Salvo: " + path.get_file()
	Sound.play("ui_confirm")
	Quests.reload()
	_refresh_list()
	return path


## "Perto": o que está em volta do herói

func _player() -> Node3D:
	for player: Node3D in get_tree().get_nodes_in_group("players"):
		if player.has_method("is_local") and player.is_local() and player.get("slot") == slot:
			return player
	var players := get_tree().get_nodes_in_group("players")
	return players[0] if not players.is_empty() else null


func _nearest_in(groups: Array, reach := 12.0) -> Node3D:
	var player := _player()
	if player == null:
		return null
	var best: Node3D = null
	var best_distance := reach
	for group: String in groups:
		for node: Node3D in get_tree().get_nodes_in_group(group):
			var distance := node.global_position.distance_to(player.global_position)
			if distance < best_distance:
				best = node
				best_distance = distance
	return best


func _pick_npc(key: String) -> void:
	var npc := _nearest_in(["npcs"])
	if npc:
		_fields[key].text = String(npc.get("npc_name"))


func _pick_npc_into(row: Dictionary, key: String) -> void:
	var npc := _nearest_in(["npcs"])
	if npc:
		row[key].text = String(npc.get("npc_name"))


func _pick_start() -> void:
	var group := "quest_areas" if _selected(_fields.start) == "area" else "quest_triggers"
	var node := _nearest_in([group])
	if node:
		_fields.start_target.text = String(node.call("id"))
	else:
		_status.text = "Nenhuma área/gatilho perto (ponha pelo /construir)."


func _pick_objective_target(row: Dictionary) -> void:
	var kind := _selected(row.kind)
	if kind == "matar":
		return
	var node := _nearest_in(["quest_areas"] if kind == "chegar" else ["quest_triggers"])
	if node:
		row.target.text = String(node.call("id"))


## Objeto do mapa mais perto para reagir: portões, contêineres, gatilhos e peças do mapa/construtor.
func _pick_object(row: Dictionary) -> void:
	var node := _nearest_in(["lore_gates", "containers", "quest_triggers"], 4.0)
	var god := get_tree().get_first_node_in_group("god_mode")
	var player := _player()
	if node == null and god and player:
		node = god.piece_near(player.global_position)
	if node:
		row.reaction_target.text = String(node.name)
	else:
		_status.text = "Nada perto para reagir."
