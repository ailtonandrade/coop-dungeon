extends Camera3D
## Câmera única compartilhada (sem tela dividida): segue o centro do grupo
## e se afasta quando os jogadores se espalham.

@export var player_root: Node3D

var _focus := Vector3.ZERO
var _distance := GameConfig.CAMERA_DIST_MIN


func _ready() -> void:
	fov = GameConfig.CAMERA_FOV
	rotation_degrees = Vector3(GameConfig.CAMERA_PITCH_DEG, GameConfig.CAMERA_YAW_DEG, 0.0)
	_apply()


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


func _apply() -> void:
	global_position = _focus + global_basis.z * _distance


func _players() -> Array[Player]:
	var players: Array[Player] = []
	if player_root:
		for child in player_root.get_children():
			if child is Player:
				players.append(child)
	return players
