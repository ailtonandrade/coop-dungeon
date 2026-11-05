class_name QuestsPanel
extends PanelContainer
## Missões do grupo: as em andamento (com os objetivos) e as já concluídas, separadas em
## principais e secundárias. Na roda dos painéis do inventário: RB / Q passa para o próximo.
##
## Controle: analógico/direcional rola · RB volta ao inventário · B / Back fecha.
## Teclado: W/S ou roda do mouse rola · Q · Shift / I.

signal close_requested
signal switch_requested

const SCROLL_SPEED := 600.0

var player: Player
## Trocando para outro painel do mesmo jogador: ao sair, não solta o herói.
var keep_blocked := false

var _scroll: ScrollContainer
var _list: VBoxContainer
var _header: Label


func open_for(p_player: Player) -> void:
	player = p_player
	InputService.set_blocked(player.slot, true)
	_build()
	_refresh()
	Quests.quests_changed.connect(_refresh)


func _exit_tree() -> void:
	if is_instance_valid(player) and not keep_blocked:
		InputService.set_blocked(player.slot, false)


func _build() -> void:
	add_theme_stylebox_override("panel", UiSkin.panel())
	custom_minimum_size = Vector2(500, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var color := GameConfig.PLAYER_COLORS[player.index]
	column.add_child(UiSkin.label(Txt.t("P%d %s · missões") % [player.index + 1, player.display_name], 20, color, "Bold", 4))
	_header = UiSkin.label("", 14, UiSkin.DIM, "Regular", 3)
	_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_header)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(480, 380)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	column.add_child(UiSkin.label("Do grupo todo · RB/Q inventário · B fecha", 13, Color(1, 1, 1, 0.6), "Regular", 3))


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	var active := Quests.tracked()
	var done := Quests.finished()
	var main_done := done.filter(func(q: QuestDef) -> bool: return q.category == "principal").size()
	_header.text = Txt.t("Em andamento: %d · concluídas: %d (%d principais, %d secundárias)") \
			% [active.size(), done.size(), main_done, done.size() - main_done]
	_section(Txt.t("EM ANDAMENTO"), active.is_empty())
	for quest in active:
		_list.add_child(_row(quest, false))
	for category: String in ["principal", "secundaria"]:
		var list := done.filter(func(q: QuestDef) -> bool: return q.category == category)
		_section(Txt.t("PRINCIPAIS CONCLUÍDAS") if category == "principal" else Txt.t("SECUNDÁRIAS CONCLUÍDAS"), list.is_empty())
		for quest: QuestDef in list:
			_list.add_child(_row(quest, true))


func _section(title: String, empty: bool) -> void:
	_list.add_child(UiSkin.label(title, 15, UiSkin.AMBER, "Bold", 3))
	if empty:
		_list.add_child(UiSkin.label(Txt.t("Nenhuma."), 13, UiSkin.DIM, "Regular", 2))


func _row(quest: QuestDef, finished: bool) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiSkin.slot())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	box.add_child(column)
	var star := "★ " if quest.category == "principal" else ""
	var title := UiSkin.label(star + Txt.t(quest.title), 16, UiSkin.TEXT if not finished else UiSkin.TEXT.darkened(0.2), "Bold", 2)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	if not quest.summary.is_empty():
		var summary := UiSkin.label(Txt.t(quest.summary), 13, UiSkin.TEXT.darkened(0.15), "Regular", 2)
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(summary)
	if finished:
		column.add_child(UiSkin.label(Txt.t("Concluída"), 12, UiSkin.SAFE, "Regular", 2))
		return box
	for i in quest.objectives.size():
		var objective := quest.objectives[i]
		var goal := objective.goal()
		var count := mini(Quests.count_of(quest.id, i), goal)
		var mark := "■" if count >= goal else "□"
		var where := Txt.t(" (no inventário)") if objective.kind in QuestObjective.INVENTORY_KINDS and count < goal else ""
		column.add_child(UiSkin.label("%s %s  %d/%d%s" % [mark, Txt.t(objective.text()), count, goal, where], 13,
				UiSkin.SAFE if count >= goal else UiSkin.TEXT, "Regular", 2))
	if Quests.state_of(quest.id) == "pronta":
		column.add_child(UiSkin.label(Txt.t("Volte para %s") % quest.giver, 13, UiSkin.AMBER, "Regular", 2))
	return box


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		close_requested.emit()
		return
	var slot := player.slot
	var move := InputService.raw_move(slot).y
	if absf(move) > 0.2:
		_scroll.scroll_vertical += roundi(move * SCROLL_SPEED * delta)
	if InputService.raw_just_pressed(slot, InputService.Action.ARTIFACT):
		Sound.play("ui_confirm")
		switch_requested.emit()
	elif InputService.back_just_pressed(slot) \
			or InputService.raw_just_pressed(slot, InputService.Action.PAUSE):
		Sound.play("ui_back")
		close_requested.emit()
