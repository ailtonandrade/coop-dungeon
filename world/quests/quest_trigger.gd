@tool
class_name QuestTrigger
extends Node3D
## Gatilho de missão: perto dele, LB / F "usa". Conta para objetivos "interagir" e pode começar
## missões (start "gatilho") com o mesmo id. O id é `trigger_id` ou, vazio, o nome do nó (as peças
## do /editar têm nome "god_..."). Visual: invisível (só o aviso aparece de perto), alavanca,
## terminal, caixa ou placa. `single_use`: depois de usado, não aparece mais (o grupo todo).

const RANGE := 1.9

@export var trigger_id := ""
@export_enum("invisivel", "alavanca", "terminal", "caixa", "placa") var look := "alavanca":
	set(value):
		look = value
		if is_inside_tree():
			_build()
## Aviso de perto ("Examinar", "Puxar alavanca"...).
@export var prompt := "Examinar"
## Mensagem ao usar (só para quem usou; vazio = nenhuma).
@export_multiline var message := ""
@export var single_use := true
## Fatos que o grupo passa a saber ao usar.
@export var teaches: Array[String] = []

var _label: Label3D
var _check := 0.0


func id() -> String:
	return trigger_id if not trigger_id.is_empty() else String(name)


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	add_to_group("quest_triggers")
	add_to_group("quest_markers")


func used() -> bool:
	return single_use and get_node("/root/Lore").knows("gatilho_" + id())


static func nearest(tree: SceneTree, position: Vector3) -> QuestTrigger:
	var best: QuestTrigger = null
	var best_distance := RANGE
	for trigger: QuestTrigger in tree.get_nodes_in_group("quest_triggers"):
		if not trigger.is_visible_in_tree() and trigger.look != "invisivel":
			continue
		if trigger.used():
			continue
		var distance := Vector2(trigger.global_position.x - position.x, trigger.global_position.z - position.z).length()
		if distance < best_distance:
			best = trigger
			best_distance = distance
	return best


## Usar (LB / F perto).
func use(player: Node) -> void:
	if used():
		return
	get_node("/root/Sound").play("container_open" if look in ["caixa", "alavanca"] else "ui_confirm", global_position)
	if not message.is_empty():
		get_node("/root/Chat").local_note(Txt.t(message))
	if single_use:
		get_node("/root/Lore").learn(["gatilho_" + id()])
	if not teaches.is_empty():
		get_node("/root/Lore").learn(teaches)
	get_node("/root/Quests").interact(id(), player)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _label == null:
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.25
	var near := false
	if not used():
		for player: Node3D in get_tree().get_nodes_in_group("players"):
			if player.has_method("is_local") and player.is_local() and player.global_position.distance_to(global_position) < RANGE + 0.6:
				near = true
	_label.visible = near
	if near:
		_label.text = Txt.t(prompt) + "  ·  " + get_node("/root/InputService").hint(get_node("/root/InputService").Action.PICKUP)
	var marker := get_node_or_null("Marcador") as Node3D
	if marker:
		marker.visible = look != "invisivel" or QuestArea.show_markers


func _build() -> void:
	for child in get_children():
		if child.has_meta("trigger_part"):
			child.free()
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.3, 0.31, 0.33)
	metal.metallic = 0.6
	match look:
		"alavanca":
			_box(Vector3(0.3, 0.5, 0.15), Vector3(0, 0.95, 0), metal)
			var lever := _box(Vector3(0.05, 0.4, 0.05), Vector3(0, 1.2, 0.1), _glow(Color(1.0, 0.75, 0.2)))
			lever.rotation.x = -0.6
		"terminal":
			_box(Vector3(0.5, 1.0, 0.35), Vector3(0, 0.5, 0), metal)
			_box(Vector3(0.38, 0.26, 0.02), Vector3(0, 0.82, 0.18), _glow(Color(0.35, 1.0, 0.55)))
		"caixa":
			var wood := StandardMaterial3D.new()
			wood.albedo_color = Color(0.36, 0.27, 0.18)
			_box(Vector3(0.6, 0.4, 0.4), Vector3(0, 0.2, 0), wood)
		"placa":
			_box(Vector3(0.06, 1.2, 0.06), Vector3(0, 0.6, 0), metal)
			var sign := StandardMaterial3D.new()
			sign.albedo_color = Color(0.75, 0.7, 0.55)
			_box(Vector3(0.7, 0.45, 0.04), Vector3(0, 1.25, 0), sign)
	# Marcador (sempre na cena, para o fantasma do /editar; no jogo só aparece se não for
	# invisível ou com o editor de missões/construtor ligado).
	var marker := MeshInstance3D.new()
	marker.name = "Marcador"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.5
	marker.mesh = ring
	marker.material_override = _glow(Color(1.0, 0.8, 0.25, 0.8))
	marker.position.y = 0.03
	marker.set_meta("trigger_part", true)
	add_child(marker)
	if owner:
		marker.owner = null
	_label = Label3D.new()
	_label.text = Txt.t(prompt) + "  ·  LB / F" if not Engine.is_editor_hint() else prompt
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.004
	_label.font_size = 40
	_label.outline_size = 10
	_label.modulate = Color(1.0, 0.85, 0.4)
	_label.position.y = 1.7
	_label.visible = Engine.is_editor_hint()
	_label.set_meta("trigger_part", true)
	add_child(_label)


func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	mesh.set_meta("trigger_part", true)
	add_child(mesh)
	return mesh


static func _glow(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
