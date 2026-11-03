@tool
class_name NeonSign
extends Node3D
## Letreiro de neon: o texto aceso (miolo quase branco e o halo na cor do neon), uma placa
## escura atrás e uma luz colorida que pinta a parede e o chão em volta. De noite brilha forte;
## de dia fica mais fraco (o neon continua ligado, mas some na claridade). Pode piscar de vez
## em quando, como neon velho de ferro-velho.
##
## Mexa no Inspector: texto, cor, ícone, altura das letras, se tem placa atrás, se pisca e se fica
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
## Desenho em tubo de neon à esquerda do texto.
@export_enum("nenhum", "chave", "carrinho", "copo", "cofre", "chip", "lanche", "cruz", "caveira") var icon := "nenhum":
	set(value):
		icon = value
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

## Desenhos dos ícones: linhas (listas de pontos, num quadrado de -0.5 a 0.5, y para cima).
## "o" no começo da lista = círculo [centro x, centro y, raio].
const ICONS := {
	"chave": [[Vector2(-0.38, -0.38), Vector2(0.12, 0.12)], [Vector2(-0.46, -0.3), Vector2(-0.3, -0.46)],
		["o", 0.22, 0.22, 0.17, 40.0, 320.0]],
	"carrinho": [[Vector2(-0.48, 0.32), Vector2(-0.32, 0.32), Vector2(-0.18, -0.12), Vector2(0.36, -0.12), Vector2(0.46, 0.2), Vector2(-0.26, 0.2)],
		["o", -0.1, -0.3, 0.07, 0.0, 360.0], ["o", 0.28, -0.3, 0.07, 0.0, 360.0]],
	"copo": [[Vector2(-0.36, 0.38), Vector2(0.36, 0.38), Vector2(0.0, -0.02), Vector2(-0.36, 0.38)],
		[Vector2(0.0, -0.02), Vector2(0.0, -0.36)], [Vector2(-0.2, -0.38), Vector2(0.2, -0.38)], ["o", 0.1, 0.24, 0.05, 0.0, 360.0]],
	"cofre": [[Vector2(-0.42, -0.4), Vector2(-0.42, 0.4), Vector2(0.42, 0.4), Vector2(0.42, -0.4), Vector2(-0.42, -0.4)],
		["o", 0.0, 0.0, 0.2, 0.0, 360.0], [Vector2(0.0, 0.2), Vector2(0.0, 0.3)], [Vector2(0.2, 0.0), Vector2(0.3, 0.0)]],
	"chip": [[Vector2(-0.26, -0.26), Vector2(-0.26, 0.26), Vector2(0.26, 0.26), Vector2(0.26, -0.26), Vector2(-0.26, -0.26)],
		[Vector2(-0.12, -0.26), Vector2(-0.12, -0.44)], [Vector2(0.12, -0.26), Vector2(0.12, -0.44)], [Vector2(-0.12, 0.26), Vector2(-0.12, 0.44)],
		[Vector2(0.12, 0.26), Vector2(0.12, 0.44)], [Vector2(-0.26, 0.12), Vector2(-0.44, 0.12)], [Vector2(-0.26, -0.12), Vector2(-0.44, -0.12)],
		[Vector2(0.26, 0.12), Vector2(0.44, 0.12)], [Vector2(0.26, -0.12), Vector2(0.44, -0.12)]],
	"lanche": [["o", 0.0, 0.02, 0.4, 0.0, 180.0], [Vector2(-0.44, -0.1), Vector2(0.44, -0.1)],
		[Vector2(-0.4, -0.26), Vector2(-0.3, -0.34), Vector2(0.3, -0.34), Vector2(0.4, -0.26)]],
	"cruz": [[Vector2(-0.12, -0.42), Vector2(-0.12, -0.12), Vector2(-0.42, -0.12), Vector2(-0.42, 0.12), Vector2(-0.12, 0.12),
		Vector2(-0.12, 0.42), Vector2(0.12, 0.42), Vector2(0.12, 0.12), Vector2(0.42, 0.12), Vector2(0.42, -0.12), Vector2(0.12, -0.12),
		Vector2(0.12, -0.42), Vector2(-0.12, -0.42)]],
	"caveira": [["o", 0.0, 0.08, 0.34, -30.0, 210.0], [Vector2(-0.29, -0.09), Vector2(-0.2, -0.3), Vector2(0.2, -0.3), Vector2(0.29, -0.09)],
		["o", -0.13, 0.08, 0.08, 0.0, 360.0], ["o", 0.13, 0.08, 0.08, 0.0, 360.0], [Vector2(-0.08, -0.3), Vector2(-0.08, -0.42), Vector2(0.08, -0.42), Vector2(0.08, -0.3)]],
}

const FONT := preload("res://ui/fonts/ChakraPetch-SemiBold.ttf")
const FONT_SIZE := 96
## De dia o neon fica com esta fração do brilho.
const DAY_LEVEL := 0.4

var _label: Label3D
var _icon_material: StandardMaterial3D
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
	var text_width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x * pixel
	# Ícone à esquerda: o conjunto (ícone + texto) fica centrado no nó.
	var icon_size := letter_height * 1.5 if ICONS.has(icon) else 0.0
	var gap := letter_height * 0.35 if icon_size > 0.0 else 0.0
	if text.is_empty() and icon_size > 0.0:
		icon_size = letter_height * 2.0
	var width := text_width + gap + icon_size
	var text_x := (icon_size + gap) / 2.0
	var icon_x := -width / 2.0 + icon_size / 2.0

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
	_label.position = Vector3(text_x, 0, 0.01)
	_part(_label)
	if icon_size > 0.0:
		_icon_material = StandardMaterial3D.new()
		_icon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_build_icon(ICONS[icon], icon_size, Vector3(icon_x, 0, 0.01))
	else:
		_icon_material = null

	_light = OmniLight3D.new()
	_light.light_color = color
	_light.omni_range = light_range
	_light.omni_attenuation = 1.4
	_light.position = Vector3(0, -letter_height * 0.4, 0.7)
	_light.shadow_enabled = false
	_part(_light)
	_level = -1.0
	_set_level(_target_level())


## Tubos do ícone: cada trecho de linha é uma barrinha acesa.
func _build_icon(strokes: Array, size: float, at: Vector3) -> void:
	var thickness := maxf(size * 0.055, 0.018)
	for stroke: Array in strokes:
		var points: Array[Vector2] = []
		if stroke.size() > 0 and stroke[0] is String:
			# Círculo (ou arco): centro, raio, ângulo de início e fim, em graus.
			var steps := 14
			for i in steps + 1:
				var angle := deg_to_rad(lerpf(stroke[4], stroke[5], float(i) / steps))
				points.append(Vector2(stroke[1], stroke[2]) + Vector2(cos(angle), sin(angle)) * float(stroke[3]))
		else:
			for point: Vector2 in stroke:
				points.append(point)
		for i in points.size() - 1:
			var a := points[i] * size
			var b := points[i + 1] * size
			var tube := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(a.distance_to(b) + thickness, thickness, thickness)
			tube.mesh = box
			tube.material_override = _icon_material
			tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var middle := (a + b) / 2.0
			tube.position = at + Vector3(middle.x, middle.y, 0)
			tube.rotation.z = (b - a).angle()
			_part(tube)


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
	if _icon_material:
		_icon_material.albedo_color = Color(core.r, core.g, core.b) * lerpf(1.0, 2.4, level)
	_label.outline_modulate = Color(color.r * 1.6, color.g * 1.6, color.b * 1.6, lerpf(0.25, 0.6, level))
	_light.light_energy = light_energy * level
	_light.visible = level > 0.05
