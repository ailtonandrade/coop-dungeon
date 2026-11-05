extends CanvasLayer
## Editor de missões DENTRO DO JOGO (só o dono do jogo, rodando pelo editor do Godot). Liga e
## desliga digitando COMMAND no chat (a mensagem não vai para a sala). Este arquivo fica de fora
## do jogo exportado (filtro de exportação), como o modo construtor: ninguém que baixar o jogo
## tem acesso. Sem class_name de propósito.
##
## Lista as missões de world/quests à esquerda; à direita, a ficha inteira (categoria, como
## começa, falas, objetivos, reações, recompensa). Os botões "perto" preenchem o campo com o que
## estiver perto do herói (NPC, área, gatilho, porta, contêiner, peça do mapa). Salvar grava o
## .tres em world/quests e já vale no jogo. Gatilhos e áreas se colocam pelo /editar
## (categoria Missoes); com o editor aberto, os marcadores aparecem.

const COMMAND := "/missoes"
const DIR := "res://world/quests/"
const PANEL_W := 760
const START_HELP := "npc: oferecida na conversa com o NPC.\narea / gatilho: id da área ou do gatilho de missão (ponha pelo /editar, categoria Missoes).\nitem: id do item; começa quando alguém do grupo tem o item (pegou do chão, de um Item de missão\ndo mapa, ganhou, ou já tinha, como o diário da mochila). \"perto\" lista os itens."
const TARGET_HELP := "matar: classe da criatura · falar: use o campo NPC · interagir: id do gatilho · chegar: id da área\nler: id do item de ler (diário, carta) ou do documento da história (vale o do mapa também)\nusar: id do item que se usa pelo inventário (ficha do item: Uso > usable)\npegar: id do item que precisa ter. \"perto\" abre a lista."
const AFTER_HELP := "Missões que precisam estar entregues antes desta aparecer (vírgula). Principal que vem depois\nvira o PRÓXIMO PASSO assim que a anterior termina: aparece no rastreador, o minimapa aponta e o NPC ganha \"!\".\nDuas que vêm depois da mesma: as duas aparecem e o jogador escolhe qual rastrear."
const FACTS_HELP := "Fato = uma etiqueta de \"o grupo já descobriu isso\" (ex.: diario_helena, lab4_portao).\nÉ o mesmo de ler um documento, ouvir um NPC ou abrir um portão. Separe por vírgula.\nUse para ligar missões entre si e com a história: uma missão ensina, a outra só aparece depois."

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
	# Editando missões ninguém te ataca.
	Player.set_editor_shield("missoes", true)
	InputService.set_blocked(slot, true)
	InputService.screen_menu_open = true
	_refresh_list()
	if _editing_path.is_empty():
		_new_quest()
	Chat.local_note(Txt.t("Editor de missões ligado (%s de novo para sair).") % COMMAND)


func _exit_tree() -> void:
	Player.set_editor_shield("missoes", false)


func stop() -> void:
	active = false
	visible = false
	QuestArea.show_markers = false
	Player.set_editor_shield("missoes", false)
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
	left.add_child(UiSkin.label("Gatilhos, áreas e itens de\nmissão: /editar, categoria\nMissoes (F escolhe o item).", 13, UiSkin.DIM, "Regular", 2))

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
	_option("start", "Começa por", ["npc", "area", "gatilho", "item"])
	_line("start_target", "Id da área / gatilho / item", _pick_start).tooltip_text = START_HELP
	_small_button(_fields.start_target.get_parent(), "lista", _choose_start_target)
	_npc_list_button(_line("giver", "NPC que dá / recebe", _pick_npc.bind("giver")))
	_check("return_to_giver", "Volta para entregar ao NPC")
	# A ficha se ajeita ao jeito de começar (só mostra o que faz sentido).
	_fields.start.item_selected.connect(func(_index: int) -> void: _refresh_start_form())
	_fields.giver.text_changed.connect(func(_text: String) -> void: _refresh_start_form())
	_fields.return_to_giver.toggled.connect(func(_on: bool) -> void: _refresh_start_form())
	_item("start_item", "Item ao começar")
	_text("offer_text", "Fala ao oferecer / aviso ao começar")
	_text("progress_text", "Fala em andamento")
	_text("done_text", "Fala ao entregar")
	_line("after", "Vem depois de (missões)").tooltip_text = AFTER_HELP
	_small_button(_fields.after.get_parent(), "lista", _choose_after)
	_line("requires", "Só aparece se o grupo já sabe (fatos)").tooltip_text = FACTS_HELP
	_line("teaches", "Ao concluir, o grupo passa a saber (fatos)").tooltip_text = FACTS_HELP
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
	_spin("repeat_cooldown", "Espera para repetir (minutos)", 0, 10080)

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
	_line("target", "Alvo (classe / gatilho / área / item / documento)", _pick_objective_target.bind(row), column, row).tooltip_text = TARGET_HELP
	_small_button(row.target.get_parent(), "lista", _choose_target.bind(row))
	_spin("amount", "Quantidade (matar)", 1, 999, column, row)
	_npc_list_button(_line("npc", "NPC (falar)", _pick_npc_into.bind(row, "npc"), column, row))
	_line("keywords", "Palavras em ordem (vírgula)", Callable(), column, row)
	_text("replies", "Respostas (uma por linha, na ordem)", column, row)
	_check("show_buttons", "Palavra vira botão (controle)", column, row)
	_line("label", "Nome no questLog (opcional)", Callable(), column, row)
	_item("gives_item", "Ao cumprir: dá item", column, row)
	_line("teaches", "Ao cumprir, o grupo passa a saber (fatos)", Callable(), column, row).tooltip_text = FACTS_HELP
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
	# O objetivo se ajeita ao tipo (matar pede criatura e quantidade; falar, NPC e palavras...).
	row.kind.item_selected.connect(func(_index: int) -> void: _refresh_objective(row))
	row.reaction.item_selected.connect(func(_index: int) -> void: _refresh_objective(row))
	_refresh_objective(row)


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
	_fields.after.text = ", ".join(quest.after)
	_fields.requires.text = ", ".join(quest.requires)
	_fields.teaches.text = ", ".join(quest.teaches)
	_fields.reward_gold.value = quest.reward_gold
	_fields.reward_xp.value = quest.reward_xp
	_select(_fields.reward_item, quest.reward_item)
	_fields.repeatable.button_pressed = quest.repeatable
	_fields.repeat_cooldown.value = quest.repeat_cooldown
	for row in _objective_rows:
		row.box.queue_free()
	_objective_rows.clear()
	for objective in quest.objectives:
		_add_objective(objective)
	_refresh_start_form()
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
	quest.after = _list_of(_fields.after.text)
	quest.requires = _list_of(_fields.requires.text)
	quest.teaches = _list_of(_fields.teaches.text)
	quest.reward_gold = int(_fields.reward_gold.value)
	quest.reward_xp = int(_fields.reward_xp.value)
	quest.reward_item = _selected(_fields.reward_item)
	quest.repeatable = _fields.repeatable.button_pressed
	quest.repeat_cooldown = int(_fields.repeat_cooldown.value)
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
	if _selected(_fields.start) == "item":
		_choose_id(_fields.start_target, _item_choices(false))
		return
	var group := "quest_areas" if _selected(_fields.start) == "area" else "quest_triggers"
	var node := _nearest_in([group])
	if node:
		_fields.start_target.text = String(node.call("id"))
	else:
		_status.text = "Nenhuma área/gatilho perto (ponha pelo /editar)."


func _pick_objective_target(row: Dictionary) -> void:
	var kind := _selected(row.kind)
	if kind == "matar":
		_choose_id(row.target, QuestObjective.CREATURE_NAMES.keys())
		return
	if kind in QuestObjective.INVENTORY_KINDS:
		_choose_id(row.target, _item_choices(kind == "ler"))
		return
	var node := _nearest_in(["quest_areas"] if kind == "chegar" else ["quest_triggers"])
	if node:
		row.target.text = String(node.call("id"))


## Botão "lista" ao lado de um campo de NPC: escolhe clicando, NPCs separados por região.
func _npc_list_button(edit: LineEdit) -> void:
	var row := edit.get_parent()
	if row:
		_small_button(row, "lista", _choose_npc.bind(edit))


## Todos os NPCs do mapa (também os de blocos ainda não carregados), por região:
## {nome da região: [nomes...]}, regiões e nomes em ordem alfabética.
func npcs_by_region() -> Dictionary:
	var places: Dictionary = {}
	var map: Dictionary = Quests._places_map()
	for npc_name: String in map.get("npcs", {}):
		places[npc_name] = map.npcs[npc_name]
	for npc: Node3D in get_tree().get_nodes_in_group("npcs"):
		var npc_name := String(npc.get("npc_name"))
		if not npc_name.is_empty() and not places.has(npc_name):
			places[npc_name] = npc.global_position
	return _by_region(places)


func _choose_npc(edit: LineEdit) -> void:
	_choose_grouped(edit, npcs_by_region(), "Nenhum NPC no mapa.")


## "lista" do "Vem depois de": escolhe uma missão e junta à lista (principais primeiro).
func _choose_after() -> void:
	var menu := PopupMenu.new()
	var own := PropBuilder.id_from(_fields.id.text)
	var quests: Array = Quests.defs().values()
	quests.sort_custom(func(a: QuestDef, b: QuestDef) -> bool:
		return (a.category == "principal") != (b.category == "principal") and a.category == "principal" \
				or ((a.category == "principal") == (b.category == "principal") and a.id < b.id))
	for quest: QuestDef in quests:
		if quest.id == own:
			continue
		menu.add_item("%s%s  (%s)" % ["★ " if quest.category == "principal" else "", quest.title, quest.id])
		menu.set_item_metadata(menu.item_count - 1, quest.id)
	if menu.item_count == 0:
		menu.free()
		_status.text = "Nenhuma outra missão ainda."
		return
	menu.index_pressed.connect(func(index: int) -> void:
		var list := _list_of(_fields.after.text)
		var picked := String(menu.get_item_metadata(index))
		if not list.has(picked):
			list.append(picked)
		_fields.after.text = ", ".join(list))
	menu.popup_hide.connect(menu.queue_free, CONNECT_DEFERRED)
	add_child(menu)
	menu.popup(Rect2i(Vector2i(get_viewport().get_mouse_position()), Vector2i(320, 0)))


## Ficha que muda com o tipo

## Mostra/esconde a linha do campo e troca o nome dela.
static func _show_row(field: Control, shown: bool, label := "") -> void:
	var row := field.get_parent() as Control
	if row == null:
		return
	row.visible = shown
	if not label.is_empty() and row.get_child_count() > 0 and row.get_child(0) is Label:
		(row.get_child(0) as Label).text = label


func _refresh_start_form() -> void:
	var start := _selected(_fields.start)
	var giver := String(_fields.giver.text).strip_edges()
	var labels := {"area": "Área que começa a missão", "gatilho": "Gatilho que começa a missão",
		"item": "Item que começa (quando alguém do grupo tem)"}
	_show_row(_fields.start_target, start != "npc", labels.get(start, ""))
	_show_row(_fields.giver, true, "NPC que oferece e recebe" if start == "npc" else "NPC que recebe (vazio = conclui sozinha)")
	var returns := start == "npc" or not giver.is_empty()
	_show_row(_fields.return_to_giver, returns)
	_show_row(_fields.offer_text, true, "Fala ao oferecer" if start == "npc" else "Aviso ao começar (no chat)")
	var talks: bool = not giver.is_empty() and _fields.return_to_giver.button_pressed
	_show_row(_fields.progress_text, talks)
	_show_row(_fields.done_text, talks)


const TARGET_LABELS := {
	"matar": "Criatura", "interagir": "Gatilho (alavanca, terminal, caixa, placa)", "chegar": "Área",
	"ler": "Item ou documento para ler", "usar": "Item para usar", "pegar": "Item que precisa ter",
}


func _refresh_objective(row: Dictionary) -> void:
	var kind := _selected(row.kind)
	_show_row(row.target, kind != "falar", TARGET_LABELS.get(kind, "Alvo"))
	_show_row(row.amount, kind == "matar", "Quantas")
	for key: String in ["npc", "keywords", "replies", "show_buttons"]:
		_show_row(row[key], kind == "falar")
	_show_row(row.npc, kind == "falar", "Falar com (NPC)")
	_show_row(row.reaction_target, _selected(row.reaction) != "nenhuma")


## Listas

## "lista" do jeito de começar: áreas ou gatilhos (por região) ou itens.
func _choose_start_target() -> void:
	match _selected(_fields.start):
		"area":
			_choose_grouped(_fields.start_target, quest_pieces_by_region("area"), "Nenhuma área de missão no mapa (ponha pelo /editar).")
		"gatilho":
			_choose_grouped(_fields.start_target, quest_pieces_by_region("gatilho"), "Nenhum gatilho de missão no mapa (ponha pelo /editar).")
		"item":
			_choose_id(_fields.start_target, _item_choices(false))


## "lista" do alvo do objetivo, conforme o tipo.
func _choose_target(row: Dictionary) -> void:
	var kind := _selected(row.kind)
	match kind:
		"matar":
			_choose_id(row.target, QuestObjective.CREATURE_NAMES.keys())
		"interagir":
			_choose_grouped(row.target, quest_pieces_by_region("gatilho"), "Nenhum gatilho de missão no mapa (ponha pelo /editar).")
		"chegar":
			_choose_grouped(row.target, quest_pieces_by_region("area"), "Nenhuma área de missão no mapa (ponha pelo /editar).")
		"ler", "usar", "pegar":
			_choose_id(row.target, _item_choices(kind == "ler"))


## Áreas ("area") ou gatilhos ("gatilho") de missão do mapa inteiro (também de blocos ainda
## não carregados e os postos agora pelo /editar), por região: {região: [ids...]}.
func quest_pieces_by_region(kind: String) -> Dictionary:
	var places := {}
	var pieces: Dictionary = Quests._places_map().get("quest_pieces", {})
	for piece_id: String in pieces:
		if pieces[piece_id][0] == kind:
			places[piece_id] = pieces[piece_id][1]
	for node: Node3D in get_tree().get_nodes_in_group("quest_areas" if kind == "area" else "quest_triggers"):
		places[String(node.call("id"))] = node.global_position
	return _by_region(places)


## {nome: posição} -> {região: [nomes em ordem]}, regiões em ordem.
func _by_region(places: Dictionary) -> Dictionary:
	var streamer := get_tree().get_first_node_in_group("world_streamer")
	var groups := {}
	for place_name: String in places:
		var region: Resource = streamer.region_at(places[place_name]) if streamer else null
		var region_name: String = String(region.get("display_name")) if region and not String(region.get("display_name")).is_empty() else "Sem região"
		if not groups.has(region_name):
			groups[region_name] = []
		groups[region_name].append(place_name)
	var names := groups.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	var result := {}
	for region_name: String in names:
		var list: Array = groups[region_name]
		list.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
		result[region_name] = list
	return result


## Menu com uma entrada por região e, dentro, os nomes: clicar preenche o campo.
func _choose_grouped(edit: LineEdit, groups: Dictionary, empty_text: String) -> void:
	if groups.is_empty():
		_status.text = empty_text
		return
	var menu := PopupMenu.new()
	for region_name: String in groups:
		var sub := PopupMenu.new()
		for entry: String in groups[region_name]:
			sub.add_item(entry)
			sub.set_item_metadata(sub.item_count - 1, entry)
		sub.index_pressed.connect(func(index: int) -> void:
			edit.text = String(sub.get_item_metadata(index))
			edit.text_changed.emit(edit.text)
			menu.hide())
		menu.add_submenu_node_item("%s  (%d)" % [region_name, (groups[region_name] as Array).size()], sub)
	menu.popup_hide.connect(menu.queue_free, CONNECT_DEFERRED)
	add_child(menu)
	menu.popup(Rect2i(Vector2i(get_viewport().get_mouse_position()), Vector2i(260, 0)))


## Lista para escolher um id (itens, documentos, criaturas): o botão "perto" dos tipos que não
## estão no mapa abre esta lista; o primeiro Item de missão perto do herói vem no topo.
func _choose_id(edit: LineEdit, ids: Array) -> void:
	var menu := PopupMenu.new()
	var near := _nearest_in(["quest_items"], 6.0)
	var choices: Array = []
	if near and not String(near.call("item_id")).is_empty():
		choices.append(String(near.call("item_id")))
	for id: Variant in ids:
		if not choices.has(id):
			choices.append(id)
	for id: String in choices:
		var shown := id
		if ItemDB.has(id):
			shown = "%s  (%s)" % [id, ItemDB.display_name({"id": id})]
		elif Lore.document(id):
			shown = "%s  (documento: %s)" % [id, Lore.document(id).title]
		menu.add_item(shown)
		menu.set_item_metadata(menu.item_count - 1, id)
	menu.index_pressed.connect(func(index: int) -> void:
		edit.text = String(menu.get_item_metadata(index))
		menu.queue_free())
	menu.popup_hide.connect(menu.queue_free, CONNECT_DEFERRED)
	add_child(menu)
	menu.popup_centered(Vector2i(420, 360))


## Itens de ler/usar primeiro, depois os outros; `documents` põe os documentos da história.
func _item_choices(documents: bool) -> Array:
	var usable: Array = []
	var others: Array = []
	for id: String in _item_ids:
		if ItemDB.is_usable({"id": id}):
			usable.append(id)
		else:
			others.append(id)
	var result := usable
	if documents:
		result += Array(Lore.book().document_ids())
	return result + others


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
