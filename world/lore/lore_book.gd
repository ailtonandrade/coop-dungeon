@tool
class_name LoreBook
extends Resource
## Livro da história: os documentos (diários, gravações, terminais). Edite pelo Inspector
## (world/lore/lore.tres). As conversas dos NPCs ficam em world/lore/npcs/ (NpcDialogue).
## Ver docs/LORE.md.

@export var documents: Array[LoreDocument] = []


func document(id: String) -> LoreDocument:
	for doc in documents:
		if doc and doc.id == id:
			return doc
	return null


func document_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for doc in documents:
		if doc and not doc.id.is_empty():
			ids.append(doc.id)
	return ids
