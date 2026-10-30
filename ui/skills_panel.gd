class_name SkillsPanel
extends PanelContainer
## Habilidades do herói, estilo Tibia: nível de cada uma e a barra do quanto falta para o
## próximo. Sobem com o uso (acertar com a arma, aguentar dano, apanhar). Na roda dos painéis
## do inventário: RB / Q passa para o próximo.
##
## Controle: RB volta ao inventário · B / Back fecha. Teclado: Q · Shift / I.

signal close_requested
signal switch_requested

var player: Player
## Trocando para outro painel do mesmo jogador: ao sair, não solta o herói.
var keep_blocked := false

var _rows: Array[Control] = []
var _header: Label


func open_for(p_player: Player) -> void:
	player = p_player
	player.inventory_updated.connect(_refresh)
	player.progress.changed.connect(_refresh)
	InputService.set_blocked(player.slot, true)
	_build()
	_refresh()


func _exit_tree() -> void:
	if is_instance_valid(player) and not keep_blocked:
		InputService.set_blocked(player.slot, false)


func _build() -> void:
	add_theme_stylebox_override("panel", UiSkin.panel())
	custom_minimum_size = Vector2(470, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var color := GameConfig.PLAYER_COLORS[player.index]
	column.add_child(UiSkin.label("P%d %s · habilidades" % [player.index + 1, player.display_name], 20, color, "Bold", 4))
	_header = UiSkin.label("", 14, UiSkin.DIM, "Regular", 3)
	_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_header)
	for id: String in Progression.SKILLS:
		var row := Control.new()
		row.custom_minimum_size = Vector2(440, 44)
		row.draw.connect(_draw_row.bind(row, id))
		column.add_child(row)
		_rows.append(row)
	column.add_child(UiSkin.label("Sobem usando · RB/Q inventário · B fecha", 13, Color(1, 1, 1, 0.6), "Regular", 3))


func _refresh() -> void:
	if not is_instance_valid(player):
		return
	var melee: String = Progression.SKILLS[player.weapon_skill("melee")].name
	var ranged: String = Progression.SKILLS[player.weapon_skill("ranged")].name
	_header.text = "Armas na mão treinam: %s (corpo a corpo) e %s (distância). Vigor sobe aguentando dano; Resiliência, apanhando ou esquivando." % [melee, ranged]
	for row in _rows:
		row.queue_redraw()


func _draw_row(row: Control, id: String) -> void:
	var progress := player.progress
	var level := progress.skill_level(id)
	var in_use := id == player.weapon_skill("melee") or id == player.weapon_skill("ranged")
	var rect := Rect2(Vector2.ZERO, row.size)
	row.draw_style_box(UiSkin.slot(), rect)
	if in_use:
		row.draw_rect(Rect2(rect.position, Vector2(3, rect.size.y)), GameConfig.PLAYER_COLORS[player.index])
	var bold := UiSkin.font("Bold")
	row.draw_string(bold, Vector2(14, 19), Progression.SKILLS[id].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			UiSkin.TEXT if in_use else UiSkin.TEXT.darkened(0.15))
	row.draw_string(UiSkin.font("Regular"), Vector2(14, 36), Progression.skill_text(id, level), HORIZONTAL_ALIGNMENT_LEFT, 220, 12, UiSkin.DIM)
	row.draw_string(UiSkin.title_font(), Vector2(row.size.x - 190, 30), str(level), HORIZONTAL_ALIGNMENT_RIGHT, 50, 22, UiSkin.AMBER)
	# Barra do Tibia: quanto falta para o próximo nível.
	var bar := Rect2(Vector2(row.size.x - 130, 16), Vector2(116, 10))
	row.draw_rect(bar.grow(1), UiSkin.INK)
	row.draw_rect(bar, Color(0.12, 0.05, 0.05))
	var ratio := progress.skill_ratio(id)
	row.draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), Color(0.85, 0.2, 0.2).lerp(UiSkin.SAFE, ratio))
	row.draw_string(UiSkin.font("Regular"), Vector2(bar.position.x, 40), "%d%%" % roundi(ratio * 100.0), HORIZONTAL_ALIGNMENT_LEFT, bar.size.x, 11, UiSkin.DIM)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		close_requested.emit()
		return
	var slot := player.slot
	if InputService.raw_just_pressed(slot, InputService.Action.ARTIFACT):
		Sound.play("ui_confirm")
		switch_requested.emit()
	elif InputService.raw_just_pressed(slot, InputService.Action.DODGE) \
			or InputService.raw_just_pressed(slot, InputService.Action.PAUSE):
		Sound.play("ui_back")
		close_requested.emit()
