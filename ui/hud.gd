extends CanvasLayer
## HUD: um cartão por slot (vida, poção, caído) e o contador de ondas no topo.

var _names: Array[Label] = []
var _bars: Array[ProgressBar] = []
var _wave_label: Label


func _ready() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -100
	row.offset_bottom = -20
	add_child(row)
	for slot in GameConfig.MAX_PLAYERS:
		var color := GameConfig.PLAYER_COLORS[slot]
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
	help.text = "Controle: X ataca · RT flecha · A rola · Y poção     Teclado: J ataca · K flecha · Espaço rola · E poção"
	help.position = Vector2(24, 16)
	add_child(help)


func _process(_delta: float) -> void:
	var players := {}
	for player: Player in get_tree().get_nodes_in_group("players"):
		players[player.slot] = player
	for slot in _names.size():
		var player: Player = players.get(slot)
		_bars[slot].visible = player != null
		if player == null:
			_names[slot].text = "P%d: aperte Start (teclado: Enter)" % (slot + 1)
			continue
		_bars[slot].value = player.health.hp / player.health.max_hp * 100.0
		var text := "P%d" % (slot + 1)
		if not player.is_targetable():
			text += "  CAÍDO: chegue perto pra reviver"
		elif player.potion_cooldown > 0.0:
			text += "  poção %ds" % ceili(player.potion_cooldown)
		else:
			text += "  poção pronta"
		_names[slot].text = text

	var spawner := get_tree().get_first_node_in_group("wave_spawner")
	if spawner and spawner.wave > 0:
		_wave_label.text = "Onda %d  ·  inimigos: %d" % [spawner.wave, spawner.alive_count()]
	else:
		_wave_label.text = ""


func _make_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 8)
	return label
