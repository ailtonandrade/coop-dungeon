@tool
class_name LoreGate
extends StaticBody3D
## Portão (grade com cadeado eletrônico) que só abre para quem já sabe os fatos de `requires`.
## Com `lock` "codigo" ou "invasao", o painel do lado vira um terminal: LB / F perto dele abre a
## tranca (LockPanel): digitar a chave (`code`) ou invadir pelo minigame de senha. Destravou, o
## grupo passa a saber `unlock_fact` e o portão abre para todo mundo.
## Fechado: sólido, luz vermelha. Aberto: a grade some, a luz do painel (na parede, ao lado do
## vão) fica verde, e as criaturas passam a achar caminho por ali. Roda no editor (@tool) só para mostrar o visual.

@export var requires: Array[String] = []
## Como destrava: "fatos" (só pelos fatos de requires), "codigo" (digitar `code` no terminal) ou
## "invasao" (minigame de senha no terminal).
@export_enum("fatos", "codigo", "invasao") var lock := "fatos"
## Chave de "codigo" (sem diferença de maiúscula, espaço ou tracinho).
@export var code := ""
## Fato que o grupo passa a saber ao destravar pelo terminal (vazio = "destravou_" + nome).
@export var unlock_fact := ""

const TERMINAL_RANGE := 2.6
@export var size := Vector2(2.0, 2.4):
	set(value):
		size = value
		if is_inside_tree():
			_build()

var open := false
var _bars: Node3D
var _light: MeshInstance3D
var _collision: CollisionShape3D
var _prompt: Label3D
var _prompt_check := 0.0


func _ready() -> void:
	collision_layer = GameConfig.LAYER_WORLD
	_build()
	if Engine.is_editor_hint():
		return
	add_to_group("lore_gates")
	if lock != "fatos" and unlock_fact.is_empty():
		unlock_fact = "destravou_%s" % String(name).to_snake_case()
	get_node("/root/Lore").facts_changed.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	if _prompt == null or Engine.is_editor_hint():
		return
	_prompt_check -= delta
	if _prompt_check > 0.0:
		return
	_prompt_check = 0.25
	var near := false
	if not open:
		for player: Node3D in get_tree().get_nodes_in_group("players"):
			if player.has_method("is_local") and player.is_local() \
					and Vector2(player.global_position.x - terminal_position().x, player.global_position.z - terminal_position().z).length() < TERMINAL_RANGE:
				near = true
	_prompt.visible = near


func _refresh() -> void:
	var now: bool = get_node("/root/Lore").knows_all(needs())
	if now == open:
		return
	open = now
	_bars.visible = not open
	_collision.set_deferred("disabled", open)
	(_light.material_override as StandardMaterial3D).albedo_color = Color(0.2, 1.0, 0.4) if open else Color(1.0, 0.15, 0.1)
	(_light.material_override as StandardMaterial3D).emission = (_light.material_override as StandardMaterial3D).albedo_color
	# Pelo nó (e não pelo nome WorldStreamer): esta classe roda também no editor.
	var chunk := _chunk()
	var streamer := get_tree().get_first_node_in_group("world_streamer")
	if chunk and streamer:
		streamer.bake_navigation.call_deferred(chunk, true)


## Fatos para abrir: os de requires e, com terminal, o de destravar.
func needs() -> Array:
	var all: Array = requires.duplicate()
	if lock != "fatos" and not unlock_fact.is_empty():
		all.append(unlock_fact)
	return all


## Terminal trancado mais perto de `position` (ao alcance do LB / F), ou null.
static func nearest_terminal(tree: SceneTree, position: Vector3) -> LoreGate:
	var best: LoreGate = null
	var best_distance := TERMINAL_RANGE
	for gate: LoreGate in tree.get_nodes_in_group("lore_gates"):
		if gate.open or gate.lock == "fatos":
			continue
		var distance := Vector2(gate.terminal_position().x - position.x, gate.terminal_position().z - position.z).length()
		if distance < best_distance:
			best = gate
			best_distance = distance
	return best


## Onde fica o painel (terminal) do portão, no mundo.
func terminal_position() -> Vector3:
	return global_transform * Vector3(-size.x / 2.0 - 0.3, 0.0, 0.6)


func _chunk() -> Node:
	var node: Node = self
	while node and not node.has_node("Navigation"):
		node = node.get_parent()
	return node


func _build() -> void:
	for child in get_children():
		if child.has_meta("gate_part"):
			child.free()
	_collision = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, size.y, 0.2)
	_collision.shape = shape
	_collision.position.y = size.y / 2.0
	_part(_collision)
	_bars = Node3D.new()
	_part(_bars)
	var metal := Color(0.32, 0.33, 0.35)
	var count := maxi(int(size.x / 0.25), 2)
	for i in count + 1:
		_bar(Vector3(0.05, size.y, 0.05), Vector3(-size.x / 2.0 + size.x * i / count, size.y / 2.0, 0), metal)
	_bar(Vector3(size.x, 0.08, 0.08), Vector3(0, size.y * 0.85, 0), metal)
	_bar(Vector3(size.x, 0.08, 0.08), Vector3(0, size.y * 0.15, 0), metal)
	# Painel do cadeado eletrônico na parede, ao lado do vão (fica lá aberto ou fechado).
	var panel := MeshInstance3D.new()
	var panel_box := BoxMesh.new()
	panel_box.size = Vector3(0.22, 0.32, 0.06)
	panel.mesh = panel_box
	var panel_material := StandardMaterial3D.new()
	panel_material.albedo_color = Color(0.15, 0.15, 0.16)
	panel.material_override = panel_material
	panel.position = Vector3(-size.x / 2.0 - 0.3, size.y * 0.5, 0.18)
	_part(panel)
	_light = MeshInstance3D.new()
	var dot := BoxMesh.new()
	dot.size = Vector3(0.08, 0.08, 0.04)
	_light.mesh = dot
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.15, 0.1)
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 3.0
	_light.material_override = material
	_light.position = Vector3(-size.x / 2.0 - 0.3, size.y * 0.55, 0.22)
	_part(_light)
	_prompt = null
	if lock != "fatos":
		# Telinha verde do terminal no painel e o aviso quando alguém chega perto.
		var screen := MeshInstance3D.new()
		var screen_box := BoxMesh.new()
		screen_box.size = Vector3(0.16, 0.1, 0.02)
		screen.mesh = screen_box
		var screen_material := StandardMaterial3D.new()
		screen_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		screen_material.albedo_color = Color(0.35, 1.0, 0.55) * 1.4
		screen.material_override = screen_material
		screen.position = Vector3(-size.x / 2.0 - 0.3, size.y * 0.45, 0.22)
		_part(screen)
		_prompt = Label3D.new()
		_prompt.text = "TECLADO · LB / F" if lock == "codigo" else "TERMINAL · LB / F"
		_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_prompt.pixel_size = 0.004
		_prompt.font_size = 40
		_prompt.outline_size = 10
		_prompt.modulate = Color(0.5, 1.0, 0.65)
		_prompt.position = Vector3(-size.x / 2.0 - 0.3, size.y * 0.5 + 0.45, 0.3)
		_prompt.visible = false
		_part(_prompt)


func _bar(bar_size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = bar_size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.6
	mesh.material_override = material
	mesh.position = pos
	_bars.add_child(mesh)


func _part(node: Node) -> void:
	node.set_meta("gate_part", true)
	add_child(node)
