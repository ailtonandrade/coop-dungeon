class_name GodMode
extends Node
## Modo construtor: o dono do mundo (host, ou o sofá offline) anda pelo mapa com o herói e
## carimba peças prontas onde quiser, como no editor de mapa, só que de dentro do jogo.
## Peça física cai de DROP_HEIGHT, rola e, quando para, fica gravada ali. Cada peça vai para
## a cena do bloco (rodando pelo editor) ou para o save do mundo (jogo exportado): WorldEdits.
##
## Teclado e mouse: G liga/desliga · clique esquerdo coloca no cursor · Q/E ou rodinha troca a
## peça · R gira 45° (Shift+R volta) · Z desfaz a última · Delete apaga a peça do construtor
## no cursor · F edita o conteúdo do contêiner no cursor.
## Controle (liga/desliga pela pausa): X coloca à frente · direcional ◀ ▶ troca · Y gira ·
## B desfaz · RB edita o contêiner à frente.

const DROP_HEIGHT := 1.5
const AHEAD := 2.5
const REMOVE_RADIUS := 1.6
## Peça física que não parar sozinha em tanto tempo é gravada onde estiver.
const SETTLE_MAX := 6.0

var active := false
var slot := -1

var _catalog: Array[Dictionary] = []
var _index := 0
var _yaw := 0.0
var _ghost: Node3D
var _ghost_material: StandardMaterial3D
var _target := Vector3.ZERO
var _target_ok := false
## Peças físicas caindo: [nó, chave do bloco, segundos].
var _settling: Array = []
## Desfazer: ids colocados nesta sessão, do mais antigo ao mais novo.
var _undo: Array[String] = []
var _hud: CanvasLayer
var _title: Label
var _piece: Label
var _hint: Label
var _pad_was := {}
## Painel do conteúdo do contêiner (aberto sobre um contêiner do construtor).
var _loot_panel: PanelContainer
var _loot_items: ItemList
var _loot_inside: ItemList
var _loot_gold: Label
var _loot_target: Node
var _loot_lines: Array = []  # [[item, quantidade]...]
var _loot_gold_value := 0


static func of(node: Node) -> GodMode:
	return node.get_tree().get_first_node_in_group("god_mode") if node.is_inside_tree() else null


func _ready() -> void:
	add_to_group("god_mode")
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material.albedo_color = Color(0.3, 0.95, 1.0, 0.45)
	_build_hud()


## Quem pode construir nesta máquina: o host (ou o sofá offline).
static func allowed() -> bool:
	return NetService.mode != NetService.Mode.CLIENT


func toggle(p_slot: int) -> void:
	if active:
		stop()
	else:
		start(p_slot)


func start(p_slot: int) -> void:
	if not allowed() or _player_of(p_slot) == null:
		return
	slot = p_slot
	active = true
	_catalog = PropBuilder.catalog()
	_index = clampi(_index, 0, maxi(_catalog.size() - 1, 0))
	_player_of(slot).building = true
	_rebuild_ghost()
	_hud.visible = true
	_refresh_hud()
	Chat.system("Modo construtor ligado.")


func stop() -> void:
	if not active:
		return
	if _loot_panel.visible:
		close_loot_editor()
	var player := _player_of(slot)
	if player:
		player.building = false
	active = false
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	_hud.visible = false
	Chat.system("Modo construtor desligado.")


## Peça escolhida agora ({path, name, kind, def}).
func current() -> Dictionary:
	return _catalog[_index] if _index < _catalog.size() else {}


func select_next(step: int) -> void:
	if _catalog.is_empty():
		return
	_index = wrapi(_index + step, 0, _catalog.size())
	Sound.play("ui_move")
	_rebuild_ghost()
	_refresh_hud()


func rotate_piece(step_deg: float) -> void:
	_yaw = wrapf(_yaw + deg_to_rad(step_deg), 0.0, TAU)


## Coloca a peça escolhida no ponto (global). Retorna o nó criado, ou null.
func place_at(point: Vector3) -> Node3D:
	var entry := current()
	var streamer := WorldStreamer.of(self)
	if entry.is_empty() or streamer == null:
		return null
	var found: Array = streamer.chunk_at(point)
	var chunk: Node3D = found[0]
	if chunk == null:
		return null
	var scene := load(String(entry.path)) as PackedScene
	var node := scene.instantiate() as Node3D if scene else null
	if node == null:
		return null
	var id := WorldEdits.new_id()
	node.name = id
	if node is LootContainer:
		node.container_id = id
	var physics := node is RigidBody3D
	WorldEdits.parent_in(chunk).add_child(node)
	node.global_transform = Transform3D(Basis(Vector3.UP, _yaw), point + Vector3.UP * (DROP_HEIGHT if physics else 0.0))
	Sound.play("ui_confirm", point)
	if physics:
		_settling.append([node, found[1], 0.0])
	else:
		_finalize(node, found[1])
	return node


## Desfaz a última peça colocada nesta sessão.
func undo() -> void:
	while not _undo.is_empty():
		var id: String = _undo.pop_back()
		if remove_piece(id):
			return


## Apaga a peça do construtor mais perto do ponto (só as do construtor, não as do editor).
func remove_near(point: Vector3) -> bool:
	var best: Node3D = null
	var best_distance := REMOVE_RADIUS
	for chunk: Node in get_tree().get_nodes_in_group("world_streamer")[0].get_children():
		for node in WorldEdits.parent_in(chunk).get_children():
			if node is Node3D and String(node.name).begins_with(WorldEdits.ID_PREFIX):
				var distance := Combat.flat(node.global_position - point).length()
				if distance < best_distance:
					best = node
					best_distance = distance
	return best != null and remove_piece(String(best.name))


func remove_piece(id: String) -> bool:
	var streamer := WorldStreamer.of(self)
	if streamer == null:
		return false
	var removed := false
	for chunk: Node3D in streamer.get_children():
		var node := WorldEdits.parent_in(chunk).get_node_or_null(NodePath(id))
		if node == null:
			continue
		var key: String = streamer.chunk_at(node.global_position)[1]
		if WorldEdits.saves_in_map_files():
			WorldEdits.remove_from_scene(streamer.scene_path_of(key), id)
		node.queue_free()
		WorldStreamer.bake_navigation.call_deferred(chunk, true)
		removed = true
	if removed:
		_settling = _settling.filter(func(item: Array) -> bool: return is_instance_valid(item[0]) and item[0].name != id)
		NetService.remove_world_edit(id)
		Sound.play("ui_back")
	return removed


## Grava a peça onde ela está agora.
func _finalize(node: Node3D, key: String) -> void:
	var streamer := WorldStreamer.of(self)
	var chunk: Node3D = streamer.chunk_at(node.global_position)[0] if streamer else null
	if chunk == null:
		return
	var entry := {
		"id": String(node.name),
		"key": key,
		"prefab": node.scene_file_path,
		"xform": WorldEdits.pack_xform(chunk.global_transform.affine_inverse() * node.global_transform),
	}
	var in_file := WorldEdits.saves_in_map_files() and WorldEdits.save_to_scene(streamer.scene_path_of(key), entry)
	NetService.add_world_edit(entry, in_file)
	_undo.append(entry.id)
	WorldStreamer.bake_navigation(chunk, true)


func _physics_process(delta: float) -> void:
	for item: Array in _settling.duplicate():
		var body := item[0] as RigidBody3D
		if not is_instance_valid(body):
			_settling.erase(item)
			continue
		item[2] += delta
		if (item[2] > 0.5 and body.sleeping) or item[2] > SETTLE_MAX:
			_settling.erase(item)
			_finalize(body, item[1])
	if not active:
		return
	var player := _player_of(slot)
	if player == null:
		stop()
		return
	_update_target(player)
	_read_pad()
	if _ghost:
		_ghost.visible = _target_ok
		_ghost.global_transform = Transform3D(Basis(Vector3.UP, _yaw), _target)


## Ponto onde a peça vai: o cursor do mouse no chão (teclado) ou à frente do herói (controle).
func _update_target(player: Node3D) -> void:
	var space := player.get_world_3d().direct_space_state
	var camera := get_viewport().get_camera_3d()
	var from: Vector3
	var to: Vector3
	if InputService.device_of(slot) == InputService.KEYBOARD and camera:
		var screen := get_viewport().get_mouse_position()
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			screen = get_viewport().get_visible_rect().size / 2.0
		from = camera.project_ray_origin(screen)
		to = from + camera.project_ray_normal(screen) * 80.0
	else:
		var ahead: Vector3 = player.global_position + (-player.global_basis.z) * AHEAD
		from = ahead + Vector3.UP * 4.0
		to = ahead + Vector3.DOWN * 6.0
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, GameConfig.LAYER_SOLID))
	_target_ok = not hit.is_empty()
	if _target_ok:
		_target = hit.position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_G:
		if active or allowed():
			toggle(slot if active else _keyboard_slot())
			get_viewport().set_input_as_handled()
		return
	if not active or InputService.device_of(slot) != InputService.KEYBOARD or InputService.screen_menu_open or _loot_panel.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if _target_ok:
					place_at(_target)
			MOUSE_BUTTON_WHEEL_UP:
				select_next(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				select_next(1)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_Q:
				select_next(-1)
			KEY_E:
				select_next(1)
			KEY_R:
				rotate_piece(-45.0 if event.shift_pressed else 45.0)
			KEY_Z:
				undo()
			KEY_DELETE, KEY_BACKSPACE:
				if _target_ok:
					remove_near(_target)
			KEY_F:
				open_loot_editor(_container_near(_target) if _target_ok else null)
			_:
				return
		get_viewport().set_input_as_handled()


func _read_pad() -> void:
	var device := InputService.device_of(slot)
	if device < 0 or InputService.screen_menu_open:
		return
	if _loot_panel.visible:
		if InputService.raw_just_pressed(slot, InputService.Action.DODGE):
			close_loot_editor()
		return
	if InputService.raw_just_pressed(slot, InputService.Action.MELEE) and _target_ok:
		place_at(_target)
	if InputService.raw_just_pressed(slot, InputService.Action.POTION):
		rotate_piece(45.0)
	if InputService.raw_just_pressed(slot, InputService.Action.DODGE):
		if _loot_panel.visible:
			close_loot_editor()
		else:
			undo()
	if InputService.raw_just_pressed(slot, InputService.Action.ARTIFACT) and not _loot_panel.visible:
		open_loot_editor(_container_near(_target) if _target_ok else null)
	for button: JoyButton in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		var down := Input.is_joy_button_pressed(device, button)
		if down and not _pad_was.get(button, false):
			select_next(-1 if button == JOY_BUTTON_DPAD_LEFT else 1)
		_pad_was[button] = down


## Contêiner do construtor perto do ponto (os do editor de mapa se editam no editor).
func _container_near(point: Vector3) -> Node:
	var best: Node = null
	var best_distance := 2.5
	for container: Node in get_tree().get_nodes_in_group("containers"):
		if String(container.name).begins_with(WorldEdits.ID_PREFIX):
			var distance := Combat.flat((container as Node3D).global_position - point).length()
			if distance < best_distance:
				best = container
				best_distance = distance
	return best


## Abre o painel do conteúdo de um contêiner colocado pelo construtor.
func open_loot_editor(container: Node) -> void:
	if container == null:
		Sound.play("ui_error")
		return
	_loot_target = container
	_loot_lines = []
	for line: ContainerItem in container.contents:
		if line:
			_loot_lines.append([line.item_id, line.count])
	_loot_gold_value = int(container.gold)
	_loot_items.clear()
	for id: String in ItemDB.ids():
		if id != "gold":
			var index := _loot_items.add_item(ItemDB.display_name({"id": id}))
			_loot_items.set_item_metadata(index, id)
	_refresh_loot()
	_loot_panel.visible = true
	InputService.set_blocked(slot, true)
	_loot_items.grab_focus()
	if _loot_items.item_count > 0:
		_loot_items.select(0)


## Põe mais um do item no contêiner.
func loot_add(item_id: String) -> void:
	for pair: Array in _loot_lines:
		if pair[0] == item_id:
			pair[1] = mini(int(pair[1]) + 1, 99)
			_refresh_loot()
			return
	_loot_lines.append([item_id, 1])
	_refresh_loot()


## Tira um da linha `index` do conteúdo.
func loot_remove(index: int) -> void:
	if index < 0 or index >= _loot_lines.size():
		return
	_loot_lines[index][1] = int(_loot_lines[index][1]) - 1
	if _loot_lines[index][1] <= 0:
		_loot_lines.remove_at(index)
	_refresh_loot()


func loot_gold(delta_gold: int) -> void:
	_loot_gold_value = clampi(_loot_gold_value + delta_gold, 0, 100000)
	_refresh_loot()


## Fecha o painel e grava o conteúdo (na cena do bloco ou no save do mundo).
func close_loot_editor() -> void:
	_loot_panel.visible = false
	if slot >= 0:
		InputService.set_blocked(slot, false)
	if not is_instance_valid(_loot_target):
		return
	var entry := NetService.world_edit(String(_loot_target.name))
	if entry.is_empty():
		return
	entry["loot"] = _loot_lines.duplicate(true)
	entry["gold"] = _loot_gold_value
	WorldEdits.apply_loot(_loot_target, entry)
	var streamer := WorldStreamer.of(self)
	if WorldEdits.saves_in_map_files() and NetService.session_edits.has(entry) and streamer:
		WorldEdits.save_loot_to_scene(streamer.scene_path_of(String(entry.key)), entry)
	else:
		NetService.world_edit_changed(entry)
	Sound.play("ui_confirm")


func _refresh_loot() -> void:
	_loot_inside.clear()
	for pair: Array in _loot_lines:
		_loot_inside.add_item("%dx %s" % [pair[1], ItemDB.display_name({"id": pair[0]})])
	_loot_gold.text = "Parafusos: %d" % _loot_gold_value


func _build_loot_panel() -> void:
	_loot_panel = PanelContainer.new()
	_loot_panel.add_theme_stylebox_override("panel", UiSkin.panel())
	_loot_panel.visible = false
	_loot_panel.set_anchors_preset(Control.PRESET_CENTER)
	_loot_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_loot_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_hud.add_child(_loot_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_loot_panel.add_child(column)
	column.add_child(UiSkin.label("CONTEÚDO DO CONTÊINER", 20, UiSkin.NEON, "Bold", 3))
	var lists := HBoxContainer.new()
	lists.add_theme_constant_override("separation", 14)
	column.add_child(lists)
	var left := VBoxContainer.new()
	lists.add_child(left)
	left.add_child(UiSkin.label("Itens (clique duplo / A põe)", 15, UiSkin.DIM, "SemiBold", 3))
	_loot_items = ItemList.new()
	_loot_items.custom_minimum_size = Vector2(300, 320)
	_loot_items.item_activated.connect(func(index: int) -> void: loot_add(_loot_items.get_item_metadata(index)))
	left.add_child(_loot_items)
	var right := VBoxContainer.new()
	lists.add_child(right)
	right.add_child(UiSkin.label("Dentro (clique duplo tira um)", 15, UiSkin.DIM, "SemiBold", 3))
	_loot_inside = ItemList.new()
	_loot_inside.custom_minimum_size = Vector2(300, 270)
	_loot_inside.item_activated.connect(loot_remove)
	right.add_child(_loot_inside)
	_loot_gold = UiSkin.label("", 16, UiSkin.AMBER, "Bold", 3)
	right.add_child(_loot_gold)
	var gold_row := HBoxContainer.new()
	right.add_child(gold_row)
	for amount: int in [-50, 50, 500]:
		var button := Button.new()
		button.text = "%+d" % amount
		button.pressed.connect(loot_gold.bind(amount))
		gold_row.add_child(button)
	var done := Button.new()
	done.text = "Pronto (B / Esc)"
	done.pressed.connect(close_loot_editor)
	column.add_child(done)


func _input(event: InputEvent) -> void:
	if _loot_panel and _loot_panel.visible and event is InputEventKey and event.pressed \
			and event.physical_keycode == KEY_ESCAPE:
		close_loot_editor()
		get_viewport().set_input_as_handled()


func _keyboard_slot() -> int:
	for candidate in InputService.active_slots():
		if InputService.device_of(candidate) == InputService.KEYBOARD:
			return candidate
	var slots := InputService.active_slots()
	return slots[0] if not slots.is_empty() else -1


func _player_of(p_slot: int) -> Player:
	for player: Player in get_tree().get_nodes_in_group("players"):
		if player.is_local() and player.slot == p_slot:
			return player
	return null


## Fantasma da peça: só o visual, translúcido, sem colisão nem scripts.
func _rebuild_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
	_ghost = Node3D.new()
	_ghost.name = "FantasmaDaPeca"
	add_child(_ghost)
	var entry := current()
	if entry.is_empty():
		return
	var scene := load(String(entry.path)) as PackedScene
	var source := scene.instantiate() if scene else null
	if source == null:
		return
	var model: Variant = source.get("model")
	if source is LootContainer and model is PackedScene:
		var visual := (model as PackedScene).instantiate() as Node3D
		visual.scale = Vector3.ONE * float(source.get("model_scale"))
		source.add_child(visual)
	for mesh: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		var copy := MeshInstance3D.new()
		copy.mesh = mesh.mesh
		copy.material_override = _ghost_material
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		copy.transform = _relative(source, mesh)
		_ghost.add_child(copy)
	source.free()


static func _relative(root: Node, node: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current_node: Node = node
	while current_node and current_node != root:
		if current_node is Node3D:
			xform = (current_node as Node3D).transform * xform
		current_node = current_node.get_parent()
	return xform


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 5
	_hud.visible = false
	add_child(_hud)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiSkin.panel())
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -150
	_hud.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	_title = UiSkin.label("MODO CONSTRUTOR", 16, UiSkin.NEON, "Bold", 3)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_piece = UiSkin.label("", 22, UiSkin.TEXT, "Bold", 4)
	_piece.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_piece)
	_hint = UiSkin.label("", 14, UiSkin.DIM, "Regular", 3)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hint)
	_build_loot_panel()


func _refresh_hud() -> void:
	var entry := current()
	if entry.is_empty():
		_piece.text = "Nenhuma peça em world/prefabs"
		return
	var kind_text: String = {"fixo": "fixo", "conteiner": "contêiner", "fisico": "físico (cai e rola)", "atravessavel": "enfeite"}.get(entry.kind, "peça pronta")
	var before: String = _catalog[wrapi(_index - 1, 0, _catalog.size())].name
	var after: String = _catalog[wrapi(_index + 1, 0, _catalog.size())].name
	_piece.text = "◀ %s   [ %s ]   %s ▶" % [before, entry.name, after]
	_title.text = "MODO CONSTRUTOR · %s · %d/%d" % [kind_text, _index + 1, _catalog.size()]
	var keyboard := InputService.device_of(slot) == InputService.KEYBOARD
	_hint.text = ("Clique coloca · Q/E ou rodinha troca · R gira · Z desfaz · Delete apaga · F conteúdo do contêiner · G sai" if keyboard
			else "X coloca · ◀ ▶ troca · Y gira · B desfaz · RB conteúdo do contêiner · pausa > Modo construtor sai")
	if WorldEdits.saves_in_map_files():
		_hint.text += "\nGrava direto nas cenas dos blocos (mapa oficial)."
	else:
		_hint.text += "\nGrava no save deste mundo."
