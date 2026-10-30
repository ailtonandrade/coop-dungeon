class_name Loot
extends Node3D
## Item caído no chão, estilo MU Online: todo mundo vê, qualquer um do time pode pegar
## (quem pegar primeiro leva) e só sai do chão quando alguém pega (botão de pegar perto dele).
## O host decide a coleta: se couber na mochila, o item vai para o inventário e o loot some.

const PICKUP_RADIUS := 1.8
const LIFETIME := 180.0
## Quantos itens uma criatura pode deixar: cada chance é testada em ordem e para na primeira que falha.
const DROP_CHANCES := [0.55, 0.3, 0.12]
## Moedas: quase sempre caem, mais quanto maior o poder (perigo da região).
const GOLD_CHANCE := 0.85
const GOLD_PER_POWER := Vector2i(3, 8)

var item: Dictionary

var _life := LIFETIME
var _visual: Node3D


## Host: larga um item no chão.
static func drop(source: Node, p_item: Dictionary, pos: Vector3) -> void:
	NetReplicator.of(source).spawn("loot", {"item": p_item, "pos": pos})


## Host: o que uma criatura deixa ao morrer (zero, um ou mais itens espalhados).
## `creature` é o id dela (GameConfig.CREATURES), para as regras de loot das fichas.
static func roll_drops(source: Node3D, power: int, creature := "") -> void:
	for item in roll_items(power, creature):
		var scatter := Vector3(randf_range(-1.2, 1.2), 0.0, randf_range(-1.2, 1.2))
		drop(source, item, Combat.flat(source.global_position) + scatter)


## Sorteia o loot (sem largar no chão): moedas, o sorteio geral e as regras das fichas
## para esta criatura.
static func roll_items(power: int, creature := "") -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if randf() < GOLD_CHANCE:
		items.append(ItemDB.make_gold(maxi(1, power) * randi_range(GOLD_PER_POWER.x, GOLD_PER_POWER.y)))
	for chance: float in DROP_CHANCES:
		if randf() >= chance:
			break
		var item := ItemDB.random_drop(power)
		if not item.is_empty():
			items.append(item)
	for entry: Array in ItemDB.creature_drops(creature):
		var rule: ItemDrop = entry[1]
		if randf() * 100.0 >= rule.chance:
			continue
		for i in rule.roll_count():
			items.append(ItemDB.make(entry[0], maxi(power + rule.power_bonus, 1), rule.roll_rarity()))
	return items


## Host: o loot mais perto de `position` dentro do alcance de pegar, ou null.
static func nearest(tree: SceneTree, position: Vector3) -> Loot:
	var best: Loot = null
	var best_distance := PICKUP_RADIUS
	for loot: Loot in tree.get_nodes_in_group("loot"):
		var distance := Combat.flat(loot.global_position - position).length()
		if distance <= best_distance and not loot.is_queued_for_deletion():
			best = loot
			best_distance = distance
	return best


static func build(data: Dictionary) -> Loot:
	var loot := Loot.new()
	loot.item = data.item
	return loot


func _ready() -> void:
	add_to_group("loot")
	var color: Color = ItemDB.GOLD.color if item.get("id") == "gold" else ItemDB.rarity_color(item)
	_visual = ItemVisuals.build(item)
	_visual.scale = Vector3.ONE * 1.6 * float(ItemDB.def(item).get("ground_scale", 1.0))
	add_child(_visual)

	# Facho de luz na cor da raridade, para achar no meio da luta.
	var beam := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.1
	cylinder.bottom_radius = 0.2
	cylinder.height = 2.2
	beam.mesh = cylinder
	var beam_material := Combat.overlay_material(Color(color, 0.2))
	beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = beam_material
	beam.position.y = 1.1
	add_child(beam)

	# Nome no chão na cor da raridade (como no MU).
	var label := Label3D.new()
	label.text = ItemDB.display_name(item) if item.get("id") == "gold" \
			else "%s · poder %d" % [ItemDB.display_name(item), int(item.get("power", 1))]
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 30
	label.outline_size = 8
	label.layers = 2
	label.position.y = 1.2
	add_child(label)


func _process(delta: float) -> void:
	_visual.rotation.y += delta * 1.5
	_visual.position.y = 0.4 + sin(Time.get_ticks_msec() / 400.0) * 0.08


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_life -= delta
	if _life <= 0.0:
		queue_free()
