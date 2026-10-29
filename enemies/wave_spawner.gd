extends Node3D
## Ondas de inimigos na arena. Quando uma onda acaba, vem a próxima, maior.
## Se o grupo inteiro cair, volta para a onda 1.

signal wave_started(number: int)

const FIRST_WAVE_DELAY := 2.0
const BETWEEN_WAVES := 3.0
## Pontos de entrada nas bordas da arena (x, z).
const SPAWN_POINTS: Array[Vector2] = [
	Vector2(-13, -13), Vector2(13, -13), Vector2(-13, 13), Vector2(13, 13),
	Vector2(0, -14), Vector2(0, 14), Vector2(-14, 0), Vector2(14, 0),
]

@export var player_manager: Node

var wave := 0

var _alive := 0
var _timer := FIRST_WAVE_DELAY


func _ready() -> void:
	add_to_group("wave_spawner")
	if player_manager:
		player_manager.party_wiped.connect(reset)


func alive_count() -> int:
	return _alive


func reset() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	wave = 0
	_alive = 0
	_timer = FIRST_WAVE_DELAY


func _physics_process(delta: float) -> void:
	if _alive > 0 or get_tree().get_nodes_in_group("players").is_empty():
		return
	_timer -= delta
	if _timer <= 0.0:
		_spawn_wave()


func _spawn_wave() -> void:
	wave += 1
	_timer = BETWEEN_WAVES
	var kinds: Array[Enemy.Kind] = []
	for i in 2 + wave:
		kinds.append(Enemy.Kind.MELEE)
	for i in floori(wave / 2.0):
		kinds.append(Enemy.Kind.RANGED)
	var points := SPAWN_POINTS.duplicate()
	points.shuffle()
	for i in kinds.size():
		var point: Vector2 = points[i % points.size()]
		var jitter := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		var enemy := Enemy.create(kinds[i])
		add_child(enemy)
		enemy.global_position = Vector3(point.x, 0.0, point.y) + jitter
		enemy.reset_physics_interpolation()
		enemy.died.connect(func(_enemy: Enemy) -> void: _alive -= 1)
		_alive += 1
	wave_started.emit(wave)
