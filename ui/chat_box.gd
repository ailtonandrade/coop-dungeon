class_name ChatBox
extends PanelContainer
## Caixa do chat do mundo (canto inferior esquerdo, acima dos cartões), com cara de terminal:
## moldura neon, "CANAL // MUNDO", hora em cada linha. Fechada, mostra as últimas mensagens e
## elas somem sozinhas; aberta, mostra o histórico e o campo de digitar.
##
## Teclado: Enter abre, digita, Enter manda, Esc fecha.
## Controle: direcional para baixo abre as mensagens rápidas; cima/baixo escolhe, A manda, B fecha.

const VISIBLE_LINES := 8
const FADE_AFTER := 10.0
const WIDTH := 540.0

var _log: RichTextLabel
var _header: Label
var _input: LineEdit
var _quick: VBoxContainer
var _typing_slot := -1
var _quick_slot := -1
var _quick_cursor := 0
var _last_dir := 0


func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.04, 0.06, 0.72)
	style.border_color = Color(UiSkin.NEON, 0.55)
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.corner_detail = 1
	style.set_corner_radius_all(0)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	_header = UiSkin.label("◢ CANAL // MUNDO", 12, Color(UiSkin.NEON, 0.8), "Bold", 2)
	column.add_child(_header)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.fit_content = true
	_log.scroll_active = false
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_font_override("normal_font", UiSkin.font("SemiBold"))
	_log.add_theme_font_override("bold_font", UiSkin.font("Bold"))
	_log.add_theme_font_size_override("normal_font_size", 16)
	_log.add_theme_font_size_override("bold_font_size", 16)
	_log.add_theme_constant_override("outline_size", 4)
	_log.add_theme_color_override("font_outline_color", UiSkin.INK)
	column.add_child(_log)
	_input = LineEdit.new()
	_input.placeholder_text = "Mensagem para a sala (Enter manda, Esc fecha)"
	_input.max_length = Chat.MAX_LENGTH
	_input.visible = false
	_input.custom_minimum_size = Vector2(0, 40)
	_input.text_submitted.connect(_submit)
	column.add_child(_input)
	_quick = VBoxContainer.new()
	_quick.visible = false
	column.add_child(_quick)
	Chat.message_added.connect(func(_m: Dictionary) -> void: _render())
	_render()


func is_open() -> bool:
	return _typing_slot != -1 or _quick_slot != -1


## Enter do teclado: abre para o jogador do teclado digitar.
func open_typing(slot: int) -> void:
	if is_open():
		return
	_typing_slot = slot
	InputService.set_blocked(slot, true)
	_input.visible = true
	_input.text = ""
	_input.grab_focus.call_deferred()
	_render()


## Direcional para baixo no controle: lista de mensagens rápidas.
func open_quick(slot: int) -> void:
	if is_open():
		return
	_quick_slot = slot
	_quick_cursor = 0
	_last_dir = 1  # o próprio aperto que abriu não desce a lista
	InputService.set_blocked(slot, true)
	_quick.visible = true
	_render_quick()
	_render()


func close() -> void:
	for slot in [_typing_slot, _quick_slot]:
		if slot != -1:
			InputService.set_blocked(slot, false)
	_typing_slot = -1
	_quick_slot = -1
	_input.visible = false
	_input.release_focus()
	_quick.visible = false
	_render()


func _submit(text: String) -> void:
	var player := _player(_typing_slot)
	if player and not Chat.clean_text(text).is_empty():
		Chat.send(player, text)
		Sound.play("ui_confirm")
	close()


func _unhandled_key_input(event: InputEvent) -> void:
	if _typing_slot != -1 and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if _quick_slot != -1:
		var raw := InputService.raw_move(_quick_slot)
		var dir := 0 if absf(raw.y) < 0.5 else signi(roundi(raw.y))
		if dir != 0 and dir != _last_dir:
			_quick_cursor = wrapi(_quick_cursor + dir, 0, Chat.QUICK.size())
			Sound.play("ui_move")
			_render_quick()
		_last_dir = dir
		if InputService.raw_just_pressed(_quick_slot, InputService.Action.JUMP):
			var player := _player(_quick_slot)
			if player:
				Chat.send(player, Chat.QUICK[_quick_cursor])
				Sound.play("ui_confirm")
			close()
		elif InputService.raw_just_pressed(_quick_slot, InputService.Action.DODGE):
			close()
	# Mensagens somem sozinhas com o chat fechado.
	if not is_open() and Engine.get_process_frames() % 30 == 0:
		_render()


func _render() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var lines := PackedStringArray()
	var count := 0
	var shown: Array[Dictionary] = []
	for i in range(Chat.history.size() - 1, -1, -1):
		var message: Dictionary = Chat.history[i]
		if not is_open() and now - float(message.at) > FADE_AFTER:
			break
		shown.push_front(message)
		count += 1
		if count >= (VISIBLE_LINES * 2 if is_open() else VISIBLE_LINES):
			break
	for message in shown:
		var text := _escape(message.text)
		var time := "[color=#6a7a80]%s[/color] " % message.time
		if message.kind == "system":
			lines.append("%s[color=#%s]» %s[/color]" % [time, UiSkin.AMBER.to_html(false), text])
		else:
			var color: Color = GameConfig.PLAYER_COLORS[clampi(int(message.color), 0, 3)].lightened(0.25)
			lines.append("%s[b][color=#%s]%s:[/color][/b] %s" % [time, color.to_html(false), _escape(message.from), text])
	_log.text = "\n".join(lines)
	var empty := shown.is_empty()
	visible = is_open() or not empty
	_header.visible = is_open() or not empty


func _render_quick() -> void:
	for child in _quick.get_children():
		child.queue_free()
	_quick.add_child(UiSkin.label("Mensagem rápida (cima/baixo, A manda, B fecha):", 13, UiSkin.DIM, "Regular", 2))
	for i in Chat.QUICK.size():
		var selected := i == _quick_cursor
		var label := UiSkin.label(("▶ " if selected else "   ") + Chat.QUICK[i], 16,
				UiSkin.NEON if selected else UiSkin.TEXT, "Bold" if selected else "SemiBold", 3)
		_quick.add_child(label)


func _player(slot: int) -> Node:
	for player in get_tree().get_nodes_in_group("players"):
		if player.is_local() and player.slot == slot:
			return player
	return null


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
