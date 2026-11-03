extends Node
## Missões (questLog): fichas em world/quests/*.tres (QuestDef). O progresso é do grupo e fica
## no save do mundo (NetService.world["quests"]): {id: {"state": "ativa"|"pronta"|"entregue",
## "count": [n, ...]}}. Quem manda é o host: conta as criaturas derrotadas, aceita e entrega;
## os convidados pedem por RPC e recebem o estado novo a cada mudança.

signal quests_changed
## Uma missão mudou de estado ("ativa", "pronta", "entregue"): para a tela dar destaque.
signal quest_event(quest_id: String, state: String)

const DIR := "res://world/quests"

var _defs := {}  # id -> QuestDef


func defs() -> Dictionary:
	if _defs.is_empty():
		for file in DirAccess.get_files_at(DIR) if DirAccess.dir_exists_absolute(DIR) else PackedStringArray():
			var path := DIR.path_join(file.trim_suffix(".remap"))
			if not path.ends_with(".tres"):
				continue
			var def := load(path) as QuestDef
			if def and not def.id.is_empty():
				_defs[def.id] = def
	return _defs


func def(id: String) -> QuestDef:
	return defs().get(id)


func states() -> Dictionary:
	return NetService.world.get("quests", {})


func state_of(id: String) -> String:
	return String(states().get(id, {}).get("state", ""))


func count_of(id: String, objective: int) -> int:
	var counts: Array = states().get(id, {}).get("count", [])
	return int(counts[objective]) if objective < counts.size() else 0


## Missões em andamento ou prontas para entregar (para o questLog), na ordem em que foram pegas.
func tracked() -> Array[QuestDef]:
	var result: Array[QuestDef] = []
	for id: String in states():
		var quest := def(id)
		if quest and state_of(id) in ["ativa", "pronta"]:
			result.append(quest)
	return result


## Missões deste NPC que dá para pegar agora.
func offers(npc_name: String) -> Array[QuestDef]:
	var result: Array[QuestDef] = []
	for quest: QuestDef in defs().values():
		if quest.giver != npc_name or not Lore.knows_all(quest.requires):
			continue
		var state := state_of(quest.id)
		if state.is_empty() or (state == "entregue" and quest.repeatable):
			result.append(quest)
	return result


## Missões deste NPC já pegas (andamento ou para entregar).
func taken(npc_name: String) -> Array[QuestDef]:
	var result: Array[QuestDef] = []
	for quest: QuestDef in defs().values():
		if quest.giver == npc_name and state_of(quest.id) in ["ativa", "pronta"]:
			result.append(quest)
	return result


## Pega a missão (qualquer máquina pede; o host grava).
func accept(id: String) -> void:
	if multiplayer.is_server():
		_accept(id)
	else:
		_rpc_accept.rpc_id(1, id)


## Entrega a missão pronta: recompensa para o grupo todo.
func turn_in(id: String, player: Node) -> void:
	if multiplayer.is_server():
		_turn_in(id, player)
	else:
		_rpc_turn_in.rpc_id(1, id, int(player.get_meta("net_id", -1)))


## Host: uma criatura foi derrotada (Enemy._on_died).
func on_kill(creature_id: String) -> void:
	if not multiplayer.is_server():
		return
	var changed := false
	var all := states()
	for id: String in all:
		var entry: Dictionary = all[id]
		var quest := def(id)
		if quest == null or entry.get("state") != "ativa":
			continue
		var counts: Array = entry.get("count", [])
		for i in quest.objectives.size():
			var objective := quest.objectives[i]
			if objective.kind == "matar" and objective.target == creature_id and int(counts[i]) < objective.amount:
				counts[i] = int(counts[i]) + 1
				changed = true
		entry["count"] = counts
		if _finished(quest, counts):
			entry["state"] = "pronta"
			Chat.system(Txt.t("Missão pronta: %s · volte para %s") % [Txt.t(quest.title), quest.giver])
			_event(id, "pronta")
	if changed:
		_store(all)


func _finished(quest: QuestDef, counts: Array) -> bool:
	for i in quest.objectives.size():
		if i >= counts.size() or int(counts[i]) < quest.objectives[i].amount:
			return false
	return true


func _accept(id: String) -> void:
	var quest := def(id)
	if quest == null or not offers(quest.giver).has(quest):
		return
	var all := states()
	var counts := []
	counts.resize(quest.objectives.size())
	counts.fill(0)
	all[id] = {"state": "ativa", "count": counts}
	_store(all)
	_event(id, "ativa")


func _turn_in(id: String, player: Node) -> void:
	var quest := def(id)
	if quest == null or state_of(id) != "pronta":
		return
	var all := states()
	all[id]["state"] = "entregue"
	_store(all)
	for member: Node in get_tree().get_nodes_in_group("players"):
		if quest.reward_gold > 0 and member.has_method("give_item"):
			member.give_item(ItemDB.make_gold(quest.reward_gold))
		if quest.reward_xp > 0 and member.has_method("add_xp"):
			member.add_xp(quest.reward_xp)
	if not quest.reward_item.is_empty() and ItemDB.has(quest.reward_item) and player and player.has_method("give_item"):
		if not player.give_item(ItemDB.make(quest.reward_item, 2, "rare")):
			Loot.drop(player, ItemDB.make(quest.reward_item, 2, "rare"), Combat.flat(player.global_position) + Vector3(0.6, 0, 0))
	Lore.learn(quest.teaches)
	Chat.system(Txt.t("Missão concluída: %s") % Txt.t(quest.title))
	_event(id, "entregue")


func _store(all: Dictionary) -> void:
	NetService.world["quests"] = all
	if NetService.world.has("id"):
		SaveService.save_world(NetService.world)
	quests_changed.emit()
	if NetService.is_online():
		_rpc_state.rpc(all)


func _event(id: String, state: String) -> void:
	quest_event.emit(id, state)
	if NetService.is_online():
		_rpc_event.rpc(id, state)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_accept(id: String) -> void:
	if multiplayer.is_server():
		_accept(id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_turn_in(id: String, net_id: int) -> void:
	if not multiplayer.is_server():
		return
	var scene := get_tree().current_scene
	var replicator := NetReplicator.of(scene) if scene else null
	var player: Node = replicator.get_entity(net_id) if replicator else null
	if player and player.get("owner_peer") == multiplayer.get_remote_sender_id():
		_turn_in(id, player)


@rpc("authority", "call_remote", "reliable")
func _rpc_state(all: Dictionary) -> void:
	NetService.world["quests"] = all
	quests_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_event(id: String, state: String) -> void:
	quest_event.emit(id, state)
