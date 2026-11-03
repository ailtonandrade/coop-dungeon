class_name Weather
extends Node
## Clima do mundo: chuva que vem e vai sozinha, e poeira no ar o tempo todo. Quem manda no mundo (host ou sofá offline)
## sorteia; o clima vai no save do mundo (chave "rain": 0 ou 1) e para os convidados.
##
## Chovendo: gotas caindo em volta dos heróis, respingos no chão, som de chuva, chão mais
## molhado (brilha nas luzes), luz mais fechada (o relógio lê `level`).
## Dentro de casa/caverna (interiores) a chuva some e o som fica abafado.

## Duração de cada trecho (segundos de verdade) e a chance de o próximo ser de chuva.
const SPELL_MIN := 180.0
const SPELL_MAX := 480.0
const RAIN_CHANCE := 0.35
## Quanto tempo a chuva leva para chegar ou parar.
const RAMP := 25.0
const AREA := 26.0
const DROPS := 2200
const SPLASHES := 260
const DUST := 420
const RAIN_SOUND := "res://audio/music/chuva.ogg"

## 0 = seco, 1 = chovendo forte (vai mudando aos poucos até `target`).
var level := 0.0
var target := 0.0

var _spell_left := 0.0
var _rain: GPUParticles3D
var _splash: GPUParticles3D
var _dust: GPUParticles3D
var _sound: AudioStreamPlayer
var _ground_check := 0.0
var _indoors := false


static func of(tree: SceneTree) -> Weather:
	return tree.get_first_node_in_group("weather") as Weather


func _ready() -> void:
	add_to_group("weather")
	NetService.weather_received.connect(func(value: float) -> void: target = value)
	target = float(NetService.world.get("rain", 0.0))
	level = target
	_spell_left = randf_range(SPELL_MIN, SPELL_MAX)
	_build()
	_apply_effects()


## Liga/desliga a chuva (comando /chuva do dono do jogo). Só quem manda no mundo.
func set_rain(on: bool) -> void:
	if NetService.mode == NetService.Mode.CLIENT:
		return
	target = 1.0 if on else 0.0
	_spell_left = randf_range(SPELL_MIN, SPELL_MAX)
	NetService.world["rain"] = target
	NetService.send_weather(target)


func is_raining() -> bool:
	return target > 0.5


func _process(delta: float) -> void:
	if NetService.mode != NetService.Mode.CLIENT:
		_spell_left -= delta
		if _spell_left <= 0.0:
			set_rain(randf() < RAIN_CHANCE)
	level = move_toward(level, target, delta / RAMP)
	_follow_players()
	_apply_effects()


func _build() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "Gotas"
	_rain.amount = DROPS
	_rain.lifetime = 0.9
	_rain.preprocess = 1.0
	_rain.visibility_aabb = AABB(Vector3(-AREA, -16, -AREA), Vector3(AREA * 2, 24, AREA * 2))
	_rain.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(AREA, 0.5, AREA)
	process.direction = Vector3(0.12, -1.0, 0.05)
	process.spread = 3.0
	process.initial_velocity_min = 16.0
	process.initial_velocity_max = 20.0
	process.gravity = Vector3(0, -6, 0)
	_rain.process_material = process
	var drop := QuadMesh.new()
	drop.size = Vector2(0.025, 0.55)
	var drop_material := StandardMaterial3D.new()
	drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_material.albedo_color = Color(0.75, 0.82, 0.95, 0.28)
	drop_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	drop.material = drop_material
	_rain.draw_pass_1 = drop
	add_child(_rain)

	_splash = GPUParticles3D.new()
	_splash.name = "Respingos"
	_splash.amount = SPLASHES
	_splash.lifetime = 0.3
	_splash.visibility_aabb = AABB(Vector3(-AREA, -2, -AREA), Vector3(AREA * 2, 4, AREA * 2))
	_splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var splash_process := ParticleProcessMaterial.new()
	splash_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	splash_process.emission_box_extents = Vector3(AREA * 0.8, 0.0, AREA * 0.8)
	splash_process.direction = Vector3.UP
	splash_process.spread = 40.0
	splash_process.initial_velocity_min = 0.6
	splash_process.initial_velocity_max = 1.4
	splash_process.gravity = Vector3(0, -9, 0)
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.0))
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	splash_process.scale_curve = grow_texture
	_splash.process_material = splash_process
	var splash_mesh := QuadMesh.new()
	splash_mesh.size = Vector2(0.06, 0.06)
	var splash_material := StandardMaterial3D.new()
	splash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	splash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	splash_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	splash_material.albedo_color = Color(0.85, 0.9, 1.0, 0.35)
	splash_mesh.material = splash_material
	_splash.draw_pass_1 = splash_mesh
	add_child(_splash)

	# Poeira no ar, sempre (some quase toda com a chuva, que assenta o pó): grãos claros
	# boiando devagar em volta dos heróis, pegando a luz.
	_dust = GPUParticles3D.new()
	_dust.name = "Poeira"
	_dust.amount = DUST
	_dust.lifetime = 9.0
	_dust.preprocess = 9.0
	_dust.visibility_aabb = AABB(Vector3(-AREA, -2, -AREA), Vector3(AREA * 2, 10, AREA * 2))
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dust_process := ParticleProcessMaterial.new()
	dust_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dust_process.emission_box_extents = Vector3(AREA * 0.7, 3.0, AREA * 0.7)
	dust_process.direction = Vector3(1, 0.1, 0.3)
	dust_process.spread = 60.0
	dust_process.initial_velocity_min = 0.05
	dust_process.initial_velocity_max = 0.35
	dust_process.gravity = Vector3(0.05, -0.02, 0.02)
	dust_process.turbulence_enabled = true
	dust_process.turbulence_noise_strength = 0.4
	dust_process.turbulence_noise_scale = 3.0
	var fade := Curve.new()
	fade.add_point(Vector2(0, 0))
	fade.add_point(Vector2(0.2, 1))
	fade.add_point(Vector2(0.8, 1))
	fade.add_point(Vector2(1, 0))
	var fade_texture := CurveTexture.new()
	fade_texture.curve = fade
	dust_process.scale_curve = fade_texture
	_dust.process_material = dust_process
	var mote := QuadMesh.new()
	mote.size = Vector2(0.035, 0.035)
	var mote_material := StandardMaterial3D.new()
	mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mote_material.albedo_color = Color(0.85, 0.8, 0.68, 0.45)
	mote.material = mote_material
	_dust.draw_pass_1 = mote
	add_child(_dust)

	_sound = AudioStreamPlayer.new()
	_sound.name = "SomDaChuva"
	_sound.bus = "Ambience"
	var stream := load(RAIN_SOUND) as AudioStreamOggVorbis
	if stream:
		stream.loop = true
	_sound.stream = stream
	_sound.volume_db = -60.0
	add_child(_sound)


## A chuva cai em volta dos heróis desta máquina (o meio deles).
func _follow_players() -> void:
	var sum := Vector3.ZERO
	var count := 0
	for player: Node3D in get_tree().get_nodes_in_group("players"):
		if player.has_method("is_local") and player.is_local():
			sum += player.global_position
			count += 1
	if count == 0:
		var camera := get_viewport().get_camera_3d() if get_viewport() else null
		if camera == null:
			return
		sum = camera.global_position * Vector3(1, 0, 1)
		count = 1
	var center := sum / count
	_indoors = _is_indoors(center)
	_rain.global_position = center + Vector3(0, 13.0, 0)
	_splash.global_position = center + Vector3(0, 0.05, 0)
	_dust.global_position = center + Vector3(0, 2.5, 0)


func _is_indoors(point: Vector3) -> bool:
	var streamer := get_tree().get_first_node_in_group("world_streamer")
	if streamer == null or not streamer.has_method("chunk_at"):
		return false
	var key: String = streamer.chunk_at(point)[1]
	return key.begins_with("i:")


func _apply_effects() -> void:
	var outside := 0.0 if _indoors else level
	var visible_rain := outside > 0.02
	_rain.emitting = visible_rain
	_rain.visible = visible_rain
	_rain.amount_ratio = clampf(outside, 0.05, 1.0)
	_splash.emitting = visible_rain
	_splash.visible = visible_rain
	_splash.amount_ratio = clampf(outside, 0.05, 1.0)
	# A chuva assenta a poeira; dentro de casa e caverna também tem pó (menos).
	_dust.amount_ratio = clampf((1.0 - level * 0.85) * (0.5 if _indoors else 1.0), 0.05, 1.0)
	# Som: forte fora, abafado dentro; some quando seca.
	var loudness := level * (0.35 if _indoors else 1.0)
	if loudness > 0.01:
		if not _sound.playing and _sound.stream:
			_sound.play()
		_sound.volume_db = linear_to_db(loudness) - 4.0
	elif _sound.playing:
		_sound.stop()
	_ground_check -= get_process_delta_time()
	if _ground_check <= 0.0:
		_ground_check = 1.0
		_wet_ground()


## Chão molhado: o chão dos blocos fica mais liso (brilha com as luzes) enquanto chove.
func _wet_ground() -> void:
	var streamer := get_tree().get_first_node_in_group("world_streamer")
	if streamer == null:
		return
	for chunk: Node in streamer.get_children():
		for path: String in ["Navigation/Ground/Mesh", "Navigation/Floor/Mesh"]:
			var mesh := chunk.get_node_or_null(path) as MeshInstance3D
			if mesh == null or not mesh.material_override is BaseMaterial3D:
				continue
			var material := mesh.material_override as BaseMaterial3D
			if not material.has_meta("dry_roughness"):
				material.set_meta("dry_roughness", material.roughness)
				material.set_meta("dry_specular", material.metallic_specular)
			var dry := float(material.get_meta("dry_roughness"))
			material.roughness = lerpf(dry, minf(dry, 0.32), level)
			material.metallic_specular = lerpf(float(material.get_meta("dry_specular")), 0.8, level)
