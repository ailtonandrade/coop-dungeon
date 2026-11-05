class_name KnowledgePanel
extends PanelContainer
## Conhecimento do grupo: os fatos da história que já se sabe e de onde vieram (documento lido,
## conversa, missão, porta...). Título e origem vêm da ficha do fato (FactDef, em
## res://world/lore/facts); sem ficha, o id e a origem gravada na hora. Na roda dos painéis do
## inventário: RB / Q passa para o próximo.
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
	Lore.facts_changed.connect(_refresh)


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
	column.add_child(UiSkin.label(Txt.t("P%d %s · conhecimento") % [player.index + 1, player.display_name], 20, color, "Bold", 4))
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
	column.add_child(UiSkin.label("O grupo inteiro sabe o mesmo · RB/Q inventário · B fecha", 13, Color(1, 1, 1, 0.6), "Regular", 3))


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	var ids := Lore.known_facts()
	_header.text = Txt.t("Fatos que o grupo descobriu: %d. Ler documentos e conversar abre caminhos novos.") % ids.size() \
			if not ids.is_empty() else Txt.t("Nada ainda. Leia documentos e terminais e converse com o povo da vila.")
	for id in ids:
		_list.add_child(_row(id))


func _row(id: String) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiSkin.slot())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	box.add_child(column)
	var title := UiSkin.label(Lore.fact_title(id), 16, UiSkin.TEXT, "Bold", 2)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var description := Lore.fact_description(id)
	if not description.is_empty():
		var text := UiSkin.label(description, 13, UiSkin.TEXT.darkened(0.15), "Regular", 2)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(text)
	var source := UiSkin.label(Txt.t("Onde: %s") % Lore.fact_source(id), 12, UiSkin.AMBER, "Regular", 2)
	source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(source)
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
