@tool
class_name NpcLine
extends Resource
## Fala de um NPC que depende do que o grupo sabe. Vale a de maior prioridade cujos fatos
## `requires` o grupo tem e `forbids` não tem.
## `approach`: o NPC puxa o assunto sozinho quando o grupo chega perto (balão), uma vez.

## Nome do NPC (o npc_name dele no mapa, ex.: "Dona Alda").
@export var npc := ""
@export var requires: Array[String] = []
@export var forbids: Array[String] = []
@export_multiline var text := ""
## Fatos que o grupo passa a saber ouvindo esta fala.
@export var teaches: Array[String] = []
@export var approach := false
@export var priority := 0


func key() -> String:
	return "%s|%s|%s" % [npc, ",".join(requires), text.left(24)]
