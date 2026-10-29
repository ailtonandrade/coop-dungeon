extends Node3D
## Cena do mundo aberto. Monta ambiente e luz, carrega na hora os blocos em volta do ponto
## de partida (antes de alguém nascer) e libera a entrada dos jogadores.
## Os blocos em si vêm do WorldMap pelo WorldStreamer.

@export var world_map: WorldMap

@onready var _streamer: WorldStreamer = $WorldStreamer
@onready var _players: Node3D = $PlayerManager


func _ready() -> void:
	_build_environment()
	_streamer.world_map = world_map
	_players.spawn_position = world_map.spawn_point
	_streamer.load_now(world_map.spawn_point)
	# Mundo pronto: libera entrar no jogo e avisa o host (se for cliente).
	InputService.joining_enabled = true
	NetService.notify_level_ready()
	InputService.join_last_device()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.07, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60.0, 30.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
