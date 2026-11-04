extends Node
## Missões (questLog): fichas em world/quests/*.tres (QuestDef). O progresso é do grupo e fica
## no save do mundo (NetService.world["quests"]): {id: {"state": "ativa"|"pronta"|"entregue",
## "count": [n, ...]}}. Reações já feitas nos objetos do mapa ficam em world["quest_reactions"]
## ({nome do nó: "sumir"|"aparecer"|"abrir"}).
##
## Quem manda é o host: recebe os acontecimentos (criatura derrotada, palavra dita a um NPC,
## gatilho apertado, área alcançada), conta os objetivos, começa missões de área/gatilho, entrega
## recompensas e faz as reações. Os convidados mandam os acontecimentos por RPC e recebem o
## estado novo a cada mudança.

signal quests_changed
## Uma missão mudou de estado ("ativa", "pronta", "entregue"): para a tela dar destaque.
signal quest_event(quest_id: String, state: String)

const DIR := "res://world/quests"

var _defs := {}  # id -> QuestDef
var _streamer: Node


## Recarrega as fichas (o editor de missões salvou uma nova).
func reload() -> void:
	_defs.clear()
	_places.clear()
	defs()
	_apply_all_reactions()
	quests_changed.emit()


func defs() -> Dictionary:
	if _defs.is_empty():
		for file in DirAccess.get_files_at(DIR) if DirAccess.dir_exists_absolute(DIR) else PackedStringArray():
			var path := DIR.path_join(file.trim_suffix(".remap"))
			if not path.ends_with(".tres"):
				continue
			var def := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as QuestDef
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


func objective_done(quest: QuestDef, index: int) -> bool:
	return count_of(quest.id, index) >= quest.objectives[index].goal()


## Missões em andamento ou prontas para entregar (para o questLog): principais primeiro.
func tracked() -> Array[QuestDef]:
	var result: Array[QuestDef] = []
	for id: String in states():
		var quest := def(id)
		if quest and state_of(id) in ["ativa", "pronta"]:
			result.append(quest)
	result.sort_custom(func(a: QuestDef, b: QuestDef) -> bool: return a.category == "principal" and b.category != "principal")
	return result


func available(quest: QuestDef) -> bool:
	if not Lore.knows_all(quest.requires):
		return false
	var state := state_of(quest.id)
	return state.is_empty() or (state == "entregue" and quest.repeatable and cooldown_left(quest) <= 0)


## Repetível já entregue: segundos que faltam para poder pegar de novo (0 = já pode).
func cooldown_left(quest: QuestDef) -> int:
	if not quest.repeatable or state_of(quest.id) != "entregue" or quest.repeat_cooldown <= 0:
		return 0
	var done_at := int(states().get(quest.id, {}).get("done_at", 0))
	return maxi(done_at + quest.repeat_cooldown * 60 - int(Time.get_unix_time_from_system()), 0)


## Repetíveis deste NPC esperando a vez (para ele dizer "volta mais tarde").
func waiting(npc_name: String) -> Array[QuestDef]:
	var result: Array[QuestDef] = []
	for quest: QuestDef in defs().values():
		if quest.start == "npc" and quest.giver == npc_name and Lore.knows_all(quest.requires) and cooldown_left(quest) > 0:
			result.append(quest)
	return result


## Missões deste NPC que dá para pegar na conversa.
func offers(npc_name: String) -> Array[QuestDef]:
	var result: Array[QuestDef] = []
	for quest: QuestDef in defs().values():
		if quest.start == "npc" and quest.giver == npc_name and available(quest):
			result.append(quest)
	return result


## Missões deste NPC já pegas (andamento ou para entregar).
func taken(npc_name: String) -> Array[QuestDef]:
	var result: Array[QuestDef] = []
	for quest: QuestDef in defs().values():
		if quest.giver == npc_name and quest.return_to_giver and state_of(quest.id) in ["ativa", "pronta"]:
			result.append(quest)
	return result


## Pega a missão (qualquer máquina pede; o host grava).
func accept(id: String, player: Node = null) -> void:
	if multiplayer.is_server():
		_accept(id, player)
	else:
		_rpc_accept.rpc_id(1, id, _net_id(player))


## Entrega a missão pronta: recompensa para o grupo todo.
func turn_in(id: String, player: Node) -> void:
	if multiplayer.is_server():
		_turn_in(id, player)
	else:
		_rpc_turn_in.rpc_id(1, id, _net_id(player))


## Acontecimentos

## Host: uma criatura foi derrotada (Enemy._on_died).
func on_kill(creature_id: String) -> void:
	if multiplayer.is_server():
		_event("matar", creature_id, "", null)


## Jogador apertou LB / F num gatilho de missão (QuestTrigger).
func interact(trigger_id: String, player: Node = null) -> void:
	if multiplayer.is_server():
		_event("interagir", trigger_id, "", player)
	else:
		_rpc_event.rpc_id(1, "interagir", trigger_id, "", _net_id(player))


## Jogador entrou numa área de missão (QuestArea).
func reach(area_id: String, player: Node = null) -> void:
	if multiplayer.is_server():
		_event("chegar", area_id, "", player)
	else:
		_rpc_event.rpc_id(1, "chegar", area_id, "", _net_id(player))


## Palavra dita a um NPC na conversa: se é a próxima de um objetivo "falar", devolve a resposta
## dele (e avisa o host); senão "".
func talk(npc_name: String, said: String, player: Node = null) -> String:
	var clean := Lore.normalize(said)
	for quest in tracked():
		if state_of(quest.id) != "ativa":
			continue
		for i in quest.objectives.size():
			var objective := quest.objectives[i]
			if objective.kind != "falar" or objective.npc != npc_name or objective_done(quest, i):
				continue
			var step := count_of(quest.id, i)
			var word := Lore.normalize(objective.keywords[step]) if step < objective.keywords.size() else ""
			if word.is_empty() or not (" %s " % clean).contains(" %s " % word):
				continue
			if multiplayer.is_server():
				_event("falar", npc_name, word, player)
			else:
				_rpc_event.rpc_id(1, "falar", npc_name, word, _net_id(player))
			return objective.replies[step] if step < objective.replies.size() else "..."
	return ""


## Próximas palavras de objetivos "falar" com este NPC (botões na conversa).
func next_words(npc_name: String) -> PackedStringArray:
	var words := PackedStringArray()
	for quest in tracked():
		if state_of(quest.id) != "ativa":
			continue
		for i in quest.objectives.size():
			var objective := quest.objectives[i]
			if objective.kind == "falar" and objective.npc == npc_name and objective.show_buttons and not objective_done(quest, i):
				var step := count_of(quest.id, i)
				if step < objective.keywords.size():
					words.append(objective.keywords[step])
	return words


## Host: conta o acontecimento nas missões ativas e começa as de área/gatilho.
func _event(kind: String, a: String, b: String, player: Node) -> void:
	# Começar missão pela área ou pelo gatilho.
	var start_kind: String = {"chegar": "area", "interagir": "gatilho"}.get(kind, "")
	if not start_kind.is_empty():
		for quest: QuestDef in defs().values():
			if quest.start == start_kind and quest.start_target == a and available(quest):
				_accept(quest.id, player)
	var all := states()
	var changed := false
	for id: String in all.keys():
		var entry: Dictionary = all[id]
		var quest := def(id)
		if quest == null or entry.get("state") != "ativa":
			continue
		var counts: Array = entry.get("count", [])
		while counts.size() < quest.objectives.size():
			counts.append(0)
		for i in quest.objectives.size():
			var objective := quest.objectives[i]
			if objective.kind != kind or int(counts[i]) >= objective.goal():
				continue
			var hit := false
			match kind:
				"matar", "interagir", "chegar":
					hit = objective.target == a
				"falar":
					var step := int(counts[i])
					hit = objective.npc == a and step < objective.keywords.size() and Lore.normalize(objective.keywords[step]) == b
			if not hit:
				continue
			counts[i] = int(counts[i]) + 1
			changed = true
			if int(counts[i]) >= objective.goal():
				_objective_done(objective, player)
		entry["count"] = counts
		all[id] = entry
		if _finished(quest, counts):
			changed = true
			if not quest.giver.is_empty() and quest.return_to_giver:
				entry["state"] = "pronta"
				Chat.system(Txt.t("Missão pronta: %s · volte para %s") % [Txt.t(quest.title), quest.giver])
				_announce(id, "pronta")
			else:
				_store(all)
				_complete(quest, player)
				all = states()
	if changed:
		_store(all)


func _finished(quest: QuestDef, counts: Array) -> bool:
	for i in quest.objectives.size():
		if i >= counts.size() or int(counts[i]) < quest.objectives[i].goal():
			return false
	return true


func _objective_done(objective: QuestObjective, player: Node) -> void:
	Lore.learn(objective.teaches)
	if not objective.gives_item.is_empty():
		_give_item(objective.gives_item, player)
	if objective.reaction != "nenhuma" and not objective.reaction_target.is_empty():
		react(objective.reaction_target, objective.reaction)


func _accept(id: String, player: Node = null) -> void:
	var quest := def(id)
	if quest == null or not available(quest):
		return
	var all := states()
	var counts := []
	counts.resize(quest.objectives.size())
	counts.fill(0)
	all[id] = {"state": "ativa", "count": counts}
	_store(all)
	if quest.start != "npc":
		Chat.system(Txt.t("Nova missão: %s") % Txt.t(quest.title))
		if not quest.offer_text.is_empty():
			Chat.system(Txt.t(quest.offer_text))
	if not quest.start_item.is_empty():
		_give_item(quest.start_item, player)
	_announce(id, "ativa")
	# Missão sem objetivos (só "vá falar com fulano"): já fica pronta.
	if quest.objectives.is_empty():
		_event("", "", "", player)


func _turn_in(id: String, player: Node) -> void:
	var quest := def(id)
	if quest == null or state_of(id) != "pronta":
		return
	_complete(quest, player)


func _complete(quest: QuestDef, player: Node) -> void:
	var all := states()
	if not all.has(quest.id):
		return
	all[quest.id]["state"] = "entregue"
	all[quest.id]["done_at"] = int(Time.get_unix_time_from_system())
	_store(all)
	for member: Node in get_tree().get_nodes_in_group("players"):
		if quest.reward_gold > 0 and member.has_method("give_item"):
			member.give_item(ItemDB.make_gold(quest.reward_gold))
		if quest.reward_xp > 0 and member.has_method("add_xp"):
			member.add_xp(quest.reward_xp)
	if not quest.reward_item.is_empty():
		_give_item(quest.reward_item, player, "rare")
	Lore.learn(quest.teaches)
	Chat.system(Txt.t("Missão concluída: %s") % Txt.t(quest.title))
	_announce(quest.id, "entregue")


func _give_item(item_id: String, player: Node, rarity := "common") -> void:
	if not ItemDB.has(item_id):
		return
	if player == null or not is_instance_valid(player):
		var players := get_tree().get_nodes_in_group("players")
		player = players[0] if not players.is_empty() else null
	if player == null:
		return
	var item := ItemDB.make(item_id, 2, rarity)
	if not player.give_item(item):
		Loot.drop(player, item, Combat.flat(player.global_position) + Vector3(0.6, 0, 0))


## Para onde ir (marcador no minimapa e distância no questLog)

## Pontos do mapa inteiro, lidos dos arquivos dos blocos (sem carregar o bloco):
## {"spawners": [[pos, kinds]], "npcs": {nome: pos}, "named": {nome do nó: pos}}.
var _places := {}


## Onde fica o próximo passo da missão, perto de `from` (null se não dá para saber).
## Pronta: o NPC que recebe. Matar: o acampamento mais perto da classe. Falar: o NPC.
## Interagir/chegar: o gatilho/a área.
func target_of(quest: QuestDef, from: Vector3) -> Variant:
	if state_of(quest.id) == "pronta":
		return _places_map().npcs.get(quest.giver)
	for i in quest.objectives.size():
		if objective_done(quest, i):
			continue
		var objective := quest.objectives[i]
		match objective.kind:
			"matar":
				var kind := _creature_kind(objective.target)
				var best: Variant = null
				var best_distance := INF
				for spawner: Array in _places_map().spawners:
					if (spawner[1] as PackedInt32Array).has(kind) and (spawner[0] as Vector3).distance_to(from) < best_distance:
						best = spawner[0]
						best_distance = (spawner[0] as Vector3).distance_to(from)
				return best
			"falar":
				return _places_map().npcs.get(objective.npc)
			"interagir", "chegar":
				return _places_map().named.get(objective.target)
	return null


static func _creature_kind(creature_id: String) -> int:
	for kind: int in Enemy.STATS:
		if Enemy.STATS[kind].id == creature_id:
			return kind
	return -1


func _places_map() -> Dictionary:
	if not _places.is_empty() or not is_instance_valid(_streamer) or _streamer.get("world_map") == null:
		return _places if not _places.is_empty() else {"spawners": [], "npcs": {}, "named": {}}
	_places = {"spawners": [], "npcs": {}, "named": {}, "links": {}}
	var map: WorldMap = _streamer.world_map
	for coords: Vector2i in map.chunks:
		_read_scene(String(map.chunks[coords]), map.chunk_origin(coords))
	for id: String in map.interiors:
		_read_scene(String(map.interiors[id].get("path", "")), map.interiors[id].get("origin", Vector3.ZERO))
	return _places


## Lê a cena do bloco pelo "estado" (nós e propriedades), sem montar nada.
func _read_scene(path: String, origin: Vector3) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var state := (load(path) as PackedScene).get_state()
	var xforms := {".": Transform3D(Basis.IDENTITY, origin)}
	for i in state.get_node_count():
		var node_path := String(state.get_node_path(i))
		var parent_path := String(state.get_node_path(i, true))
		var local := Transform3D.IDENTITY
		var props := {}
		for j in state.get_node_property_count(i):
			props[state.get_node_property_name(i, j)] = state.get_node_property_value(i, j)
		if props.get("transform") is Transform3D:
			local = props.transform
		elif props.get("position") is Vector3:
			local.origin = props.position
		var parent: Transform3D = xforms.get(parent_path, xforms["."]) if i > 0 else Transform3D.IDENTITY
		var global: Transform3D = (parent * local) if i > 0 else xforms["."]
		xforms[node_path] = global
		var name := String(state.get_node_name(i))
		var script: Variant = props.get("script")
		var script_path: String = (script as Script).resource_path if script is Script else ""
		if script_path.ends_with("creature_spawner.gd") and props.get("kinds") is PackedInt32Array:
			_places.spawners.append([global.origin, props.kinds])
		if props.has("npc_name"):
			_places.npcs[String(props.npc_name)] = global.origin
		var instance := state.get_node_instance(i)
		var is_quest_piece := script_path.ends_with("quest_trigger.gd") or script_path.ends_with("quest_area.gd") \
				or (instance != null and (instance.resource_path.ends_with("gatilho_de_missao.tscn") or instance.resource_path.ends_with("area_de_missao.tscn")))
		_places.named[name] = global.origin
		# Passagens (alçapão/esgoto/escada) ligadas pelo link_id: as duas pontas.
		var door_script := script_path.ends_with("world/door.gd") or (instance != null and instance.resource_path.begins_with("res://world/prefabs/portas/"))
		if door_script and String(props.get("link_id", "")) != "":
			var style := String(props.get("style", ""))
			if style.is_empty() and instance != null:
				var inner := instance.get_state()
				for k in inner.get_node_property_count(0):
					if inner.get_node_property_name(0, k) == "style":
						style = String(inner.get_node_property_value(0, k))
			var links: Dictionary = _places.get("links", {})
			var list: Array = links.get(String(props.link_id), [])
			list.append([global.origin, style, -global.basis.z])
			links[String(props.link_id)] = list
			_places["links"] = links
		if is_quest_piece:
			for key in ["trigger_id", "area_id"]:
				if String(props.get(key, "")) != "":
					_places.named[String(props[key])] = global.origin


## Reações nos objetos do mapa

## Faz (e guarda) uma reação: "sumir", "aparecer" ou "abrir" no nó de nome `target`.
func react(target: String, action: String) -> void:
	var reactions: Dictionary = NetService.world.get("quest_reactions", {})
	reactions[target] = action
	NetService.world["quest_reactions"] = reactions
	if multiplayer.is_server() and NetService.world.has("id"):
		SaveService.save_world(NetService.world)
	if multiplayer.is_server() and NetService.is_online():
		_rpc_react.rpc(target, action)
	_apply_reaction(target, action)


## O mundo ligou o carregador de blocos: reações valem também nos blocos que chegarem depois.
func attach(streamer: Node) -> void:
	_streamer = streamer
	_places.clear()
	if not streamer.chunk_loaded.is_connected(_on_chunk_loaded):
		streamer.chunk_loaded.connect(_on_chunk_loaded)
	_apply_all_reactions()


func _on_chunk_loaded(_key: String) -> void:
	_apply_all_reactions.call_deferred()


func _apply_all_reactions() -> void:
	var reactions: Dictionary = NetService.world.get("quest_reactions", {})
	# O que só aparece com uma reação começa escondido.
	for quest: QuestDef in defs().values():
		for objective in quest.objectives:
			if objective.reaction == "aparecer" and not reactions.has(objective.reaction_target):
				_apply_reaction(objective.reaction_target, "esconder")
	for target: String in reactions:
		_apply_reaction(target, reactions[target])


func _apply_reaction(target: String, action: String) -> void:
	if target.is_empty() or not is_instance_valid(_streamer):
		return
	for chunk in _streamer.get_children():
		var node := chunk.find_child(target, true, false)
		if node == null:
			continue
		match action:
			"sumir", "esconder":
				_set_present(node, false)
			"aparecer":
				_set_present(node, true)
			"abrir":
				if node.has_method("force_open"):
					node.force_open()
				elif node.get("requires") is Array:
					node.set("requires", [] as Array[String])
				else:
					_set_present(node, false)


## Some ou volta: visível e com colisão (guarda as camadas para voltar igual).
static func _set_present(node: Node, present: bool) -> void:
	if node is Node3D:
		(node as Node3D).visible = present
	var bodies: Array = node.find_children("*", "CollisionObject3D", true, false)
	if node is CollisionObject3D:
		bodies.append(node)
	for body: CollisionObject3D in bodies:
		if not body.has_meta("quest_layer"):
			body.set_meta("quest_layer", body.collision_layer)
		body.set_deferred("collision_layer", int(body.get_meta("quest_layer")) if present else 0)


## Rede

func _net_id(player: Node) -> int:
	return int(player.get_meta("net_id", -1)) if player else -1


func _player_from(net_id: int) -> Node:
	var scene := get_tree().current_scene
	var replicator := NetReplicator.of(scene) if scene else null
	var player: Node = replicator.get_entity(net_id) if replicator and net_id >= 0 else null
	if player and player.get("owner_peer") == multiplayer.get_remote_sender_id():
		return player
	return null


func _store(all: Dictionary) -> void:
	NetService.world["quests"] = all
	if NetService.world.has("id"):
		SaveService.save_world(NetService.world)
	quests_changed.emit()
	if NetService.is_online():
		_rpc_state.rpc(all)


func _announce(id: String, state: String) -> void:
	quest_event.emit(id, state)
	if NetService.is_online():
		_rpc_announce.rpc(id, state)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_accept(id: String, net_id: int) -> void:
	if multiplayer.is_server():
		_accept(id, _player_from(net_id))


@rpc("any_peer", "call_remote", "reliable")
func _rpc_turn_in(id: String, net_id: int) -> void:
	if multiplayer.is_server():
		var player := _player_from(net_id)
		if player:
			_turn_in(id, player)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_event(kind: String, a: String, b: String, net_id: int) -> void:
	if multiplayer.is_server() and kind in ["interagir", "chegar", "falar"] and a.length() <= 96 and b.length() <= 64:
		_event(kind, a, b, _player_from(net_id))


@rpc("authority", "call_remote", "reliable")
func _rpc_state(all: Dictionary) -> void:
	NetService.world["quests"] = all
	quests_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_announce(id: String, state: String) -> void:
	quest_event.emit(id, state)


@rpc("authority", "call_remote", "reliable")
func _rpc_react(target: String, action: String) -> void:
	var reactions: Dictionary = NetService.world.get("quest_reactions", {})
	reactions[target] = action
	NetService.world["quest_reactions"] = reactions
	_apply_reaction(target, action)
