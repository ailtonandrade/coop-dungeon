class_name CharacterSelect
extends PanelContainer
## Escolha de personagem de um jogador do sofá, ao apertar Start no mundo. Cada um escolhe o
## seu ao mesmo tempo, com o próprio controle. Dá para criar um novo (até 5 por máquina) e
## personalizar ali mesmo: visual do corpo, cor do chip pirata e nome sorteado. Nome digitado e
## apagar ficam na tela Personagens do menu principal.
##
## Controle: cima/baixo escolhe · esquerda/direita troca o visual · Y cor do chip
##           X sorteia nome · A / Start entra · B sai
## Teclado:  W/S · A/D · E · J · Espaço / Enter · Shift

signal finished(character_id: String)
signal cancelled

const REPEAT_DELAY := 0.3
const REPEAT_RATE := 0.14

var slot := 0
## Personagens já em jogo nesta máquina (não dá para entrar duas vezes com o mesmo).
var taken: Array = []
## De onde vem a lista acima (atualizada enquanto escolhe: outro do sofá pode entrar antes).
var taken_source := Callable()
var _taken_timer := 0.0

var _characters: Array[Dictionary] = []
var _cursor := 0
var _list: VBoxContainer
var _preview: CharacterPreview
var _details: Label
var _repeat := 0.0
var _last_dir := Vector2i.ZERO


func open_for(p_slot: int, source: Callable) -> void:
	slot = p_slot
	taken_source = source
	taken = source.call() if source.is_valid() else []
	InputService.set_blocked(slot, true)
	_build()
	_reload()
	var last: String = Settings.last_character[slot] if slot < Settings.last_character.size() else ""
	for i in _characters.size():
		if _characters[i].id == last and not taken.has(last):
			_cursor = i
	_refresh()


func _exit_tree() -> void:
	InputService.set_blocked(slot, false)


func _build() -> void:
	add_theme_stylebox_override("panel", UiSkin.panel())
	custom_minimum_size = Vector2(520, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var color := GameConfig.PLAYER_COLORS[slot]
	column.add_child(UiSkin.label("P%d · escolha seu personagem" % (slot + 1), 20, color, "Bold", 4))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(320, 0)
	_list.add_theme_constant_override("separation", 4)
	row.add_child(_list)
	_preview = CharacterPreview.new()
	_preview.custom_minimum_size = Vector2(170, 230)
	row.add_child(_preview)
	_details = UiSkin.label("", 15, UiSkin.TEXT, "Regular", 3)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_details)
	column.add_child(UiSkin.label("A entra · ◀ ▶ visual · Y cor do chip · X sorteia nome · B sai", 13, Color(1, 1, 1, 0.6), "Regular", 3))


func _reload() -> void:
	_characters = SaveService.list_characters()


## Linha "novo personagem" no fim, se ainda couber.
func _can_create() -> bool:
	return _characters.size() < Characters.MAX


func _row_count() -> int:
	return _characters.size() + (1 if _can_create() else 0)


func _refresh() -> void:
	_cursor = clampi(_cursor, 0, maxi(_row_count() - 1, 0))
	for child in _list.get_children():
		child.queue_free()
	for i in _row_count():
		var is_new := i >= _characters.size()
		var text := "+ Novo personagem"
		var color := UiSkin.NEON
		if not is_new:
			var character := _characters[i]
			text = "%s  ·  %s  ·  nível %d" % [character.name, Characters.MODELS[character.model], Characters.level_of(character)]
			color = UiSkin.TEXT
			if taken.has(character.id):
				text += "  (já em jogo)"
				color = UiSkin.DIM
		var label := UiSkin.label(text, 17, color, "Bold" if i == _cursor else "SemiBold", 3)
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.08) if i == _cursor else Color(0, 0, 0, 0)
		style.border_color = GameConfig.PLAYER_COLORS[slot]
		style.set_border_width_all(2 if i == _cursor else 0)
		style.set_content_margin_all(6)
		panel.add_theme_stylebox_override("panel", style)
		panel.add_child(label)
		_list.add_child(panel)
	var current := _current()
	_preview.show_character(current)
	if current.is_empty():
		_details.text = "Cria um personagem novo com nome e visual sorteados (dá para mudar aqui ou no menu Personagens)."
	else:
		_details.text = "%s · chip %s · %d/%d personagens nesta máquina" % [
			Characters.MODELS[current.model], Characters.CHIP_COLOR_NAMES[current.chip_color], _characters.size(), Characters.MAX]


func _current() -> Dictionary:
	return _characters[_cursor] if _cursor < _characters.size() else {}


func _physics_process(delta: float) -> void:
	_taken_timer -= delta
	if _taken_timer <= 0.0 and taken_source.is_valid():
		_taken_timer = 0.25
		var now: Array = taken_source.call()
		if now != taken:
			taken = now
			_refresh()
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
	if InputService.raw_just_pressed(slot, InputService.Action.JUMP) or InputService.raw_just_pressed(slot, InputService.Action.PAUSE):
		_confirm()
	elif InputService.raw_just_pressed(slot, InputService.Action.POTION):
		_edit(func(c: Dictionary) -> void: c.chip_color = wrapi(int(c.chip_color) + 1, 0, Characters.CHIP_COLORS.size()))
	elif InputService.raw_just_pressed(slot, InputService.Action.MELEE):
		_edit(func(c: Dictionary) -> void: c.name = Characters.random_name())
	elif InputService.raw_just_pressed(slot, InputService.Action.DODGE):
		Sound.play("ui_back")
		cancelled.emit()


func _step(dir: Vector2i) -> void:
	if dir.y != 0:
		Sound.play("ui_move")
		_cursor = wrapi(_cursor + dir.y, 0, maxi(_row_count(), 1))
		_refresh()
	elif dir.x != 0:
		_edit(func(c: Dictionary) -> void: c.model = Characters.step_model(c.model, dir.x))


## Muda o personagem marcado (visual, cor, nome) e salva na hora.
func _edit(change: Callable) -> void:
	var current := _current()
	if current.is_empty() or taken.has(current.id):
		Sound.play("ui_error")
		return
	change.call(current)
	SaveService.save_character(current)
	Sound.play("ui_move")
	_refresh()


func _confirm() -> void:
	var current := _current()
	if current.is_empty():
		if not _can_create():
			Sound.play("ui_error")
			return
		var created := Characters.create()
		SaveService.save_character(created)
		_reload()
		_cursor = _characters.size() - 1
		Sound.play("ui_confirm")
		_refresh()
		return
	if taken_source.is_valid():
		taken = taken_source.call()
	if taken.has(current.id):
		Sound.play("ui_error")
		_refresh()
		return
	Sound.play("ui_confirm")
	Settings.remember_character(slot, current.id)
	finished.emit(current.id)
