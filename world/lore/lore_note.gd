@tool
class_name LoreNote
extends Node3D
## Documento da história no mapa (caderno, terminal, foto, troféu): perto dele, LB / F lê. Ler
## abre o texto (LoreReader) e o grupo passa a saber os fatos do documento. Sem aviso nenhum.
## Roda também no editor (@tool, para mostrar o visual): por isso fala com o serviço Lore
## pelo caminho, não pelo nome.

const READ_RANGE := 1.9

## Id do documento no livro da história (world/lore/lore.tres).
@export var document_id := "":
	set(value):
		document_id = value
		notify_property_list_changed()
@export_enum("caderno", "terminal", "foto", "trofeu") var look := "caderno":
	set(value):
		look = value
		if is_inside_tree():
			_build_visual()
## Só aparece para quem já sabe estes fatos (vazio = sempre).
@export var requires: Array[String] = []

var _visual: Node3D
var _label: Label3D


func _validate_property(property: Dictionary) -> void:
	if property.name == "document_id" and ResourceLoader.exists("res://world/lore/lore.tres"):
		var book := load("res://world/lore/lore.tres") as LoreBook
		if book:
			property.hint = PROPERTY_HINT_ENUM_SUGGESTION
			property.hint_string = ",".join(book.document_ids())


func _ready() -> void:
	_build_visual()
	if Engine.is_editor_hint():
		return
	add_to_group("lore_notes")
	_label = WorldText.make("", 18, Color(0.85, 0.95, 1.0))
	_label.position.y = 1.5
	add_child(_label)
	_lore().facts_changed.connect(_refresh)
	_refresh()


func _lore() -> Node:
	return get_node("/root/Lore")


func is_available() -> bool:
	return Engine.is_editor_hint() or _lore().knows_all(requires)


func document() -> LoreDocument:
	return _lore().document(document_id)


func _refresh() -> void:
	visible = is_available()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not visible:
		return
	var near := false
	for player: Node3D in get_tree().get_nodes_in_group("players"):
		if player.is_local() and Combat.flat(player.global_position - global_position).length() <= READ_RANGE:
			near = true
			break
	_label.text = ("[LB / F] ler" if look != "terminal" else "[LB / F] acessar") if near else ""


## Documento mais perto do ponto que dá para ler, ou null.
static func nearest(tree: SceneTree, position: Vector3) -> LoreNote:
	var best: LoreNote = null
	var best_distance := READ_RANGE
	for note: LoreNote in tree.get_nodes_in_group("lore_notes"):
		var distance := Combat.flat(note.global_position - position).length()
		if note.visible and distance <= best_distance:
			best = note
			best_distance = distance
	return best


func _build_visual() -> void:
	if _visual:
		_visual.queue_free()
	_visual = Node3D.new()
	add_child(_visual)
	match look:
		"terminal":
			_box(Vector3(0.7, 0.9, 0.5), Vector3(0, 0.45, 0), Color(0.18, 0.19, 0.21))
			_box(Vector3(0.62, 0.42, 0.06), Vector3(0, 1.1, 0.1), Color(0.12, 0.13, 0.15))
			_box(Vector3(0.54, 0.34, 0.02), Vector3(0, 1.1, 0.135), Color(0.2, 0.9, 0.55), true)
		"foto":
			_box(Vector3(0.5, 0.5, 0.5), Vector3(0, 0.25, 0), Color(0.42, 0.3, 0.2))
			_box(Vector3(0.22, 0.02, 0.17), Vector3(0, 0.51, 0), Color(0.85, 0.82, 0.72))
		"trofeu":
			_box(Vector3(0.5, 0.5, 0.5), Vector3(0, 0.25, 0), Color(0.42, 0.3, 0.2))
			_box(Vector3(0.14, 0.28, 0.14), Vector3(0, 0.64, 0), Color(0.9, 0.72, 0.25), true)
		_:
			_box(Vector3(0.55, 0.5, 0.45), Vector3(0, 0.25, 0), Color(0.42, 0.3, 0.2))
			_box(Vector3(0.26, 0.05, 0.34), Vector3(0, 0.525, 0), Color(0.55, 0.12, 0.1))
			_box(Vector3(0.24, 0.04, 0.32), Vector3(0.005, 0.53, 0), Color(0.9, 0.86, 0.75))


func _box(size: Vector3, pos: Vector3, color: Color, glow := false) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.5
	mesh.material_override = material
	mesh.position = pos
	_visual.add_child(mesh)
