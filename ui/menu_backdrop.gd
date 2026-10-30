class_name MenuBackdrop
extends Node3D
## Fundo do menu principal: a vila inicial do mapa de verdade, à noite, com a câmera
## girando devagar em volta (como a tela inicial do LoL ou do Minecraft Dungeons).
## Só enfeite: tira tudo que tem comportamento (criaturas, entradas).

const SCENE := "res://world/chunks/chunk_0_0.tscn"
const CENTER := Vector3(32, 0, 34)
const RADIUS := 22.0
const HEIGHT := 12.0
## Voltas por minuto.
const SPEED := 0.6

var _camera: Camera3D
var _angle := 0.7


func _ready() -> void:
	var packed := load(SCENE) as PackedScene
	if packed:
		var town := packed.instantiate()
		for node in town.find_children("*", "", true, false):
			if node is CreatureSpawner or node is Entrance:
				node.queue_free()
		add_child(town)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.03, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.42, 0.65)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.08, 0.16)
	env.fog_density = 0.012
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-50.0, -40.0, 0.0)
	moon.light_color = Color(0.6, 0.65, 1.0)
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	add_child(moon)

	# Pontos de neon espalhados pela vila.
	var neons := [[Vector3(18, 4, 22), Color(1.0, 0.3, 0.75)], [Vector3(46, 4, 24), Color(0.2, 0.95, 1.0)],
			[Vector3(30, 3, 46), Color(1.0, 0.6, 0.2)], [Vector3(50, 4, 48), Color(0.2, 0.95, 1.0)]]
	for entry: Array in neons:
		var light := OmniLight3D.new()
		light.position = entry[0]
		light.light_color = entry[1]
		light.light_energy = 3.0
		light.omni_range = 16.0
		add_child(light)

	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	_camera.make_current()
	_place_camera()


func _process(delta: float) -> void:
	_angle += delta * TAU * SPEED / 60.0
	_place_camera()


func _place_camera() -> void:
	_camera.position = CENTER + Vector3(cos(_angle) * RADIUS, HEIGHT, sin(_angle) * RADIUS)
	_camera.look_at(CENTER + Vector3(0, 2, 0))
