class_name CreatureSpawner
extends Marker3D
## Ponto de criaturas no mapa (acampamento, toca). Fica dentro de um bloco: quando o bloco
## carrega, as criaturas nascem em volta; quando descarrega, somem. Quem morre volta depois
## de `respawn_time`. Roda só no host; as criaturas vão pela rede pelo NetReplicator.

## Tipos (Enemy.Kind) sorteados para cada criatura.
@export var kinds: PackedInt32Array = PackedInt32Array([0])
@export var count := 3
@export var respawn_time := 30.0
## Raio em volta do ponto onde as criaturas nascem.
@export var spread := 3.0
## A criatura persegue quem chega até aqui...
@export var aggro_radius := 10.0
## ...e desiste se o alvo a levar para mais longe que isso do ponto.
@export var leash_radius := 20.0
## Poder do loot (perigo da região).
@export var power := 1

var _alive: Array[Enemy] = []
var _respawns: Array[float] = []
var _started := false


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_alive = _alive.filter(func(e: Enemy) -> bool: return is_instance_valid(e) and e.is_targetable())
	if not _started:
		_started = true
		for i in count:
			_spawn()
		return
	for i in range(_respawns.size() - 1, -1, -1):
		_respawns[i] -= delta
		if _respawns[i] <= 0.0:
			_respawns.remove_at(i)
			_spawn()


func _exit_tree() -> void:
	if not multiplayer.is_server():
		return
	for enemy in _alive:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_alive.clear()


func _spawn() -> void:
	var replicator := NetReplicator.of(self)
	if replicator == null:
		return
	var offset := Vector3(randf_range(-spread, spread), 0.0, randf_range(-spread, spread))
	var enemy: Enemy = replicator.spawn("enemy", {
		"kind": kinds[randi() % kinds.size()], "pos": global_position + offset, "home": global_position,
		"aggro": aggro_radius, "leash": leash_radius, "power": power,
	})
	enemy.died.connect(func(_e: Enemy) -> void: _respawns.append(respawn_time))
	_alive.append(enemy)
