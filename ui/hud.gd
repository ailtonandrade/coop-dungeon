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
var _wave_label: Label
var _net_label: Label
var _net_chip: PanelContainer
var _pause: Control
var _pause_info: Label
var _resume_button: Button
var _minimap_button: Button
var _camera_button: Button
var _inventories := {}  # slot local -> InventoryPanel
var _services := {}  # slot local -> ServicePanel
var _banner: RegionBanner
var _region: RegionDef


func _ready() -> void:
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
	var players := {}
	for player: Player in get_tree().get_nodes_in_group("players"):
		players[player.index] = player
	var free_local := InputService.active_slots().size() < GameConfig.MAX_PLAYERS
	for card in _cards:
		card.player = players.get(card.index)
		card.invite = free_local and NetService.player_count() < GameConfig.MAX_PLAYERS

	var spawner := get_tree().get_first_node_in_group("wave_spawner")
	if spawner and spawner.wave > 0:
		_wave_label.text = "Onda %d  ·  inimigos: %d" % [spawner.wave, spawner.alive_count()]
	else:
		_wave_label.text = ""
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
	var panel := InventoryPanel.new()
	_root.add_child(panel)
	panel.open_for(player)
	panel.close_requested.connect(_close_inventory.bind(slot))
	_inventories[slot] = panel


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
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 32)
	panel.add_child(columns)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 12)
	columns.add_child(box)
	var title := UiSkin.title("PAUSA", 44, UiSkin.AMBER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_pause_info = UiSkin.label("", 17, Color(0.8, 0.92, 1.0), "Regular", 4)
	_pause_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_pause_info)
	_resume_button = _make_button(box, "Continuar", _toggle_pause)
	_camera_button = _make_button(box, "", Settings.toggle_camera_mode)
	_minimap_button = _make_button(box, "", Settings.toggle_minimap_mode)
	Settings.changed.connect(_update_minimap_button)
	_update_minimap_button()
	_make_button(box, "Sair para o menu", func() -> void: NetService.leave_session())

	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 4)
	columns.add_child(controls)
	controls.add_child(UiSkin.label("CONTROLES", 22, UiSkin.NEON, "Bold"))
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


func _update_minimap_button() -> void:
	_camera_button.text = "Câmera: atrás do herói (só 1 jogador na tela)" if Settings.camera_mode == "behind" else "Câmera: de cima (isométrica)"
	_minimap_button.text = "Minimapa: %s" % ("rotativo (gira com o herói)" if Settings.minimap_mode == "rotating" else "fixo (norte pra cima)")


func _toggle_pause() -> void:
	_pause.visible = not _pause.visible
	InputService.screen_menu_open = _pause.visible
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
	button.custom_minimum_size = Vector2(0, 50)
	button.add_theme_font_size_override("font_size", 21)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
