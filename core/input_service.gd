extends Node
## Liga cada controle (ou o teclado) a um slot de jogador e lê os comandos por slot.
## O jogo nunca lê Input direto: pergunta aqui pelo slot, assim o couch co-op não mistura controles.

signal player_joined(slot: int, device: int)
signal player_left(slot: int)

const KEYBOARD := -1
const NO_DEVICE := -2

enum Action { MELEE, DODGE, RANGED, POTION, ARTIFACT, PAUSE, JUMP, INVENTORY, PICKUP }

const JOY_BUTTONS := {
	Action.MELEE: JOY_BUTTON_X,
	Action.JUMP: JOY_BUTTON_A,
	Action.DODGE: JOY_BUTTON_B,
	Action.POTION: JOY_BUTTON_Y,
	Action.ARTIFACT: JOY_BUTTON_RIGHT_SHOULDER,
	Action.PAUSE: JOY_BUTTON_START,
	Action.INVENTORY: JOY_BUTTON_BACK,
	Action.PICKUP: JOY_BUTTON_LEFT_SHOULDER,
}
## Teclado + mouse: botão esquerdo ataca, direito mira e atira.
const MOUSE_BUTTONS := {
	Action.MELEE: MOUSE_BUTTON_LEFT,
	Action.RANGED: MOUSE_BUTTON_RIGHT,
}
const JOY_TRIGGERS := {
	Action.RANGED: JOY_AXIS_TRIGGER_RIGHT,
}
const KEYS := {
	Action.MELEE: KEY_J,
	Action.JUMP: KEY_SPACE,
	Action.DODGE: KEY_SHIFT,
	Action.RANGED: KEY_K,
	Action.POTION: KEY_E,
	Action.ARTIFACT: KEY_Q,
	Action.PAUSE: KEY_ESCAPE,
	Action.INVENTORY: KEY_I,
	Action.PICKUP: KEY_F,
}

## Só aceita entrar no jogo dentro de uma fase (no menu, o controle navega a interface).
var joining_enabled := false
## Menu que cobre a tela inteira (pausa): bloqueia os comandos de jogo de todos os slots
## desta máquina, inclusive cliques do mouse nos botões do menu.
var screen_menu_open := false
## Último controle (ou teclado) usado, para entrar sozinho ao começar a fase.
var last_device := KEYBOARD

## Converte um ponto da tela num ponto do chão na altura dada (a câmera registra).
## Usado para mirar com o mouse.
var aim_projector := Callable()

var _devices: Array[int] = []
## Onde está o herói de cada slot (a mira do mouse sai dele).
var _aim_anchor: Array[Vector3] = []
## Slot com menu aberto (inventário): o jogo não vê os comandos dele, só a interface (raw_*).
var _blocked: Array[bool] = []
## Bitmask das ações pressionadas por slot, neste frame e no anterior.
var _down: Array[int] = []
var _prev: Array[int] = []


func _ready() -> void:
	for i in GameConfig.MAX_PLAYERS:
		_devices.append(NO_DEVICE)
		_blocked.append(false)
		_aim_anchor.append(Vector3.ZERO)
		_down.append(0)
		_prev.append(0)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		last_device = event.device
	elif event is InputEventKey and event.pressed:
		last_device = KEYBOARD


func _unhandled_input(event: InputEvent) -> void:
	if not joining_enabled:
		return
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
	return not is_blocked(slot) and raw_pressed(slot, action)


func just_pressed(slot: int, action: Action) -> bool:
	return not is_blocked(slot) and raw_just_pressed(slot, action)


## Bitmask das ações seguradas neste quadro.
func get_down_mask(slot: int) -> int:
	return 0 if is_blocked(slot) else _down[slot]


## Bitmask das ações que começaram a ser apertadas neste quadro.
func get_pressed_mask(slot: int) -> int:
	return 0 if is_blocked(slot) else _down[slot] & ~_prev[slot]


## Bloqueia (ou libera) os comandos de jogo de um slot enquanto ele usa um menu.
func set_blocked(slot: int, blocked: bool) -> void:
	_blocked[slot] = blocked


## Comandos de jogo bloqueados: menu do próprio slot (inventário) ou menu da tela toda (pausa).
func is_blocked(slot: int) -> bool:
	return _blocked[slot] or screen_menu_open


## Leitura para menus: ignora o bloqueio.
func raw_pressed(slot: int, action: Action) -> bool:
	return _down[slot] & (1 << action) != 0


func raw_just_pressed(slot: int, action: Action) -> bool:
	return raw_pressed(slot, action) and _prev[slot] & (1 << action) == 0


func join_last_device() -> void:
	if not joining_enabled:
		return
	if last_device == KEYBOARD or Input.get_connected_joypads().has(last_device):
		_try_join(last_device)


## Volta ao estado do menu: ninguém no jogo e sem aceitar entradas novas.
func reset() -> void:
	joining_enabled = false
	screen_menu_open = false
	for slot in _devices.size():
		leave(slot)


## Direção do analógico esquerdo (ou WASD) em coordenadas de tela, comprimento 0..1.
func get_move(slot: int) -> Vector2:
	return Vector2.ZERO if is_blocked(slot) else raw_move(slot)


## Mira (twin-stick) já no chão do mundo: Vector2(x, z) de comprimento 1, ou zero se não mira.
## Controle: analógico direito. Teclado: mouse, enquanto segura um botão do mouse.
func get_aim(slot: int) -> Vector2:
	if is_blocked(slot):
		return Vector2.ZERO
	var device := _devices[slot]
	if device == KEYBOARD:
		var mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		if not mouse_down or not aim_projector.is_valid() or not is_inside_tree():
			return Vector2.ZERO
		var anchor := _aim_anchor[slot]
		var point: Vector3 = aim_projector.call(get_viewport().get_mouse_position(), anchor.y + 1.0)
		var flat := Vector2(point.x - anchor.x, point.z - anchor.z)
		return flat.normalized() if flat.length() > 0.3 else Vector2.ZERO
	if device >= 0:
		var stick := Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
		if stick.length() < GameConfig.AIM_DEADZONE:
			return Vector2.ZERO
		var world := Vector3(stick.x, 0.0, stick.y).rotated(Vector3.UP, deg_to_rad(GameConfig.CAMERA_YAW_DEG))
		return Vector2(world.x, world.z).normalized()
	return Vector2.ZERO


func set_aim_anchor(slot: int, world_position: Vector3) -> void:
	_aim_anchor[slot] = world_position


## Direção para menus: analógico, direcional ou WASD/setas, ignorando o bloqueio.
func raw_move(slot: int) -> Vector2:
	var device := _devices[slot]
	if device == KEYBOARD:
		var v := Vector2(
			float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
					- float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
			float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
					- float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		return v.limit_length(1.0)
	if device >= 0:
		var dpad := Vector2(
			float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT)),
			float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP)))
		if dpad != Vector2.ZERO:
			return dpad.normalized()
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
	_blocked[slot] = false
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
	if is_inside_tree():
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
		return (KEYS.has(action) and Input.is_physical_key_pressed(KEYS[action])) \
				or (MOUSE_BUTTONS.has(action) and Input.is_mouse_button_pressed(MOUSE_BUTTONS[action]))
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
