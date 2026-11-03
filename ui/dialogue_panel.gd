class_name DialoguePanel
extends PanelContainer
## Conversa com um NPC, do jeito do Tibia: ele cumprimenta com a personalidade dele, e o
## jogador escolhe um assunto (botões) ou digita uma palavra (teclado). Respostas podem ensinar
## fatos da história, liberar portões/contêineres e dar itens (Lore, NpcDialogue).
## Se o NPC tem serviço (loja, cofre...), um botão abre a tela dele; fechar volta para cá.
##
## Controle: setas escolhem · A confirma · B tchau. Teclado: digite e Enter, ou clique.

signal close_requested
signal service_requested

var player: Player
var npc: WorldNpc

var _log: RichTextLabel
var _topics: HFlowContainer
var _typing: LineEdit
var _service_button: Button
var _lines: PackedStringArray = []
var _guard := 0.2


func open_for(p_player: Player, p_npc: WorldNpc) -> void:
	player = p_player
	npc = p_npc
	InputService.set_blocked(player.slot, true)
	_build()
	var hello := Lore.greeting(npc.npc_name)
	_npc_says(Txt.t(hello.text) if hello else Txt.t("Olá."))
	if hello:
		Lore.learn(hello.teaches)
	_refresh_topics()
	Lore.facts_changed.connect(_refresh_topics)


func _exit_tree() -> void:
	if is_instance_valid(player):
		InputService.set_blocked(player.slot, false)


func _build() -> void:
	var color := GameConfig.PLAYER_COLORS[player.index]
	add_theme_stylebox_override("panel", UiSkin.panel())
	custom_minimum_size = Vector2(500, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var title: String = "%s · %s" % [npc.npc_name, Txt.t(WorldNpc.SERVICE_NAMES[npc.service])] if npc.npc_name else Txt.t(WorldNpc.SERVICE_NAMES[npc.service])
	column.add_child(UiSkin.label("P%d · %s" % [player.index + 1, title], 20, color, "Bold", 3))
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(480, 190)
	_log.add_theme_font_size_override("normal_font_size", 16)
	_log.add_theme_font_size_override("bold_font_size", 16)
	column.add_child(_log)
	_topics = HFlowContainer.new()
	_topics.add_theme_constant_override("h_separation", 6)
	_topics.add_theme_constant_override("v_separation", 6)
	column.add_child(_topics)
	_typing = LineEdit.new()
	_typing.placeholder_text = "Digite uma palavra e Enter (ex.: trabalho, água, nome)"
	_typing.custom_minimum_size = Vector2(0, 40)
	_typing.max_length = 80
	_typing.text_submitted.connect(_on_typed)
	_typing.visible = InputService.device_of(player.slot) == InputService.KEYBOARD
	column.add_child(_typing)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var found := Lore.dialogue(npc.npc_name)
	_service_button = _button(row, found.service_button if found and found.service_button else _service_text(), func() -> void: service_requested.emit())
	_service_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(row, "Tchau", _bye)
	column.add_child(UiSkin.label("Setas escolhem · A confirma · B tchau" if not _typing.visible else "Clique num assunto ou digite · Esc tchau", 13, Color(1, 1, 1, 0.55), "Regular", 2))


func _service_text() -> String:
	return {WorldNpc.Service.MERCHANT: "Ver mercadorias", WorldNpc.Service.BLACKSMITH: "Upgrade na oficina",
		WorldNpc.Service.ENCHANTER: "Instalar mods", WorldNpc.Service.BANK: "Abrir o cofre"}.get(npc.service, "Serviço")


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _refresh_topics() -> void:
	for child in _topics.get_children():
		child.queue_free()
	var first: Button = null
	for topic in Lore.topics_for(npc.npc_name, player):
		var button := _button(_topics, Txt.t(topic.button_text()), choose.bind(topic))
		if first == null:
			first = button
	if InputService.device_of(player.slot) != InputService.KEYBOARD:
		(first if first else _service_button).grab_focus.call_deferred()
	else:
		_typing.grab_focus.call_deferred()


## O jogador escolheu um assunto (botão ou palavra digitada).
func choose(topic: DialogueTopic) -> void:
	_player_says(Txt.t(topic.button_text()))
	_npc_says(Txt.t(topic.text))
	Lore.heard(npc.npc_name, topic, player)
	Sound.play("ui_confirm")


## Palavra digitada: assunto que bate, "loja"/"tchau", ou "não entendi".
func say(text: String) -> void:
	var clean := Lore.normalize(text)
	if clean.is_empty():
		return
	var topic := Lore.answer(npc.npc_name, text, player)
	if topic:
		_player_says(text)
		_npc_says(Txt.t(topic.text))
		Lore.heard(npc.npc_name, topic, player)
	elif _has_word(clean, ["tchau", "bye", "falou", "adeus", "goodbye", "farewell"]):
		_bye()
	elif _has_word(clean, ["loja", "trade", "comprar", "vender", "cofre", "servico", "shop", "buy", "sell", "vault", "service"]):
		_player_says(text)
		service_requested.emit()
	else:
		_player_says(text)
		var found := Lore.dialogue(npc.npc_name)
		_npc_says(Txt.t(found.unknown) if found else "Hm?")


static func _has_word(text: String, words: Array) -> bool:
	for word in text.split(" ", false):
		if words.has(word):
			return true
	return false


func _on_typed(text: String) -> void:
	_typing.text = ""
	say(text)
	_typing.grab_focus.call_deferred()


func _bye() -> void:
	var found := Lore.dialogue(npc.npc_name)
	if found and found.farewell:
		npc.say(Txt.t(found.farewell))
	close_requested.emit()


func _npc_says(text: String) -> void:
	_lines.append(Txt.t("[color=#f2e9cf][b]%s:[/b] %s[/color]") % [npc.npc_name, text.replace("[", "[lb]")])
	_render()


func _player_says(text: String) -> void:
	_lines.append(Txt.t("[color=#8fd3ff]%s: %s[/color]") % [player.display_name, text.replace("[", "[lb]")])
	_render()


func _render() -> void:
	_log.text = "\n".join(_lines)


## Conversa recente (para os testes e para reabrir depois da loja).
func history() -> PackedStringArray:
	return _lines


func _physics_process(delta: float) -> void:
	if not visible or not is_instance_valid(player) or not InputService.is_active(player.slot):
		return
	# Aberta, a conversa segura os comandos do jogo (a loja, ao fechar, solta no fim do quadro).
	InputService.set_blocked(player.slot, true)
	_guard -= delta
	if _guard > 0.0:
		return
	if InputService.device_of(player.slot) != InputService.KEYBOARD and InputService.back_just_pressed(player.slot):
		_bye()


## Esc dá tchau mesmo com o campo de digitar em foco (por isso _typing, antes da interface).
func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE \
			and InputService.device_of(player.slot) == InputService.KEYBOARD:
		get_viewport().set_input_as_handled()
		_bye()
