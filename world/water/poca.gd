extends Node3D
## Poça d'água: espelha o letreiro de neon mais perto (a cor dele brilha na água, mais forte de
## noite). O reflexo de verdade vem do reflexo de tela nas qualidades média e alta.

const REACH := 9.0
const STRENGTH := 0.9

var _water: GeometryInstance3D
var _check := 0.0


func _ready() -> void:
	add_to_group("puddles")
	_water = get_node_or_null("Agua") as GeometryInstance3D
	_check = randf() * 0.5


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or _water == null:
		return
	_check = 1.0
	var best: Node3D = null
	var best_distance := REACH
	for sign: Node in get_tree().get_nodes_in_group("neon_signs"):
		var distance := (sign as Node3D).global_position.distance_to(global_position)
		if distance < best_distance:
			best = sign
			best_distance = distance
	var glow := Color(0, 0, 0, 0)
	if best:
		var level: float = best.get("_level") if best.get("_level") != null and float(best.get("_level")) >= 0.0 else 1.0
		var falloff := 1.0 - best_distance / REACH
		var color: Color = best.get("color")
		glow = Color(color.r, color.g, color.b, STRENGTH * falloff * falloff * level)
	_water.set_instance_shader_parameter("glow", glow)
