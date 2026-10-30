extends CanvasLayer
## HUD: um cartão por vaga da sala (P1 a P4) com retrato, vida, atalhos e parafusos,
## a faixa da região, o minimapa no canto superior direito, a situação da conexão e o menu
## de pausa (Esc, Start ou Back) com os controles.
## No online o jogo não pausa de verdade: o menu só cobre a tela.
## O visual vem do tema do projeto e do UiSkin (ui/skin/).

const CONTROLS := [
	["Mirar", "analógico direito", "mouse"],
	["Câmera atrás: girar", "analógico direito", "mouse"],
	["Atacar", "X (segure = combo)", "clique esquerdo / J"],
	["Atirar", "RT", "clique direito / K"],
	["Pular / escalar", "A", "Espaço"],
	["Rolar", "B", "Shift"],
	["Poção", "Y", "E"],
	["Artefato", "RB", "Q"],
	["Pegar / falar", "LB", "F"],
	["Inventário", "Back", "I"],
	["Menu", "Start", "Esc"],
]

var _root: Control
var _cards: Array[PlayerCard] = []
var _card_row: HBoxContainer
var _wave_label: Label
var _net_label: Label
var _net_chip: PanelContainer
var _pause: Control
var _pause_info: Label
var _resume_button: Button
var _copy_button: Button
var _password_row: Control
var _pause_pages := {}
var _pause_tabs := {}
var _pause_page := "Jogo"
var _shown_internet_state := -1

var _inventories := {}  # slot local -> InventoryPanel
var _services := {}  # slot local -> ServicePanel
var _selects := {}  # slot local -> CharacterSelect (escolhendo personagem antes de entrar)
var _banner: RegionBanner
var _region: RegionDef


func _ready() -> void:
	add_to_group("hud")
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_bottom = -12
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(row)
	_card_row = row
	for index in GameConfig.MAX_PLAYERS:
		var card := PlayerCard.new()
		card.index = index
		row.add_child(card)
		_cards.append(card)

	_wave_label = UiSkin.title("", 34, UiSkin.AMBER)
	_wave_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_wave_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.offset_top = 24
	_root.add_child(_wave_label)

	# Nome da região ao entrar nela (some sozinho).
	_banner = RegionBanner.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_left = -RegionBanner.WIDTH / 2.0
	_banner.offset_right = RegionBanner.WIDTH / 2.0
	_banner.offset_top = 70
	_banner.offset_bottom = 180
	_root.add_child(_banner)

	var hint := PanelContainer.new()
	hint.add_theme_stylebox_override("panel", UiSkin.chip())
	hint.position = Vector2(20, 18)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_child(UiSkin.label("START / ESC  ·  menu e controles", 15, UiSkin.TEXT, "SemiBold", 4))
	_root.add_child(hint)

	var minimap := Minimap.new()
	minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -24 - Minimap.SIZE
	minimap.offset_right = -24
	minimap.offset_top = 24
	minimap.offset_bottom = 24 + Minimap.SIZE
	_root.add_child(minimap)

	_net_chip = PanelContainer.new()
	_net_chip.add_theme_stylebox_override("panel", UiSkin.chip())
	_net_chip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_net_chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_net_chip.offset_top = 24 + Minimap.SIZE + 10
	_net_chip.offset_right = -24
	_net_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_net_label = UiSkin.label("", 15, Color(0.75, 0.95, 1.0), "SemiBold", 4)
	_net_chip.add_child(_net_label)
	_root.add_child(_net_chip)

	_build_pause_menu()


func _process(_delta: float) -> void:
	if _pause.visible and NetService.internet and NetService.internet.state != _shown_internet_state:
		_shown_internet_state = NetService.internet.state
		_update_pause_info()
	var players := {}
	for player: Player in get_tree().get_nodes_in_group("players"):
		players[player.index] = player
	var free_local := InputService.active_slots().size() < GameConfig.MAX_PLAYERS
	for card in _cards:
		card.player = players.get(card.index)
		# Vagas livres ("aperte START") só aparecem com o menu de pausa aberto.
		card.invite = _pause.visible and free_local and NetService.player_count() < GameConfig.MAX_PLAYERS

	var spawner := get_tree().get_first_node_in_group("wave_spawner")
	if spawner and spawner.wave > 0:
		_wave_label.text = "Onda %d  ·  inimigos: %d" % [spawner.wave, spawner.alive_count()]
	else:
		_wave_label.text = ""
	_fit_cards()
	_net_label.text = _connection_text()
	_net_chip.visible = not _net_label.text.is_empty()
	_update_region()
	_process_inventory_layout()


func _physics_process(_delta: float) -> void:
	for slot in InputService.active_slots():
		if InputService.raw_just_pressed(slot, InputService.Action.INVENTORY) and not _services.has(slot):
			_toggle_inventory(slot)
		elif InputService.just_pressed(slot, InputService.Action.PICKUP):
			_try_open_service(slot)
	for slot: int in _inventories.keys():
		if not InputService.is_active(slot):
			_close_inventory(slot)
	for slot: int in _services.keys():
		if not InputService.is_active(slot):
			_close_service(slot)
	for slot: int in _selects.keys():
		if not InputService.is_active(slot):
			_close_select(slot)
	if _pause.visible:
		for slot in InputService.active_slots():
			var step := int(InputService.raw_just_pressed(slot, InputService.Action.ARTIFACT)) \
					- int(InputService.raw_just_pressed(slot, InputService.Action.PICKUP))
			if step != 0:
				var names := _pause_pages.keys()
				_show_pause_page(names[wrapi(names.find(_pause_page) + step, 0, names.size())])
				Sound.play("ui_move")
	for slot in InputService.active_slots():
		# Com o menu aberto os comandos de jogo estão bloqueados, então o Start que fecha é lido direto.
		var pressed := InputService.raw_just_pressed(slot, InputService.Action.PAUSE) if _pause.visible \
				else InputService.just_pressed(slot, InputService.Action.PAUSE)
		if pressed:
			_toggle_pause()
			return


func _unhandled_input(event: InputEvent) -> void:
	# Esc abre o menu mesmo sem ninguém no jogo ainda.
	var escape: bool = event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE and not InputService.active_slots().size()
	if escape:
		_toggle_pause()


## Interface grande (configurações) ou tela estreita: os 4 cartões encolhem para caber.
func _fit_cards() -> void:
	var view := get_viewport().get_visible_rect().size
	var needed := _card_row.get_combined_minimum_size().x
	var fit := minf(1.0, (view.x - 24.0) / maxf(needed, 1.0))
	_card_row.pivot_offset = Vector2(_card_row.size.x / 2.0, _card_row.size.y)
	_card_row.scale = Vector2(fit, fit)


## Mostra o nome da região quando o primeiro jogador desta tela entra numa nova.
func _update_region() -> void:
	var streamer := WorldStreamer.of(self)
	if streamer == null:
		return
	var player: Player = null
	for candidate: Player in get_tree().get_nodes_in_group("players"):
		if candidate.is_local() and (player == null or candidate.index < player.index):
			player = candidate
	if player == null:
		return
	var region := streamer.region_at(player.global_position)
	if region == null or region == _region:
		return
	_region = region
	_banner.show_region(region)

## Controle que acabou de entrar: escolhe o personagem antes de nascer.
func open_character_select(slot: int) -> void:
	if _selects.has(slot):
		return
	var panel := CharacterSelect.new()
	_root.add_child(panel)
	panel.open_for(slot, _characters_in_use)
	panel.finished.connect(func(character_id: String) -> void:
		_close_select(slot)
		NetService.request_player(slot, character_id))
	panel.cancelled.connect(func() -> void:
		_close_select(slot)
		InputService.leave(slot))
	_selects[slot] = panel


## Personagens desta máquina que já estão em jogo (cada um só entra uma vez).
func _characters_in_use() -> Array:
	var manager := get_tree().get_first_node_in_group("player_manager")
	return manager.local_characters() if manager else []


func _close_select(slot: int) -> void:
	if _selects.has(slot):
		_selects[slot].queue_free()
		_selects.erase(slot)


## Abre o inventário do jogador local `slot` acima do cartão dele, ou fecha se já está aberto.
func _toggle_inventory(slot: int) -> void:
	if _inventories.has(slot):
		_close_inventory(slot)
		return
	var player: Player = null
	for candidate: Player in get_tree().get_nodes_in_group("players"):
		if candidate.is_local() and candidate.slot == slot:
			player = candidate
	if player == null:
		return
	_open_panel(slot, InventoryPanel.new(), player)


## Abre no lugar do inventário um painel do jogador (inventário ou chip pirata); RB/Q alterna.
func _open_panel(slot: int, panel: Control, player: Player) -> void:
	_root.add_child(panel)
	panel.open_for(player)
	panel.close_requested.connect(_close_inventory.bind(slot))
	panel.switch_requested.connect(_switch_panel.bind(slot))
	_inventories[slot] = panel


func _switch_panel(slot: int) -> void:
	var current: Control = _inventories.get(slot)
	if current == null or not is_instance_valid(current.player):
		return
	var player: Player = current.player
	current.keep_blocked = true
	current.queue_free()
	_inventories.erase(slot)
	_open_panel(slot, ChipPanel.new() if current is InventoryPanel else InventoryPanel.new(), player)


func _close_inventory(slot: int) -> void:
	if _inventories.has(slot):
		_inventories[slot].queue_free()
		_inventories.erase(slot)


## Perto de um NPC, o botão de pegar abre a tela do serviço dele para esse jogador.
func _try_open_service(slot: int) -> void:
	var player := _local_player(slot)
	if player == null or _inventories.has(slot) or _services.has(slot):
		return
	var npc := WorldNpc.nearest(get_tree(), player.global_position)
	if npc == null:
		return
	var panel := ServicePanel.new()
	_root.add_child(panel)
	panel.open_for(player, npc)
	panel.close_requested.connect(_close_service.bind(slot))
	_services[slot] = panel


func _close_service(slot: int) -> void:
	if _services.has(slot):
		_services[slot].queue_free()
		_services.erase(slot)


func _local_player(slot: int) -> Player:
	for candidate: Player in get_tree().get_nodes_in_group("players"):
		if candidate.is_local() and candidate.slot == slot:
			return candidate
	return null


func _process_inventory_layout() -> void:
	# Cada painel (inventário ou serviço) fica acima do cartão do dono: a tela é dividida
	# em 4 colunas, P1 a P4.
	var view := get_viewport().get_visible_rect().size
	var column := view.x / GameConfig.MAX_PLAYERS
	for panel: Control in _inventories.values() + _services.values():
		if not is_instance_valid(panel.player):
			continue
		var x := clampf(panel.player.index * column + (column - panel.size.x) / 2.0, 8.0, view.x - panel.size.x - 8.0)
		panel.position = Vector2(x, view.y - PlayerCard.SIZE.y - 24.0 - panel.size.y)
	# Escolha de personagem: na coluna da vaga, no meio da altura da tela.
	# Sozinho, em tamanho normal; com mais gente escolhendo, cada um cabe na sua coluna.
	var crowded := _selects.size() > 1
	for slot: int in _selects:
		var select: Control = _selects[slot]
		var fit := minf(1.0, (column - 12.0) / maxf(select.size.x, 1.0)) if crowded else 1.0
		select.scale = Vector2(fit, fit)
		var width := select.size.x * fit
		var sx := clampf(slot * column + (column - width) / 2.0, 8.0, view.x - width - 8.0)
		select.position = Vector2(sx, (view.y - select.size.y * fit) / 2.0 - 40.0)


func _connection_text() -> String:
	var world_name: String = NetService.world.get("name", "")
	match NetService.mode:
		NetService.Mode.HOST:
			var addresses := NetService.local_addresses()
			var ip := addresses[0] if not addresses.is_empty() else "?"
			var internet := NetService.internet
			var reach := "rede local: IP %s" % ip
			if internet and not internet.code.is_empty():
				reach = "código %s" % internet.code
			elif internet and internet.state == InternetAccess.State.CHECKING:
				reach = "abrindo para a internet..."
			return "%s · online (host) · %s · %d/%d" % [world_name, reach, NetService.player_count(), GameConfig.MAX_PLAYERS]
		NetService.Mode.CLIENT:
			return "%s · online · %d/%d" % [world_name, NetService.player_count(), GameConfig.MAX_PLAYERS]
	return "%s · offline" % world_name if world_name else ""


func _build_pause_menu() -> void:
	_pause = Control.new()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	_root.add_child(_pause)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.01, 0.02, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_pause.add_child(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(900, 0)
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := UiSkin.title("PAUSA", 44, UiSkin.AMBER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	# Abas: Jogo, Configurações, Controles (LB/RB ou os botões trocam).
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	column.add_child(tabs)
	var pages := {}

	var game := VBoxContainer.new()
	game.add_theme_constant_override("separation", 12)
	_pause_info = UiSkin.label("", 17, Color(0.8, 0.92, 1.0), "Regular", 4)
	_pause_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	game.add_child(_pause_info)
	_resume_button = _make_button(game, "Continuar", _toggle_pause)
	_copy_button = _make_button(game, "", func() -> void:
		if NetService.internet:
			DisplayServer.clipboard_set(NetService.internet.code)
			_copy_button.text = "Copiado! Mande para o amigo: %s" % NetService.internet.code)
	_copy_button.visible = false
	_password_row = _build_password_row(game)
	_make_button(game, "Sair para o menu", func() -> void: NetService.leave_session())
	pages["Jogo"] = game

	pages["Configurações"] = SettingsPanel.new()
	var voice := VoicePanel.new()
	voice.show_people = true
	pages["Voz"] = voice

	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 4)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 4)
	controls.add_child(grid)
	for header: String in ["", "Controle", "Teclado e mouse"]:
		grid.add_child(UiSkin.label(header, 14, UiSkin.DIM, "Bold", 3))
	for entry: Array in CONTROLS:
		grid.add_child(UiSkin.label(entry[0], 16, UiSkin.TEXT, "SemiBold", 3))
		grid.add_child(UiSkin.label(entry[1], 16, UiSkin.AMBER, "Bold", 3))
		grid.add_child(UiSkin.label(entry[2], 16, Color(0.75, 0.9, 1.0), "Regular", 3))
	pages["Controles"] = controls

	for page_name: String in pages:
		var page: Control = pages[page_name]
		column.add_child(page)
		var tab := _make_button(tabs, page_name, _show_pause_page.bind(page_name))
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.toggle_mode = true
		_pause_tabs[page_name] = tab
	_pause_pages = pages
	_show_pause_page("Jogo")


func _show_pause_page(page_name: String) -> void:
	for key: String in _pause_pages:
		_pause_pages[key].visible = key == page_name
		_pause_tabs[key].set_pressed_no_signal(key == page_name)
	_pause_page = page_name


## Host: senha do mundo (vazia = sem senha). Vale para quem entrar pela rede local ou internet.
func _build_password_row(parent: Control) -> Control:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var edit := LineEdit.new()
	edit.placeholder_text = "Senha do mundo (vazio = sem senha)"
	edit.secret = true
	edit.custom_minimum_size = Vector2(0, 46)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	var save := _make_button(row, "Salvar senha", func() -> void:
		NetService.set_world_password(edit.text)
		edit.text = ""
		_update_pause_info())
	save.custom_minimum_size = Vector2(170, 46)
	return row


func _toggle_pause() -> void:
	_pause.visible = not _pause.visible
	InputService.screen_menu_open = _pause.visible
	if not _pause.visible:
		return
	# Por cima de tudo (escolha de personagem, inventários).
	_root.move_child(_pause, -1)
	_show_pause_page("Jogo")
	_update_pause_info()
	_resume_button.grab_focus()


func _update_pause_info() -> void:
	var lines := PackedStringArray([_connection_text()])
	var internet := NetService.internet
	if NetService.mode == NetService.Mode.HOST:
		lines.append("Amigos na mesma rede veem este mundo em \"Buscar mundos\".")
		if internet:
			lines.append(internet.describe())
	_password_row.visible = NetService.mode == NetService.Mode.HOST
	if NetService.mode == NetService.Mode.HOST:
		lines.append("Mundo com senha." if NetService.has_password() else "Mundo sem senha: quem tiver o código ou o IP entra.")
	_pause_info.text = "\n".join(lines)
	_copy_button.visible = internet != null and not internet.code.is_empty()
	if _copy_button.visible:
		_copy_button.text = "Copiar código do mundo (%s)" % internet.code


func _make_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 50)
	button.add_theme_font_size_override("font_size", 21)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
