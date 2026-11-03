extends Node
## Conhecimento do grupo (a história escondida, sem questlog): fatos que o grupo descobriu lendo
## documentos e ouvindo NPCs. Ficam no save do mundo (NetService.world["facts"]), vão para os
## convidados junto com o mundo e a cada descoberta. O jogo não avisa nada: só passam a existir
## falas novas, NPCs que puxam assunto e acessos que abrem (LoreGate, Entrance.requires).

signal facts_changed

const BOOK_PATH := "res://world/lore/lore.tres"
const NPC_DIR := "res://world/lore/npcs"

var _book: LoreBook
## Falas de "puxar assunto" já ditas nesta sessão (não repetem).
var _said := {}
var _dialogues := {}  # nome do NPC -> NpcDialogue


func book() -> LoreBook:
	if _book == null:
		_book = load(BOOK_PATH) as LoreBook if ResourceLoader.exists(BOOK_PATH) else LoreBook.new()
	return _book


func facts() -> Dictionary:
	return NetService.world.get("facts", {})


func knows(id: String) -> bool:
	return facts().has(id)


func knows_all(ids: Array) -> bool:
	return ids.all(func(id: String) -> bool: return knows(id))


func allowed(requires: Array, forbids: Array) -> bool:
	return knows_all(requires) and not forbids.any(func(id: String) -> bool: return knows(id))


## Grava fatos novos (qualquer máquina pode pedir; quem grava é o host).
func learn(ids: Array) -> void:
	var fresh := ids.filter(func(id: Variant) -> bool: return id is String and not id.is_empty() and not knows(id))
	if fresh.is_empty():
		return
	if multiplayer.is_server():
		_add(fresh)
		if NetService.is_online():
			_rpc_learned.rpc(fresh)
	else:
		_rpc_request.rpc_id(1, fresh)


func document(id: String) -> LoreDocument:
	return book().document(id)


## Conversas (NpcDialogue, um arquivo por NPC em NPC_DIR)

func dialogue(npc_name: String) -> NpcDialogue:
	if _dialogues.is_empty():
		for file in DirAccess.get_files_at(NPC_DIR):
			file = file.trim_suffix(".remap")
			if file.ends_with(".tres"):
				var found := load(NPC_DIR.path_join(file)) as NpcDialogue
				if found and not found.npc.is_empty():
					_dialogues[found.npc] = found
	return _dialogues.get(npc_name)


## A fala que vale agora numa lista (maior prioridade entre as liberadas), ou null.
func best_line(lines: Array) -> DialogueLine:
	var best: DialogueLine = null
	for line: DialogueLine in lines:
		if line and allowed(line.requires, line.forbids) and (best == null or line.priority > best.priority):
			best = line
	return best


func greeting(npc_name: String) -> DialogueLine:
	var found := dialogue(npc_name)
	return best_line(found.greetings) if found else null


## Fala de "puxar assunto" ainda não dita nesta sessão, ou null.
func approach_line(npc_name: String) -> DialogueLine:
	var found := dialogue(npc_name)
	var line := best_line(found.approach) if found else null
	return line if line and not _said.has(line.get_instance_id()) else null


func mark_said(line: Resource) -> void:
	_said[line.get_instance_id()] = true


## O assunto vale para este jogador agora (fatos do grupo e item na mochila)?
func topic_open(topic: DialogueTopic, player: Node) -> bool:
	return topic != null and allowed(topic.requires, topic.forbids) \
			and (topic.requires_item.is_empty() or has_item(player, topic.requires_item))


## Botões de assunto para este jogador, do mais importante para o menos.
func topics_for(npc_name: String, player: Node) -> Array[DialogueTopic]:
	var found := dialogue(npc_name)
	var result: Array[DialogueTopic] = []
	if found:
		for topic in found.topics:
			if topic and not topic.hidden and topic_open(topic, player):
				result.append(topic)
	result.sort_custom(func(a: DialogueTopic, b: DialogueTopic) -> bool: return a.priority > b.priority)
	return result


## O que o jogador digitou bate com que assunto (inclusive os escondidos)? Null se nenhum.
func answer(npc_name: String, typed: String, player: Node) -> DialogueTopic:
	var found := dialogue(npc_name)
	if found == null:
		return null
	var words := normalize(typed).split(" ", false)
	var best: DialogueTopic = null
	for topic in found.topics:
		if not topic_open(topic, player):
			continue
		for keyword in topic.keywords:
			var key := normalize(keyword)
			if not key.is_empty() and (words.has(key) or (key.contains(" ") and normalize(typed).contains(key))):
				if best == null or topic.priority > best.priority:
					best = topic
				break
	return best


## Minúsculas, sem acento e sem pontuação ("Água?" -> "agua").
static func normalize(text: String) -> String:
	var plain := text.to_lower()
	for pair: Array in [["á", "a"], ["à", "a"], ["â", "a"], ["ã", "a"], ["é", "e"], ["ê", "e"], ["í", "i"],
			["ó", "o"], ["ô", "o"], ["õ", "o"], ["ú", "u"], ["ü", "u"], ["ç", "c"]]:
		plain = plain.replace(pair[0], pair[1])
	var result := ""
	for character in plain:
		var letter := (character >= "a" and character <= "z") or (character >= "0" and character <= "9")
		result += character if letter else " "
	return " ".join(result.split(" ", false))


static func has_item(player: Node, item_id: String) -> bool:
	if player == null or player.get("inventory") == null:
		return false
	# all_items() devolve [lugar, item].
	return player.inventory.all_items().any(func(entry: Array) -> bool: return entry[1] is Dictionary and entry[1].get("id") == item_id)


## O jogador ouviu a resposta: o grupo aprende os fatos e, se o assunto dá item, o host entrega
## (uma vez por mundo).
func heard(npc_name: String, topic: DialogueTopic, player: Node) -> void:
	learn(topic.teaches)
	if topic.gives_item.is_empty() or not ItemDB.has(topic.gives_item):
		return
	var given := "item_%s_%s" % [PropBuilder.id_from(npc_name), topic.gives_item]
	if knows(given):
		return
	if multiplayer.is_server():
		_give(player, topic.gives_item, given)
	else:
		_rpc_give.rpc_id(1, int(player.get_meta("net_id", -1)), topic.gives_item, given)


func _give(player: Node, item_id: String, fact: String) -> void:
	if player == null or knows(fact):
		return
	learn([fact])
	var item := ItemDB.make(item_id, 1, "common")
	if player.inventory.add_item(item).is_empty():
		Loot.drop(player, item, Combat.flat(player.global_position) + Vector3(0.6, 0, 0))


@rpc("any_peer", "call_remote", "reliable")
func _rpc_give(net_id: int, item_id: String, fact: String) -> void:
	if not multiplayer.is_server() or not ItemDB.has(item_id):
		return
	var scene := get_tree().current_scene
	var replicator := NetReplicator.of(scene) if scene else null
	var player: Node = replicator.get_entity(net_id) if replicator else null
	if player and player.get("owner_peer") == multiplayer.get_remote_sender_id():
		_give(player, item_id, fact)


func _add(fresh: Array) -> void:
	var known := facts()
	for id: String in fresh:
		known[id] = true
	NetService.world["facts"] = known
	if multiplayer.is_server() and NetService.world.has("id"):
		SaveService.save_world(NetService.world)
	facts_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request(ids: Array) -> void:
	if multiplayer.is_server():
		learn(ids.filter(func(id: Variant) -> bool: return id is String and id.length() <= 64))


@rpc("authority", "call_remote", "reliable")
func _rpc_learned(ids: Array) -> void:
	_add(ids)
