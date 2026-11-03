@tool
class_name NpcDialogue
extends Resource
## Conversa de um NPC (um arquivo por NPC em world/lore/npcs/). Ligada ao NPC do mapa pelo nome
## (`npc`, igual ao npc_name dele). Abra no Inspector, ou pelo painel "Histórias" do editor.

@export var npc := ""
## O que ele diz quando a conversa abre (a de maior prioridade que vale). Personalidade aqui.
@export var greetings: Array[DialogueLine] = []
## O que ele grita sozinho quando o grupo chega perto (balão; uma vez por sessão).
@export var approach: Array[DialogueLine] = []
@export var topics: Array[DialogueTopic] = []
## Resposta para palavra que ele não conhece.
@export_multiline var unknown := "Hm? Não entendi."
@export_multiline var farewell := "Até mais."
## Texto do botão do serviço (loja, cofre...). Vazio = nome do serviço.
@export var service_button := ""
