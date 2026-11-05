class_name BaseBuildMode
extends CanvasLayer
## Modo de construção do jogador (a base/abrigo): liga com /construir no chat (teclado) ou
## segurando LB + RB (controle). Mostra um fantasma da peça à frente do herói, encaixado na
## grade da base (BaseCatalog.GRID), verde se dá para construir e vermelho se não; o host
## confere tudo de novo (Player.apply_inventory_command "base_*").
##
## Teclado/mouse: clique esquerdo constrói · clique direito desmonta · Q/E troca a peça ·
## T troca o material · R gira · /construir sai.
## Controle: X constrói · RT desmonta · ◀ ▶ troca a peça · ▲ troca o material · Y gira · B sai.

const AHEAD := 2.6

var slot := -1
var player: Player

var _recipe_index := 0
var _material_index := 0
var _yaw_steps := 0
var _ghost: Node3D
var _ghost_key := ""
var _ghost_ok := StandardMaterial3D.new()
var _ghost_bad := StandardMaterial3D.new()
var _target := Vector3.ZERO
var _target_yaw := 0.0
var _problem := ""
var _panel: PanelContainer
var _title: Label
var _info: Label
var _hint: Label
var _pad_was := {}


func open_for(p_player: Player) -> void:
	player = p_player
	slot = p_player.slot
	player.request_inventory("base_mode", [true])
	Chat.local_note(Txt.t("Modo de construção ligado (/construir de novo para sair)."))


func close() -> void:
	if is_instance_valid(player):
		player.request_inventory("base_mode", [false])
	if _ghost:
		_ghost.queue_free()
	queue_free()


func _ready() -> void:
	layer = 6
	for material: StandardMaterial3D in [_ghost_ok, _ghost_bad]:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = false
	_ghost_ok.albedo_color = Color(0.35, 1.0, 0.7, 0.45)
	_ghost_bad.albedo_color = Color(1.0, 0.35, 0.3, 0.45)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiSkin.panel())
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_panel.position.y = 70
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_panel.add_child(column)
	_title = UiSkin.label("", 18, UiSkin.NEON, "Bold", 3)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_info = UiSkin.label("", 15, UiSkin.TEXT, "Regular", 2)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_info)
	_hint = UiSkin.label("", 12, UiSkin.DIM, "Regular", 2)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hint)


func recipes() -> Array:
	if not is_instance_valid(player):
		return []
	var list := BaseCatalog.unlocked(player.progress.level)
	var has_base := not BaseManager.base_of(BaseManager.key_of(player)).is_empty()
	return list.filter(func(id: String) -> bool: return (id == "terminal") != has_base)


func current_recipe() -> String:
	var list := recipes()
	if list.is_empty():
		return ""
	_recipe_index = posmod(_recipe_index, list.size())
	return list[_recipe_index]


func current_material() -> String:
	return BaseCatalog.MATERIALS[posmod(_material_index, BaseCatalog.MATERIALS.size())]


func _process(_delta: float) -> void:
	if not is_instance_valid(player) or player.is_downed():
		close()
		return
	_read_input()
	_update_target()
	_update_ghost()
	_refresh_panel()


func _read_input() -> void:
	var keyboard := InputService.device_of(slot) == InputService.KEYBOARD
	if InputService.raw_just_pressed(slot, InputService.Action.MELEE):
		_build()
	if InputService.raw_just_pressed(slot, InputService.Action.RANGED):
		player.request_inventory("base_remove", [_target])
	if keyboard:
		if InputService.raw_just_pressed(slot, InputService.Action.ARTIFACT):
			_step_recipe(-1)
		if InputService.raw_just_pressed(slot, InputService.Action.POTION):
			_step_recipe(1)
		if _key_once(KEY_T):
			_material_index += 1
			Sound.play("ui_move")
		if _key_once(KEY_R):
			_yaw_steps += 1
			Sound.play("ui_move")
	else:
		var device := InputService.device_of(slot)
		if _pad_once(device, JOY_BUTTON_DPAD_LEFT):
			_step_recipe(-1)
		if _pad_once(device, JOY_BUTTON_DPAD_RIGHT):
			_step_recipe(1)
		if _pad_once(device, JOY_BUTTON_DPAD_UP):
			_material_index += 1
			Sound.play("ui_move")
		if InputService.raw_just_pressed(slot, InputService.Action.POTION):
			_yaw_steps += 1
			Sound.play("ui_move")
		if InputService.raw_just_pressed(slot, InputService.Action.DODGE):
			close()


func _step_recipe(step: int) -> void:
	_recipe_index += step
	_yaw_steps = 0
	Sound.play("ui_move")


var _keys_was := {}


func _key_once(key: Key) -> bool:
	var down := Input.is_physical_key_pressed(key) and not InputService.typing()
	var once: bool = down and not _keys_was.get(key, false)
	_keys_was[key] = down
	return once


func _pad_once(device: int, button: JoyButton) -> bool:
	var down := Input.is_joy_button_pressed(device, button)
	var once: bool = down and not _pad_was.get(button, false)
	_pad_was[button] = down
	return once


## Onde a peça vai: à frente do herói, encaixada na grade da base (parede na borda da casa).
func _update_target() -> void:
	var recipe := current_recipe()
	var forward := -player.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	var ahead := player.global_position + forward * AHEAD
	var base := BaseManager.base_of(BaseManager.key_of(player))
	var origin := BaseManager.center_of(base) if not base.is_empty() else player.global_position
	var grid := BaseCatalog.GRID
	var kind: String = BaseCatalog.RECIPES.get(recipe, {}).get("kind", "")
	match kind:
		"floor", "roof":
			_target = Vector3(origin.x + roundf((ahead.x - origin.x) / grid) * grid, origin.y, origin.z + roundf((ahead.z - origin.z) / grid) * grid)
			_target_yaw = 0.0
		"wall", "door":
			# Borda da casa mais perto do ponto à frente, no eixo para onde o herói olha (R troca).
			var along_x := absf(forward.x) > absf(forward.z)
			if _yaw_steps % 2 == 1:
				along_x = not along_x
			var cx := (ahead.x - origin.x) / grid
			var cz := (ahead.z - origin.z) / grid
			if along_x:
				_target = Vector3(origin.x + (floorf(cx) + 0.5) * grid, origin.y, origin.z + roundf(cz) * grid)
				_target_yaw = PI / 2.0
			else:
				_target = Vector3(origin.x + roundf(cx) * grid, origin.y, origin.z + (floorf(cz) + 0.5) * grid)
				_target_yaw = 0.0
		_:
			_target = Vector3(snappedf(ahead.x, 0.5), player.global_position.y if base.is_empty() else origin.y, snappedf(ahead.z, 0.5))
			_target_yaw = atan2(-forward.x, -forward.z) if kind == "terminal" else snappedf(atan2(-forward.x, -forward.z), PI / 2.0) + _yaw_steps * PI / 2.0
	if kind in ["floor", "roof"]:
		_target_yaw = 0.0
	_problem = _local_problem(recipe)


## O que dá para saber aqui antes de pedir ao host (ele confere de novo).
func _local_problem(recipe: String) -> String:
	if recipe.is_empty():
		return Txt.t("Nenhuma receita ainda (o terminal de base libera no nível %d).") % BaseCatalog.RECIPES.terminal.level
	var costs := BaseCatalog.cost(recipe, current_material())
	if not BaseCatalog.can_afford(player.inventory, costs):
		return Txt.t("Faltam materiais (%s)") % BaseCatalog.cost_text(costs)
	var key := BaseManager.key_of(player)
	if recipe == "terminal":
		return BaseManager.terminal_problem(player.get_tree(), _target, key)
	var base := BaseManager.base_of(key)
	var center := BaseManager.center_of(base)
	if Vector2(_target.x - center.x, _target.z - center.z).length() > BaseCatalog.BASE_RADIUS - 0.5:
		return "Fora da área do seu abrigo"
	return BaseManager.overlap_problem(base, recipe, _target, _target_yaw)


func _build() -> void:
	var recipe := current_recipe()
	if recipe.is_empty():
		Sound.play("ui_error")
		return
	if recipe == "terminal":
		player.request_inventory("base_terminal", [_target])
	else:
		player.request_inventory("base_build", [recipe, current_material(), _target, _target_yaw])


func _update_ghost() -> void:
	var recipe := current_recipe()
	var kind: String = BaseCatalog.RECIPES.get(recipe, {}).get("kind", "")
	var key := "%s/%s" % [kind, current_material()]
	if key != _ghost_key:
		if _ghost:
			_ghost.queue_free()
		_ghost = BasePieces.build(kind, current_material(), true) if not kind.is_empty() else null
		_ghost_key = key
		if _ghost:
			player.get_tree().current_scene.add_child(_ghost)
	if _ghost == null:
		return
	_ghost.global_position = _target
	_ghost.rotation.y = _target_yaw
	var material := _ghost_ok if _problem.is_empty() else _ghost_bad
	for mesh: MeshInstance3D in _ghost.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for light: Light3D in _ghost.find_children("*", "Light3D", true, false):
		light.visible = false


func _refresh_panel() -> void:
	var recipe := current_recipe()
	var list := recipes()
	var name_text := BaseCatalog.recipe_name(recipe) if not recipe.is_empty() else "—"
	if BaseCatalog.is_structure(recipe):
		name_text += " · " + ItemDB.ammo_name(current_material())
	_title.text = Txt.t("CONSTRUÇÃO · %s (%d/%d)") % [name_text.to_upper(), (_recipe_index % maxi(list.size(), 1)) + 1, list.size()]
	var parts := PackedStringArray()
	if not recipe.is_empty():
		parts.append(Txt.t("Custo: %s") % BaseCatalog.cost_text(BaseCatalog.cost(recipe, current_material())))
	var stock := PackedStringArray()
	for material: String in BaseCatalog.MATERIALS:
		stock.append("%s %d" % [ItemDB.ammo_name(material), player.inventory.ammo_of(material)])
	parts.append(" · ".join(stock))
	if not _problem.is_empty():
		parts.append("⚠ " + Txt.t(_problem))
	_info.text = "\n".join(parts)
	_info.add_theme_color_override("font_color", UiSkin.TEXT if _problem.is_empty() else Color(1.0, 0.65, 0.55))
	var keyboard := InputService.device_of(slot) == InputService.KEYBOARD
	_hint.text = Txt.t("Clique constrói · clique direito desmonta · Q/E peça · T material · R gira · /construir sai") if keyboard \
			else Txt.t("X constrói · RT desmonta · ◀ ▶ peça · ▲ material · Y gira · B sai")
