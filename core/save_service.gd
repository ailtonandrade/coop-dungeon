extends Node
## Fachada de save. O jogo só fala com esta classe; o backend muda por plataforma.
## - world: progresso da campanha, pertence ao host (jogador 1).
## - player: personagem (equipamento, nível), pertence à conta de cada jogador.

const SAVE_VERSION := 1

var _backend: SaveBackend = LocalSaveBackend.new()


func save_world(data: Dictionary) -> bool:
	return _write("world_" + PlatformService.get_host_profile_id(), data)


func load_world() -> Dictionary:
	return _read("world_" + PlatformService.get_host_profile_id())


func save_player(slot: int, data: Dictionary) -> bool:
	return _write("player_" + PlatformService.get_profile_id(slot), data)


func load_player(slot: int) -> Dictionary:
	return _read("player_" + PlatformService.get_profile_id(slot))


## O envelope guarda versão (para migrar saves antigos) e horário (para resolver
## conflito quando o save local e o da nuvem divergem no cross save).
func _write(key: String, data: Dictionary) -> bool:
	var envelope := {
		"version": SAVE_VERSION,
		"updated_at": Time.get_unix_time_from_system(),
		"data": data,
	}
	return _backend.write(key, envelope)


func _read(key: String) -> Dictionary:
	return _backend.read(key).get("data", {})
