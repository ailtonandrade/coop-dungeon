extends Node3D
## Vagas da sala (P1 a P4) e regras do grupo. Roda no host: cria os jogadores pelo
## NetReplicator quando alguém pede para entrar (no sofá ou pela rede).
## A "corda" vale só entre quem divide a mesma tela (mesma máquina): o limite de distância
## fica no movimento do herói (COUCH_LEASH) e, de reserva, quem passar de TETHER_DISTANCE
## (queda, empurrão) é teleportado. Jogadores online podem ir para regiões diferentes.
## Se todos caírem, todo mundo volta de pé no início depois de alguns segundos.

signal party_wiped

@export var spawn_position := Vector3.ZERO

var _players: Dictionary = {}  # índice na sala -> Player
var _wipe_timer := 0.0


func _ready() -> void:
	add_to_group("player_manager")
	InputService.player_joined.connect(func(slot: int, _device: int) -> void: NetService.request_player(slot))
	InputService.player_left.connect(func(slot: int) -> void: NetService.request_leave(slot))


func add_player(peer: int, slot: int, display_name: String, save := {}) -> void:
	if _find(peer, slot) or _players.size() >= GameConfig.MAX_PLAYERS:
		return
	var index := 0
	while _players.has(index):
		index += 1
	var base := spawn_position
	if not _players.is_empty():
		base = (_players.values()[0] as Player).global_position
	_players[index] = NetReplicator.of(self).spawn("player", {
		"peer": peer, "slot": slot, "index": index, "name": display_name,
		"inventory": save.get("inventory", {}),
		"pos": base + _ring_offset(index),
	})


func remove_player(peer: int, slot: int) -> void:
	var player := _find(peer, slot)
	if player:
		_players.erase(player.index)
		player.queue_free()


func remove_peer(peer: int) -> void:
	for player: Player in _players.values():
		if player.owner_peer == peer:
			remove_player(peer, player.slot)


func _find(peer: int, slot: int) -> Player:
	for player: Player in _players.values():
		if player.owner_peer == peer and player.slot == slot:
			return player
	return null


func _ring_offset(index: int) -> Vector3:
	return Vector3.RIGHT.rotated(Vector3.UP, TAU * index / GameConfig.MAX_PLAYERS) * 1.5


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_check_wipe(delta)
	for player: Player in _players.values():
		if not player.is_targetable():
			continue
		var nearest := _nearest_screen_mate(player)
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
	for index: int in _players:
		var player: Player = _players[index]
		player.revive(1.0)
		player.teleport_to(spawn_position + _ring_offset(index))
	party_wiped.emit()


## Companheiro de pé mais perto que joga na mesma tela (mesma máquina).
func _nearest_screen_mate(player: Player) -> Player:
	var nearest: Player = null
	var best := INF
	for other: Player in _players.values():
		if other == player or other.owner_peer != player.owner_peer or not other.is_targetable():
			continue
		var d := player.global_position.distance_squared_to(other.global_position)
		if d < best:
			best = d
			nearest = other
	return nearest
