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
## Nome da loja nas fichas de item ("vendido por"); vazio = usa o nome do NPC.
@export var shop_id := ""

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


func shop_key() -> String:
	return shop_id if shop_id else npc_name


## Estoque do comerciante: o que está no NPC (Inspector) mais o que as fichas de item dizem
## que esta loja vende.
func stock() -> PackedStringArray:
	var result := PackedStringArray()
	for id in shop_items:
		if ItemDB.has(id) and not result.has(id):
			result.append(id)
	if not shop_key().is_empty():
		for id in ItemDB.sold_by(shop_key()):
			if not result.has(id):
				result.append(id)
	return result


## Item `index` do estoque do comerciante (novo a cada compra).
func shop_item(index: int) -> Dictionary:
	var items := stock()
	if index < 0 or index >= items.size():
		return {}
	return ItemDB.make(items[index], shop_power)


func _ready() -> void:
	add_to_group("npcs")
	if model:
		var body := model.instantiate()
		var pivot := Node3D.new()
		pivot.rotation.y = PI  # modelos olham para +Z; a frente do jogo é -Z
		add_child(pivot)
		pivot.add_child(body)
		CharacterAnimator.new(body, AnimSets.HUMANOID).play("idle")
	_title = "%s\n%s" % [npc_name, Txt.t(SERVICE_NAMES[service])] if npc_name else Txt.t(SERVICE_NAMES[service])
	_label = WorldText.make(_title, 20, Color(0.75, 1.0, 0.75))
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
	_label.text = _title + (InputService.pickup_text(Txt.t("\n[LB / F] falar")) if near else "")
	# Puxa assunto sozinho quando o grupo chega perto depois de descobrir algo (uma vez).
	if near:
		var line: DialogueLine = Lore.approach_line(npc_name)
		if line:
			Lore.mark_said(line)
			say(line.text)


## Balão de fala acima da cabeça por uns segundos (só nesta tela).
func say(text: String) -> void:
	var bubble := WorldText.make("“%s”" % Txt.t(text), 17, Color(1.0, 0.95, 0.8), true)
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.width = 900.0
	bubble.position.y = 3.2
	add_child(bubble)
	var tween := bubble.create_tween()
	tween.tween_interval(6.0)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.8)
	tween.tween_callback(bubble.queue_free)
