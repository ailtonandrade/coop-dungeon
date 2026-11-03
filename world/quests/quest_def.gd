@tool
class_name QuestDef
extends Resource
## Missão (sidequest) dada por um NPC: aparece na conversa com ele, entra no questLog (canto da
## tela) e é do grupo todo (online também). Um arquivo por missão em world/quests/.
##
## A história principal não usa isto (ela fica nas entrelinhas, pelo sistema de Conhecimento);
## missões podem exigir fatos (`requires`) e ensinar fatos ao entregar (`teaches`).

@export var id := ""
@export var title := ""
## Nome do NPC que dá e recebe a missão (como está no mapa).
@export var giver := ""
## Fala ao oferecer (quando o jogador escolhe a missão na conversa).
@export_multiline var offer_text := ""
## Fala se o jogador voltar antes de terminar.
@export_multiline var progress_text := ""
## Fala ao entregar.
@export_multiline var done_text := ""
## Uma linha para o questLog ("Brando quer o pátio limpo").
@export var summary := ""
@export var objectives: Array[QuestObjective] = []
## Só aparece quando o grupo sabe estes fatos.
@export var requires: Array[String] = []
## Fatos que o grupo passa a saber ao entregar.
@export var teaches: Array[String] = []

@export_group("Recompensa (para cada um do grupo)")
@export_range(0, 100000) var reward_gold := 100
@export_range(0, 100000) var reward_xp := 50
## Item (id em items/defs) que vai para quem entregou (vazio = nenhum).
@export var reward_item := ""
## Dá para pegar de novo depois de entregar.
@export var repeatable := false
