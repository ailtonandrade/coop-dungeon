extends CanvasLayer
## HUD: um cartão por vaga da sala (P1 a P4) com vida e poção, a onda no topo,
## o minimapa no canto superior direito, a situação da conexão e o menu de pausa
## (Esc, Start ou Back).
## No online o jogo não pausa de verdade: o menu só cobre a tela.

var _names: Array[Label] = []
var _bars: Array[ProgressBar] = []
var _wave_label: Label
var _net_label: Label
var _pause: PanelContainer
var _pause_info: Label
var _resume_button: Button
var _minimap_button: Button


func _ready() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -100
	row.offset_bottom = -20
	add_child(row)
	for index in GameConfig.MAX_PLAYERS:
		var color := GameConfig.PLAYER_COLORS[index]
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.alignment = BoxContainer.ALIGNMENT_END
		row.add_child(card)

		var label := _make_label(26, color)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(label)
		_names.append(label)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(260, 18)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = color
		var background := StyleBoxFlat.new()
		background.bg_color = Color(0, 0, 0, 0.6)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", background)
		card.add_child(bar)
		_bars.append(bar)

	_wave_label = _make_label(34, Color.WHITE)
	_wave_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_wave_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.offset_top = 52
	add_child(_wave_label)

	var help := _make_label(18, Color(1, 1, 1, 0.8))
	help.text = "Controle: A pula · X ataca · RT flecha · B rola · Y poção     Teclado: Espaço pula · J ataca · K flecha · Shift rola · E poção     Esc/Start: menu"
	help.position = Vector2(24, 16)
	add_child(help)

	var minimap := Minimap.new()
	minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -24 - Minimap.SIZE
	minimap.offset_right = -24
	minimap.offset_top = 52
	minimap.offset_bottom = 52 + Minimap.SIZE
	add_child(minimap)

	_net_label = _make_label(18, Color(0.8, 0.9, 1.0))
	_net_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_net_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_net_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_net_label.offset_top = 52 + Minimap.SIZE + 8
	_net_label.offset_right = -24
	add_child(_net_label)

	_build_pause_menu()


func _process(_delta: float) -> void:
	var players := {}
	for player: Player in get_tree().get_nodes_in_group("players"):
		players[player.index] = player
	var free_local := InputService.active_slots().size() < GameConfig.MAX_PLAYERS
	for index in _names.size():
		var player: Player = players.get(index)
		_bars[index].visible = player != null
		if player == null:
			_names[index].text = "P%d: aperte Start (teclado: Enter)" % (index + 1) if free_local else ""
			continue
		_bars[index].value = player.health.hp / player.health.max_hp * 100.0
		var text := "P%d %s" % [index + 1, player.display_name]
		if not player.is_targetable():
			text += "  CAÍDO: chegue perto pra reviver"
		elif player.potion_cooldown > 0.0:
			text += "  poção %ds" % ceili(player.potion_cooldown)
		else:
			text += "  poção pronta"
		_names[index].text = text

	var spawner := get_tree().get_first_node_in_group("wave_spawner")
	if spawner and spawner.wave > 0:
		_wave_label.text = "Onda %d  ·  inimigos: %d" % [spawner.wave, spawner.alive_count()]
	else:
		_wave_label.text = ""
	_net_label.text = _connection_text()


func _physics_process(_delta: float) -> void:
	for slot in InputService.active_slots():
		if InputService.just_pressed(slot, InputService.Action.PAUSE):
			_toggle_pause()
			return


func _unhandled_input(event: InputEvent) -> void:
	# Esc e Back abrem o menu mesmo sem ninguém no jogo ainda.
	var escape: bool = event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE and not InputService.active_slots().size()
	var back: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK
	if escape or back:
		_toggle_pause()


func _connection_text() -> String:
	var world_name: String = NetService.world.get("name", "")
	match NetService.mode:
		NetService.Mode.HOST:
			var addresses := NetService.local_addresses()
			var ip := addresses[0] if not addresses.is_empty() else "?"
			return "%s · online (host) · IP %s:%d · %d/%d" % [world_name, ip, NetService.port,
					NetService.player_count(), GameConfig.MAX_PLAYERS]
		NetService.Mode.CLIENT:
			return "%s · online · %d/%d" % [world_name, NetService.player_count(), GameConfig.MAX_PLAYERS]
	return "%s · offline" % world_name if world_name else ""


func _build_pause_menu() -> void:
	_pause = PanelContainer.new()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_pause.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pause.grow_vertical = Control.GROW_DIRECTION_BOTH
	_pause.custom_minimum_size = Vector2(560, 0)
	_pause.visible = false
	add_child(_pause)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_pause.add_child(box)
	var title := _make_label(36, Color.WHITE)
	title.text = "Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_pause_info = _make_label(20, Color(0.85, 0.9, 1.0))
	_pause_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_pause_info)
	_resume_button = _make_button(box, "Continuar", _toggle_pause)
	_minimap_button = _make_button(box, "", Settings.toggle_minimap_mode)
	Settings.changed.connect(_update_minimap_button)
	_update_minimap_button()
	_make_button(box, "Sair para o menu", func() -> void: NetService.leave_session())


func _update_minimap_button() -> void:
	_minimap_button.text = "Minimapa: %s" % ("rotativo (gira com o herói)" if Settings.minimap_mode == "rotating" else "fixo (norte pra cima)")


func _toggle_pause() -> void:
	_pause.visible = not _pause.visible
	if not _pause.visible:
		return
	var lines := PackedStringArray([_connection_text()])
	if NetService.mode == NetService.Mode.HOST:
		lines.append("Amigos na mesma rede veem este mundo em \"Buscar mundos\".")
		lines.append("Pela internet: passe o IP e libere a porta %d (UDP) no roteador." % NetService.port)
	_pause_info.text = "\n".join(lines)
	_resume_button.grab_focus()


func _make_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 52)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _make_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 8)
	return label
