class_name SettingsPanel
extends VBoxContainer
## Configurações desta máquina, iguais no menu principal e na aba da pausa: tamanho da
## interface, volumes, câmera, sensibilidade e minimapa. Tudo salva na hora (Settings).

var _camera_button: Button
var _minimap_button: Button


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	add_child(UiSkin.label("CONFIGURAÇÕES", 22, UiSkin.NEON, "Bold"))
	_slider("Tamanho dos textos e menus", Settings.UI_SCALE_MIN, Settings.UI_SCALE_MAX, 0.05, Settings.ui_scale,
			Settings.set_ui_scale, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_slider("Volume geral", 0.0, 1.0, 0.05, Settings.master_volume, func(v: float) -> void: Settings.set_volume("master", v), _percent)
	_slider("Música e ambiente", 0.0, 1.0, 0.05, Settings.music_volume, func(v: float) -> void: Settings.set_volume("music", v), _percent)
	_slider("Efeitos", 0.0, 1.0, 0.05, Settings.sfx_volume, func(v: float) -> void: Settings.set_volume("sfx", v), _percent)
	_camera_button = _button(Settings.toggle_camera_mode)
	_slider("Sensibilidade da câmera atrás", 0.3, 3.0, 0.1, Settings.look_sensitivity, Settings.set_look_sensitivity,
			func(v: float) -> String: return "%.1fx" % v)
	_minimap_button = _button(Settings.toggle_minimap_mode)
	Settings.changed.connect(_update_texts)
	_update_texts()


func _update_texts() -> void:
	_camera_button.text = "Câmera: atrás do herói (só 1 jogador na tela)" if Settings.camera_mode == "behind" else "Câmera: de cima (isométrica)"
	_minimap_button.text = "Minimapa: %s" % ("rotativo (gira com o herói)" if Settings.minimap_mode == "rotating" else "fixo (norte pra cima)")


func first_focus() -> Control:
	return find_children("*", "HSlider", true, false)[0]


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
