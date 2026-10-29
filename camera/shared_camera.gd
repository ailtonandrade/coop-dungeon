extends Camera3D
## Câmera única compartilhada (sem tela dividida): segue o centro do grupo
## e se afasta quando os jogadores se espalham.

@export var player_root: Node3D

const SHAKE_DECAY := 2.5
const SHAKE_MAX_OFFSET := 0.6

var _focus := Vector3.ZERO
var _distance := GameConfig.CAMERA_DIST_MIN
var _trauma := 0.0


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
	_trauma = maxf(_trauma - SHAKE_DECAY * delta, 0.0)
	var amount := _trauma * _trauma * SHAKE_MAX_OFFSET
	h_offset = randf_range(-amount, amount)
	v_offset = randf_range(-amount, amount)


func _physics_process(delta: float) -> void:
	var players := _players()
	if players.is_empty():
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

	_focus = _focus.lerp(center, 1.0 - exp(-GameConfig.CAMERA_FOLLOW_SPEED * delta))
	_distance = lerpf(_distance, target_distance, 1.0 - exp(-GameConfig.CAMERA_ZOOM_SPEED * delta))
	_apply()


func _exit_tree() -> void:
	if InputService.aim_projector == Callable(self, "project_to_ground"):
		InputService.aim_projector = Callable()


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
