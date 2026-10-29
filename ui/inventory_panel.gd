class_name InventoryPanel
extends PanelContainer
## Inventário de um jogador local, estilo Tibia, com cursor próprio: cada um do sofá
## navega o seu ao mesmo tempo. Enquanto está aberto, o herói dele não anda nem ataca.
##
## Controle: direcional/analógico move · A pega e solta · Y equipa (ou abre a bolsa)
##           X larga no chão · B cancela / volta da bolsa / fecha · Back fecha
## Teclado:  WASD/setas · Espaço · E · J · Shift · I

signal close_requested

const COLUMNS := 4
const REPEAT_DELAY := 0.3
const REPEAT_RATE := 0.11
const PLACEHOLDERS := {
	"amulet": "amulet", "head": "helmet", "bag": "backpack", "melee": "sword", "chest": "vest",
	"ranged": "bow", "ring": "ring", "legs": "legs", "feet": "boots",
}

var player: Player

var _equip_icons: Array[ItemIcon] = []
var _bag_icons: Array[ItemIcon] = []
var _bag_grid: GridContainer
var _bag_title: Label
var _details: Label
var _section := "bag"  # "eq" ou "bag"
var _cursor := 0
var _container_path: Array = ["bag"]
var _held: Array = []  # casa do item que está "na mão" do cursor
var _repeat := 0.0
var _last_dir := Vector2i.ZERO


func open_for(p_player: Player) -> void:
	player = p_player
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
	style.bg_color = Color(0.05, 0.06, 0.08, 0.93)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	column.add_child(_label("P%d %s · inventário" % [player.index + 1, player.display_name], 20, color))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)

	var equip_box := VBoxContainer.new()
	equip_box.add_child(_label("Equipamento", 16, Color(0.8, 0.8, 0.8)))
	var equip_grid := GridContainer.new()
	equip_grid.columns = 3
	equip_grid.add_theme_constant_override("h_separation", 4)
	equip_grid.add_theme_constant_override("v_separation", 4)
	equip_box.add_child(equip_grid)
	for slot: String in ItemDB.EQUIP_SLOTS:
		var icon := ItemIcon.new()
		icon.placeholder = PLACEHOLDERS[slot]
		icon.cursor_color = color
		equip_grid.add_child(icon)
		_equip_icons.append(icon)
	row.add_child(equip_box)

	var bag_box := VBoxContainer.new()
	_bag_title = _label("", 16, Color(0.8, 0.8, 0.8))
	bag_box.add_child(_bag_title)
	_bag_grid = GridContainer.new()
	_bag_grid.columns = COLUMNS
	_bag_grid.add_theme_constant_override("h_separation", 4)
	_bag_grid.add_theme_constant_override("v_separation", 4)
	bag_box.add_child(_bag_grid)
	row.add_child(bag_box)

	_details = _label("", 16, Color.WHITE)
	_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.custom_minimum_size = Vector2(440, 96)
	column.add_child(_details)
	column.add_child(_label("A pega/solta · Y equipa/abre · X larga · B volta · Back fecha", 13, Color(1, 1, 1, 0.6)))


## Atualização

func _refresh() -> void:
	if not is_instance_valid(player):
		return
	var inventory := player.inventory
	if inventory.container_at(_container_path) == null:
		_container_path = ["bag"]
	if not _held.is_empty() and inventory.get_item(_held) == null:
		_held = []
	var container: Variant = inventory.container_at(_container_path)
	var capacity: int = container.contents.size() if container else 0

	while _bag_icons.size() < capacity:
		var icon := ItemIcon.new()
		icon.cursor_color = GameConfig.PLAYER_COLORS[player.index]
		_bag_grid.add_child(icon)
		_bag_icons.append(icon)
	while _bag_icons.size() > capacity:
		_bag_icons.pop_back().queue_free()

	if _section == "bag" and capacity == 0:
		_section = "eq"
	_cursor = clampi(_cursor, 0, (capacity if _section == "bag" else ItemDB.EQUIP_SLOTS.size()) - 1)

	for i in _equip_icons.size():
		_paint(_equip_icons[i], ["eq", ItemDB.EQUIP_SLOTS[i]], _section == "eq" and _cursor == i)
	for i in capacity:
		_paint(_bag_icons[i], _container_path + [i], _section == "bag" and _cursor == i)

	var names := PackedStringArray()
	for depth in range(1, _container_path.size() + 1):
		var bag: Variant = inventory.container_at(_container_path.slice(0, depth))
		names.append(ItemDB.display_name(bag) if bag else "?")
	var used := 0
	if container:
		used = container.contents.filter(func(i: Variant) -> bool: return i != null).size()
	_bag_title.text = "%s  (%d/%d)" % [" › ".join(names), used, capacity] if container else "Sem mochila"
	_details.text = _describe()


func _paint(icon: ItemIcon, path: Array, selected: bool) -> void:
	icon.item = player.inventory.get_item(path)
	icon.selected = selected
	icon.lifted = path == _held
	icon.queue_redraw()


func _describe() -> String:
	var lines := PackedStringArray()
	if not _held.is_empty():
		lines.append("Na mão: %s (solte com A)" % ItemDB.display_name(player.inventory.get_item(_held)))
	var item: Variant = player.inventory.get_item(_cursor_path())
	if item == null:
		if _section == "eq":
			lines.append(ItemDB.SLOT_NAMES[ItemDB.EQUIP_SLOTS[_cursor]] + ": vazio")
		return "\n".join(lines)
	lines.append("%s  ·  %s  ·  poder %d" % [ItemDB.display_name(item), ItemDB.rarity_name(item), int(item.power)])
	var stats := ItemDB.describe(item)
	var compare := _comparison(item)
	if compare:
		stats.append(compare)
	lines.append("   ".join(stats))
	return "\n".join(lines)


## "+2.5 de dano" comparando com o que está equipado na mesma casa.
func _comparison(item: Dictionary) -> String:
	var slot := ItemDB.slot_of(item)
	if _section == "eq" or slot == "bag":
		return ""
	var equipped: Variant = player.inventory.equipment.get(slot)
	for key: String in ["damage", "armor", "hp", "damage_pct"]:
		var mine := ItemDB.stat(item, key)
		if mine != 0.0:
			var diff := mine - (ItemDB.stat(equipped, key) if equipped else 0.0)
			return "(%s%s vs equipado)" % ["+" if diff >= 0.0 else "", str(snappedf(diff, 0.1))]
	return ""


## Controles

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
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
	elif InputService.raw_just_pressed(slot, InputService.Action.POTION):
		_quick()
	elif InputService.raw_just_pressed(slot, InputService.Action.MELEE):
		_drop()
	elif InputService.raw_just_pressed(slot, InputService.Action.DODGE) \
			or InputService.raw_just_pressed(slot, InputService.Action.PAUSE):
		_back()


func _step(dir: Vector2i) -> void:
	var capacity := _bag_icons.size()
	if _section == "eq":
		var col := _cursor % 3 + dir.x
		var row := clampi(_cursor / 3 + dir.y, 0, 2)
		if col > 2 and capacity > 0:
			_section = "bag"
			_cursor = mini(row * COLUMNS, capacity - 1)
		else:
			_cursor = row * 3 + clampi(col, 0, 2)
	else:
		var col := _cursor % COLUMNS + dir.x
		var row := _cursor / COLUMNS + dir.y
		if col < 0:
			_section = "eq"
			_cursor = mini(row, 2) * 3 + 2
		else:
			var target := row * COLUMNS + mini(col, COLUMNS - 1)
			if row >= 0 and target < capacity:
				_cursor = target
	_refresh()


func _cursor_path() -> Array:
	if _section == "eq":
		return ["eq", ItemDB.EQUIP_SLOTS[_cursor]]
	return _container_path + [_cursor]


## A: pega o item da casa; com item na mão, solta nela (troca, guarda na bolsa ou equipa).
func _confirm() -> void:
	var path := _cursor_path()
	if _held.is_empty():
		if player.inventory.get_item(path) != null:
			_held = path
	else:
		if path != _held:
			player.request_inventory("move", [_held, path])
		_held = []
	_refresh()


## Y: equipa o item da mochila (ou abre, se for bolsa); no equipamento, guarda na mochila.
func _quick() -> void:
	var path := _cursor_path()
	var item: Variant = player.inventory.get_item(path)
	if item == null:
		return
	if _section == "eq":
		if path == ["eq", "bag"]:
			_section = "bag"
			_container_path = ["bag"]
			_cursor = 0
		else:
			player.request_inventory("move", [path, ["eq", "bag"]])
	elif ItemDB.is_container(item):
		_container_path = path
		_cursor = 0
	else:
		player.request_inventory("equip", [path])
	_refresh()


func _drop() -> void:
	var path := _cursor_path()
	if player.inventory.get_item(path) != null:
		player.request_inventory("drop", [path])
		if _held == path:
			_held = []


## B: solta o que está na mão; dentro de uma bolsa, volta para a anterior; senão fecha.
func _back() -> void:
	if not _held.is_empty():
		_held = []
	elif _container_path.size() > 1:
		_cursor = _container_path.pop_back()
	else:
		close_requested.emit()
		return
	_refresh()


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
