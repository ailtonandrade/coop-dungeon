class_name HitFx
extends RefCounted
## Efeitos de acerto que rodam em todas as máquinas (chamados pelos fx_* das entidades):
## número de dano que salta, faíscas no impacto e a explosão da morte.
## Ficam soltos na cena (não no alvo, que pode sumir antes do efeito acabar).

const NUMBER_COLORS := {
	"hit": Color(1.0, 0.97, 0.9), "heavy": Color(1.0, 0.78, 0.25),
	"hurt": Color(1.0, 0.32, 0.28), "heal": Color(0.45, 1.0, 0.5),
}


## Número que salta da cabeça e some: "hit" (golpe comum), "heavy" (finalizador), "hurt"
## (dano no herói) ou "heal" (cura, com +).
static func damage_number(source: Node3D, position: Vector3, amount: float, kind := "hit") -> void:
	var scene := _scene(source)
	if scene == null or amount <= 0.0:
		return
	var label := Label3D.new()
	label.text = ("+%d" if kind == "heal" else "%d") % maxi(roundi(amount), 1)
	label.modulate = NUMBER_COLORS.get(kind, Color.WHITE)
	label.outline_modulate = Color(0.05, 0.03, 0.03)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0011
	label.font = UiSkin.title_font()
	label.font_size = 52 if kind == "heavy" else 38
	label.outline_size = 14
	label.layers = 2
	label.render_priority = 10
	scene.add_child(label)
	label.global_position = position + Vector3(randf_range(-0.35, 0.35), 0.0, randf_range(-0.2, 0.2))
	label.scale = Vector3.ONE * 0.4
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector3.ONE * (1.25 if kind == "heavy" else 1.0), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "global_position", label.global_position + Vector3(0, 1.1, 0), 0.75).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.45)
	tween.parallel().tween_property(label, "outline_modulate:a", 0.0, 0.35).set_delay(0.45)
	tween.tween_callback(label.queue_free)


## Faíscas saindo do ponto do acerto.
static func sparks(source: Node3D, position: Vector3, color: Color, amount := 14, speed := 5.0) -> void:
	var scene := _scene(source)
	if scene == null:
		return
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = 0.4
	particles.direction = Vector3.UP
	particles.spread = 75.0
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, -14, 0)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	particles.scale_amount_curve = curve
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.05, 0.16)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	box.material = material
	particles.mesh = box
	particles.particle_flag_align_y = true
	scene.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


## Morte: chuva de faíscas, fumaça e um clarão rápido.
static func death_burst(source: Node3D, position: Vector3, color: Color) -> void:
	var scene := _scene(source)
	if scene == null:
		return
	sparks(source, position, color, 28, 7.0)
	sparks(source, position, Color(1.0, 0.9, 0.6), 10, 4.0)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 4.0
	light.omni_range = 5.0
	scene.add_child(light)
	light.global_position = position + Vector3.UP * 0.5
	var fade := light.create_tween()
	fade.tween_property(light, "light_energy", 0.0, 0.25)
	fade.tween_callback(light.queue_free)
	for i in 5:
		var puff := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.25
		sphere.height = 0.5
		sphere.radial_segments = 8
		sphere.rings = 4
		puff.mesh = sphere
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.25, 0.23, 0.22, 0.55)
		puff.material_override = material
		scene.add_child(puff)
		puff.global_position = position + Vector3(randf_range(-0.4, 0.4), randf_range(-0.2, 0.4), randf_range(-0.4, 0.4))
		var tween := puff.create_tween()
		tween.tween_property(puff, "scale", Vector3.ONE * randf_range(2.0, 3.0), 0.7).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(puff, "global_position", puff.global_position + Vector3.UP * 0.8, 0.7)
		tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.7)
		tween.tween_callback(puff.queue_free)


## Subiu de nível: coluna de luz na cor do jogador, faíscas e "NÍVEL N" subindo.
static func level_up(source: Node3D, position: Vector3, new_level: int, color: Color) -> void:
	var scene := _scene(source)
	if scene == null:
		return
	var pillar := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.7
	cylinder.bottom_radius = 0.9
	cylinder.height = 6.0
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	pillar.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color, 0.5)
	pillar.material_override = material
	scene.add_child(pillar)
	pillar.global_position = position + Vector3.UP * 3.0
	pillar.scale = Vector3(0.2, 1.0, 0.2)
	var tween := pillar.create_tween()
	tween.tween_property(pillar, "scale", Vector3(1.0, 1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.9)
	tween.tween_callback(pillar.queue_free)
	sparks(source, position + Vector3.UP * 0.3, color.lightened(0.4), 30, 6.0)
	var label := Label3D.new()
	label.text = "NÍVEL %d" % new_level
	label.modulate = Color(1.0, 0.85, 0.35)
	label.outline_modulate = Color(0.05, 0.03, 0.03)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0011
	label.font = UiSkin.title_font()
	label.font_size = 54
	label.outline_size = 16
	label.layers = 2
	label.render_priority = 10
	scene.add_child(label)
	label.global_position = position + Vector3.UP * 2.4
	var rise := label.create_tween()
	rise.tween_property(label, "global_position", label.global_position + Vector3.UP * 1.2, 1.6).set_ease(Tween.EASE_OUT)
	rise.parallel().tween_property(label, "modulate:a", 0.0, 0.5).set_delay(1.1)
	rise.parallel().tween_property(label, "outline_modulate:a", 0.0, 0.5).set_delay(1.1)
	rise.tween_callback(label.queue_free)


static func _scene(source: Node3D) -> Node:
	if source == null or not source.is_inside_tree():
		return null
	return source.get_tree().current_scene
