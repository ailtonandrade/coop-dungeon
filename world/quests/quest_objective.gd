@tool
class_name QuestObjective
extends Resource
## Um objetivo de missão. Tipos:
##  - "matar": derrotar `amount` criaturas da classe `target` (punk, atirador, corrompido, androide).
##  - "falar": dizer na conversa com o NPC `npc` as palavras de `keywords`, NA ORDEM (cada uma só
##    vale depois da anterior: ele vai revelando). `replies` é o que ele responde a cada uma.
##    `show_buttons` mostra a próxima palavra como botão (para quem joga no controle).
##  - "interagir": apertar LB / F no gatilho de missão (QuestTrigger) de id `target`.
##  - "chegar": entrar na área de missão (QuestArea) de id `target`.
##  - "ler": ler pelo inventário o item de id `target` (diário, carta) ou o documento de id
##    `target` (também o do mapa, LoreNote). Sem ponto no mapa.
##  - "usar": usar pelo inventário o item de id `target` (Y / E). Sem ponto no mapa.
##  - "pegar": ter o item de id `target` (pegar do chão, ganhar, comprar ou já ter).
## Ao cumprir: pode dar um item (`gives_item`), ensinar um fato (`teaches`) e fazer uma reação
## num objeto do mapa (`reaction` em `reaction_target`, pelo nome do nó).

const KINDS := ["matar", "falar", "interagir", "chegar", "ler", "usar", "pegar"]
## Tipos que acontecem no inventário (sem ponto no mapa).
const INVENTORY_KINDS := ["ler", "usar", "pegar"]
const REACTIONS := ["nenhuma", "sumir", "aparecer", "abrir"]
const CREATURE_NAMES := {"punk": "Bandidos de cano", "atirador": "Atiradores de pregos",
	"corrompido": "Corrompidos", "androide": "Androides de segurança"}

@export_enum("matar", "falar", "interagir", "chegar", "ler", "usar", "pegar") var kind := "matar"
## matar: classe da criatura · interagir: id do gatilho · chegar: id da área ·
## ler: id do item ou do documento · usar/pegar: id do item.
@export var target := "punk"
@export_range(1, 999) var amount := 5
## falar: com quem (nome do NPC no mapa).
@export var npc := ""
## falar: palavras, em ordem.
@export var keywords: PackedStringArray = []
## falar: resposta do NPC a cada palavra (mesma ordem).
@export var replies: PackedStringArray = []
@export var show_buttons := true
## Como aparece no questLog (vazio = automático).
@export var label := ""

@export_group("Ao cumprir")
@export var gives_item := ""
@export var teaches: Array[String] = []
@export_enum("nenhuma", "sumir", "aparecer", "abrir") var reaction := "nenhuma"
## Nome do nó no mapa que reage (porta, contêiner, parede, gatilho, peça do construtor "god_...").
@export var reaction_target := ""


## Quanto precisa para cumprir (matar: quantidade; falar: número de palavras; o resto: 1).
func goal() -> int:
	match kind:
		"matar":
			return amount
		"falar":
			return maxi(keywords.size(), 1)
	return 1


func text() -> String:
	if not label.is_empty():
		return label
	match kind:
		"matar":
			return String(CREATURE_NAMES.get(target, target))
		"falar":
			return "Falar com %s" % npc
		"interagir":
			return "Investigar"
		"chegar":
			return "Ir até o local"
		"ler":
			return "Ler %s" % _thing_name()
		"usar":
			return "Usar %s" % _thing_name()
		"pegar":
			return "Pegar %s" % _thing_name()
	return target


## Nome do item (ou título do documento) do alvo, para o questLog.
func _thing_name() -> String:
	if ItemDB.has(target):
		return ItemDB.display_name({"id": target})
	var tree := Engine.get_main_loop() as SceneTree
	var lore: Node = tree.root.get_node_or_null("Lore") if tree else null
	var doc: Resource = lore.document(target) if lore else null
	return String(doc.title) if doc else target
