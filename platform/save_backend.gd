class_name SaveBackend
extends RefCounted
## Contrato de armazenamento. Implementações previstas:
## - LocalSaveBackend: arquivo em user:// (protótipo, e cache offline em todas as plataformas)
## - Xbox / Microsoft Store: XGameSave do GDK (via port W4 Games)
## - Nuvem cruzada (Steam <-> Xbox): PlayFab, chaveado pela conta Microsoft


func write(_key: String, _data: Dictionary) -> bool:
	return false


func read(_key: String) -> Dictionary:
	return {}


## Chaves salvas que começam com `prefix`.
func list(_prefix: String) -> PackedStringArray:
	return PackedStringArray()


func delete(_key: String) -> bool:
	return false
