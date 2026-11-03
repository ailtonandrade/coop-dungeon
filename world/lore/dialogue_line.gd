@tool
class_name DialogueLine
extends Resource
## Uma fala do NPC que depende do que o grupo sabe: vale a de maior prioridade cujos fatos
## `requires` o grupo tem e `forbids` não tem. Usada no cumprimento e no "puxar assunto".

@export_multiline var text := ""
@export var requires: Array[String] = []
@export var forbids: Array[String] = []
## Fatos que o grupo passa a saber ouvindo esta fala.
@export var teaches: Array[String] = []
@export var priority := 0
