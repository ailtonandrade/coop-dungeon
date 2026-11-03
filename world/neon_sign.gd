@tool
class_name NeonSign
extends Node3D
## Letreiro de neon: o texto aceso (miolo quase branco e o halo na cor do neon), uma placa
## escura atrás e uma luz colorida que pinta a parede e o chão em volta. De noite brilha forte;
## de dia fica mais fraco (o neon continua ligado, mas some na claridade). Pode piscar de vez
## em quando, como neon velho de ferro-velho.
##
## Mexa no Inspector: texto, cor, altura das letras, se tem placa atrás, se pisca e se fica
## num pé (letreiro solto no chão, para barraca na rua). A prévia atualiza no editor.

@export var text := "BAR":
	set(value):
		text = value
		_rebuild()
@export var color := Color(1.0, 0.25, 0.8):
	set(value):
		color = value
		_rebuild()
## Altura das letras, em metros.
@export_range(0.15, 2.0, 0.01) var letter_height := 0.42:
	set(value):
		letter_height = value
		_rebuild()
## Placa escura atrás das letras.
@export var board := true:
	set(value):
		board = value
		_rebuild()
## Pisca de vez em quando (neon com defeito).
@export var flicker := false
## Letreiro solto, num pé de ferro até o chão (o nó fica na altura das letras).
@export var stand := false:
	set(value):
		stand = value
		_rebuild()
@export_range(0.0, 20.0, 0.1) var light_range := 6.0:
	set(value):
		light_range = value
		_rebuild()
@export_range(0.0, 8.0, 0.1) var light_energy := 1.6:
	set(value):
		light_energy = value
		_rebuild()

const FONT := preload("res://ui/fonts/ChakraPetch-SemiBold.ttf")
const FONT_SIZE := 96
## De dia o neon fica com esta fração do brilho.
const DAY_LEVEL := 0.4

var _label: Label3D
var _light: OmniLight3D
var _level := -1.0
var _check := 0.0
var _flicker_wait := 0.0
var _flicker_left := 0.0


func _ready() -> void:
	add_to_group("neon_signs")
	_rebuild()
	_flicker_wait = randf_range(2.0, 9.0)


func _rebuild() -> void:
	# Carregando a cena, cada campo chama isto: espera o _ready montar uma vez só.
	if not is_node_ready():
		return
	for child in get_children():
		if child.has_meta("neon_part"):
			remove_child(child)
			child.queue_free()
	var pixel := letter_height / float(FONT_SIZE) * 1.35
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x * pixel

	if board:
		var plate := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(width + letter_height * 0.9, letter_height * 1.8, 0.06)
		plate.mesh = box
		var plate_material := StandardMaterial3D.new()
		plate_material.albedo_color = Color(0.05, 0.05, 0.06)
		plate_material.roughness = 0.6
		plate_material.metallic = 0.3
		plate.material_override = plate_material
		plate.position.z = -0.04
		_part(plate)
		# Moldura fina na cor do neon, bem fraquinha (tubo da borda).
		var frame_material := StandardMaterial3D.new()
		frame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		frame_material.albedo_color = Color(color, 1.0) * 1.6
		var frame_w := box.size.x
		var frame_h := box.size.y
		for side: Array in [[Vector3(0, frame_h / 2.0, 0), Vector3(frame_w, 0.025, 0.025)], [Vector3(0, -frame_h / 2.0, 0), Vector3(frame_w, 0.025, 0.025)],
				[Vector3(frame_w / 2.0, 0, 0), Vector3(0.025, frame_h, 0.025)], [Vector3(-frame_w / 2.0, 0, 0), Vector3(0.025, frame_h, 0.025)]]:
			var tube := MeshInstance3D.new()
			var tube_box := BoxMesh.new()
			tube_box.size = side[1]
			tube.mesh = tube_box
			tube.material_override = frame_material
			tube.position = side[0] + Vector3(0, 0, 0.0)
			tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_part(tube)

	if stand:
		var leg_material := StandardMaterial3D.new()
		leg_material.albedo_color = Color(0.16, 0.16, 0.17)
		leg_material.metallic = 0.6
		leg_material.roughness = 0.5
		# O pé vai do letreiro até o chão (o nó fica pendurado na altura em que foi posto).
		var height := maxf(position.y, letter_height)
		for x: float in [-1.0, 1.0]:
			var leg := MeshInstance3D.new()
			var tube := BoxMesh.new()
			tube.size = Vector3(0.07, height, 0.07)
			leg.mesh = tube
			leg.material_override = leg_material
			leg.position = Vector3(x * (width / 2.0 + letter_height * 0.25), -height / 2.0, -0.08)
			_part(leg)

	_label = Label3D.new()
	_label.text = text
	_label.font = FONT
	_label.font_size = FONT_SIZE
	_label.pixel_size = pixel
	_label.outline_size = 22
	_label.double_sided = false
	_label.shaded = false
	_label.no_depth_test = false
	_label.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_label.position.z = 0.01
	_part(_label)

	_light = OmniLight3D.new()
	_light.light_color = color
	_light.omni_range = light_range
	_light.omni_attenuation = 1.4
	_light.position = Vector3(0, -letter_height * 0.4, 0.7)
	_light.shadow_enabled = false
	_part(_light)
	_level = -1.0
	_set_level(_target_level())


func _part(node: Node3D) -> void:
	node.set_meta("neon_part", true)
	add_child(node)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _label == null:
		return
	var level := _level
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		level = _target_level()
	if flicker:
		_flicker_wait -= delta
		if _flicker_wait <= 0.0:
			_flicker_wait = randf_range(3.0, 11.0)
			_flicker_left = randf_range(0.12, 0.35)
		if _flicker_left > 0.0:
			_flicker_left -= delta
			# Engasga: apaga e volta umas vezes bem rápido.
			var on := fmod(_flicker_left, 0.08) > 0.045
			_apply(level * (1.0 if on else 0.12))
			return
	if absf(level - _level) > 0.005:
		_set_level(level)


## Brilho pela hora do mundo (de noite inteiro; de dia DAY_LEVEL). Sem relógio: noite.
func _target_level() -> float:
	if not is_inside_tree():
		return 1.0
	var clock := get_tree().get_first_node_in_group("day_night")
	if clock == null or not clock.has_method("street_lights_level"):
		return 1.0
	return lerpf(DAY_LEVEL, 1.0, clock.street_lights_level(clock.hour))


func _set_level(level: float) -> void:
	_level = level
	_apply(level)


func _apply(level: float) -> void:
	if _label == null:
		return
	# Miolo quase branco (o tubo aceso) e o halo na cor: brilhante o bastante para o glow.
	var core := color.lerp(Color.WHITE, 0.55)
	_label.modulate = Color(core.r, core.g, core.b) * lerpf(1.0, 2.6, level)
	_label.outline_modulate = Color(color.r * 1.6, color.g * 1.6, color.b * 1.6, lerpf(0.25, 0.6, level))
	_light.light_energy = light_energy * level
	_light.visible = level > 0.05
