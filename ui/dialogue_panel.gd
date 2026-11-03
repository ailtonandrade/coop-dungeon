class_name DialoguePanel
extends PanelContainer
## Conversa com um NPC, do jeito do Tibia: ele cumprimenta com a personalidade dele, e o
## jogador escolhe um assunto (botões) ou digita uma palavra (teclado). Respostas podem ensinar
## fatos da história, liberar portões/contêineres e dar itens (Lore, NpcDialogue).
## Se o NPC tem serviço (loja, cofre...), um botão abre a tela dele; fechar volta para cá.
##
## Controle: direcional/analógico escolhe (◀ ▶ em ordem, ▲ ▼ a linha de cima/baixo) · A confirma ·
## B tchau · analógico direito rola a conversa. Cada controle mexe só na conversa do seu jogador
## (não usa o foco global do Godot). Teclado: digite e Enter, ou clique.

signal close_requested
signal service_requested

var player: Player
var npc: WorldNpc

var _log: RichTextLabel
var _topics: HFlowContainer
var _typing: LineEdit
var _service_button: Button
var _bye_button: Button
var _lines: PackedStringArray = []
var _guard := 0.2
var _cursor := 0
var _last_dir := Vector2i.ZERO
var _repeat := 0.0

const REPEAT_DELAY := 0.3
const REPEAT_RATE := 0.15


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
	_bye_button = _button(row, "Tchau", _bye)
	column.add_child(UiSkin.label("Direcional escolhe · A confirma · B tchau · analógico direito rola a conversa" if not _typing.visible else "Clique num assunto ou digite · Esc tchau", 13, Color(1, 1, 1, 0.55), "Regular", 2))


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
		_cursor = 0
		_show_cursor.call_deferred()
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
	if InputService.device_of(player.slot) == InputService.KEYBOARD:
		return
	_navigate(delta)
	# A e B esperam um instante: o aperto que abriu a conversa não confirma nem fecha.
	_guard -= delta
	if _guard > 0.0:
		return
	if InputService.back_just_pressed(player.slot):
		_bye()
		return
	if InputService.raw_just_pressed(player.slot, InputService.Action.JUMP):
		var buttons := _nav_buttons()
		if _cursor < buttons.size():
			buttons[_cursor].pressed.emit()
	# Analógico direito rola a conversa.
	var device := InputService.device_of(player.slot)
	var scroll := Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
	if absf(scroll) > 0.3:
		_log.get_v_scroll_bar().value += scroll * 500.0 * delta


## Botões que o controle percorre, na ordem da tela: assuntos, serviço, tchau.
func _nav_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for child in _topics.get_children():
		if child is Button and not child.is_queued_for_deletion():
			result.append(child)
	for button in [_service_button, _bye_button]:
		if button and button.visible:
			result.append(button)
	return result


func _navigate(delta: float) -> void:
	var raw := InputService.raw_move(player.slot)
	var dir := Vector2i(0 if absf(raw.x) < 0.5 else signi(roundi(raw.x)), 0 if absf(raw.y) < 0.5 else signi(roundi(raw.y)))
	if dir.y != 0:
		dir.x = 0
	if dir == Vector2i.ZERO:
		_last_dir = dir
		return
	if dir != _last_dir:
		_repeat = REPEAT_DELAY
	else:
		_repeat -= delta
		if _repeat > 0.0:
			return
		_repeat = REPEAT_RATE
	_last_dir = dir
	_move_cursor(dir)


## ◀ ▶: anterior/próximo em ordem. ▲ ▼: o botão mais perto na linha de cima/de baixo.
func _move_cursor(dir: Vector2i) -> void:
	var buttons := _nav_buttons()
	if buttons.is_empty():
		return
	_cursor = clampi(_cursor, 0, buttons.size() - 1)
	if dir.x != 0:
		_cursor = wrapi(_cursor + dir.x, 0, buttons.size())
	else:
		var here := buttons[_cursor].get_global_rect()
		var best := -1
		var best_score := INF
		var target_row := INF
		for i in buttons.size():
			var rect := buttons[i].get_global_rect()
			var dy := (rect.get_center().y - here.get_center().y) * dir.y
			if dy < 4.0:
				continue
			# Primeiro a linha mais próxima; dentro dela, o mais perto na horizontal.
			if dy < target_row - 4.0:
				target_row = dy
				best_score = INF
			if absf(dy - target_row) <= 4.0:
				var dx := absf(rect.get_center().x - here.get_center().x)
				if dx < best_score:
					best_score = dx
					best = i
		if best == -1:
			return
		_cursor = best
	Sound.play("ui_move")
	_show_cursor()


## Destaca o botão escolhido sem usar o foco do Godot (que é um só para a tela toda: com o foco,
## o direcional de qualquer controle mexeria nesta conversa).
func _show_cursor() -> void:
	var buttons := _nav_buttons()
	if buttons.is_empty():
		return
	_cursor = clampi(_cursor, 0, buttons.size() - 1)
	for i in buttons.size():
		var button := buttons[i]
		button.focus_mode = Control.FOCUS_NONE
		if i == _cursor:
			button.add_theme_stylebox_override("normal", button.get_theme_stylebox("focus") if button.has_theme_stylebox("focus") else button.get_theme_stylebox("hover"))
			button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
		else:
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_color_override("font_color")


## Botão que o controle deste jogador marcou agora (para os testes), ou null.
func selected() -> Button:
	var buttons := _nav_buttons()
	return buttons[_cursor] if _cursor < buttons.size() else null


## Esc dá tchau mesmo com o campo de digitar em foco (por isso _typing, antes da interface).
func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE \
			and InputService.device_of(player.slot) == InputService.KEYBOARD:
		get_viewport().set_input_as_handled()
		_bye()
