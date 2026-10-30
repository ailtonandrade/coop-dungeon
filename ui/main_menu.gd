extends Control
## Menu principal: criar mundo, jogar um mundo salvo, buscar mundos de outros jogadores
## (rede local) ou entrar por IP. Navega com mouse, teclado ou controle.

const VISIBILITIES := [
	["open", "Aberto: aparece pra quem buscar na rede local"],
	["private", "Privado: só entra quem tiver o seu IP"],
	["offline", "Offline: só o pessoal do sofá"],
]

var _screens := {}
var _status: Label
var _name_edit: LineEdit
var _seed_edit: LineEdit
var _visibility: OptionButton
var _password_edit: LineEdit
var _join_password_edit: LineEdit
var _worlds_box: VBoxContainer
var _found_box: VBoxContainer
var _ip_edit: LineEdit
var _discovery: LanDiscovery
var _pending_delete := ""
# Tela Personagens
var _char_list: VBoxContainer
var _char_name: LineEdit
var _char_model: OptionButton
var _char_colors: HBoxContainer
var _char_preview: CharacterPreview
var _char_info: Label
var _char_delete: Button
var _editing := {}
# Personagem ativo em destaque (lado direito do menu principal)
var _active_card: PanelContainer
var _active_preview: CharacterPreview
var _active_name: Label
var _active_info: Label


func _ready() -> void:
	InputService.reset()
	Sound.play_ambience("")
	Sound.play_music("menu")
	add_child(MenuBackdrop.new())
	_build_overlay()
	_build_active_card()

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.offset_left = 90
	column.offset_right = 90 + 620
	column.add_theme_constant_override("separation", 14)
	add_child(column)

	column.add_child(_build_logo())
	_status = UiSkin.label(NetService.last_message, 19, UiSkin.AMBER, "SemiBold", 4)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	column.add_child(_status)
	NetService.status_changed.connect(func(text: String) -> void: _status.text = text)

	_screens.main = _build_main()
	_screens.create = _build_create()
	_screens.worlds = _build_worlds()
	_screens.browse = _build_browse()
	_screens.settings = _build_settings()
	_screens.characters = _build_characters()
	for screen: Control in _screens.values():
		column.add_child(screen)
	_show("main")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _screens.main.visible:
		_show("main")
		get_viewport().set_input_as_handled()


func _show(screen_name: String) -> void:
	for key: String in _screens:
		_screens[key].visible = key == screen_name
	if _discovery and screen_name != "browse":
		_discovery.queue_free()
		_discovery = null
	# O personagem ativo fica em destaque só na tela principal (as outras usam o espaço).
	if _active_card:
		_active_card.visible = screen_name == "main"
		_refresh_active_card()
	match screen_name:
		"worlds":
			_refresh_worlds()
		"browse":
			_start_browse()
		"characters":
			_refresh_characters()
	_focus_first(_screens[screen_name])


## Personagem ativo: é com ele que você entra no mundo (troca na tela Personagens).
func _build_active_card() -> void:
	_active_card = PanelContainer.new()
	_active_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_active_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_active_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_active_card.offset_right = -110
	_active_card.offset_left = -110 - 360
	add_child(_active_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_active_card.add_child(box)
	var header := UiSkin.label("JOGANDO COMO", 14, UiSkin.NEON, "Bold", 3)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(header)
	_active_preview = CharacterPreview.new()
	_active_preview.custom_minimum_size = Vector2(320, 360)
	box.add_child(_active_preview)
	_active_name = UiSkin.title("", 30, UiSkin.AMBER)
	_active_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_active_name)
	_active_info = UiSkin.label("", 15, UiSkin.TEXT, "SemiBold", 3)
	_active_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_active_info)
	var change := _button(box, "Trocar personagem", func() -> void: _show("characters"))
	change.alignment = HORIZONTAL_ALIGNMENT_CENTER


## Mostra o ativo (sem nenhum ainda, cria um para começar).
func _refresh_active_card() -> void:
	var active := SaveService.load_character(Settings.active_character)
	if active.is_empty():
		var characters := SaveService.list_characters()
		if characters.is_empty():
			active = Characters.create()
			SaveService.save_character(active)
		else:
			active = characters[0]
		Settings.set_active_character(active.id)
	_active_preview.show_character(active)
	_active_name.text = active.name.to_upper()
	_active_info.text = "Nível %d · %s · chip %s" % [Characters.level_of(active), Characters.MODELS[active.model], Characters.CHIP_COLOR_NAMES[active.chip_color]]


## Visual

## Escurece a esquerda (onde fica o menu) e as bordas, com faíscas de solda subindo.
func _build_overlay() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02, 0.02, 0.03, 0.92))
	gradient.set_color(1, Color(0.02, 0.02, 0.03, 0.0))
	gradient.add_point(0.45, Color(0.02, 0.02, 0.03, 0.75))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_to = Vector2(1, 0)
	var side := TextureRect.new()
	side.texture = texture
	side.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	side.offset_right = 1100
	side.stretch_mode = TextureRect.STRETCH_SCALE
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(side)

	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://ui/skin/menu_overlay.gdshader")
	vignette.material = material
	add_child(vignette)

	var sparks := CPUParticles2D.new()
	sparks.amount = 70
	sparks.lifetime = 6.0
	sparks.preprocess = 6.0
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(1200, 10)
	sparks.direction = Vector2(0.15, -1)
	sparks.spread = 20.0
	sparks.gravity = Vector2(0, -8)
	sparks.initial_velocity_min = 25.0
	sparks.initial_velocity_max = 70.0
	sparks.scale_amount_min = 1.5
	sparks.scale_amount_max = 3.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.75, 0.3, 0.0))
	ramp.add_point(0.15, Color(1.0, 0.6, 0.2, 0.9))
	ramp.set_color(1, Color(1.0, 0.25, 0.4, 0.0))
	sparks.color_ramp = ramp
	add_child(sparks)
	var place := func() -> void:
		var view := get_viewport_rect().size
		sparks.position = Vector2(view.x / 2.0, view.y + 10)
		sparks.emission_rect_extents = Vector2(view.x / 2.0, 10)
	place.call()
	get_viewport().size_changed.connect(place)

	var version := UiSkin.label("v%s · protótipo" % NetService.GAME_VERSION, 14, UiSkin.DIM, "Regular", 3)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.offset_left = 24
	version.offset_bottom = -16
	add_child(version)

	var hints := UiSkin.label("A / Enter  confirmar      B / Esc  voltar", 15, UiSkin.TEXT, "SemiBold", 3)
	hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hints.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hints.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hints.offset_right = -24
	hints.offset_bottom = -16
	add_child(hints)


## Logo: título em estêncil com o "glitch" do chip (cópias ciano e magenta tremendo).
func _build_logo() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(620, 104)
	box.add_child(stack)
	var layers: Array[Label] = []
	for color: Color in [UiSkin.NEON, UiSkin.NEON_PINK, UiSkin.AMBER]:
		var layer := UiSkin.title(GameConfig.GAME_TITLE.to_upper(), 88, color)
		layer.add_theme_constant_override("outline_size", 0 if color != UiSkin.AMBER else 12)
		layer.add_theme_constant_override("shadow_offset_y", 0)
		if color != UiSkin.AMBER:
			layer.modulate.a = 0.75
		stack.add_child(layer)
		layers.append(layer)
	var glitch := func() -> void:
		var strong := randf() < 0.18
		var amount := 6.0 if strong else 1.5
		layers[0].position = Vector2(-amount, randf_range(-1, 1))
		layers[1].position = Vector2(amount, randf_range(-1, 1))
		layers[2].position = Vector2(randf_range(-2, 2), 0) if strong else Vector2.ZERO
	var timer := Timer.new()
	timer.wait_time = 0.09
	timer.autostart = true
	timer.timeout.connect(glitch)
	stack.add_child(timer)

	var line := ColorRect.new()
	line.color = UiSkin.BRASS
	line.custom_minimum_size = Vector2(0, 2)
	box.add_child(line)
	box.add_child(Control.new())
	return box


## Telas

func _build_main() -> Control:
	var box := _vbox()
	_button(box, "Novo mundo", func() -> void: _show("create"))
	_button(box, "Meus mundos", func() -> void: _show("worlds"))
	if NetService.online_supported():
		_button(box, "Buscar mundos (rede local / IP)", func() -> void: _show("browse"))
	_button(box, "Personagens", func() -> void: _show("characters"))
	_button(box, "Configurações", func() -> void: _show("settings"))
	if not OS.has_feature("web"):
		_button(box, "Sair", func() -> void: get_tree().quit())
	return box


## Personagens desta máquina (até 5): criar, mudar nome e visual, apagar.
func _build_characters() -> Control:
	var box := _vbox()
	box.add_child(_label("Personagens", 34))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var left := _vbox()
	left.custom_minimum_size = Vector2(300, 0)
	row.add_child(left)
	_char_list = _vbox()
	left.add_child(_char_list)
	var editor := _vbox()
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(editor)
	_char_preview = CharacterPreview.new()
	_char_preview.custom_minimum_size = Vector2(0, 230)
	editor.add_child(_char_preview)
	_char_name = LineEdit.new()
	_char_name.placeholder_text = "Nome do personagem"
	_char_name.max_length = Characters.NAME_MAX
	_style_input(_char_name)
	_char_name.text_changed.connect(func(text: String) -> void: _edit_character("name", text))
	editor.add_child(_char_name)
	_char_model = OptionButton.new()
	for model: String in Characters.MODELS:
		_char_model.add_item(Characters.MODELS[model])
	_char_model.custom_minimum_size = Vector2(0, 48)
	_char_model.item_selected.connect(func(index: int) -> void: _edit_character("model", Characters.MODELS.keys()[index]))
	editor.add_child(_char_model)
	_char_colors = HBoxContainer.new()
	_char_colors.add_theme_constant_override("separation", 6)
	editor.add_child(_char_colors)
	for i in Characters.CHIP_COLORS.size():
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(44, 40)
		swatch.tooltip_text = "Chip %s" % Characters.CHIP_COLOR_NAMES[i]
		var style := StyleBoxFlat.new()
		style.bg_color = Characters.CHIP_COLORS[i]
		style.set_corner_radius_all(4)
		swatch.add_theme_stylebox_override("normal", style)
		swatch.add_theme_stylebox_override("hover", style)
		swatch.add_theme_stylebox_override("pressed", style)
		swatch.pressed.connect(func() -> void: _edit_character("chip_color", i))
		_char_colors.add_child(swatch)
	_char_info = _label("", 16, UiSkin.DIM)
	editor.add_child(_char_info)
	var actions := HBoxContainer.new()
	editor.add_child(actions)
	_button(actions, "Sortear nome", func() -> void:
		_char_name.text = Characters.random_name()
		_edit_character("name", _char_name.text))
	_char_delete = _button(actions, "Apagar", _delete_character)
	_button(box, "Voltar", func() -> void: _show("main"))
	return box


func _refresh_characters(select_id := "") -> void:
	for child in _char_list.get_children():
		child.queue_free()
	var characters := SaveService.list_characters()
	if select_id.is_empty() and not _editing.is_empty():
		select_id = _editing.id
	_editing = {}
	if select_id.is_empty():
		select_id = Settings.active_character
	for character in characters:
		var active: bool = character.id == Settings.active_character
		var text := "%s%s  ·  nível %d" % ["▶ " if active else "", character.name, Characters.level_of(character)]
		_button(_char_list, text, _select_character.bind(character.id))
		if character.id == select_id or (select_id.is_empty() and _editing.is_empty()):
			_editing = character
	if characters.size() < Characters.MAX:
		_button(_char_list, "+ Novo personagem (%d/%d)" % [characters.size(), Characters.MAX], func() -> void:
			var created := Characters.create()
			SaveService.save_character(created)
			Settings.set_active_character(created.id)
			_refresh_characters(created.id))
	_show_editing()


## Escolher na lista já deixa o personagem como ativo (é com ele que você entra no mundo).
func _select_character(character_id: String) -> void:
	_pending_delete = ""
	Settings.set_active_character(character_id)
	_refresh_characters(character_id)


func _show_editing() -> void:
	var has := not _editing.is_empty()
	for control: Control in [_char_name, _char_model, _char_colors, _char_delete]:
		control.visible = has
	_char_preview.show_character(_editing)
	if not has:
		_char_info.text = "Nenhum personagem ainda: crie um."
		return
	_char_name.text = _editing.name
	_char_model.select(Characters.MODELS.keys().find(_editing.model))
	_char_info.text = "%s · chip %s · nível %d · ▶ é com ele que você entra no mundo" % [Characters.MODELS[_editing.model], Characters.CHIP_COLOR_NAMES[_editing.chip_color], Characters.level_of(_editing)]
	_char_delete.text = "Apagar"


func _edit_character(field: String, value: Variant) -> void:
	if _editing.is_empty():
		return
	_editing[field] = value
	SaveService.save_character(_editing)
	_editing = SaveService.load_character(_editing.id)
	_char_preview.show_character(_editing)
	_char_info.text = "%s · chip %s · nível %d" % [Characters.MODELS[_editing.model], Characters.CHIP_COLOR_NAMES[_editing.chip_color], Characters.level_of(_editing)]


## Apagar pede confirmação (o personagem leva junto inventário e nível).
func _delete_character() -> void:
	if _editing.is_empty():
		return
	if _pending_delete != _editing.id:
		_pending_delete = _editing.id
		_char_delete.text = "Confirmar? (perde itens e nível)"
		return
	_pending_delete = ""
	SaveService.delete_character(_editing.id)
	if Settings.active_character == _editing.id:
		var rest := SaveService.list_characters()
		Settings.set_active_character(rest[0].id if not rest.is_empty() else "")
	_editing = {}
	_refresh_characters()


func _build_settings() -> Control:
	var box := _vbox()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 36)
	box.add_child(row)
	var settings := SettingsPanel.new()
	settings.custom_minimum_size = Vector2(560, 0)
	row.add_child(settings)
	row.add_child(VoicePanel.new())
	_button(box, "Voltar", func() -> void: _show("main"))
	return box


func _build_create() -> Control:
	var box := _vbox()
	box.add_child(_label("Novo mundo", 34))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Nome do mundo"
	_name_edit.text = "Mundo de %s" % NetService.player_name
	_style_input(_name_edit)
	box.add_child(_name_edit)
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "Semente (vazio = aleatória)"
	_style_input(_seed_edit)
	box.add_child(_seed_edit)
	_visibility = OptionButton.new()
	for entry: Array in VISIBILITIES:
		_visibility.add_item(entry[1])
	# Sem online (navegador): só o pessoal do sofá.
	if not NetService.online_supported():
		_visibility.select(VISIBILITIES.size() - 1)
		_visibility.disabled = true
	_visibility.custom_minimum_size = Vector2(0, 52)
	_visibility.add_theme_font_size_override("font_size", 19)
	box.add_child(_visibility)
	_password_edit = LineEdit.new()
	_password_edit.placeholder_text = "Senha para entrar (vazio = sem senha)"
	_password_edit.secret = true
	_style_input(_password_edit)
	box.add_child(_password_edit)
	# Offline é só o sofá: ninguém entra pela rede, então senha não faz sentido.
	_visibility.item_selected.connect(func(index: int) -> void:
		_password_edit.editable = VISIBILITIES[index][0] != "offline"
		if not _password_edit.editable:
			_password_edit.text = "")
	_button(box, "Criar e jogar", _create_world)
	_button(box, "Voltar", func() -> void: _show("main"))
	return box


func _build_worlds() -> Control:
	var box := _vbox()
	box.add_child(_label("Meus mundos", 34))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	box.add_child(scroll)
	_worlds_box = _vbox()
	_worlds_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_worlds_box)
	_button(box, "Voltar", func() -> void: _show("main"))
	return box


func _build_browse() -> Control:
	var box := _vbox()
	box.add_child(_label("Mundos na rede local", 34))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 260)
	box.add_child(scroll)
	_found_box = _vbox()
	_found_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_found_box)
	box.add_child(_label("Ou entre pelo código do mundo (ou IP) que o host passar:", 20))
	var row := HBoxContainer.new()
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "ex.: K7Q2-9XM  ou  192.168.0.10"
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_input(_ip_edit)
	row.add_child(_ip_edit)
	_button(row, "Entrar", _join_typed)
	_ip_edit.text_submitted.connect(func(_t: String) -> void: _join_typed())
	box.add_child(row)
	_join_password_edit = LineEdit.new()
	_join_password_edit.placeholder_text = "Senha (se o mundo tiver)"
	_join_password_edit.secret = true
	_style_input(_join_password_edit)
	_join_password_edit.text_submitted.connect(func(_t: String) -> void: _join_typed())
	box.add_child(_join_password_edit)
	_button(box, "Voltar", func() -> void: _show("main"))
	return box


## Ações

func _create_world() -> void:
	var world_name := _name_edit.text.strip_edges()
	if world_name.is_empty():
		world_name = "Mundo de %s" % NetService.player_name
	var seed_text := _seed_edit.text.strip_edges()
	var world_seed := randi()
	if seed_text.is_valid_int():
		world_seed = seed_text.to_int()
	elif not seed_text.is_empty():
		world_seed = seed_text.hash()
	var world := SaveService.new_world(world_name, world_seed, VISIBILITIES[_visibility.selected][0])
	if not _password_edit.text.strip_edges().is_empty() and world.visibility != "offline":
		world["password"] = NetService.password_hash(_password_edit.text)
	SaveService.save_world(world)
	_play(world)


func _play(world: Dictionary) -> void:
	if NetService.play_world(world) != OK:
		_status.text = NetService.last_message


## Código do mundo, "IP" ou "IP:porta".
func _join_typed() -> void:
	var target := InternetAccess.parse_address(_ip_edit.text)
	if target.is_empty():
		_status.text = "Código ou IP inválido. O código tem 7 letras/números (ex.: K7Q2-9XM)."
		return
	_join(target[0], target[1])


func _join(address: String, port: int) -> void:
	if address.is_empty():
		_status.text = "Digite o IP do host."
		return
	if NetService.join(address, port, _join_password_edit.text) != OK:
		_status.text = NetService.last_message


func _refresh_worlds() -> void:
	for child in _worlds_box.get_children():
		child.queue_free()
	var worlds := SaveService.list_worlds()
	if worlds.is_empty():
		_worlds_box.add_child(_label("Nenhum mundo ainda. Crie um em \"Novo mundo\".", 22))
		return
	for world in worlds:
		var row := HBoxContainer.new()
		_worlds_box.add_child(row)
		var visibility_name: String = {"open": "aberto", "private": "privado", "offline": "offline"}.get(world.get("visibility"), "")
		var lock := "  ·  com senha" if world.has("password") else ""
		var play := _button(row, "%s  ·  %s%s" % [world.name, visibility_name, lock],
				_play.bind(world))
		play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var delete := _button(row, "Apagar", Callable())
		delete.pressed.connect(_delete_world.bind(str(world.id), delete))


## Apagar pede confirmação: o primeiro aperto troca o texto, o segundo apaga.
func _delete_world(world_id: String, button: Button) -> void:
	if _pending_delete != world_id:
		_pending_delete = world_id
		button.text = "Confirmar?"
		return
	_pending_delete = ""
	SaveService.delete_world(world_id)
	_refresh_worlds()
	_focus_first(_screens.worlds)


func _start_browse() -> void:
	_discovery = LanDiscovery.new()
	add_child(_discovery)
	if _discovery.start_listening() != OK:
		_status.text = "Não deu pra buscar na rede local (porta %d ocupada?). Use o IP." % LanDiscovery.PORT
	_discovery.worlds_changed.connect(_refresh_found)
	_refresh_found()


func _refresh_found() -> void:
	for child in _found_box.get_children():
		child.queue_free()
	if _discovery == null or _discovery.worlds.is_empty():
		_found_box.add_child(_label("Procurando mundos abertos na rede...", 22, Color(0.7, 0.7, 0.7)))
		return
	for info: Dictionary in _discovery.worlds.values():
		var full := int(info.players) >= int(info.max)
		var other_version: bool = info.get("version") != NetService.GAME_VERSION
		var text := "%s  ·  de %s  ·  %d/%d" % [info.name, info.host, int(info.players), int(info.max)]
		if info.get("locked", false):
			text += "  ·  com senha"
		if full:
			text += "  ·  cheio"
		elif other_version:
			text += "  ·  versão %s" % info.version
		var button := _button(_found_box, text, _join.bind(str(info.address), int(info.port)))
		button.disabled = full or other_version


## Peças de interface

func _vbox() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	return box


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 54)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 22)
	if action.is_valid():
		button.pressed.connect(action)
	parent.add_child(button)
	return button


func _label(text: String, size: int, color := UiSkin.TEXT) -> Label:
	if size >= 30:
		return UiSkin.title(text.to_upper(), size, UiSkin.AMBER)
	return UiSkin.label(text, size, color, "SemiBold", 4)


func _style_input(edit: LineEdit) -> void:
	edit.custom_minimum_size = Vector2(0, 52)
	edit.add_theme_font_size_override("font_size", 20)


## Foca o primeiro botão da tela (com controle, caixas de texto pedem teclado virtual).
func _focus_first(root: Control) -> void:
	for node in root.find_children("*", "Button", true, false):
		var control := node as Control
		if control.focus_mode == Control.FOCUS_ALL and control.is_visible_in_tree() and not control.is_queued_for_deletion() \
				and not (control is Button and control.disabled):
			control.grab_focus.call_deferred()
			return
