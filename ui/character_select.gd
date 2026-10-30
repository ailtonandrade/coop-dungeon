class_name CharacterSelect
extends PanelContainer
## Escolha de personagem de quem entra no sofá depois do primeiro (segurou Y na pausa).
## Cards com prévia dos personagens deste PC e um card "Novo"; no "Novo", escolhe visual,
## cor do chip e nome (sorteado no controle; digitado no teclado) e entra.
##
## Cards:   esquerda/direita escolhe · A entra (ou cria, no "Novo") · B desiste
## Criação: esquerda/direita visual · Y cor do chip · X sorteia nome · A entra · B volta
## Teclado:  nos cards A/D · Espaço · Shift; na criação, digita o nome, ← → visual, Enter, Esc

signal finished(character_id: String)
signal cancelled

const REPEAT_DELAY := 0.3
const REPEAT_RATE := 0.16
const CARD_SIZE := Vector2(150, 250)

var slot := 0
## Personagens já em jogo nesta máquina (não dá para entrar duas vezes com o mesmo).
var taken: Array = []
## De onde vem a lista acima (atualizada enquanto escolhe: outro do sofá pode entrar antes).
var taken_source := Callable()

var _characters: Array[Dictionary] = []
var _cursor := 0
var _creating := false
var _draft := {}
var _title: Label
var _cards: HBoxContainer
var _create_box: VBoxContainer
var _create_preview: CharacterPreview
var _model_label: Label
var _name_edit: LineEdit
var _hint: Label
var _repeat := 0.0
var _last_dir := 0
var _taken_timer := 0.0


func open_for(p_slot: int, source: Callable) -> void:
	slot = p_slot
	taken_source = source
	taken = source.call() if source.is_valid() else []
	InputService.set_blocked(slot, true)
	_build()
	_characters = SaveService.list_characters()
	var last: String = Settings.last_character[slot] if slot < Settings.last_character.size() else ""
	# Começa no último usado por este jogador; senão, no primeiro que ninguém está usando.
	_cursor = -1
	for i in _characters.size():
		if _characters[i].id == last and not taken.has(last):
			_cursor = i
	if _cursor == -1:
		_cursor = maxi(_characters.find_custom(func(c: Dictionary) -> bool: return not taken.has(c.id)), 0)
	# Sem nenhum livre: já começa no "Novo".
	if _characters.all(func(c: Dictionary) -> bool: return taken.has(c.id)) and _characters.size() < Characters.MAX:
		_cursor = _characters.size()
	_refresh_cards()


func _exit_tree() -> void:
	InputService.set_blocked(slot, false)


func _build() -> void:
	add_theme_stylebox_override("panel", UiSkin.panel())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	_title = UiSkin.label("", 20, GameConfig.PLAYER_COLORS[slot], "Bold", 4)
	column.add_child(_title)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 10)
	column.add_child(_cards)

	_create_box = VBoxContainer.new()
	_create_box.visible = false
	_create_box.add_theme_constant_override("separation", 6)
	column.add_child(_create_box)
	var create_row := HBoxContainer.new()
	create_row.add_theme_constant_override("separation", 16)
	_create_box.add_child(create_row)
	_create_preview = CharacterPreview.new()
	_create_preview.custom_minimum_size = Vector2(200, 270)
	create_row.add_child(_create_preview)
	var fields := VBoxContainer.new()
	fields.add_theme_constant_override("separation", 10)
	fields.custom_minimum_size = Vector2(320, 0)
	create_row.add_child(fields)
	fields.add_child(UiSkin.label("Visual", 14, UiSkin.DIM, "Regular", 3))
	_model_label = UiSkin.label("", 22, UiSkin.TEXT, "Bold", 4)
	fields.add_child(_model_label)
	fields.add_child(UiSkin.label("Nome", 14, UiSkin.DIM, "Regular", 3))
	_name_edit = LineEdit.new()
	_name_edit.max_length = Characters.NAME_MAX
	_name_edit.custom_minimum_size = Vector2(0, 44)
	_name_edit.text_changed.connect(func(text: String) -> void: _draft.name = text)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _confirm_create())
	_name_edit.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
			_name_edit.accept_event()
			_back())
	fields.add_child(_name_edit)

	_hint = UiSkin.label("", 13, Color(1, 1, 1, 0.65), "Regular", 3)
	column.add_child(_hint)


## Cards

func _row_count() -> int:
	return _characters.size() + (1 if _characters.size() < Characters.MAX else 0)


func _refresh_cards() -> void:
	_creating = false
	_create_box.visible = false
	_cards.visible = true
	_title.text = "P%d · escolha seu personagem" % (slot + 1)
	_hint.text = "◀ ▶ escolhe · A entra · B desiste"
	_cursor = clampi(_cursor, 0, maxi(_row_count() - 1, 0))
	for child in _cards.get_children():
		child.queue_free()
	for i in _row_count():
		_cards.add_child(_card(i))


func _card(i: int) -> Control:
	var selected := i == _cursor
	var is_new := i >= _characters.size()
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.06, 0.85) if not selected else Color(0.06, 0.1, 0.14, 0.95)
	style.border_color = GameConfig.PLAYER_COLORS[slot] if selected else Color(UiSkin.BRASS, 0.4)
	style.set_border_width_all(3 if selected else 1)
	style.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	if is_new:
		var plus := UiSkin.title("+", 90, UiSkin.NEON)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.custom_minimum_size = Vector2(0, 170)
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(plus)
		box.add_child(_centered(UiSkin.label("Novo personagem", 15, UiSkin.NEON, "Bold", 3)))
		box.add_child(_centered(UiSkin.label("%d/%d" % [_characters.size(), Characters.MAX], 12, UiSkin.DIM, "Regular", 3)))
		return card
	var character := _characters[i]
	var preview := CharacterPreview.new()
	preview.custom_minimum_size = Vector2(0, 170)
	box.add_child(preview)
	preview.show_character(character)
	var used := taken.has(character.id)
	box.add_child(_centered(UiSkin.label(character.name, 15, UiSkin.DIM if used else UiSkin.TEXT, "Bold", 3)))
	var info := "em jogo" if used else "nível %d · %s" % [Characters.level_of(character), Characters.MODELS[character.model]]
	var info_label := UiSkin.label(info, 11, UiSkin.DANGER if used else UiSkin.DIM, "Regular", 2)
	info_label.clip_text = true
	box.add_child(_centered(info_label))
	if used:
		card.modulate = Color(1, 1, 1, 0.55)
	return card


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## Criação

func _start_create() -> void:
	if _characters.size() >= Characters.MAX:
		Sound.play("ui_error")
		return
	_creating = true
	_draft = Characters.create()
	_cards.visible = false
	_create_box.visible = true
	_title.text = "P%d · novo personagem" % (slot + 1)
	var keyboard := InputService.device_of(slot) == InputService.KEYBOARD
	_hint.text = "◀ ▶ visual · Y cor do chip · X sorteia nome · A entra · B volta" if not keyboard \
			else "Digite o nome · ← → visual · Enter entra · Esc volta"
	_name_edit.text = _draft.name
	_name_edit.editable = keyboard
	if keyboard:
		_name_edit.grab_focus.call_deferred()
	_refresh_create()


func _refresh_create() -> void:
	_model_label.text = "◀  %s  ▶" % Characters.MODELS[_draft.model]
	_create_preview.show_character(_draft)


func _confirm_create() -> void:
	_draft = Characters.sanitize(_draft)
	if not SaveService.save_character(_draft):
		Sound.play("ui_error")
		return
	Sound.play("ui_confirm")
	Settings.remember_character(slot, _draft.id)
	finished.emit(_draft.id)


## Entrada

func _physics_process(delta: float) -> void:
	_taken_timer -= delta
	if _taken_timer <= 0.0 and taken_source.is_valid() and not _creating:
		_taken_timer = 0.25
		var now: Array = taken_source.call()
		if now != taken:
			taken = now
			_refresh_cards()
	var typing := _creating and _name_edit.has_focus()
	var raw := InputService.raw_move(slot)
	var dir := 0 if absf(raw.x) < 0.5 else signi(roundi(raw.x))
	# Digitando o nome no teclado, A/D são letras: só as setas mudam o visual.
	if typing:
		dir = int(Input.is_physical_key_pressed(KEY_RIGHT)) - int(Input.is_physical_key_pressed(KEY_LEFT))
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
	if typing:
		return
	if InputService.raw_just_pressed(slot, InputService.Action.JUMP) or InputService.raw_just_pressed(slot, InputService.Action.PAUSE):
		_accept()
	elif InputService.raw_just_pressed(slot, InputService.Action.DODGE):
		_back()
	elif _creating and InputService.raw_just_pressed(slot, InputService.Action.POTION):
		_draft.chip_color = wrapi(int(_draft.chip_color) + 1, 0, Characters.CHIP_COLORS.size())
		Sound.play("ui_move")
		_refresh_create()
	elif _creating and InputService.raw_just_pressed(slot, InputService.Action.MELEE):
		_draft.name = Characters.random_name()
		_name_edit.text = _draft.name
		Sound.play("ui_move")


func _step(dir: int) -> void:
	Sound.play("ui_move")
	if _creating:
		_draft.model = Characters.step_model(_draft.model, dir)
		_refresh_create()
	else:
		_cursor = wrapi(_cursor + dir, 0, maxi(_row_count(), 1))
		_refresh_cards()


func _accept() -> void:
	if _creating:
		_confirm_create()
		return
	if _cursor >= _characters.size():
		_start_create()
		return
	var current := _characters[_cursor]
	if taken_source.is_valid():
		taken = taken_source.call()
	if taken.has(current.id):
		Sound.play("ui_error")
		_refresh_cards()
		return
	Sound.play("ui_confirm")
	Settings.remember_character(slot, current.id)
	finished.emit(current.id)


func _back() -> void:
	Sound.play("ui_back")
	if _creating:
		_refresh_cards()
	else:
		cancelled.emit()


## Para a HUD: o card marcado agora (vazio no "Novo" e na criação).
func _current() -> Dictionary:
	return _characters[_cursor] if not _creating and _cursor < _characters.size() else {}
