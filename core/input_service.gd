extends Node
## Liga cada controle (ou o teclado) a um slot de jogador e lê os comandos por slot.
## O jogo nunca lê Input direto: pergunta aqui pelo slot, assim o couch co-op não mistura controles.

signal player_joined(slot: int, device: int)
signal player_left(slot: int)

const KEYBOARD := -1
const NO_DEVICE := -2

enum Action { MELEE, DODGE, RANGED, POTION, ARTIFACT, PAUSE }

const JOY_BUTTONS := {
	Action.MELEE: JOY_BUTTON_X,
	Action.DODGE: JOY_BUTTON_A,
	Action.POTION: JOY_BUTTON_Y,
	Action.ARTIFACT: JOY_BUTTON_RIGHT_SHOULDER,
	Action.PAUSE: JOY_BUTTON_START,
}
const JOY_TRIGGERS := {
	Action.RANGED: JOY_AXIS_TRIGGER_RIGHT,
}
const KEYS := {
	Action.MELEE: KEY_J,
	Action.DODGE: KEY_SPACE,
	Action.RANGED: KEY_K,
	Action.POTION: KEY_E,
	Action.ARTIFACT: KEY_Q,
	Action.PAUSE: KEY_ESCAPE,
}

var _devices: Array[int] = []
## Bitmask das ações pressionadas por slot, neste frame e no anterior.
var _down: Array[int] = []
var _prev: Array[int] = []


func _ready() -> void:
	for i in GameConfig.MAX_PLAYERS:
		_devices.append(NO_DEVICE)
		_down.append(0)
		_prev.append(0)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START or event.button_index == JOY_BUTTON_A:
			_try_join(event.device)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ENTER:
			_try_join(KEYBOARD)


func _physics_process(_delta: float) -> void:
	for slot in _devices.size():
		_prev[slot] = _down[slot]
		_down[slot] = _poll(_devices[slot])


func is_active(slot: int) -> bool:
	return _devices[slot] != NO_DEVICE


func active_slots() -> Array[int]:
	var slots: Array[int] = []
	for slot in _devices.size():
		if is_active(slot):
			slots.append(slot)
	return slots


func is_pressed(slot: int, action: Action) -> bool:
	return _down[slot] & (1 << action) != 0


func just_pressed(slot: int, action: Action) -> bool:
	return is_pressed(slot, action) and _prev[slot] & (1 << action) == 0


## Direção do analógico esquerdo (ou WASD) em coordenadas de tela, comprimento 0..1.
func get_move(slot: int) -> Vector2:
	var device := _devices[slot]
	if device == KEYBOARD:
		var v := Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		return v.limit_length(1.0)
	if device >= 0:
		var v := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		var mag := v.length()
		if mag < GameConfig.STICK_DEADZONE:
			return Vector2.ZERO
		return v / mag * inverse_lerp(GameConfig.STICK_DEADZONE, 1.0, minf(mag, 1.0))
	return Vector2.ZERO


## Protótipo: controle desconectado tira o jogador. Na versão de console isso precisa
## pausar e pedir reconexão (requisito de certificação do Xbox).
func leave(slot: int) -> void:
	if not is_active(slot):
		return
	_devices[slot] = NO_DEVICE
	_down[slot] = 0
	_prev[slot] = 0
	player_left.emit(slot)


func _try_join(device: int) -> void:
	if _devices.has(device):
		return
	var slot := _devices.find(NO_DEVICE)
	if slot == -1:
		return
	_devices[slot] = device
	# Começa com o estado atual para o botão que fez entrar não virar ação no primeiro frame.
	_down[slot] = _poll(device)
	_prev[slot] = _down[slot]
	get_viewport().set_input_as_handled()
	player_joined.emit(slot, device)


func _poll(device: int) -> int:
	if device == NO_DEVICE:
		return 0
	var mask := 0
	for action: int in Action.values():
		if _read(device, action):
			mask |= 1 << action
	return mask


func _read(device: int, action: int) -> bool:
	if device == KEYBOARD:
		return KEYS.has(action) and Input.is_physical_key_pressed(KEYS[action])
	if JOY_BUTTONS.has(action):
		return Input.is_joy_button_pressed(device, JOY_BUTTONS[action])
	if JOY_TRIGGERS.has(action):
		return Input.get_joy_axis(device, JOY_TRIGGERS[action]) > 0.5
	return false


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		return
	var slot := _devices.find(device)
	if slot != -1:
		leave(slot)
