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
## Ao cumprir: pode dar um item (`gives_item`), ensinar um fato (`teaches`) e fazer uma reação
## num objeto do mapa (`reaction` em `reaction_target`, pelo nome do nó).

const KINDS := ["matar", "falar", "interagir", "chegar"]
const REACTIONS := ["nenhuma", "sumir", "aparecer", "abrir"]
const CREATURE_NAMES := {"punk": "Bandidos de cano", "atirador": "Atiradores de pregos",
	"corrompido": "Corrompidos", "androide": "Androides de segurança"}

@export_enum("matar", "falar", "interagir", "chegar") var kind := "matar"
## matar: classe da criatura · interagir: id do gatilho · chegar: id da área.
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
	return target
