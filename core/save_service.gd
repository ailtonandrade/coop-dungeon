extends Node
## Fachada de save. O jogo só fala com esta classe; o backend muda por plataforma.
## - world: cada mundo criado (nome, semente, progresso), pertence ao host (jogador 1).
##   No online, o mundo é sempre o do host.
## - player: personagem (equipamento, nível), pertence à conta de cada jogador.
##   No online, cada convidado leva e salva o próprio.

const SAVE_VERSION := 1

var _backend: SaveBackend = LocalSaveBackend.new()


## Testes automáticos salvam numa pasta separada (e limpa), sem tocar nos saves de verdade.
func use_test_storage(folder: String) -> void:
	var local := LocalSaveBackend.new()
	local.dir = "user://" + folder
	if DirAccess.dir_exists_absolute(local.dir):
		for file in DirAccess.get_files_at(local.dir):
			DirAccess.remove_absolute(local.dir.path_join(file))
	_backend = local


## Cria a ficha de um mundo novo (ainda não salva).
func new_world(world_name: String, world_seed: int, visibility: String) -> Dictionary:
	return {
		"id": "%d%04d" % [Time.get_unix_time_from_system(), randi() % 10000],
		"name": world_name,
		"seed": world_seed,
		"visibility": visibility,
		"owner": PlatformService.get_host_profile_id(),
		"created_at": Time.get_unix_time_from_system(),
		"best_wave": 0,
	}


func save_world(world: Dictionary) -> bool:
	if not world.has("id"):
		return false
	return _write(_world_prefix() + str(world.id), world)


func delete_world(world_id: String) -> bool:
	return _backend.delete(_world_prefix() + world_id)


## Mundos deste perfil, do jogado por último para o mais antigo.
func list_worlds() -> Array[Dictionary]:
	var worlds: Array[Dictionary] = []
	for key in _backend.list(_world_prefix()):
		var envelope := _backend.read(key)
		if envelope.has("data"):
			var world: Dictionary = envelope.data
			world["updated_at"] = envelope.get("updated_at", 0.0)
			worlds.append(world)
	worlds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.updated_at > b.updated_at)
	return worlds


func _world_prefix() -> String:
	return "world_%s_" % PlatformService.get_host_profile_id()


## Personagens desta máquina (até Characters.MAX), mais antigos primeiro.
func list_characters() -> Array[Dictionary]:
	_migrate_old_players()
	var result: Array[Dictionary] = []
	for key in _backend.list(_character_prefix()):
		var data := _read(key)
		if not data.is_empty():
			result.append(Characters.sanitize(data))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.get("created_at", 0) < b.get("created_at", 0))
	return result


func load_character(character_id: String) -> Dictionary:
	if character_id.is_empty():
		return {}
	var data := _read(_character_prefix() + character_id)
	return Characters.sanitize(data) if not data.is_empty() else {}


## Salva a ficha inteira (nome, visual, inventário, progressão). Recusa passar do limite.
func save_character(data: Dictionary) -> bool:
	var clean := Characters.sanitize(data)
	var key: String = _character_prefix() + str(clean.id)
	if _backend.read(key).is_empty() and list_characters().size() >= Characters.MAX:
		return false
	return _write(key, clean)


## Só o que muda jogando (inventário e progressão), mantendo nome e visual.
func save_character_progress(character_id: String, inventory: Dictionary, progress: Dictionary) -> bool:
	var data := load_character(character_id)
	if data.is_empty():
		return false
	data["inventory"] = inventory
	if not progress.is_empty():
		data["progress"] = progress
	return _write(_character_prefix() + character_id, data)


func delete_character(character_id: String) -> bool:
	return _backend.delete(_character_prefix() + character_id)


func _character_prefix() -> String:
	return "char_%s_" % PlatformService.get_host_profile_id()


## Saves de antes dos personagens (um por vaga do sofá) viram personagens, uma vez só.
func _migrate_old_players() -> void:
	var old_models := ["Adventurer", "Swat", "Farmer", "Worker"]
	for slot in 4:
		var key := "player_" + PlatformService.get_profile_id(slot)
		var old := _read(key)
		if old.is_empty():
			continue
		var character := Characters.create("Herói %d" % (slot + 1), old_models[slot], slot)
		character["inventory"] = old.get("inventory", {})
		character["progress"] = old.get("progress", {})
		_write(_character_prefix() + str(character.id), character)
		_backend.delete(key)


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
