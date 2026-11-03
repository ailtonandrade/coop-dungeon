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
## No chão: tamanho do item (um pouco maior que na mão, para dar de ver), queda e brilho.
const GROUND_SCALE := 1.3
const FALL_TIME := 0.45
const FALL_HEIGHT := 0.6
const GLOW_SIZE := 1.1
const _GLOW_SHADER := preload("res://items/loot_glow.gdshader")

## Generosidade do loot, escolhida pelo host (fica no save do mundo, chave "loot"):
## chance de cada item cair, moedas e chance de raridade boa.
const GENEROSITY := {
	"escasso": {"name": "Escasso", "chance": 0.6, "gold": 0.7, "rarity": 0.7},
	"normal": {"name": "Normal", "chance": 1.0, "gold": 1.0, "rarity": 1.0},
	"generoso": {"name": "Generoso", "chance": 1.5, "gold": 1.5, "rarity": 1.4},
	"farto": {"name": "Chuva de loot", "chance": 2.2, "gold": 2.2, "rarity": 2.0},
}
const GENEROSITY_ORDER := ["escasso", "normal", "generoso", "farto"]

var item: Dictionary

var _life := LIFETIME
var _visual: Node3D
var _glow: MeshInstance3D
var _rest := Transform3D.IDENTITY
var _floor := 0.0
var _fall := 0.0
var _spot := Vector3.ZERO


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
	var rules := generosity()
	if randf() < GOLD_CHANCE:
		items.append(ItemDB.make_gold(roundi(maxi(1, power) * randi_range(GOLD_PER_POWER.x, GOLD_PER_POWER.y) * rules.gold)))
	for chance: float in DROP_CHANCES:
		if randf() >= minf(chance * rules.chance, 0.95):
			break
		var item := ItemDB.random_drop(power, rules.rarity)
		if not item.is_empty():
			items.append(item)
	for entry: Array in ItemDB.creature_drops(creature):
		var rule: ItemDrop = entry[1]
		if randf() * 100.0 >= rule.chance * rules.chance:
			continue
		for i in rule.roll_count():
			items.append(ItemDB.make(entry[0], maxi(power + rule.power_bonus, 1), rule.roll_rarity()))
	return items


## Regras de generosidade do mundo aberto agora (o host decide; offline também vale).
static func generosity() -> Dictionary:
	return GENEROSITY.get(String(NetService.world.get("loot", "normal")), GENEROSITY.normal)


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
	loot._spot = data.get("pos", Vector3.ZERO)
	return loot


func _ready() -> void:
	add_to_group("loot")
	# Cai em todas as máquinas: o som diz o quanto é bom (Protótipo brilha mais alto).
	var drop_sound := "loot_drop"
	if item.get("id") != "gold":
		drop_sound = {"unique": "loot_unique", "rare": "loot_rare"}.get(item.get("rarity", "common"), "loot_drop")
	Sound.play(drop_sound, global_position)
	var color: Color = ItemDB.GOLD.color if item.get("id") == "gold" else ItemDB.rarity_color(item)
	_visual = ItemVisuals.build(item)
	_visual.scale = Vector3.ONE * GROUND_SCALE * float(ItemDB.def(item).get("ground_scale", 1.0))
	_rest = _lying_pose(_visual, _ground_yaw())
	_visual.transform = _rest
	add_child(_visual)

	# Brilho no chão na cor da raridade: discreto, só para achar no meio da luta.
	var rarity: String = item.get("rarity", "common")
	_glow = MeshInstance3D.new()
	var disc := PlaneMesh.new()
	disc.size = Vector2.ONE * GLOW_SIZE
	_glow.mesh = disc
	# Comum quase some; quanto melhor a raridade, mais o brilho aparece.
	_glow.material_override = _glow_material(Color(color, 0.45 if rarity == "common" else 1.0))
	_glow.position.y = 0.02
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)
	# Raro e Protótipo ganham um fio de luz fino e baixo (os comuns não chamam atenção).
	if item.get("id") != "gold" and rarity in ["rare", "unique"]:
		var beam := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.01
		cylinder.bottom_radius = 0.04
		cylinder.height = 0.9 if rarity == "rare" else 1.3
		cylinder.radial_segments = 8
		beam.mesh = cylinder
		var beam_material := Combat.overlay_material(Color(color, 0.18))
		beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		beam.material_override = beam_material
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.position.y = cylinder.height / 2.0
		add_child(beam)

	# Nome na cor da raridade, baixinho, logo acima do item.
	var label := WorldText.make(ItemDB.display_name(item) if item.get("id") == "gold" \
			else Txt.t("%s · poder %d") % [ItemDB.display_name(item), int(item.get("power", 1))], 12, color)
	label.position.y = 0.55
	add_child(label)
	_snap_to_floor.call_deferred()


## Giro no chão sorteado pela posição: igual em todas as máquinas, sem precisar mandar pela rede.
func _ground_yaw() -> float:
	var spot := Vector2i(roundi(_spot.x * 100.0), roundi(_spot.z * 100.0))
	return float(hash(spot) % 360) * PI / 180.0


## Deita o item no chão: a medida mais comprida fica na horizontal (espada, arco, pistola
## deitados, como em qualquer jogo) e a parte de baixo encosta no chão. Peça que já é mais
## larga que alta (capacete, bota, moeda) só pousa como está.
static func _lying_pose(visual: Node3D, yaw: float) -> Transform3D:
	var base := Transform3D(Basis.from_scale(visual.scale), Vector3.ZERO)
	var box := _bounds(visual, base)
	var tilt := Basis.IDENTITY
	if box.size.y > maxf(box.size.x, box.size.z) * 1.1:
		# Deita para o lado mais fino ficar para cima (a lâmina chapada no chão, não de quina).
		tilt = Basis(Vector3.BACK, PI / 2.0) if box.size.x <= box.size.z else Basis(Vector3.RIGHT, PI / 2.0)
	var posed := Transform3D(Basis(Vector3.UP, yaw) * tilt * base.basis, Vector3.ZERO)
	box = _bounds(visual, posed)
	posed.origin = Vector3(-box.get_center().x, -box.position.y + 0.01, -box.get_center().z)
	return posed


## Caixa das malhas do item, como se `visual` estivesse com o transform `xform`.
static func _bounds(visual: Node3D, xform: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: VisualInstance3D in visual.find_children("*", "VisualInstance3D", true, false):
		var local := Transform3D.IDENTITY
		var node: Node = mesh
		while node != visual:
			local = (node as Node3D).transform * local
			node = node.get_parent()
		var part := (xform * local) * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box if not first else AABB(Vector3(-0.2, 0, -0.2), Vector3(0.4, 0.2, 0.4))


## Acha o chão de verdade embaixo do item (calçada, escada, telhado) para não ficar enterrado
## nem boiando.
func _snap_to_floor() -> void:
	if not is_inside_tree():
		return
	var from := global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.0, GameConfig.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_floor = (hit.position as Vector3).y - global_position.y


static func _glow_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _GLOW_SHADER
	material.set_shader_parameter("tint", color)
	return material


func _process(delta: float) -> void:
	# Queda: sai um pouco do alto e quica uma vez antes de assentar.
	_fall = minf(_fall + delta / FALL_TIME, 1.0)
	var t := _fall
	var height := 0.0
	if t < 0.7:
		var k := t / 0.7
		height = FALL_HEIGHT * (1.0 - k * k)
	else:
		var k := (t - 0.7) / 0.3
		height = FALL_HEIGHT * 0.12 * sin(k * PI)
	_visual.transform = Transform3D(_rest.basis, _rest.origin + Vector3.UP * (_floor + height))
	_glow.position.y = _floor + 0.02
	var pulse := 0.75 + sin(Time.get_ticks_msec() / 500.0) * 0.25
	(_glow.material_override as ShaderMaterial).set_shader_parameter("strength", pulse)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_life -= delta
	if _life <= 0.0:
		queue_free()
