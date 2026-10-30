class_name WorldNpc
extends Node3D
## Personagem fixo do mapa que presta um serviço (comerciante, ferreiro, encantador, banco).
## Fica sempre no mesmo lugar, para o jogador aprender onde encontrar cada serviço.
## Perto dele, o botão de pegar (LB / F) abre a tela do serviço (ServicePanel). O host
## confere que o jogador está mesmo perto do NPC certo antes de comprar, refinar etc.

enum Service { MERCHANT, BLACKSMITH, ENCHANTER, BANK }

const SERVICE_NAMES := {
	Service.MERCHANT: "Sucateiro", Service.BLACKSMITH: "Mecânico (upgrade)",
	Service.ENCHANTER: "Hacker de chips (mods)", Service.BANK: "Cofre",
}

## Distância para conversar.
const TALK_RANGE := 2.6

@export var service := Service.MERCHANT
@export var npc_name := ""
@export var model: PackedScene
## Comerciante: o que ele vende (ids do ItemDB) e com que poder.
@export var shop_items := PackedStringArray([
	"sword", "axe", "bow", "longbow", "leather_hood", "iron_helmet", "leather_vest", "chainmail",
	"leather_pants", "leather_boots", "pouch", "backpack",
])
@export var shop_power := 2

var _label: Label3D
var _title := ""


## NPC mais perto de `position` dentro do alcance de conversa (de um serviço, ou qualquer um com -1).
static func nearest(tree: SceneTree, position: Vector3, wanted_service := -1, reach := TALK_RANGE) -> WorldNpc:
	var best: WorldNpc = null
	var best_distance := reach
	for npc: WorldNpc in tree.get_nodes_in_group("npcs"):
		if wanted_service != -1 and npc.service != wanted_service:
			continue
		var offset := npc.global_position - position
		var distance := Vector2(offset.x, offset.z).length()
		if distance <= best_distance:
			best = npc
			best_distance = distance
	return best


## Item `index` do estoque do comerciante (novo a cada compra).
func shop_item(index: int) -> Dictionary:
	if index < 0 or index >= shop_items.size() or not ItemDB.DEFS.has(shop_items[index]):
		return {}
	return ItemDB.make(shop_items[index], shop_power)


func _ready() -> void:
	add_to_group("npcs")
	if model:
		var body := model.instantiate()
		var pivot := Node3D.new()
		pivot.rotation.y = PI  # modelos olham para +Z; a frente do jogo é -Z
		add_child(pivot)
		pivot.add_child(body)
		CharacterAnimator.new(body, AnimSets.HUMANOID).play("idle")
	_title = "%s\n%s" % [npc_name, SERVICE_NAMES[service]] if npc_name else SERVICE_NAMES[service]
	_label = Label3D.new()
	_label.text = _title
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 30
	_label.outline_size = 8
	_label.modulate = Color(0.75, 1.0, 0.75)
	_label.layers = 2
	_label.position.y = 2.5
	add_child(_label)


## Mostra o aviso de conversa quando um jogador desta tela está perto.
func _process(_delta: float) -> void:
	var near := false
	for player: Node3D in get_tree().get_nodes_in_group("players"):
		if player.is_local():
			var offset := player.global_position - global_position
			if Vector2(offset.x, offset.z).length() <= TALK_RANGE:
				near = true
				break
	_label.text = _title + ("\n[LB / F] falar" if near else "")
