extends Camera3D
## Câmera única compartilhada (sem tela dividida): segue o centro do grupo
## e se afasta quando os jogadores se espalham.
##
## Com um jogador só nesta tela e a opção ligada (Settings.camera_mode = "behind"), vira uma
## câmera atrás do herói, estilo GTA: o analógico direito ou o mouse giram a câmera, andar é
## relativo a ela e o ataque vai para a frente dela. Entrou mais alguém no sofá: volta para a
## de cima sozinha.

@export var player_root: Node3D

const SHAKE_DECAY := 2.5
const SNAP_DISTANCE := 25.0
const SHAKE_MAX_OFFSET := 0.6

var _focus := Vector3.ZERO
var _distance := GameConfig.CAMERA_DIST_MIN
var _trauma := 0.0
var _behind := false
var _yaw := 0.0
var _pitch := -0.3
var _behind_player: Player


## Tremida de câmera (0..1). Golpes fortes e dano recebido chamam pelo grupo "shared_camera".
func shake(strength: float) -> void:
	_trauma = minf(_trauma + strength, 1.0)


func _ready() -> void:
	add_to_group("shared_camera")
	InputService.aim_projector = project_to_ground
	fov = GameConfig.CAMERA_FOV
	rotation_degrees = Vector3(GameConfig.CAMERA_PITCH_DEG, GameConfig.CAMERA_YAW_DEG, 0.0)
	_apply()


func _process(delta: float) -> void:
	if _behind:
		_update_mouse_capture()
	_trauma = maxf(_trauma - SHAKE_DECAY * delta, 0.0)
	var amount := _trauma * _trauma * SHAKE_MAX_OFFSET
	h_offset = randf_range(-amount, amount)
	v_offset = randf_range(-amount, amount)


func _physics_process(delta: float) -> void:
	var players := _players()
	if players.is_empty():
		return
	var local := players.filter(func(p: Player) -> bool: return p.is_local())
	var want_behind: bool = Settings.camera_mode == "behind" and local.size() == 1
	if want_behind != _behind or (want_behind and local[0] != _behind_player):
		_set_behind(want_behind, local[0] if want_behind else null)
	if _behind:
		_follow_behind(delta)
		return

	var center := Vector3.ZERO
	for player in players:
		center += player.global_position
	center /= players.size()

	var spread := 0.0
	for player in players:
		spread = maxf(spread, player.global_position.distance_to(center))
	var t := clampf(spread * 2.0 / GameConfig.CAMERA_SPREAD_FOR_MAX, 0.0, 1.0)
	var target_distance := lerpf(GameConfig.CAMERA_DIST_MIN, GameConfig.CAMERA_DIST_MAX, t)

	# Grupo foi teleportado (entrada de masmorra): corta direto, sem atravessar o mapa.
	if _focus.distance_to(center) > SNAP_DISTANCE:
		_focus = center
		reset_physics_interpolation()
	_focus = _focus.lerp(center, 1.0 - exp(-GameConfig.CAMERA_FOLLOW_SPEED * delta))
	_distance = lerpf(_distance, target_distance, 1.0 - exp(-GameConfig.CAMERA_ZOOM_SPEED * delta))
	_apply()


func _exit_tree() -> void:
	if InputService.aim_projector == Callable(self, "project_to_ground"):
		InputService.aim_projector = Callable()
	_set_behind(false, null)


## Atrás do herói

func is_behind() -> bool:
	return _behind


func _set_behind(on: bool, player: Player) -> void:
	_behind = on
	_behind_player = player
	InputService.behind_view = on
	if on:
		# Começa atrás de onde o herói está olhando.
		var facing: Vector3 = player.get("_facing")
		_yaw = atan2(-facing.x, -facing.z) if facing.length_squared() > 0.01 else 0.0
		_pitch = -0.3
		fov = GameConfig.BEHIND_FOV
		reset_physics_interpolation()
	else:
		fov = GameConfig.CAMERA_FOV
		rotation_degrees = Vector3(GameConfig.CAMERA_PITCH_DEG, GameConfig.CAMERA_YAW_DEG, 0.0)
		InputService.view_yaw_deg = GameConfig.CAMERA_YAW_DEG
		if is_inside_tree():
			_apply()
			reset_physics_interpolation()
	_update_mouse_capture()


func _follow_behind(delta: float) -> void:
	if not is_instance_valid(_behind_player):
		return
	var slot := _behind_player.slot
	# Analógico direito gira a câmera (o mouse gira em _unhandled_input).
	var device := InputService.device_of(slot)
	if device >= 0 and not InputService.is_blocked(slot):
		var stick := Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
		if stick.length() > GameConfig.AIM_DEADZONE:
			var speed := GameConfig.BEHIND_STICK_SPEED * Settings.look_sensitivity * delta
			_turn(-stick.x * speed, -stick.y * speed)
	var look := Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	var target := _behind_player.global_position + Vector3.UP * GameConfig.BEHIND_HEIGHT
	var wanted := target + look.z * GameConfig.BEHIND_DISTANCE + look.x * GameConfig.BEHIND_SHOULDER
	# Parede entre o herói e a câmera: chega a câmera para a frente dela.
	var query := PhysicsRayQueryParameters3D.create(target, wanted, GameConfig.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		wanted = hit.position + (target - wanted).normalized() * 0.25
	global_position = wanted
	global_basis = look
	InputService.view_yaw_deg = rad_to_deg(_yaw)
	InputService.view_forward = -Vector3(look.z.x, 0.0, look.z.z).normalized()
	InputService.set_aim_anchor(slot, _behind_player.global_position)


func _turn(yaw: float, pitch: float) -> void:
	_yaw = wrapf(_yaw + yaw, -PI, PI)
	_pitch = clampf(_pitch + pitch, GameConfig.BEHIND_PITCH_MIN, GameConfig.BEHIND_PITCH_MAX)


func _unhandled_input(event: InputEvent) -> void:
	if _behind and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var speed := GameConfig.BEHIND_MOUSE_SPEED * Settings.look_sensitivity
		_turn(-event.relative.x * speed, -event.relative.y * speed)


## Teclado e mouse atrás do herói: o mouse fica preso na janela (gira a câmera), e solta com
## qualquer menu aberto.
func _update_mouse_capture() -> void:
	var keyboard := _behind and is_instance_valid(_behind_player) and InputService.device_of(_behind_player.slot) == InputService.KEYBOARD
	var capture := keyboard and not InputService.screen_menu_open and not InputService.is_blocked(_behind_player.slot) \
			and DisplayServer.get_name() != "headless"
	var wanted := Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != wanted:
		Input.mouse_mode = wanted


## Ponto do chão (na altura `height`) embaixo de um ponto da tela. Usado pela mira do mouse.
func project_to_ground(screen_point: Vector2, height: float) -> Vector3:
	var origin := project_ray_origin(screen_point)
	var normal := project_ray_normal(screen_point)
	var hit: Variant = Plane(Vector3.UP, height).intersects_ray(origin, normal)
	return hit if hit != null else origin


func _apply() -> void:
	global_position = _focus + global_basis.z * _distance


## No online, cada máquina enquadra só os seus jogadores (a corda mantém o grupo junto).
## Se ainda não tem nenhum local, enquadra quem estiver na sala.
func _players() -> Array[Player]:
	var all: Array[Player] = []
	var local: Array[Player] = []
	if player_root:
		for child in player_root.get_children():
			if child is Player:
				all.append(child)
				if child.is_local():
					local.append(child)
	return local if not local.is_empty() else all
