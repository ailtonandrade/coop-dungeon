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
var _worlds_box: VBoxContainer
var _found_box: VBoxContainer
var _ip_edit: LineEdit
var _discovery: LanDiscovery
var _pending_delete := ""


func _ready() -> void:
	InputService.reset()
	var background := ColorRect.new()
	background.color = Color(0.05, 0.05, 0.08)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.custom_minimum_size = Vector2(760, 0)
	column.add_theme_constant_override("separation", 18)
	add_child(column)

	var title := _label(GameConfig.GAME_TITLE.to_upper(), 72, Color(1.0, 0.3, 0.75))
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.95, 1.0))
	title.add_theme_constant_override("outline_size", 6)
	column.add_child(title)
	column.add_child(_label("ferro-velho · chip queimado · gambiarra", 20, Color(0.2, 0.95, 1.0, 0.8)))
	_status = _label(NetService.last_message, 22, Color(1.0, 0.8, 0.4))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	column.add_child(_status)
	NetService.status_changed.connect(func(text: String) -> void: _status.text = text)

	_screens.main = _build_main()
	_screens.create = _build_create()
	_screens.worlds = _build_worlds()
	_screens.browse = _build_browse()
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
	match screen_name:
		"worlds":
			_refresh_worlds()
		"browse":
			_start_browse()
	_focus_first(_screens[screen_name])


## Telas

func _build_main() -> Control:
	var box := _vbox()
	_button(box, "Novo mundo", func() -> void: _show("create"))
	_button(box, "Meus mundos", func() -> void: _show("worlds"))
	_button(box, "Buscar mundos (rede local / IP)", func() -> void: _show("browse"))
	_button(box, "Sair", func() -> void: get_tree().quit())
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
	_visibility.custom_minimum_size = Vector2(0, 52)
	_visibility.add_theme_font_size_override("font_size", 22)
	box.add_child(_visibility)
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
	box.add_child(_label("Ou entre direto pelo IP do host:", 22))
	var row := HBoxContainer.new()
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "ex.: 192.168.0.10"
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_input(_ip_edit)
	row.add_child(_ip_edit)
	_button(row, "Entrar", func() -> void: _join(_ip_edit.text.strip_edges(), NetService.DEFAULT_PORT))
	box.add_child(row)
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
	SaveService.save_world(world)
	_play(world)


func _play(world: Dictionary) -> void:
	if NetService.play_world(world) != OK:
		_status.text = NetService.last_message


func _join(address: String, port: int) -> void:
	if address.is_empty():
		_status.text = "Digite o IP do host."
		return
	if NetService.join(address, port) != OK:
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
		var play := _button(row, "%s  ·  %s  ·  melhor onda %d" % [world.name, visibility_name, int(world.get("best_wave", 0))],
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
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_font_size_override("font_size", 24)
	if action.is_valid():
		button.pressed.connect(action)
	parent.add_child(button)
	return button


func _label(text: String, size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _style_input(edit: LineEdit) -> void:
	edit.custom_minimum_size = Vector2(0, 52)
	edit.add_theme_font_size_override("font_size", 22)


## Foca o primeiro botão da tela (com controle, caixas de texto pedem teclado virtual).
func _focus_first(root: Control) -> void:
	for node in root.find_children("*", "Button", true, false):
		var control := node as Control
		if control.focus_mode == Control.FOCUS_ALL and control.is_visible_in_tree() and not control.is_queued_for_deletion() \
				and not (control is Button and control.disabled):
			control.grab_focus.call_deferred()
			return
