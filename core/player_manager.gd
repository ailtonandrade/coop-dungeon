extends Node3D
## Cria e remove jogadores conforme entram e saem pelo InputService e aplica a "corda"
## do co-op: quem se afastar demais do grupo é teleportado para perto do companheiro mais próximo.
## Se todos caírem, todo mundo volta de pé no início depois de alguns segundos.

signal party_wiped

const PLAYER_SCENE := preload("res://player/player.tscn")

@export var spawn_position := Vector3.ZERO

var _players: Dictionary = {}  # slot -> Player
var _wipe_timer := 0.0


func _ready() -> void:
	InputService.player_joined.connect(_on_player_joined)
	InputService.player_left.connect(_on_player_left)
	for slot in InputService.active_slots():
		_spawn(slot)


func _physics_process(delta: float) -> void:
	_check_wipe(delta)
	for player: Player in _players.values():
		if not player.is_targetable():
			continue
		var nearest := _nearest_teammate(player)
		if player.global_position.y < GameConfig.KILL_Y:
			player.teleport_to(nearest.global_position + Vector3.BACK if nearest else spawn_position)
		elif nearest and player.global_position.distance_to(nearest.global_position) > GameConfig.TETHER_DISTANCE:
			player.teleport_to(nearest.global_position + nearest.global_basis.z)


func _check_wipe(delta: float) -> void:
	if _players.is_empty() or _players.values().any(func(p: Player) -> bool: return p.is_targetable()):
		_wipe_timer = 0.0
		return
	_wipe_timer += delta
	if _wipe_timer < GameConfig.WIPE_RESTART_TIME:
		return
	_wipe_timer = 0.0
	for slot: int in _players:
		var player: Player = _players[slot]
		player.revive(1.0)
		player.teleport_to(spawn_position + Vector3.RIGHT.rotated(Vector3.UP, TAU * slot / GameConfig.MAX_PLAYERS) * 1.5)
	party_wiped.emit()


func _on_player_joined(slot: int, _device: int) -> void:
	_spawn(slot)


func _on_player_left(slot: int) -> void:
	if _players.has(slot):
		_players[slot].queue_free()
		_players.erase(slot)


func _spawn(slot: int) -> void:
	var player := PLAYER_SCENE.instantiate() as Player
	player.slot = slot
	add_child(player)
	var base := spawn_position
	if not _players.is_empty():
		base = (_players.values()[0] as Player).global_position
	player.teleport_to(base + Vector3.RIGHT.rotated(Vector3.UP, TAU * slot / GameConfig.MAX_PLAYERS) * 1.5)
	_players[slot] = player


func _nearest_teammate(player: Player) -> Player:
	var nearest: Player = null
	var best := INF
	for other: Player in _players.values():
		if other == player or not other.is_targetable():
			continue
		var d := player.global_position.distance_squared_to(other.global_position)
		if d < best:
			best = d
			nearest = other
	return nearest
