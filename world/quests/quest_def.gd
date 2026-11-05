@tool
class_name QuestDef
extends Resource
## Missão: um arquivo por missão em world/quests/ (edite no Inspector ou, rodando pelo Godot,
## dentro do jogo com /missoes). Entra no questLog (canto da tela) e é do grupo todo.
##
## Como começa (`start`):
##  - "npc": oferecida na conversa com `giver` (Aceito / Agora não);
##  - "area": começa sozinha ao entrar na área de missão (QuestArea) de id `start_target`;
##  - "gatilho": começa ao apertar LB / F no gatilho de missão (QuestTrigger) de id `start_target`;
##  - "item": começa quando alguém do grupo tem o item de id `start_target` (pegou do chão, de
##    um Item de missão do mapa, ganhou ou já começou com ele, como o diário da mochila).
## Ao começar pode dar um item (`start_item`). Terminados os objetivos: se tem `giver` e
## `return_to_giver`, volta para entregar; senão conclui na hora (recompensa para o grupo).

@export var id := ""
@export var title := ""
@export_enum("secundaria", "principal") var category := "secundaria"
@export_enum("npc", "area", "gatilho", "item") var start := "npc"
## area/gatilho: id da área ou do gatilho que começa a missão · item: id do item.
@export var start_target := ""
## Nome do NPC que dá (start "npc") e recebe a missão.
@export var giver := ""
@export var return_to_giver := true
## Item que o grupo recebe ao começar (quem aceitou/ativou).
@export var start_item := ""
## Começa por NPC: palavras que o jogador diz ao NPC, NA ORDEM, antes de ele oferecer a missão
## (viram botões na conversa, ou se digita). Vazio = a missão aparece direto como "Trabalho".
@export var offer_keywords: PackedStringArray = []
## Resposta do NPC a cada palavra de `offer_keywords` (mesma ordem). Depois da última, ele diz a
## fala de oferecer e vêm Aceito / Agora não.
@export var offer_replies: PackedStringArray = []
## Fala ao oferecer (npc) ou aviso ao começar sozinha (area/gatilho).
@export_multiline var offer_text := ""
## Fala se o jogador voltar antes de terminar.
@export_multiline var progress_text := ""
## Fala ao entregar.
@export_multiline var done_text := ""
## Uma linha para o questLog.
@export var summary := ""
@export var objectives: Array[QuestObjective] = []
## Objetivos em ordem: cada um só aparece no questLog e só conta depois que o anterior terminou
## (a história vai se desenrolando). Desligado: todos valem ao mesmo tempo.
@export var objectives_in_order := true
## Só aparece quando o grupo sabe estes fatos.
@export var requires: Array[String] = []
## Vem depois destas missões (ids): só aparece quando todas já foram entregues. Missão
## principal que vem depois vira o "próximo passo" (rastreador, minimapa, "!" no NPC).
@export var after: Array[String] = []
## Fatos que o grupo passa a saber ao concluir.
@export var teaches: Array[String] = []

@export_group("Recompensa (para cada um do grupo)")
@export_range(0, 100000) var reward_gold := 100
@export_range(0, 100000) var reward_xp := 50
## Item (id em items/defs) que vai para quem entregou (vazio = nenhum).
@export var reward_item := ""
## Dá para pegar de novo depois de entregar.
@export var repeatable := false
## Repetível: minutos (de verdade) de espera depois de entregar até poder pegar de novo.
@export_range(0, 10080) var repeat_cooldown := 0
