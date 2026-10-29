extends CanvasLayer
## HUD mínima: um cartão por slot mostrando quem está jogando ou como entrar.

var _labels: Array[Label] = []


func _ready() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -72
	row.offset_bottom = -24
	add_child(row)
	for slot in GameConfig.MAX_PLAYERS:
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 28)
		label.add_theme_color_override("font_color", GameConfig.PLAYER_COLORS[slot])
		label.add_theme_constant_override("outline_size", 8)
		row.add_child(label)
		_labels.append(label)

	var help := Label.new()
	help.text = "Controle: analógico + A rola   |   Teclado: WASD + Espaço rola"
	help.position = Vector2(24, 16)
	help.add_theme_constant_override("outline_size", 6)
	add_child(help)

	InputService.player_joined.connect(func(_slot: int, _device: int) -> void: _refresh())
	InputService.player_left.connect(func(_slot: int) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	for slot in _labels.size():
		if InputService.is_active(slot):
			_labels[slot].text = "P%d" % (slot + 1)
		else:
			_labels[slot].text = "P%d: aperte Start (teclado: Enter)" % (slot + 1)
