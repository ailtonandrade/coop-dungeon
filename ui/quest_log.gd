class_name QuestLog
extends VBoxContainer
## questLog no canto da tela: as missões em andamento (até MAX), com o título, os objetivos
## (caixinha, nome e contador) e, quando termina, "Volte para <NPC>". Pisca quando muda. Embaixo,
## o PRÓXIMO PASSO da história (missão principal que já dá para pegar: "Fale com Dona Alda").

const MAX := 3
const AMBER := Color(1.0, 0.8, 0.28)
const TEXT := Color(0.92, 0.9, 0.84)
const DONE := Color(0.55, 0.95, 0.55)

var _flash := {}  # id da missão -> tempo de destaque restante
var _distance_check := 0.0


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Quests.quests_changed.connect(_rebuild)
	Quests.focus_changed.connect(_rebuild)
	# Fato novo pode liberar o próximo passo da história.
	Lore.facts_changed.connect(_rebuild)
	Quests.quest_event.connect(func(id: String, state: String) -> void:
		_flash[id] = 1.6
		if state == "pronta":
			Sound.play("quest_ready")
		elif state == "ativa":
			Sound.play("quest_accept")
		_rebuild())
	_rebuild()


func _process(delta: float) -> void:
	_distance_check -= delta
	if _distance_check <= 0.0:
		_distance_check = 0.5
		_update_distances()
	if _flash.is_empty():
		return
	for id: String in _flash.keys():
		_flash[id] = float(_flash[id]) - delta
		if _flash[id] <= 0.0:
			_flash.erase(id)
	for block in get_children():
		var id := String(block.get_meta("quest_id", ""))
		var glow := clampf(float(_flash.get(id, 0.0)), 0.0, 1.0)
		var alpha := 0.6 if block.has_meta("dim") else 1.0
		block.modulate = Color(1.0 + glow * 0.6, 1.0 + glow * 0.5, 1.0 + glow * 0.1, alpha)


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	# Todas (em andamento e próximos passos), a RASTREADA primeiro e em destaque; as outras mais
	# apagadas. Qual rastrear se escolhe na tela de missões (roda do inventário).
	var list := Quests.guided()
	visible = not list.is_empty()
	var focus := Quests.focus()
	if focus:
		list.erase(focus)
		list.push_front(focus)
	for i in mini(list.size(), MAX):
		var quest := list[i]
		var block := _block(quest) if not Quests.state_of(quest.id).is_empty() else _next_block(quest)
		if quest != focus:
			block.set_meta("dim", true)
			block.modulate.a = 0.6
		add_child(block)
	if list.size() > MAX:
		add_child(UiSkin.label(Txt.t("+%d na tela de missões") % (list.size() - MAX), 12, Color(TEXT, 0.6), "Regular", 2))


func _block(quest: QuestDef) -> Control:
	var panel := PanelContainer.new()
	panel.set_meta("quest_id", quest.id)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.42)
	style.border_color = Color(AMBER, 0.55)
	style.border_width_left = 3
	style.set_content_margin_all(8)
	style.content_margin_left = 12
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	panel.add_child(column)
	var info := _top_with_icon(column, quest, style)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	info.add_child(head)
	var diamond := Control.new()
	diamond.custom_minimum_size = Vector2(16, 16)
	diamond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	diamond.draw.connect(func() -> void:
		var c := Vector2(8, 8)
		diamond.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(7, 0), c + Vector2(0, 7), c + Vector2(-7, 0)]), AMBER)
		diamond.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -3), c + Vector2(3, 0), c + Vector2(0, 3), c + Vector2(-3, 0)]), Color(0, 0, 0, 0.6)))
	head.add_child(diamond)
	head.add_child(UiSkin.label(Txt.t(quest.title).to_upper(), 17, AMBER, "Bold", 3))
	# Distância até o próximo passo (o losango amarelo do minimapa).
	var distance := UiSkin.label("", 14, Color(AMBER, 0.75), "SemiBold", 2)
	distance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	distance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(distance)
	panel.set_meta("distance_label", distance)
	if not quest.summary.is_empty():
		var summary := UiSkin.label(Txt.t(quest.summary), 13, Color(TEXT, 0.7), "Regular", 2)
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(summary)
	var ready := Quests.state_of(quest.id) == "pronta"
	for i in Quests.shown_objectives(quest):
		var objective := quest.objectives[i]
		var count := Quests.count_of(quest.id, i)
		var goal := objective.goal()
		var done := count >= goal
		column.add_child(_line(done, "%s  %d/%d" % [Txt.t(objective.text()), mini(count, goal), goal]))
	if ready:
		column.add_child(_line(false, Txt.t("Volte para %s") % quest.giver, AMBER))
	return panel


func _next_block(quest: QuestDef) -> Control:
	var panel := PanelContainer.new()
	panel.set_meta("quest_id", quest.id)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.32)
	style.border_color = Color(AMBER, 0.35)
	style.border_width_left = 3
	style.set_content_margin_all(8)
	style.content_margin_left = 12
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	panel.add_child(column)
	var info := _top_with_icon(column, quest, style)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	info.add_child(head)
	head.add_child(UiSkin.label(Txt.t("PRÓXIMO PASSO"), 13, Color(AMBER, 0.8), "Bold", 3))
	var distance := UiSkin.label("", 14, Color(AMBER, 0.75), "SemiBold", 2)
	distance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	distance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(distance)
	panel.set_meta("distance_label", distance)
	info.add_child(UiSkin.label("★ " + Txt.t(quest.title), 15, TEXT, "Bold", 3))
	column.add_child(_line(false, Quests.start_hint(quest), AMBER))
	return panel


## Topo do bloco: título e resumo à esquerda; na missão RASTREADA, o mesmo sinal do minimapa e
## do NPC ("!", "?" ou "◆", na cor da rastreada) à direita, no meio. Devolve a coluna da esquerda.
func _top_with_icon(column: VBoxContainer, quest: QuestDef, style: StyleBoxFlat) -> VBoxContainer:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	column.add_child(top)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	var focus := Quests.focus()
	if focus and focus.id == quest.id:
		style.border_color = Color(Quests.FOCUS_COLOR, 0.8)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(30, 30)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.draw.connect(func() -> void:
			WorldMapPanel.draw_quest_mark(icon, Vector2(15, 15), Quests.focus_symbol(), 13.0, Quests.FOCUS_COLOR))
		top.add_child(icon)
	return info


func _update_distances() -> void:
	var from := Vector3.ZERO
	var found := false
	for player: Node3D in get_tree().get_nodes_in_group("players"):
		if player.has_method("is_local") and player.is_local():
			from = player.global_position
			found = true
			break
	for block in get_children():
		var label := block.get_meta("distance_label", null) as Label
		var quest := Quests.def(String(block.get_meta("quest_id", "")))
		if label == null or quest == null or not found:
			continue
		var target: Variant = Quests.target_of(quest, from)
		if target is Vector3:
			label.text = "%d m" % roundi(Vector2(target.x - from.x, target.z - from.z).length())
		else:
			label.text = Txt.t("no inventário") if _next_in_inventory(quest) else ""


## O próximo passo é ler/usar/pegar (acontece no inventário, sem ponto no mapa)?
static func _next_in_inventory(quest: QuestDef) -> bool:
	if Quests.state_of(quest.id) != "ativa":
		return false
	for i in quest.objectives.size():
		if not Quests.objective_done(quest, i):
			return quest.objectives[i].kind in QuestObjective.INVENTORY_KINDS
	return false


func _line(done: bool, text: String, color := TEXT) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var box := Control.new()
	box.custom_minimum_size = Vector2(14, 14)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.draw.connect(func() -> void:
		box.draw_rect(Rect2(1, 1, 12, 12), Color(color, 0.9), false, 1.5)
		if done:
			box.draw_rect(Rect2(4, 4, 6, 6), DONE))
	row.add_child(box)
	row.add_child(UiSkin.label(text, 14, DONE if done else color, "Regular", 2))
	return row
