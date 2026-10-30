class_name ServicePanel
extends PanelContainer
## Tela de serviço de um NPC (comerciante, ferreiro, encantador, banco) para um jogador local,
## com cursor próprio como o inventário: cada um do sofá usa a sua ao mesmo tempo.
## Mostra abas e uma lista de linhas; confirmar manda o comando para o host (Services),
## e a lista se atualiza quando o inventário volta.
##
## Controle: cima/baixo escolhe · esquerda/direita troca de aba · A confirma · B volta/fecha
## Teclado:  W/S ou setas · A/D · Espaço · Shift

signal close_requested

const VISIBLE_ROWS := 8
const ROW_HEIGHT := 44
const REPEAT_DELAY := 0.3
const REPEAT_RATE := 0.1
const TABS := {
	Services.MERCHANT: ["Comprar", "Vender"],
	Services.BLACKSMITH: ["Upgrade"],
	Services.ENCHANTER: ["Instalar mod"],
	Services.BANK: ["Guardar", "Retirar"],
}

var player: Player
var npc: WorldNpc

var _tab := 0
var _cursor := 0
var _rows: Array[Dictionary] = []
## Encantador: item escolhido, esperando escolher o encantamento ([] = escolhendo item).
var _enchant_path: Array = []
var _repeat := 0.0
var _last_dir := Vector2i.ZERO

var _tab_label: Label
var _list: VBoxContainer
var _details: Label
var _footer: Label


func open_for(p_player: Player, p_npc: WorldNpc) -> void:
	player = p_player
	npc = p_npc
	player.inventory_updated.connect(_refresh)
	InputService.set_blocked(player.slot, true)
	_build()
	_refresh()


func _exit_tree() -> void:
	if is_instance_valid(player):
		InputService.set_blocked(player.slot, false)


func _build() -> void:
	var color := GameConfig.PLAYER_COLORS[player.index]
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.94)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(470, 0)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var title: String = "%s · %s" % [npc.npc_name, WorldNpc.SERVICE_NAMES[npc.service]] if npc.npc_name else WorldNpc.SERVICE_NAMES[npc.service]
	column.add_child(_label("P%d · %s" % [player.index + 1, title], 20, color))
	_tab_label = _label("", 17, Color(0.85, 0.9, 1.0))
	column.add_child(_tab_label)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(0, VISIBLE_ROWS * ROW_HEIGHT)
	_list.add_theme_constant_override("separation", 2)
	column.add_child(_list)
	_details = _label("", 15, Color.WHITE)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.custom_minimum_size = Vector2(440, 44)
	column.add_child(_details)
	_footer = _label("", 15, Color(1.0, 0.85, 0.4))
	column.add_child(_footer)
	column.add_child(_label("Cima/baixo escolhe · esquerda/direita troca de aba · A confirma · B volta", 13, Color(1, 1, 1, 0.6)))


## Linhas

func _tabs() -> Array:
	return TABS[npc.service]


func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var inventory := player.inventory
	match _tabs()[_tab]:
		"Comprar":
			for i in npc.shop_items.size():
				var item := npc.shop_item(i)
				if item.is_empty():
					continue
				var price := ItemDB.value(item)
				rows.append(_row(item, ItemDB.money(price), ["buy", [i]], inventory.gold >= price))
		"Vender":
			for entry: Array in inventory.all_items(["bag"]):
				var item: Dictionary = entry[1]
				var full: bool = ItemDB.is_container(item) and item.contents.any(func(i: Variant) -> bool: return i != null)
				rows.append(_row(item, "+%d" % ItemDB.sell_price(item), ["sell", [entry[0]]], not full))
		"Upgrade":
			for entry: Array in inventory.all_items(["eq", "bag"]):
				var item: Dictionary = entry[1]
				if ItemDB.is_container(item) or ItemDB.slot_of(item) == "":
					continue
				var maxed := int(item.get("refine", 0)) >= ItemDB.MAX_REFINE
				var right := "máximo" if maxed else "%s · %d%%" % [ItemDB.money(ItemDB.refine_cost(item)), roundi(ItemDB.refine_chance(item) * 100)]
				rows.append(_row(item, right, ["refine", [entry[0]]], not maxed and inventory.gold >= ItemDB.refine_cost(item)))
		"Instalar mod":
			if _enchant_path.is_empty():
				for entry: Array in inventory.all_items(["eq", "bag"]):
					var item: Dictionary = entry[1]
					if not ItemDB.enchants_for(item).is_empty():
						rows.append(_row(item, "%d/%d" % [item.get("enchants", {}).size(), ItemDB.MAX_ENCHANTS], ["choose", entry[0]], true))
			else:
				var item: Variant = inventory.get_item(_enchant_path)
				if item == null:
					_enchant_path = []
					return _build_rows()
				for enchant_id in ItemDB.enchants_for(item):
					var enchant: Dictionary = ItemDB.ENCHANTS[enchant_id]
					var level := int(item.get("enchants", {}).get(enchant_id, 0))
					var cost := ItemDB.enchant_cost(item, enchant_id)
					var row := _row(item, ItemDB.money(cost), ["enchant", [_enchant_path, enchant_id]],
							ItemDB.can_enchant(item, enchant_id) and inventory.gold >= cost)
					row.text = "%s %d → %d (+%s %s)" % [enchant.name, level, level + 1, str(enchant.per_level), ItemDB.STATS[enchant.stat]]
					if level >= ItemDB.MAX_ENCHANT_LEVEL:
						row.right = "máximo"
					rows.append(row)
		"Guardar":
			for entry: Array in inventory.all_items(["bag"]):
				rows.append(_row(entry[1], "", ["deposit", [entry[0]]], inventory.depot.contents.has(null)))
		"Retirar":
			for entry: Array in inventory.all_items(["depot"]):
				if entry[0].size() == 2:
					rows.append(_row(entry[1], "", ["withdraw", [entry[0][1]]], true))
	return rows


func _row(item: Dictionary, right: String, action: Array, enabled: bool) -> Dictionary:
	return {"item": item, "text": ItemDB.display_name(item), "right": right, "action": action, "enabled": enabled}


func _refresh() -> void:
	if not is_instance_valid(player):
		return
	_rows = _build_rows()
	_cursor = clampi(_cursor, 0, maxi(_rows.size() - 1, 0))
	var names := PackedStringArray()
	for i in _tabs().size():
		names.append("[ %s ]" % _tabs()[i] if i == _tab else _tabs()[i])
	_tab_label.text = "   ".join(names) + ("   (escolha o mod)" if not _enchant_path.is_empty() else "")
	for child in _list.get_children():
		child.queue_free()
	if _rows.is_empty():
		_list.add_child(_label("Nada aqui.", 16, Color(1, 1, 1, 0.5)))
	var first := clampi(_cursor - VISIBLE_ROWS / 2, 0, maxi(_rows.size() - VISIBLE_ROWS, 0))
	for i in range(first, mini(first + VISIBLE_ROWS, _rows.size())):
		_list.add_child(_row_view(_rows[i], i == _cursor))
	_details.text = _describe()
	_footer.text = ItemDB.money(player.inventory.gold)


func _row_view(row: Dictionary, selected: bool) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.08) if selected else Color(0, 0, 0, 0)
	style.border_color = GameConfig.PLAYER_COLORS[player.index]
	style.set_border_width_all(2 if selected else 0)
	style.set_content_margin_all(2)
	panel.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	panel.add_child(line)
	var icon := ItemIcon.new()
	icon.item = row.item
	icon.custom_minimum_size = Vector2(36, 36)
	line.add_child(icon)
	var name_color := ItemDB.rarity_color(row.item) if row.enabled else Color(0.5, 0.5, 0.5)
	var text := _label(row.text, 16, name_color)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.clip_text = true
	line.add_child(text)
	line.add_child(_label(row.right, 15, Color(1.0, 0.85, 0.4) if row.enabled else Color(0.5, 0.5, 0.5)))
	return panel


func _describe() -> String:
	if _rows.is_empty():
		return ""
	var item: Dictionary = _rows[_cursor].item
	return "%s · %s · poder %d\n%s" % [ItemDB.display_name(item), ItemDB.rarity_name(item), int(item.get("power", 1)),
			"   ".join(ItemDB.describe(item))]


## Controles

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(npc):
		close_requested.emit()
		return
	var slot := player.slot
	var raw := InputService.raw_move(slot)
	var dir := Vector2i(roundi(raw.x) if absf(raw.x) > 0.5 else 0, roundi(raw.y) if absf(raw.y) > 0.5 else 0)
	if dir != Vector2i.ZERO:
		if dir != _last_dir:
			_step(dir)
			_repeat = REPEAT_DELAY
		else:
			_repeat -= delta
			if _repeat <= 0.0:
				_step(dir)
				_repeat = REPEAT_RATE
	_last_dir = dir
	if InputService.raw_just_pressed(slot, InputService.Action.JUMP):
		_confirm()
	elif InputService.raw_just_pressed(slot, InputService.Action.DODGE) \
			or InputService.raw_just_pressed(slot, InputService.Action.PAUSE) \
			or InputService.raw_just_pressed(slot, InputService.Action.INVENTORY):
		_back()
	# Longe do NPC (empurrado, teleportado): fecha.
	var offset := player.global_position - npc.global_position
	if Vector2(offset.x, offset.z).length() > WorldNpc.TALK_RANGE + 1.5:
		close_requested.emit()


func _step(dir: Vector2i) -> void:
	if dir.x != 0 and _enchant_path.is_empty():
		_tab = posmod(_tab + dir.x, _tabs().size())
		_cursor = 0
	elif dir.y != 0 and not _rows.is_empty():
		_cursor = clampi(_cursor + dir.y, 0, _rows.size() - 1)
	_refresh()


func _confirm() -> void:
	if _rows.is_empty():
		return
	var row: Dictionary = _rows[_cursor]
	if row.action[0] == "choose":
		_enchant_path = row.action[1]
		_cursor = 0
		_refresh()
		return
	if row.enabled:
		player.request_inventory(row.action[0], row.action[1])


func _back() -> void:
	if not _enchant_path.is_empty():
		_enchant_path = []
		_cursor = 0
		_refresh()
	else:
		close_requested.emit()


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
