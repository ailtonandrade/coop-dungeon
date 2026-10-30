class_name VoicePanel
extends HBoxContainer
## Voz: à esquerda as opções deste PC (microfone, modo, sensibilidade com medidor, rádio velho,
## volume, proximidade); à direita, na pausa do online, as pessoas da sala com volume e mudo
## só para mim, e "mudo para todos" para o host.

const MODES := [["off", "Desligada"], ["auto", "Abre quando eu falo"], ["push", "Apertar para falar (V / direcional ↑)"]]

## Mostra a lista de pessoas da sala (na pausa).
var show_people := false

var _devices: OptionButton
var _modes: OptionButton
var _meter: ProgressBar
var _threshold: HSlider
var _people: VBoxContainer
var _people_box: VBoxContainer
var _people_ids: Array[int] = [-1]  # -1: ainda não montou a lista
var _rows := {}  # peer -> {dot: ColorRect, label: Label}
var _muted_label: Label
var _refresh := 0.0


func _ready() -> void:
	add_theme_constant_override("separation", 28)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(430, 0)
	add_child(left)
	left.add_child(UiSkin.label("VOZ", 22, UiSkin.NEON, "Bold"))

	_devices = OptionButton.new()
	_devices.custom_minimum_size = Vector2(0, 44)
	_devices.add_theme_font_size_override("font_size", 16)
	var devices: PackedStringArray = Voice.devices()
	if devices.is_empty():
		devices = PackedStringArray(["Default"])
	for device in devices:
		_devices.add_item("Microfone: %s" % ("padrão do sistema" if device == "Default" else device))
		_devices.set_item_metadata(_devices.item_count - 1, device)
		if device == Settings.mic_device:
			_devices.select(_devices.item_count - 1)
	_devices.item_selected.connect(func(index: int) -> void: Settings.set_voice("mic_device", _devices.get_item_metadata(index)))
	left.add_child(_devices)

	_modes = OptionButton.new()
	_modes.custom_minimum_size = Vector2(0, 44)
	_modes.add_theme_font_size_override("font_size", 16)
	for entry: Array in MODES:
		_modes.add_item("Voz: %s" % entry[1])
		if entry[0] == Settings.voice_mode:
			_modes.select(_modes.item_count - 1)
	_modes.item_selected.connect(func(index: int) -> void: Settings.set_voice("voice_mode", MODES[index][0]))
	left.add_child(_modes)

	# Medidor do microfone com a barra da sensibilidade: a voz abre quando passa da marca.
	var meter_row := HBoxContainer.new()
	left.add_child(meter_row)
	var meter_label := UiSkin.label("Microfone", 15, UiSkin.TEXT, "SemiBold", 3)
	meter_label.custom_minimum_size = Vector2(150, 0)
	meter_row.add_child(meter_label)
	_meter = ProgressBar.new()
	_meter.max_value = 1.0
	_meter.show_percentage = false
	_meter.custom_minimum_size = Vector2(0, 14)
	_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiSkin.NEON
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.5)
	_meter.add_theme_stylebox_override("fill", fill)
	_meter.add_theme_stylebox_override("background", back)
	meter_row.add_child(_meter)

	_threshold = _slider(left, "Sensibilidade", 0.005, 0.25, 0.005, Settings.mic_threshold,
			func(v: float) -> void: Settings.set_voice("mic_threshold", v))
	_check(left, "Minha voz com rádio velho", Settings.radio_voice, func(on: bool) -> void: Settings.set_voice("radio_voice", on))
	_slider(left, "Volume das vozes", 0.0, 1.0, 0.05, Settings.voice_volume, func(v: float) -> void: Settings.set_voice("voice_volume", v))
	_check(left, "Voz mais baixa com distância entre os heróis", Settings.voice_proximity,
			func(on: bool) -> void: Settings.set_voice("voice_proximity", on))
	var note := UiSkin.label("No sofá, todos deste PC falam pelo mesmo microfone (o Godot capta um por vez).", 13, UiSkin.DIM, "Regular", 3)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(note)

	if show_people:
		_people_box = VBoxContainer.new()
		_people_box.add_theme_constant_override("separation", 8)
		_people_box.custom_minimum_size = Vector2(430, 0)
		add_child(_people_box)
		_people_box.add_child(UiSkin.label("PESSOAS NA SALA", 22, UiSkin.NEON, "Bold"))
		_muted_label = UiSkin.label("O host te mutou: ninguém ouve sua voz.", 15, UiSkin.DANGER, "Bold", 3)
		_people_box.add_child(_muted_label)
		_people = VBoxContainer.new()
		_people.add_theme_constant_override("separation", 8)
		_people_box.add_child(_people)
	visibility_changed.connect(_on_visibility)
	_on_visibility()


func _on_visibility() -> void:
	# Medidor só funciona com o microfone ligado: liga enquanto esta tela está aberta.
	Voice.monitor = is_visible_in_tree()


func _exit_tree() -> void:
	Voice.monitor = false


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_meter.value = Voice.mic_level
	var talking_color := UiSkin.SAFE if Voice.talking else UiSkin.NEON
	(_meter.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = talking_color
	if not show_people:
		return
	_muted_label.visible = Voice.am_muted()
	_refresh -= delta
	var peers := Voice.remote_peers()
	if peers != _people_ids or _refresh <= 0.0:
		_refresh = 1.0
		if peers != _people_ids:
			_people_ids = peers
			_rebuild_people()
	for peer: int in _rows:
		_rows[peer].dot.color = UiSkin.SAFE if Voice.is_speaking(peer) else Color(0.25, 0.25, 0.28)


func _rebuild_people() -> void:
	for child in _people.get_children():
		child.queue_free()
	_rows.clear()
	if _people_ids.is_empty():
		var text := "Ninguém de outro PC na sala." if NetService.is_online() else "A voz funciona no online (quem está no sofá já se ouve na sala)."
		var empty := UiSkin.label(text, 15, UiSkin.DIM, "Regular", 3)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_people.add_child(empty)
		return
	for peer in _people_ids:
		var key := Voice.peer_key(peer)
		var box := VBoxContainer.new()
		_people.add_child(box)
		var top := HBoxContainer.new()
		box.add_child(top)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(dot)
		var name_label := UiSkin.label(" " + Voice.peer_label(peer), 16, UiSkin.TEXT, "Bold", 3)
		top.add_child(name_label)
		_rows[peer] = {"dot": dot, "label": name_label}
		var controls := HBoxContainer.new()
		box.add_child(controls)
		var volume := HSlider.new()
		volume.min_value = 0.0
		volume.max_value = 1.5
		volume.step = 0.05
		volume.value = Settings.voice_peer_volume.get(key, 1.0)
		volume.custom_minimum_size = Vector2(150, 0)
		volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		volume.focus_mode = Control.FOCUS_ALL
		controls.add_child(volume)
		var mute_me := CheckBox.new()
		mute_me.text = "Mudo p/ mim"
		mute_me.button_pressed = Settings.voice_peer_muted.get(key, false)
		controls.add_child(mute_me)
		volume.value_changed.connect(func(v: float) -> void: Settings.set_peer_voice(key, v, mute_me.button_pressed))
		mute_me.toggled.connect(func(on: bool) -> void: Settings.set_peer_voice(key, volume.value, on))
		if NetService.is_host():
			var mute_all := CheckBox.new()
			mute_all.text = "Mudo p/ todos"
			mute_all.button_pressed = Voice.muted_by_host.has(peer)
			mute_all.toggled.connect(func(on: bool) -> void: Voice.set_muted_for_all(peer, on))
			controls.add_child(mute_all)
		elif Voice.muted_by_host.has(peer):
			controls.add_child(UiSkin.label("(mutado pelo host)", 14, UiSkin.DANGER, "SemiBold", 3))


func first_focus() -> Control:
	return _modes


func _slider(parent: Control, text: String, low: float, high: float, step: float, value: float, apply: Callable) -> HSlider:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := UiSkin.label(text, 15, UiSkin.TEXT, "SemiBold", 3)
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	slider.value_changed.connect(apply)
	row.add_child(slider)
	return slider


func _check(parent: Control, text: String, value: bool, apply: Callable) -> void:
	var box := CheckButton.new()
	box.text = text
	box.button_pressed = value
	box.add_theme_font_size_override("font_size", 15)
	box.toggled.connect(apply)
	parent.add_child(box)
