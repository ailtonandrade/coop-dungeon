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
	# No mundo: o ambiente de ferro-velho (vento, zumbido de neon, metal longe) e o piano
	# esparso por cima, com muito silêncio entre as frases.
	Sound.play_music("mundo")
	Sound.play_ambience("ambiente")
	# O que já existe nasce de uma vez ao carregar (loot, criaturas): sem barulho junto.
	Sound.quiet_for(1.5)
	_build_environment()
	_add_god_mode()
	_streamer.world_map = world_map
	_players.spawn_position = _debug_spawn_point(_saved_spot(world_map.spawn_point))
	_streamer.load_now(_players.spawn_position)
	# Mundo pronto: libera entrar no jogo e avisa o host (se for cliente).
	InputService.joining_enabled = true
	NetService.notify_level_ready()
	InputService.join_last_device()


## Modo construtor do dono do jogo: só rodando pelo editor do Godot. O arquivo nem vai no jogo
## exportado (filtro de exportação), por isso é carregado pelo caminho, se existir.
const GOD_MODE := "res://world/god_mode.gd"


func _add_god_mode() -> void:
	if OS.has_feature("editor") and ResourceLoader.exists(GOD_MODE):
		add_child((load(GOD_MODE) as Script).new())


## Quem manda no mundo (host ou sofá offline) volta onde o personagem ativo parou neste mundo.
func _saved_spot(default: Vector3) -> Vector3:
	if NetService.mode == NetService.Mode.CLIENT or not NetService.world.has("id"):
		return default
	var spot: Variant = SaveService.character_place(Settings.active_character, str(NetService.world.id))
	return spot if spot is Vector3 and spot.y > GameConfig.KILL_Y + 2.0 else default


## Guarda onde cada herói desta máquina está (último mundo e posição) de tempos em tempos e ao
## sair do mundo: é o que o "Continuar" do menu usa.
const PLACE_SAVE_INTERVAL := 10.0
var _place_timer := 0.0


func _process(delta: float) -> void:
	_place_timer += delta
	if _place_timer >= PLACE_SAVE_INTERVAL:
		_place_timer = 0.0
		save_places()


func _exit_tree() -> void:
	save_places()


func save_places() -> void:
	var world_id := str(NetService.world.get("id", ""))
	if world_id.is_empty():
		return
	for player: Player in get_tree().get_nodes_in_group("players") if is_inside_tree() else []:
		if player.is_local() and not player.character_id.is_empty() and not player.is_downed() \
				and player.global_position.y > GameConfig.KILL_Y + 2.0:
			SaveService.save_character_place(player.character_id, world_id, player.global_position)


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
	# Clima de ferro-velho: céu de poluição, luz fria e neon que brilha (glow).
	env.background_color = Color(0.05, 0.05, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.68)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.2
	# Neblina de poluição só ao longe: some com a borda do mapa na câmera atrás do herói e não
	# chega no que a câmera de cima mostra (até uns 40 m).
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.1, 0.09, 0.14)
	env.fog_depth_begin = 45.0
	env.fog_depth_end = 120.0
	env.fog_density = 1.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60.0, 30.0, 0.0)
	sun.light_color = Color(1.0, 0.9, 0.78)
	sun.light_energy = 0.85
	sun.add_to_group("sun")
	Graphics.apply_sun(sun, Settings.graphics_quality)
	add_child(sun)

	# Relógio do mundo: a luz acompanha a hora (dia, pôr do sol, noite).
	var clock := DayNight.new()
	clock.name = "DayNight"
	add_child(clock)
	clock.setup(env, sun)
