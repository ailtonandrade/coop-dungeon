@tool
class_name LoreBook
extends Resource
## Livro da história: todos os documentos e falas condicionadas dos NPCs. Edite pelo Inspector
## (world/lore/lore.tres). Ver docs/LORE.md.

@export var documents: Array[LoreDocument] = []
@export var lines: Array[NpcLine] = []


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
