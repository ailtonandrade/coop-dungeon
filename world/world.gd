extends Node3D
## Cena do mundo aberto. Monta ambiente e luz, carrega na hora os blocos em volta do ponto
## de partida (antes de alguém nascer) e libera a entrada dos jogadores.
## Os blocos em si vêm do WorldMap pelo WorldStreamer.

## Arquivo que o editor de mapa escreve para "Jogar a partir daqui".
const DEBUG_SPAWN_FILE := "user://debug_spawn.json"

@export var world_map: WorldMap

@onready var _streamer: WorldStreamer = $WorldStreamer
@onready var _players: Node3D = $PlayerManager


func _ready() -> void:
	_build_environment()
	_streamer.world_map = world_map
	_players.spawn_position = _debug_spawn_point(world_map.spawn_point)
	_streamer.load_now(_players.spawn_position)
	# Mundo pronto: libera entrar no jogo e avisa o host (se for cliente).
	InputService.joining_enabled = true
	NetService.notify_level_ready()
	InputService.join_last_device()


## "Jogar a partir daqui" do editor de mapa: começa no bloco escolhido (só rodando pelo editor).
func _debug_spawn_point(default: Vector3) -> Vector3:
	if not OS.has_feature("editor") or not FileAccess.file_exists(DEBUG_SPAWN_FILE):
		return default
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEBUG_SPAWN_FILE))
	DirAccess.remove_absolute(DEBUG_SPAWN_FILE)
	if data is Array and data.size() == 3:
		return Vector3(data[0], data[1], data[2])
	return default


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
