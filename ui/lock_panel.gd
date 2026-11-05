class_name LockPanel
extends PanelContainer
## Terminal de tranca (estilo terminal velho de fósforo verde). Abre pelo LB / F perto de um
## portão com tranca de código ou de invasão (LoreGate.lock).
##
## Código: digita a chave (teclado) ou escolhe os caracteres numa grade (controle: direcional
## anda, A digita, X apaga, Start confirma). Errou 3 vezes: trava uns segundos.
## Invasão: despejo de memória com palavras do mesmo tamanho; escolher uma mostra quantas letras
## estão no lugar certo ("semelhança"). 4 tentativas; acabou, o terminal tranca por um tempo.
## B / Esc sai.

signal close_requested
signal unlocked

const GREEN := Color(0.45, 1.0, 0.6)
const DIM := Color(0.45, 1.0, 0.6, 0.55)
const KEYS := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-"
const KEY_COLUMNS := 10
const MAX_WRONG := 3
const LOCKOUT := 8.0
const HACK_ATTEMPTS := 4
const HACK_LOCKOUT := 30.0
const HACK_ROWS := 12
const JUNK := "!@#$%&*()[]{}<>/\\|;:'\",.?=+_^~"
## Palavras do terminal (6 letras, sem acento, no clima do mundo).
const WORDS := ["ACESSO", "CODIGO", "MATRIZ", "SINAIS", "RACOES", "OPERAR", "PORTAO", "COFRES", "DIGITO",
	"VAZIOS", "SONHOS", "MEDICO", "DOENTE", "ESGOTO", "PRISAO", "TORRES", "CARGAS", "FILTRO", "BOMBAS",
	"ENXAME", "CORPOS", "FUMACA", "ESCUDO", "TRAVAS", "SOMBRA", "GRADES"]

## Bloqueio por portão (vale para todo o sofá até o tempo passar), em segundos do relógio.
static var _locked_until := {}

var slot := 0
var gate: Node
var mode := "codigo"

var _guard := 0.25
var _title: Label
var _status: Label
var _typed: LineEdit
var _key_buttons: Array[Button] = []
var _cursor := 0
var _wrong := 0
var _words: Array[String] = []
var _secret := ""
var _attempts := HACK_ATTEMPTS
var _word_buttons: Array[Button] = []
var _attempts_label: Label
var _log: Label
var _last_dir := Vector2i.ZERO
var _repeat := 0.0


func open_for(p_slot: int, p_gate: Node) -> void:
	slot = p_slot
	gate = p_gate
	mode = String(gate.get("lock"))
	InputService.set_blocked(slot, true)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.045, 0.025, 0.97)
	style.border_color = Color(0.3, 0.9, 0.5, 0.55)
	style.set_border_width_all(2)
	style.set_content_margin_all(22)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(700, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	_title = _mono("", 22, GREEN)
	column.add_child(_title)
	if mode == "invasao":
		_build_hack(column)
	else:
		_build_code(column)
	_status = _mono("", 17, GREEN)
	column.add_child(_status)
	var keyboard := InputService.device_of(slot) == InputService.KEYBOARD
	var hint := ""
	if mode == "invasao":
		hint = "Clique numa palavra · Esc sai" if keyboard else "Direcional escolhe · A tenta · B sai"
	else:
		hint = "Digite a chave e Enter · Esc sai" if keyboard else "Direcional anda · A digita · X apaga · Start confirma · B sai"
	column.add_child(_mono(Txt.t(hint), 13, DIM, true))
	Sound.play("ui_confirm")
	_refresh_lockout()


func _mono(text: String, size: int, color: Color, wrap := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", SystemFont.new())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _key() -> String:
	return String(gate.get("unlock_fact")) if is_instance_valid(gate) else ""


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func is_locked_out() -> bool:
	return _now() < float(_locked_until.get(_key(), 0.0))


## Código

func _build_code(column: VBoxContainer) -> void:
	_title.text = Txt.t("SINAPSE · TERMINAL DE MANUTENÇÃO\n> DIGITE A CHAVE DE SERVIÇO")
	_typed = LineEdit.new()
	_typed.add_theme_font_override("font", SystemFont.new())
	_typed.add_theme_font_size_override("font_size", 30)
	_typed.add_theme_color_override("font_color", GREEN)
	_typed.add_theme_color_override("caret_color", GREEN)
	var field := StyleBoxFlat.new()
	field.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	field.border_color = Color(0.3, 0.9, 0.5, 0.4)
	field.set_border_width_all(1)
	field.set_content_margin_all(8)
	_typed.add_theme_stylebox_override("normal", field)
	_typed.add_theme_stylebox_override("focus", field)
	_typed.max_length = 24
	_typed.custom_minimum_size = Vector2(0, 54)
	_typed.text_submitted.connect(func(_text: String) -> void: submit_code())
	_typed.text_changed.connect(func(text: String) -> void:
		var upper := text.to_upper()
		if upper != text:
			var caret := _typed.caret_column
			_typed.text = upper
			_typed.caret_column = caret)
	column.add_child(_typed)
	var keyboard := InputService.device_of(slot) == InputService.KEYBOARD
	if keyboard:
		_typed.grab_focus.call_deferred()
		return
	# Controle: grade de caracteres.
	_typed.editable = false
	var grid := GridContainer.new()
	grid.columns = KEY_COLUMNS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	column.add_child(grid)
	for character in KEYS:
		var button := Button.new()
		button.text = character
		button.custom_minimum_size = Vector2(52, 44)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", SystemFont.new())
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_type.bind(character))
		grid.add_child(button)
		_key_buttons.append(button)
	_show_cursor()


func _type(character: String) -> void:
	if is_locked_out() or _typed.text.length() >= _typed.max_length:
		return
	_typed.text += character
	Sound.play("ui_type")


## Tira espaços e tracinhos, maiúsculo: "70 r alfa 9" vale "70-R-ALFA-9".
static func normalize(code: String) -> String:
	return code.to_upper().replace(" ", "").replace("-", "").replace("_", "")


func submit_code() -> bool:
	if is_locked_out():
		Sound.play("ui_error")
		return false
	var right := normalize(_typed.text) == normalize(String(gate.get("code"))) and not normalize(_typed.text).is_empty()
	if right:
		_status.text = Txt.t("> CHAVE ACEITA. DESTRAVANDO...")
		Sound.play("container_open")
		_finish()
		return true
	_wrong += 1
	_typed.text = ""
	Sound.play("ui_error")
	if _wrong >= MAX_WRONG:
		_wrong = 0
		_locked_until[_key()] = _now() + LOCKOUT
		_refresh_lockout()
	else:
		_status.text = Txt.t("> CHAVE INVÁLIDA (%d/%d)") % [_wrong, MAX_WRONG]
	return false


## Invasão

func _build_hack(column: VBoxContainer) -> void:
	_title.text = Txt.t("SINAPSE · NÚCLEO-7 · ACESSO RESTRITO\n> SENHA NECESSÁRIA")
	_attempts_label = _mono("", 17, GREEN)
	column.add_child(_attempts_label)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pool: Array = WORDS.duplicate()
	pool.shuffle()
	for i in mini(HACK_ROWS, pool.size()):
		_words.append(String(pool[i]))
	_secret = _words[rng.randi_range(0, _words.size() - 1)]
	var rows := HBoxContainer.new()
	rows.add_theme_constant_override("separation", 18)
	column.add_child(rows)
	var dump := VBoxContainer.new()
	dump.add_theme_constant_override("separation", 2)
	rows.add_child(dump)
	var address := rng.randi_range(0xF000, 0xFA00)
	for word in _words:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		dump.add_child(row)
		row.add_child(_mono("0x%04X  " % address, 17, DIM))
		address += 12
		row.add_child(_mono(_junk(rng, rng.randi_range(2, 6)), 17, DIM))
		var button := Button.new()
		button.text = word
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", SystemFont.new())
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_color_override("font_color", GREEN)
		button.add_theme_color_override("font_hover_color", Color.BLACK)
		var hover := StyleBoxFlat.new()
		hover.bg_color = GREEN
		button.add_theme_stylebox_override("hover", hover)
		button.pressed.connect(try_word.bind(word))
		row.add_child(button)
		_word_buttons.append(button)
		row.add_child(_mono(_junk(rng, rng.randi_range(2, 6)), 17, DIM))
	_log = _mono("", 16, GREEN, true)
	_log.custom_minimum_size = Vector2(240, 0)
	_log.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_log.size_flags_vertical = Control.SIZE_FILL
	rows.add_child(_log)
	_update_attempts()
	if InputService.device_of(slot) != InputService.KEYBOARD:
		_show_cursor()


func _junk(rng: RandomNumberGenerator, count: int) -> String:
	var text := ""
	for i in count:
		text += JUNK[rng.randi_range(0, JUNK.length() - 1)]
	return text


## Letras iguais na mesma posição.
static func likeness(a: String, b: String) -> int:
	var same := 0
	for i in mini(a.length(), b.length()):
		if a[i] == b[i]:
			same += 1
	return same


func try_word(word: String) -> bool:
	if is_locked_out() or _attempts <= 0:
		Sound.play("ui_error")
		return false
	if word == _secret:
		_log.text += Txt.t("\n> %s\n> ACESSO LIBERADO") % word
		Sound.play("container_open")
		_finish()
		return true
	_attempts -= 1
	_log.text += Txt.t("\n> %s\n> NEGADO. SEMELHANÇA %d/%d") % [word, likeness(word, _secret), _secret.length()]
	Sound.play("ui_error")
	for button in _word_buttons:
		if button.text == word:
			button.disabled = true
	if _attempts <= 0:
		_locked_until[_key()] = _now() + HACK_LOCKOUT
		_refresh_lockout()
	_update_attempts()
	return false


func _update_attempts() -> void:
	if _attempts_label:
		_attempts_label.text = Txt.t("TENTATIVAS RESTANTES: ") + "■ ".repeat(_attempts).strip_edges()


## Comum

func _finish() -> void:
	unlocked.emit()
	var fact := String(gate.get("unlock_fact"))
	if not fact.is_empty():
		Lore.learn([fact], "terminal|" if String(gate.get("lock")) == "invasao" else "porta|")
	get_tree().create_timer(0.9).timeout.connect(func() -> void:
		if is_inside_tree():
			close_requested.emit())


func _refresh_lockout() -> void:
	if _status == null:
		return
	if is_locked_out():
		_status.text = Txt.t("> TERMINAL TRAVADO. AGUARDE %d s") % ceili(float(_locked_until[_key()]) - _now())


func _exit_tree() -> void:
	InputService.set_blocked(slot, false)


func _buttons() -> Array[Button]:
	return _word_buttons if mode == "invasao" else _key_buttons


func _show_cursor() -> void:
	var list := _buttons()
	for i in list.size():
		list[i].modulate = Color(1, 1, 1, 1) if i == _cursor else Color(1, 1, 1, 0.55)
		list[i].add_theme_color_override("font_color", Color.BLACK if i == _cursor and mode == "invasao" else GREEN)
		if mode == "invasao":
			var style := StyleBoxFlat.new()
			style.bg_color = GREEN if i == _cursor else Color(0, 0, 0, 0)
			list[i].add_theme_stylebox_override("normal", style)


func _physics_process(delta: float) -> void:
	if not InputService.is_active(slot):
		return
	if is_locked_out():
		_refresh_lockout()
	elif _status and _status.text.begins_with("> TERMINAL TRAVADO"):
		_status.text = ""
		if mode == "invasao":
			_reset_hack()
	_guard -= delta
	if _guard > 0.0:
		return
	if InputService.back_just_pressed(slot) and not (_typed and _typed.has_focus()):
		close_requested.emit()
		return
	if InputService.device_of(slot) == InputService.KEYBOARD:
		return
	var list := _buttons()
	if list.is_empty():
		return
	var raw := InputService.raw_move(slot)
	var dir := Vector2i(0 if absf(raw.x) < 0.5 else signi(roundi(raw.x)), 0 if absf(raw.y) < 0.5 else signi(roundi(raw.y)))
	if dir != Vector2i.ZERO:
		if dir != _last_dir:
			_move(dir)
			_repeat = 0.3
		else:
			_repeat -= delta
			if _repeat <= 0.0:
				_move(dir)
				_repeat = 0.14
	_last_dir = dir
	if InputService.raw_just_pressed(slot, InputService.Action.JUMP):
		list[_cursor].pressed.emit()
	if mode == "codigo":
		if InputService.raw_just_pressed(slot, InputService.Action.MELEE) and not _typed.text.is_empty():
			_typed.text = _typed.text.left(-1)
			Sound.play("ui_back")
		if InputService.raw_just_pressed(slot, InputService.Action.PAUSE):
			submit_code()


func _move(dir: Vector2i) -> void:
	var list := _buttons()
	if mode == "invasao":
		_cursor = wrapi(_cursor + dir.y + dir.x, 0, list.size())
	else:
		_cursor = wrapi(_cursor + dir.x + dir.y * KEY_COLUMNS, 0, list.size())
	Sound.play("ui_move")
	_show_cursor()


## Depois do bloqueio, a memória embaralha: palavras e senha novas.
func _reset_hack() -> void:
	close_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE \
			and InputService.device_of(slot) == InputService.KEYBOARD:
		get_viewport().set_input_as_handled()
		close_requested.emit()
