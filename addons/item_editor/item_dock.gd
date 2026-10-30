@tool
extends VBoxContainer
## Painel "Itens": lista as fichas, cria/duplica/apaga, traz modelos 3D, mostra o herói
## segurando o item (ajuste de encaixe e tamanho ao vivo) e gera o ícone do inventário.
## Os campos da ficha (nome, atributos, preço, lojas, loot, encaixe) ficam no Inspector;
## cada mudança é salva sozinha e a prévia acompanha.

const Tools := preload("res://addons/item_editor/item_tools.gd")
const HERO := "res://assets/characters/Adventurer.glb"
const SAVE_DELAY := 0.35
const ICON_SIZE := 128

var plugin: EditorPlugin

var _search: LineEdit
var _list: ItemList
var _ids: Array = []
var _current: ItemDef
var _viewport: SubViewport
var _camera: Camera3D
var _stage: Node3D
var _mode_button: Button
var _info: RichTextLabel
var _status: Label
var _file_dialog: EditorFileDialog
var _new_dialog: ConfirmationDialog
var _new_name: LineEdit
var _new_slot: OptionButton
var _new_from: ItemDef
var _delete_dialog: ConfirmationDialog

var _on_ground := false
var _yaw := 0.5
var _distance := 1.6
var _focus := Vector3(0, 1.0, 0)
var _save_timer := 0.0
var _dirty := false
var _pending_model := ""
var _pending_wait := 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	custom_minimum_size = Vector2(300, 0)
	add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = "Itens do jogo"
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)

	_search = LineEdit.new()
	_search.placeholder_text = "Buscar item..."
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t: String) -> void: _refresh_list())
	add_child(_search)

	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 170)
	_list.item_selected.connect(func(index: int) -> void: _select(_ids[index]))
	add_child(_list)

	var row := HBoxContainer.new()
	add_child(row)
	_button(row, "Novo", "Cria uma ficha de item nova.", _ask_new.bind(null))
	_button(row, "Duplicar", "Cópia da ficha selecionada (bom para variações).", func() -> void:
		if _current:
			_ask_new(_current))
	_button(row, "Apagar", "Apaga a ficha selecionada.", _ask_delete)

	var model_row := HBoxContainer.new()
	add_child(model_row)
	_button(model_row, "Importar modelo", "Escolhe um .glb, .gltf, .fbx, .obj ou .blend em qualquer pasta; ele é copiado para assets/items/<id>/.", _pick_model)
	_button(model_row, "Tirar modelo", "Volta para o modelo provisório de blocos.", func() -> void:
		if _current:
			_current.model = null
			_changed())

	_build_preview()

	var preview_row := HBoxContainer.new()
	add_child(preview_row)
	_mode_button = _button(preview_row, "Ver no chão", "Alterna entre o herói segurando o item e o item caído no chão (loot).", func() -> void:
		_on_ground = not _on_ground
		_mode_button.text = "Ver no herói" if _on_ground else "Ver no chão"
		_rebuild_preview())
	_button(preview_row, "Encaixe", "Liga o encaixe próprio começando do padrão do tipo, para ajustar posição e rotação no Inspector.", _use_default_mount)
	_button(preview_row, "Gerar ícone", "Fotografa o modelo para o ícone do inventário.", _make_icon)

	var hint := Label.new()
	hint.text = "Arraste na prévia para girar, roda do mouse para zoom.\nCampos da ficha: Inspector (salva sozinho)."
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.6)
	add_child(hint)

	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.custom_minimum_size = Vector2(0, 60)
	add_child(_info)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.modulate = Color(0.7, 0.9, 1.0)
	add_child(_status)

	_build_dialogs()
	_refresh_shops()
	_refresh_list()
	EditorInterface.get_inspector().property_edited.connect(_on_property_edited)


func _exit_tree() -> void:
	if Engine.is_editor_hint() and EditorInterface.get_inspector().property_edited.is_connected(_on_property_edited):
		EditorInterface.get_inspector().property_edited.disconnect(_on_property_edited)


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if _dirty:
		_save_timer -= delta
		if _save_timer <= 0.0:
			_save_now()
	if _pending_model:
		_pending_wait -= delta
		var filesystem := EditorInterface.get_resource_filesystem()
		if ResourceLoader.exists(_pending_model) and not filesystem.is_scanning():
			var scene := load(_pending_model) as PackedScene
			if scene and _current:
				_current.model = scene
				_status.text = "Modelo importado: %s" % _pending_model
				_pending_model = ""
				_changed()
		elif _pending_wait <= 0.0:
			_status.text = "O modelo não terminou de importar. Veja a aba Saída e tente de novo."
			_pending_model = ""


## Lista

func _refresh_list(select_id := "") -> void:
	var keep: String = select_id if select_id else (_current.id if _current else "")
	_list.clear()
	_ids.clear()
	var filter := _search.text.strip_edges().to_lower()
	for id: String in ItemDB.ids():
		var item := ItemDB.source(id)
		var text := "%s  ·  %s" % [item.display_name, ItemDB.SLOT_NAMES.get(item.slot, item.slot)]
		if filter and not (text.to_lower().contains(filter) or id.contains(filter)):
			continue
		var index := _list.add_item(text)
		_list.set_item_tooltip(index, "%s\n%s" % [id, Tools.where_text(item)])
		if not Tools.validate(item).is_empty():
			_list.set_item_custom_fg_color(index, Color(1.0, 0.75, 0.3))
		_ids.append(id)
		if id == keep:
			_list.select(index)
	if keep and ItemDB.source(keep) and (_current == null or _current.id != keep):
		_select(keep)


func _select(id: String) -> void:
	_save_now()
	_current = ItemDB.source(id)
	if _current == null:
		return
	EditorInterface.edit_resource(_current)
	_rebuild_preview()
	_refresh_info()


func _on_property_edited(_property: String) -> void:
	if _current and EditorInterface.get_inspector().get_edited_object() == _current:
		_changed()


## Algo mudou na ficha atual: salva daqui a pouco (junta várias mudanças seguidas).
func _changed() -> void:
	_dirty = true
	_save_timer = SAVE_DELAY
	_refresh_info()


func _save_now() -> void:
	if not _dirty or _current == null:
		return
	_dirty = false
	if Tools.save_item(_current) != OK:
		_status.text = "Não deu para salvar %s." % _current.resource_path
		return
	_refresh_list(_current.id)
	_rebuild_preview()
	_refresh_info()


func _refresh_info() -> void:
	if _current == null:
		_info.text = "[i]Escolha um item ou crie um novo.[/i]"
		return
	var text := "[b]%s[/b]  [color=gray](%s)[/color]\n%s" % [_current.display_name, _current.id, Tools.where_text(_current)]
	var issues := Tools.validate(_current)
	if issues.is_empty():
		text += "\n[color=#7f7]Ficha ok.[/color]"
	for issue in issues:
		text += "\n[color=#fb4]• %s[/color]" % issue
	_info.text = text


func _refresh_shops() -> void:
	var shops := PackedStringArray()
	var map := load(GameConfig.WORLD_MAP) as WorldMap
	if map:
		for shop in Tools.list_shops(map):
			shops.append(shop.key)
	ItemDef.set_known_shops(shops)


## Novo / duplicar / apagar

func _build_dialogs() -> void:
	_new_dialog = ConfirmationDialog.new()
	_new_dialog.title = "Item novo"
	var box := VBoxContainer.new()
	_new_dialog.add_child(box)
	var name_label := Label.new()
	name_label.text = "Nome (como aparece no jogo):"
	box.add_child(name_label)
	_new_name = LineEdit.new()
	_new_name.custom_minimum_size = Vector2(320, 0)
	box.add_child(_new_name)
	var slot_label := Label.new()
	slot_label.text = "Casa do corpo:"
	box.add_child(slot_label)
	_new_slot = OptionButton.new()
	for slot: String in ItemDB.EQUIP_SLOTS:
		_new_slot.add_item(ItemDB.SLOT_NAMES[slot])
		_new_slot.set_item_metadata(_new_slot.item_count - 1, slot)
	box.add_child(_new_slot)
	_new_dialog.confirmed.connect(_create_new)
	_new_dialog.register_text_enter(_new_name)
	add_child(_new_dialog)

	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Apagar item"
	_delete_dialog.confirmed.connect(_delete_current)
	add_child(_delete_dialog)

	_file_dialog = EditorFileDialog.new()
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	_file_dialog.title = "Modelo 3D do item"
	_file_dialog.add_filter("*.glb, *.gltf, *.fbx, *.obj, *.blend", "Modelos 3D")
	_file_dialog.file_selected.connect(_on_model_chosen)
	add_child(_file_dialog)


func _ask_new(template: ItemDef) -> void:
	_new_from = template
	_new_dialog.title = "Duplicar %s" % template.display_name if template else "Item novo"
	_new_name.text = "%s (cópia)" % template.display_name if template else ""
	_new_slot.disabled = template != null
	if template:
		_new_slot.select(ItemDB.EQUIP_SLOTS.find(template.slot))
	_refresh_shops()
	_new_dialog.popup_centered()
	_new_name.grab_focus.call_deferred()


func _create_new() -> void:
	var display_name := _new_name.text.strip_edges()
	if display_name.is_empty():
		_status.text = "Dê um nome ao item."
		return
	var base := Tools.slugify(display_name)
	var id := base
	var n := 2
	while ItemDB.has(id) or FileAccess.file_exists(Tools.path_of(id)):
		id = "%s_%d" % [base, n]
		n += 1
	var slot: String = _new_slot.get_item_metadata(_new_slot.selected)
	var item := Tools.create_item(id, display_name, slot, _new_from)
	if item == null:
		_status.text = "Não deu para criar %s." % id
		return
	_status.text = "Criado: %s (%s)" % [display_name, Tools.path_of(id)]
	EditorInterface.get_resource_filesystem().scan()
	_current = null
	_refresh_list(id)


func _ask_delete() -> void:
	if _current == null:
		return
	_delete_dialog.dialog_text = "Apagar a ficha \"%s\" (%s)?\nQuem já tem esse item nos saves perde ele." % [_current.display_name, _current.id]
	_delete_dialog.popup_centered()


func _delete_current() -> void:
	var id := _current.id
	_dirty = false
	_current = null
	Tools.delete_item(id)
	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.inspect_object(null)
	_status.text = "Apagado: %s" % id
	_refresh_list()
	_rebuild_preview()
	_refresh_info()


## Modelo

func _pick_model() -> void:
	if _current == null:
		_status.text = "Escolha ou crie um item primeiro."
		return
	_file_dialog.popup_file_dialog()


func _on_model_chosen(path: String) -> void:
	var local := ProjectSettings.localize_path(path)
	if local.begins_with("res://"):
		# Já está dentro do projeto: usa direto.
		var scene := load(local) as PackedScene
		if scene:
			_current.model = scene
			_status.text = "Modelo: %s" % local
			_changed()
			return
	var target := Tools.import_model(path, _current.id)
	if target.is_empty():
		_status.text = "Não deu para copiar o modelo (formato aceito: glb, gltf, fbx, obj, blend)."
		return
	_status.text = "Importando %s..." % target
	_pending_model = target
	_pending_wait = 60.0
	EditorInterface.get_resource_filesystem().scan()


func _use_default_mount() -> void:
	if _current == null:
		return
	var mount := Tools.default_mount(_current.look)
	_current.custom_mount = true
	_current.mount_bone = mount[0]
	_current.mount_position = mount[1]
	_current.mount_rotation = mount[2]
	_current.notify_property_list_changed()
	EditorInterface.edit_resource(_current)
	_changed()


## Prévia 3D

func _build_preview() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(0, 300)
	container.gui_input.connect(_on_preview_input)
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.09, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.7)
	env.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 35, 0)
	light.shadow_enabled = true
	_viewport.add_child(light)

	var floor := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.7
	disc.bottom_radius = 0.7
	disc.height = 0.02
	floor.mesh = disc
	floor.position.y = -0.01
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.16, 0.15, 0.15)
	floor.material_override = floor_material
	_viewport.add_child(floor)

	_camera = Camera3D.new()
	_camera.fov = 40.0
	_viewport.add_child(_camera)
	_stage = Node3D.new()
	_viewport.add_child(_stage)
	_place_camera()


func _rebuild_preview() -> void:
	for child in _stage.get_children():
		child.queue_free()
	if _current == null or not ItemDB.has(_current.id):
		return
	var entry := {"id": _current.id, "rarity": "common", "power": 1}
	if _on_ground:
		var piece := ItemVisuals.build(entry)
		piece.scale = Vector3.ONE * 1.6 * _current.ground_scale
		piece.position.y = 0.05
		_stage.add_child(piece)
		var box := Tools.bounds(piece)
		_focus = piece.position + box.get_center() * piece.scale
		_distance = clampf(box.size.length() * piece.scale.x * 1.8, 0.6, 6.0)
	else:
		var hero := (load(HERO) as PackedScene).instantiate() as Node3D
		_stage.add_child(hero)
		var anim: AnimationPlayer = hero.find_child("AnimationPlayer", true, false)
		ItemVisuals.dress(hero, [entry])
		if anim and anim.has_animation("Idle"):
			anim.play("Idle")
			anim.seek(0.0, true)
			anim.pause()
		var framing: Array = {"head": [1.45, 1.1], "amulet": [1.3, 1.1], "legs": [0.6, 1.8], "feet": [0.3, 1.4],
				"bag": [1.1, 1.8], "chest": [1.1, 1.8]}.get(_current.slot, [1.0, 2.4])
		_focus = Vector3(0, framing[0], 0)
		_distance = framing[1]
	_place_camera()


func _place_camera() -> void:
	if _camera == null:
		return
	var direction := Vector3(sin(_yaw), 0.45, cos(_yaw)).normalized()
	_camera.position = _focus + direction * _distance
	_camera.look_at(_focus)


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_yaw -= event.relative.x * 0.01
		_place_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(_distance * 0.9, 0.3)
			_place_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(_distance * 1.1, 8.0)
			_place_camera()


## Ícone: fotografa o item sozinho, fundo transparente, armas na diagonal.
func _make_icon() -> void:
	if _current == null:
		return
	_save_now()
	var studio := SubViewport.new()
	studio.size = Vector2i(ICON_SIZE, ICON_SIZE)
	studio.transparent_bg = true
	studio.own_world_3d = true
	studio.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(studio)
	for angles: Vector3 in [Vector3(-40, 30, 0), Vector3(-20, -150, 0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = angles
		light.light_energy = 1.2 if angles.y > 0 else 0.5
		studio.add_child(light)
	var holder := Node3D.new()
	studio.add_child(holder)
	var piece := ItemVisuals.build({"id": _current.id, "rarity": "common", "power": 1})
	holder.add_child(piece)
	if _current.slot in ["melee", "ranged"]:
		piece.rotation_degrees = Vector3(0, 90, -45)
	else:
		piece.rotation_degrees = Vector3(15, -30, 0)
	var box := Tools.bounds(holder)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(box.size.x, box.size.y) * 1.15 + 0.01
	camera.position = box.get_center() + Vector3(0, 0, box.size.z + 2.0)
	studio.add_child(camera)
	camera.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := studio.get_texture().get_image()
	studio.queue_free()
	var icon := Tools.save_icon(image, _current.id)
	if icon == null:
		_status.text = "Não deu para salvar o ícone."
		return
	_current.icon = icon
	_status.text = "Ícone gerado: %s" % icon.resource_path
	EditorInterface.edit_resource(_current)
	_changed()


func _button(parent: Control, text: String, tooltip: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.pressed.connect(action)
	parent.add_child(button)
	return button
