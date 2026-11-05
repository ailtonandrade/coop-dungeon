class_name SettingsPanel
extends VBoxContainer
## Configurações desta máquina, iguais no menu principal e na aba da pausa: tamanho da
## interface, volumes, câmera, sensibilidade e minimapa. Tudo salva na hora (Settings).

var _choices := {}  # chave da opção -> OptionButton


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	add_child(UiSkin.label("CONFIGURAÇÕES", 22, UiSkin.NEON, "Bold"))
	# O nome de cada idioma fica sempre na língua dele (quem não entende a atual acha a sua).
	var languages := []
	for code: String in Txt.LANGUAGES:
		languages.append([Txt.LANGUAGES[code], code])
	_choice("Idioma", "language", languages)
	_slider("Tamanho dos menus e da interface", Settings.UI_SCALE_MIN, Settings.UI_SCALE_MAX, 0.05, Settings.ui_scale,
			Settings.set_ui_scale, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_slider("Tamanho dos textos no mundo (nomes, loot, avisos)", Settings.WORLD_TEXT_MIN, Settings.WORLD_TEXT_MAX, 0.05, Settings.world_text_scale,
			Settings.set_world_text_scale, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_slider("Volume geral", 0.0, 1.0, 0.05, Settings.master_volume, func(v: float) -> void: Settings.set_volume("master", v), _percent)
	_slider("Música", 0.0, 1.0, 0.05, Settings.music_volume, func(v: float) -> void: Settings.set_volume("music", v), _percent)
	_slider("Ambiente (vento, máquinas)", 0.0, 1.0, 0.05, Settings.ambience_volume, func(v: float) -> void: Settings.set_volume("ambience", v), _percent)
	_slider("Efeitos", 0.0, 1.0, 0.05, Settings.sfx_volume, func(v: float) -> void: Settings.set_volume("sfx", v), _percent)
	_choice("Câmera", "camera_mode", [["De cima (isométrica)", "iso"], ["Atrás do herói (só 1 jogador na tela)", "behind"]])
	_slider("Sensibilidade da câmera atrás", 0.3, 3.0, 0.1, Settings.look_sensitivity, Settings.set_look_sensitivity,
			func(v: float) -> String: return "%.1fx" % v)
	_choice("Minimapa", "minimap_mode", [["Gira com a câmera", "camera"], ["Fixo (norte pra cima)", "fixed"]])
	var qualities := []
	for level: String in Graphics.LEVELS:
		qualities.append([Graphics.LABELS[level], level])
	_choice("Gráficos", "graphics_quality", qualities)
	var modes := []
	for mode: String in Settings.WINDOW_MODES:
		modes.append([Settings.WINDOW_MODE_NAMES[mode], mode])
	_choice("Tela", "window_mode", modes)
	var resolutions := []
	for resolution: String in Settings.available_resolutions():
		resolutions.append([resolution.replace("x", " × "), resolution])
	_choice("Resolução (janela)", "window_resolution", resolutions)
	_choice("VSync", "vsync", [["Ligado", true], ["Desligado", false]])
	Settings.changed.connect(_update_texts)
	_update_texts()


## Linha "nome ........ [lista]": a lista abre mostrando as opções (clique, ou A no controle).
func _choice(text: String, key: String, options: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := UiSkin.label(text, 15, UiSkin.TEXT, "Regular", 2)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(250, 40)
	picker.add_theme_font_size_override("font_size", 16)
	picker.fit_to_longest_item = false
	for option: Array in options:
		picker.add_item(Txt.t(String(option[0])))
		picker.set_item_metadata(picker.item_count - 1, option[1])
	picker.item_selected.connect(func(index: int) -> void:
		Sound.play("ui_confirm")
		Settings.set_choice(key, picker.get_item_metadata(index)))
	row.add_child(picker)
	add_child(row)
	_choices[key] = picker


## Marca em cada lista a opção em uso agora.
func _update_texts() -> void:
	var current := {
		"language": Settings.current_language(),
		"camera_mode": Settings.camera_mode,
		"minimap_mode": "fixed" if Settings.minimap_mode == "fixed" else "camera",
		"graphics_quality": Settings.graphics_quality,
		"window_mode": Settings.window_mode if Settings.window_mode in Settings.WINDOW_MODES else "janela",
		"window_resolution": Settings.current_resolution(),
		"vsync": Settings.vsync,
	}
	for key: String in _choices:
		var picker: OptionButton = _choices[key]
		for i in picker.item_count:
			if picker.get_item_metadata(i) == current[key]:
				picker.select(i)
	(_choices.window_resolution as OptionButton).disabled = current.window_mode != "janela"
	(_choices.window_resolution as OptionButton).tooltip_text = Txt.t("Na janela, escolhe o tamanho. Nas telas cheias é a do monitor; para aliviar o PC, baixe os Gráficos.")


func first_focus() -> Control:
	return _choices.get("language", find_children("*", "HSlider", true, false)[0])


## Linha com nome, barra e valor (controle: esquerda/direita mudam a barra em foco).
func _slider(text: String, low: float, high: float, step: float, value: float, apply: Callable, show: Callable) -> void:
	var row := HBoxContainer.new()
	add_child(row)
	var label := UiSkin.label(text, 16, UiSkin.TEXT, "SemiBold", 3)
	label.custom_minimum_size = Vector2(250, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(220, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	row.add_child(slider)
	var readout := UiSkin.label(show.call(value), 15, UiSkin.AMBER, "Bold", 3)
	readout.custom_minimum_size = Vector2(56, 0)
	row.add_child(readout)
	# O tamanho da interface só aplica ao soltar (senão a barra foge do mouse enquanto arrasta).
	var is_scale := apply == Settings.set_ui_scale
	slider.value_changed.connect(func(v: float) -> void:
		readout.text = show.call(v)
		Sound.play("ui_move")
		if not is_scale:
			apply.call(v))
	if is_scale:
		slider.drag_ended.connect(func(_changed: bool) -> void: apply.call(slider.value))
		slider.focus_exited.connect(func() -> void: apply.call(slider.value))
		# Controle/teclado: aplica um instante depois da última mexida.
		var timer := Timer.new()
		timer.one_shot = true
		timer.wait_time = 0.6
		timer.timeout.connect(func() -> void: apply.call(slider.value))
		slider.add_child(timer)
		slider.value_changed.connect(func(_v: float) -> void:
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				timer.start())


func _button(action: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 46)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	add_child(button)
	return button


func _percent(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)
