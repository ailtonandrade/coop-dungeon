@tool
class_name QuestArea
extends Node3D
## Área de missão: quando alguém do grupo entra no círculo (`radius`), conta para objetivos
## "chegar" e pode começar missões (start "area") com o mesmo id. O id é `area_id` ou, vazio, o
## nome do nó (as peças do /editar têm nome "god_..."). No jogo é invisível; o círculo só
## aparece no editor do Godot e com o editor de missões ou o construtor ligados.

## Liga os marcadores das peças de missão (editor de missões e construtor).
static var show_markers := false

@export var area_id := ""
## Fatos que o grupo passa a saber ao entrar (ex.: achou_esconderijo).
@export var teaches: Array[String] = []
@export_range(0.5, 30.0, 0.1) var radius := 3.0:
	set(value):
		radius = value
		if is_inside_tree():
			_build()

var _inside := false
var _check := 0.0


func id() -> String:
	return area_id if not area_id.is_empty() else String(name)


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	add_to_group("quest_areas")
	add_to_group("quest_markers")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var marker := get_node_or_null("Marcador") as Node3D
	if marker:
		marker.visible = show_markers
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.25
	var who: Node3D = null
	for player: Node3D in get_tree().get_nodes_in_group("players"):
		if player.has_method("is_local") and player.is_local() \
				and Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length() <= radius \
				and absf(player.global_position.y - global_position.y) < 4.0:
			who = player
	if who and not _inside:
		if not teaches.is_empty():
			get_node("/root/Lore").learn(teaches, "lugar|")
		get_node("/root/Quests").reach(id(), who)
	_inside = who != null


func _build() -> void:
	for child in get_children():
		if child.has_meta("area_part"):
			child.free()
	var marker := MeshInstance3D.new()
	marker.name = "Marcador"
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.04
	disc.radial_segments = 32
	marker.mesh = disc
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.3, 0.8, 1.0, 0.22)
	marker.material_override = material
	marker.position.y = 0.03
	marker.visible = Engine.is_editor_hint() or show_markers
	marker.set_meta("area_part", true)
	add_child(marker)
