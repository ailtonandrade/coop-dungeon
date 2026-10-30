class_name ChipPanel
extends PanelContainer
## Chip pirata: onde o jogador instala os pontos que ganha subindo de nível. Abre de dentro do
## inventário (RB / Q) e volta para ele do mesmo jeito. Cada um do sofá mexe no seu.
##
## Controle: cima/baixo escolhe · A instala um ponto · RB volta ao inventário · B / Back fecha
## Teclado:  W/S · Espaço · Q · Shift / I

signal close_requested
signal switch_requested

const REPEAT_DELAY := 0.3
const REPEAT_RATE := 0.12

var player: Player
## Trocando para o outro painel do mesmo jogador: ao sair, não solta o herói.
var keep_blocked := false

var _rows: Array[Control] = []
var _header: Label
var _details: Label
var _cursor := 0
var _repeat := 0.0
var _last_dir := 0


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
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var color := GameConfig.PLAYER_COLORS[player.index]
	column.add_child(UiSkin.label("P%d %s · chip pirata" % [player.index + 1, player.display_name], 20, color, "Bold", 4))
	_header = UiSkin.label("", 16, UiSkin.AMBER, "SemiBold", 3)
	column.add_child(_header)
	for id: String in Progression.CHIPS:
		var row := Control.new()
		row.custom_minimum_size = Vector2(440, 52)
		row.draw.connect(_draw_row.bind(row, id))
		column.add_child(row)
		_rows.append(row)
	_details = UiSkin.label("", 15, UiSkin.TEXT, "Regular", 3)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.custom_minimum_size = Vector2(440, 40)
	column.add_child(_details)
	column.add_child(UiSkin.label("Cima/baixo escolhe · A instala · RB/Q inventário · B fecha", 13, Color(1, 1, 1, 0.6), "Regular", 3))


func _refresh() -> void:
	if not is_instance_valid(player):
		return
	var progress := player.progress
	var next := Progression.xp_to_next(progress.level)
	_header.text = "Nível %d · XP %d/%d · pontos para instalar: %d" % [progress.level, progress.xp, next, progress.points_free()]
	var id: String = Progression.CHIPS.keys()[_cursor]
	var points := progress.chip_level(id)
	var now := Progression.chip_text(id, points) if points > 0 else "nada ainda"
	var after := Progression.chip_text(id, points + 1) if points < Progression.MAX_CHIP else "no máximo"
	_details.text = "%s: %s → %s" % [Progression.CHIPS[id].name, now, after]
	for row in _rows:
		row.queue_redraw()


func _draw_row(row: Control, id: String) -> void:
	var index := Progression.CHIPS.keys().find(id)
	var selected := index == _cursor
	var rect := Rect2(Vector2.ZERO, row.size)
	row.draw_style_box(UiSkin.slot(), rect)
	if selected:
		row.draw_rect(rect.grow(-2), GameConfig.PLAYER_COLORS[player.index], false, 3.0)
	var f := UiSkin.font("Bold")
	var points := player.progress.chip_level(id)
	row.draw_string(f, Vector2(14, 22), Progression.CHIPS[id].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UiSkin.TEXT)
	var effect := Progression.chip_text(id, points) if points > 0 else "—"
	row.draw_string(UiSkin.font("Regular"), Vector2(14, 41), effect, HORIZONTAL_ALIGNMENT_LEFT, 230, 13, UiSkin.DIM)
	# Barrinhas do nível do chip (1 a 10), acesas em neon.
	for i in Progression.MAX_CHIP:
		var cell := Rect2(Vector2(250 + i * 18, 16), Vector2(14, 20))
		row.draw_rect(cell, UiSkin.INK)
		row.draw_rect(cell.grow(-2), UiSkin.NEON if i < points else Color(0.12, 0.14, 0.16))


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		close_requested.emit()
		return
	var slot := player.slot
	var raw := InputService.raw_move(slot)
	var dir := 0 if absf(raw.y) < 0.5 else signi(roundi(raw.y))
	if dir != 0:
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
		_install()
	elif InputService.raw_just_pressed(slot, InputService.Action.ARTIFACT):
		Sound.play("ui_back")
		switch_requested.emit()
	elif InputService.raw_just_pressed(slot, InputService.Action.DODGE) \
			or InputService.raw_just_pressed(slot, InputService.Action.PAUSE):
		Sound.play("ui_back")
		close_requested.emit()


func _step(dir: int) -> void:
	Sound.play("ui_move")
	_cursor = wrapi(_cursor + dir, 0, Progression.CHIPS.size())
	_refresh()


## A: pede ao host para instalar um ponto no chip escolhido.
func _install() -> void:
	var id: String = Progression.CHIPS.keys()[_cursor]
	if not player.progress.can_install(id):
		Sound.play("ui_error")
		return
	player.request_inventory("chip", [id])
