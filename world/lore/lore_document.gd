@tool
class_name LoreDocument
extends Resource
## Documento da história (diário, gravação, tela de terminal, foto, troféu). Ler grava os
## fatos de `teaches` no mundo (Lore). Fica no livro da história (world/lore/lore.tres).

@export var id := ""
@export var title := ""
@export var author := ""
@export_multiline var text := ""
## Fatos que o grupo passa a saber ao ler. Vazio = o próprio id.
@export var teaches: Array[String] = []


func facts() -> Array[String]:
	if teaches.is_empty():
		return [id] as Array[String]
	return teaches
