@tool
class_name Door
extends Node3D
## Porta (ou tampa de esgoto) que abre com LB / F, com animação pronta.
##
## Estilo: madeira, metal, casebre (madeira velha e torta, com remendo de lata) ou esgoto
## (tampa redonda no chão). Abertura: "dentro"/"fora" (gira na dobradiça; no esgoto, levanta) ou
## "esquerda"/"direita" (desliza).
## Tranca: "livre" (abre com LB / F), "fatos" (só abre quando o grupo sabe `requires`; antes,
## "trancada"), "codigo" (teclado: digitar `code`) ou "invasao" (minigame de senha).
## Abriu: o grupo passa a saber `unlock_fact` (vazio = "abriu_" + nome) e os fatos de `teaches`;
## a porta fica aberta para todos (online também, e no save do mundo). Abrir também conta como
## "interagir" para missões (id = `door_id` ou o nome do nó).
##
## O nó fica no chão, no meio do vão da porta (esgoto: no meio do buraco). Frente = +Z.

const RANGE := 1.9
const ANIM_TIME := 0.7

@export_enum("madeira", "metal", "casebre", "esgoto") var style := "madeira":
	set(value):
		style = value
		_rebuild()
@export_enum("dentro", "fora", "esquerda", "direita") var opening := "dentro":
	set(value):
		opening = value
		_rebuild()
@export_enum("livre", "fatos", "codigo", "invasao") var lock := "livre"
@export var requires: Array[String] = []
@export var code := ""
## Fato que o grupo passa a saber ao abrir (vazio = "abriu_" + nome do nó).
@export var unlock_fact := ""
## Fatos a mais que o grupo passa a saber ao abrir.
@export var teaches: Array[String] = []
## Id para missões ("interagir"); vazio = nome do nó.
@export var door_id := ""
@export var prompt := "Abrir"

var open := false
var _leaf: Node3D
var _collision: CollisionShape3D
var _body: StaticBody3D
var _label: Label3D
var _check := 0.0
var _closed_xform := Transform3D.IDENTITY


func id() -> String:
	return door_id if not door_id.is_empty() else String(name)


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	add_to_group("doors")
	if unlock_fact.is_empty():
		unlock_fact = "abriu_%s" % String(name).to_snake_case()
	get_node("/root/Lore").facts_changed.connect(_refresh)
	_refresh(true)


## Monta o visual (também chamado pelo fantasma do /construir, fora da árvore).
func ghost_build() -> void:
	_build()


func _rebuild() -> void:
	if not is_node_ready():
		return
	_build()


func _build() -> void:
	for child in get_children():
		if child.has_meta("door_part"):
			remove_child(child)
			child.free()
	_body = StaticBody3D.new()
	_body.set_meta("door_part", true)
	add_child(_body)
	if style == "esgoto":
		_build_manhole()
	else:
		_build_door()
	_label = Label3D.new()
	_label.set_meta("door_part", true)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.004
	_label.font_size = 40
	_label.outline_size = 10
	_label.modulate = Color(1.0, 0.85, 0.45)
	_label.position.y = 2.5 if style != "esgoto" else 1.0
	_label.visible = false
	add_child(_label)
	_closed_xform = _leaf.transform


## Porta de pé: batente (moldura) e a folha, que gira ou desliza.
func _build_door() -> void:
	var width := 1.0
	var height := 2.1
	var frame_color: Color = {"madeira": Color(0.3, 0.2, 0.12), "metal": Color(0.25, 0.26, 0.28), "casebre": Color(0.32, 0.27, 0.2)}[style]
	var frame := _material(frame_color, 0.9, 0.5 if style == "metal" else 0.0)
	for x: float in [-width / 2.0 - 0.06, width / 2.0 + 0.06]:
		_box(self, Vector3(0.12, height + 0.1, 0.22), Vector3(x, (height + 0.1) / 2.0, 0), frame, true)
	_box(self, Vector3(width + 0.24, 0.12, 0.22), Vector3(0, height + 0.06, 0), frame, true)
	# Folha: um nó na dobradiça (lado esquerdo) para girar; deslizante, no meio.
	var hinge := Node3D.new()
	hinge.set_meta("door_part", true)
	var hinge_x := -width / 2.0 if opening in ["dentro", "fora"] else 0.0
	hinge.position = Vector3(hinge_x, 0, 0)
	add_child(hinge)
	_leaf = hinge
	var offset := Vector3(width / 2.0 - (0.0 if opening in ["dentro", "fora"] else width / 2.0), 0, 0)
	var thickness := 0.06
	match style:
		"madeira":
			var wood := _material(Color(0.45, 0.3, 0.17), 0.85)
			var dark := _material(Color(0.3, 0.19, 0.1), 0.9)
			_box(hinge, Vector3(width, height, thickness), offset + Vector3(0, height / 2.0, 0), wood)
			for y: float in [0.45, 1.1, 1.75]:
				_box(hinge, Vector3(width * 0.8, 0.45, 0.02), offset + Vector3(0, y, thickness / 2.0 + 0.005), dark)
			_box(hinge, Vector3(0.06, 0.06, 0.08), offset + Vector3(width * 0.38, 1.0, 0.06), _material(Color(0.75, 0.62, 0.3), 0.3, 0.8))
		"metal":
			var steel := _material(Color(0.42, 0.44, 0.47), 0.5, 0.7)
			_box(hinge, Vector3(width, height, thickness), offset + Vector3(0, height / 2.0, 0), steel)
			for y: float in [0.3, 1.05, 1.8]:
				_box(hinge, Vector3(width * 0.96, 0.08, 0.02), offset + Vector3(0, y, thickness / 2.0 + 0.005), _material(Color(0.3, 0.31, 0.33), 0.5, 0.7))
			for x: float in [-0.42, 0.42]:
				for y: float in [0.15, 1.95]:
					_box(hinge, Vector3(0.04, 0.04, 0.02), offset + Vector3(x, y, thickness / 2.0 + 0.01), _material(Color(0.2, 0.2, 0.21), 0.5, 0.8))
			_box(hinge, Vector3(0.05, 0.35, 0.06), offset + Vector3(width * 0.36, 1.0, 0.06), _material(Color(0.15, 0.15, 0.16), 0.4, 0.8))
		"casebre":
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			var planks := 5
			for i in planks:
				var plank_w := width / planks - 0.02
				var tone := rng.randf_range(0.75, 1.1)
				var plank := _box(hinge, Vector3(plank_w, height - rng.randf_range(0.0, 0.12), thickness),
						offset + Vector3(-width / 2.0 + width / planks * (i + 0.5), height / 2.0 - 0.04, 0),
						_material(Color(0.42 * tone, 0.33 * tone, 0.23 * tone), 0.95))
				plank.rotation.z = rng.randf_range(-0.025, 0.025)
			for y: float in [0.4, 1.7]:
				var bar := _box(hinge, Vector3(width, 0.1, 0.03), offset + Vector3(0, y, thickness / 2.0 + 0.012), _material(Color(0.3, 0.24, 0.16), 0.95))
				bar.rotation.z = rng.randf_range(-0.05, 0.05)
			# Remendo de lata enferrujada.
			_box(hinge, Vector3(0.35, 0.3, 0.01), offset + Vector3(0.15, 1.15, thickness / 2.0 + 0.03), _material(Color(0.5, 0.32, 0.2), 0.7, 0.6))
	_collision = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.15)
	_collision.shape = shape
	_collision.position = Vector3(0, height / 2.0, 0)
	_body.add_child(_collision)


## Tampa de esgoto: aro no chão, buraco escuro e a tampa redonda com grade em relevo.
func _build_manhole() -> void:
	var radius := 0.45
	var iron := _material(Color(0.24, 0.24, 0.25), 0.6, 0.7)
	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = radius + 0.1
	ring_mesh.bottom_radius = radius + 0.1
	ring_mesh.height = 0.04
	ring.mesh = ring_mesh
	ring.material_override = _material(Color(0.2, 0.2, 0.2), 0.8)
	ring.position.y = 0.01
	ring.set_meta("door_part", true)
	add_child(ring)
	var hole := MeshInstance3D.new()
	var hole_mesh := CylinderMesh.new()
	hole_mesh.top_radius = radius
	hole_mesh.bottom_radius = radius
	hole_mesh.height = 0.05
	hole.mesh = hole_mesh
	hole.material_override = _material(Color(0.01, 0.01, 0.01), 1.0)
	hole.position.y = 0.012
	hole.set_meta("door_part", true)
	add_child(hole)
	# A tampa gira na borda (levanta) ou desliza de lado.
	var hinge := Node3D.new()
	hinge.set_meta("door_part", true)
	hinge.position = Vector3(0, 0, -radius) if opening in ["dentro", "fora"] else Vector3.ZERO
	add_child(hinge)
	_leaf = hinge
	var offset := Vector3(0, 0, radius) if opening in ["dentro", "fora"] else Vector3.ZERO
	var lid := MeshInstance3D.new()
	var lid_mesh := CylinderMesh.new()
	lid_mesh.top_radius = radius
	lid_mesh.bottom_radius = radius
	lid_mesh.height = 0.05
	lid_mesh.radial_segments = 24
	lid.mesh = lid_mesh
	lid.material_override = iron
	lid.position = offset + Vector3(0, 0.04, 0)
	hinge.add_child(lid)
	var relief := _material(Color(0.3, 0.3, 0.31), 0.5, 0.8)
	for i in 5:
		var z := -radius * 0.6 + i * radius * 0.3
		var length := 2.0 * sqrt(maxf(radius * radius * 0.81 - z * z, 0.01))
		_box(hinge, Vector3(length, 0.015, 0.03), offset + Vector3(0, 0.072, z), relief)
		_box(hinge, Vector3(0.03, 0.015, length), offset + Vector3(z, 0.072, 0), relief)
	_collision = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(radius * 2.0, 0.1, radius * 2.0)
	_collision.shape = shape
	_collision.position.y = 0.05
	_collision.disabled = true
	_body.add_child(_collision)


static func _material(color: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = rough
	material.metallic = metal
	return material


func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material, solid := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	if parent == self:
		mesh.set_meta("door_part", true)
	parent.add_child(mesh)
	if solid and _body:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		shape.position = at
		_body.add_child(shape)
	return mesh


## Abrir

## Precisa de teclado/invasão (LockPanel) para abrir.
func needs_terminal() -> bool:
	return not open and lock in ["codigo", "invasao"]


func is_locked() -> bool:
	return lock == "fatos" and not get_node("/root/Lore").knows_all(requires)


static func nearest(tree: SceneTree, position: Vector3) -> Door:
	var best: Door = null
	var best_distance := RANGE
	for door: Door in tree.get_nodes_in_group("doors"):
		if door.open or not door.is_visible_in_tree():
			continue
		var distance := Vector2(door.global_position.x - position.x, door.global_position.z - position.z).length()
		if distance < best_distance:
			best = door
			best_distance = distance
	return best


## LB / F perto: livre abre; trancada por fatos avisa; código/invasão o HUD abre o terminal.
func use(_player: Node) -> void:
	if open:
		return
	if is_locked():
		get_node("/root/Sound").play("ui_error", global_position)
		get_node("/root/Chat").local_note(Txt.t("Trancada."))
		return
	get_node("/root/Lore").learn([unlock_fact])


## Abre de vez (reação de missão "abrir").
func force_open() -> void:
	lock = "livre"
	requires = []
	get_node("/root/Lore").learn([unlock_fact])


func _refresh(instant := false) -> void:
	var now: bool = get_node("/root/Lore").knows(unlock_fact)
	if now == open:
		return
	open = now
	_label.visible = false
	if _collision:
		_collision.set_deferred("disabled", open if style != "esgoto" else true)
	var target := _open_xform() if open else _closed_xform
	if instant:
		_leaf.transform = target
	else:
		get_node("/root/Sound").play("container_open" if style != "metal" else "chest_open", global_position)
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(_leaf, "transform", target, ANIM_TIME)
	if open and not instant:
		# Abriu agora: fatos a mais (também quando abriu pelo teclado) e conta para missões.
		get_node("/root/Lore").learn(teaches)
		get_node("/root/Quests").interact(id(), null)
	var streamer := get_tree().get_first_node_in_group("world_streamer")
	var chunk := _chunk()
	if streamer and chunk:
		streamer.bake_navigation.call_deferred(chunk, true)


## Onde a folha (ou a tampa) fica aberta.
func _open_xform() -> Transform3D:
	var t := _closed_xform
	if style == "esgoto":
		match opening:
			"dentro", "fora":
				return Transform3D(Basis(Vector3.RIGHT, -1.9), t.origin)
			"esquerda":
				return Transform3D(t.basis, t.origin + Vector3(-0.95, 0.02, 0))
			_:
				return Transform3D(t.basis, t.origin + Vector3(0.95, 0.02, 0))
	match opening:
		"dentro":
			return Transform3D(Basis(Vector3.UP, PI / 2.0), t.origin)
		"fora":
			return Transform3D(Basis(Vector3.UP, -PI / 2.0), t.origin)
		"esquerda":
			return Transform3D(t.basis, t.origin + Vector3(-1.0, 0, -0.08))
	return Transform3D(t.basis, t.origin + Vector3(1.0, 0, -0.08))


func _chunk() -> Node:
	var node: Node = self
	while node and not node.has_node("Navigation"):
		node = node.get_parent()
	return node


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _label == null or open:
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.25
	var near := false
	for player: Node3D in get_tree().get_nodes_in_group("players"):
		if player.has_method("is_local") and player.is_local() \
				and Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length() < RANGE + 0.5:
			near = true
	_label.visible = near
	if near:
		var key: String = get_node("/root/InputService").hint(get_node("/root/InputService").Action.PICKUP)
		var verb := Txt.t("Trancada") if is_locked() else (Txt.t("Teclado") if lock == "codigo" else (Txt.t("Terminal") if lock == "invasao" else Txt.t(prompt)))
		_label.text = "%s · %s" % [verb, key]
