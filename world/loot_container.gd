@tool
class_name LootContainer
extends Node3D
## Baú, contêiner, caixote... com coisa dentro, colocado à mão no mapa (peça pronta no editor).
## O conteúdo fica no Inspector: itens fixos (com chance), parafusos e sorteios extras do loot
## da região. Perto dele, o botão de pegar (LB / F) abre: os itens saltam para o chão em volta,
## como o loot das criaturas (todo o time vê e pega).
##
## Abre uma vez por mundo (fica salvo no mundo do host) ou volta a encher depois de
## `refill_minutes`. O host decide e avisa os convidados (NetService.set_container_opened).
##
## Roda também no editor (@tool, para mostrar o modelo): por isso fala com os serviços do jogo
## e com o Loot pelo caminho, sem citar os nomes deles direto.

const LOOT_SCRIPT := "res://items/loot.gd"


## Identificador único no mapa (é o que fica salvo). O editor preenche sozinho.
@export var container_id := ""
@export var title := "Baú"
@export var model: PackedScene:
	set(value):
		model = value
		if is_inside_tree():
			_build_visual()
@export_range(0.1, 5.0, 0.01) var model_scale := 1.0
## Distância (do centro) de onde dá para abrir; contêiner grande precisa de mais.
@export_range(0.5, 8.0, 0.1, "suffix:m") var open_range := 2.2
@export var contents: Array[ContainerItem] = []
@export_range(0, 100000) var gold := 0
## Itens extras sorteados do loot geral, no poder do perigo da região.
@export_range(0, 10) var random_items := 0
## 0 = abre uma vez por mundo; senão, enche de novo depois desses minutos.
@export_range(0.0, 10080.0, 1.0, "suffix:min") var refill_minutes := 0.0
## Som ao abrir (evento do SoundBank): "chest_open" (madeira) ou "container_open" (metal).
@export var open_sound := "chest_open"

var _visual: Node3D
var _label: Label3D
var _opened := false


func _ready() -> void:
	if Engine.is_editor_hint():
		# Novo, ou copiado (Ctrl+D) de outro baú da mesma cena: ganha um id próprio.
		if container_id.is_empty() or _id_taken_in_scene():
			container_id = new_id()
		_build_visual()
		return
	add_to_group("containers")
	_build_visual()
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 26
	_label.outline_size = 8
	_label.modulate = Color(1.0, 0.85, 0.4)
	_label.layers = 2
	_label.position.y = 1.6
	add_child(_label)
	refresh()


static func new_id() -> String:
	return "%08x%04x" % [Time.get_unix_time_from_system(), randi() % 0x10000]


func _id_taken_in_scene() -> bool:
	var scene := get_tree().edited_scene_root if get_tree() else null
	if scene == null:
		return false
	for other in scene.find_children("*", "Node3D", true, false):
		if other != self and other is LootContainer and other.container_id == container_id:
			return true
	return false


## Está aberto agora (pelo estado salvo no mundo e o tempo de reabastecer)?
func is_open(now: float = Time.get_unix_time_from_system()) -> bool:
	var net := _net()
	var states: Dictionary = net.world.get("containers", {}) if net else {}
	var opened_at: float = states.get(container_id, -1.0)
	if opened_at < 0.0:
		return false
	return refill_minutes <= 0.0 or now - opened_at < refill_minutes * 60.0


## Atualiza o visual pelo estado (chamado ao nascer e quando o host avisa que abriu).
func refresh() -> void:
	_opened = is_open()
	if _visual:
		# Aberto: fica mais escuro, para o jogador saber que já foi saqueado.
		_dim(_visual, _opened)


## Acabou de ser aberto (em todas as máquinas, avisado pelo NetService).
func on_opened() -> void:
	refresh()
	var sound := get_node_or_null("/root/Sound")
	if sound:
		sound.play(open_sound, global_position + Vector3.UP * 0.5)


## Host: um jogador apertou pegar perto. Larga o conteúdo no chão e guarda que abriu.
func open_by(player: Node3D) -> bool:
	if _opened or _flat(player.global_position - global_position).length() > open_range:
		return false
	var items := roll_contents(_region_power())
	var loot: Script = load(LOOT_SCRIPT)
	for i in items.size():
		var angle := TAU * i / maxf(items.size(), 1.0) + randf_range(-0.3, 0.3)
		var spot := global_position + Vector3(cos(angle), 0.0, sin(angle)) * (open_range * 0.5 + randf_range(0.6, 1.2))
		loot.drop(self, items[i], _flat(spot))
	_net().set_container_opened(container_id)
	return true


## O que sai do baú (sem largar no chão): itens fixos que passaram na chance, parafusos e os
## sorteios extras.
func roll_contents(region_power: int) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for line: ContainerItem in contents:
		if line == null or not ItemDB.has(line.item_id) or randf() * 100.0 >= line.chance:
			continue
		var power := line.power if line.power > 0 else region_power
		for i in line.count:
			var rarity := ItemDB.random_rarity() if line.rarity == "random" else line.rarity
			items.append(ItemDB.make(line.item_id, maxi(power, 1), rarity))
	for i in random_items:
		var extra := ItemDB.random_drop(region_power)
		if not extra.is_empty():
			items.append(extra)
	if gold > 0:
		items.append(ItemDB.make_gold(gold))
	return items


## Mais perto de `position` dentro do alcance, ainda fechado, ou null.
static func nearest(tree: SceneTree, position: Vector3) -> LootContainer:
	var best: LootContainer = null
	var best_score := INF
	for container: LootContainer in tree.get_nodes_in_group("containers"):
		var distance := _flat(container.global_position - position).length()
		# Compara pela folga até o alcance de cada um (contêiner grande tem alcance maior).
		var score := distance - container.open_range
		if not container._opened and score <= 0.0 and score < best_score:
			best = container
			best_score = score
	return best


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _label == null:
		return
	if _opened and refill_minutes > 0.0 and not is_open():
		refresh()
	var near := false
	if not _opened:
		for player: Node3D in get_tree().get_nodes_in_group("players"):
			if player.is_local() and _flat(player.global_position - global_position).length() <= open_range:
				near = true
				break
	_label.text = "%s\n[LB / F] abrir" % title if near else ""


func _region_power() -> int:
	var streamer := get_tree().get_first_node_in_group("world_streamer")
	var region: Resource = streamer.region_at(global_position) if streamer else null
	return maxi(region.danger if region else 1, 1)


func _net() -> Node:
	return get_node_or_null("/root/NetService")


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _build_visual() -> void:
	if _visual:
		_visual.queue_free()
		_visual = null
	if model == null:
		return
	_visual = model.instantiate()
	_visual.scale = Vector3.ONE * model_scale
	add_child(_visual)


func _dim(root: Node, dark: bool) -> void:
	var material: StandardMaterial3D = null
	if dark:
		material = StandardMaterial3D.new()
		material.albedo_color = Color(0, 0, 0, 0.45)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = material
