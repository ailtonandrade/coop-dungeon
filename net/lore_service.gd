extends Node
## Conhecimento do grupo (a história escondida, sem questlog): fatos que o grupo descobriu lendo
## documentos e ouvindo NPCs. Ficam no save do mundo (NetService.world["facts"]), vão para os
## convidados junto com o mundo e a cada descoberta. O jogo não avisa nada: só passam a existir
## falas novas, NPCs que puxam assunto e acessos que abrem (LoreGate, Entrance.requires).

signal facts_changed

const BOOK_PATH := "res://world/lore/lore.tres"
const NPC_DIR := "res://world/lore/npcs"
const FACT_DIR := "res://world/lore/facts"
## Fatos internos (região visitada, gatilho usado, porta aberta, item entregue): não aparecem
## no Conhecimento (a não ser que tenham ficha sem `hidden`).
const INTERNAL_PREFIXES := ["visitou_", "gatilho_", "abriu_", "item_", "conheceu_"]
const MAX_SOURCE := 120

var _book: LoreBook
## Falas de "puxar assunto" já ditas nesta sessão (não repetem).
var _said := {}
var _dialogues := {}  # nome do NPC -> NpcDialogue
var _fact_defs := {}  # id -> FactDef
var _fact_defs_loaded := false


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


## Grava fatos novos (qualquer máquina pode pedir; quem grava é o host). `source` = de onde veio,
## "tipo|nome" (documento, conversa, missao, porta, terminal, lugar, objeto), para a tela de
## Conhecimento.
func learn(ids: Array, source := "") -> void:
	var fresh := ids.filter(func(id: Variant) -> bool: return id is String and not id.is_empty() and not knows(id))
	if fresh.is_empty():
		return
	source = source.left(MAX_SOURCE)
	if multiplayer.is_server():
		_add(fresh, source)
		if NetService.is_online():
			_rpc_learned.rpc(fresh, source)
	else:
		_rpc_request.rpc_id(1, fresh, source)


## Conhecimento (tela na roda do inventário): fatos que o grupo sabe, com ficha (FactDef) ou não.

func fact_def(id: String) -> FactDef:
	if not _fact_defs_loaded:
		_fact_defs_loaded = true
		if DirAccess.dir_exists_absolute(FACT_DIR):
			for file in DirAccess.get_files_at(FACT_DIR):
				file = file.trim_suffix(".remap")
				if file.ends_with(".tres"):
					var found := load(FACT_DIR.path_join(file)) as FactDef
					if found and not found.id.is_empty():
						_fact_defs[found.id] = found
	return _fact_defs.get(id)


## Fato que vale mostrar ao jogador (sem os marcadores internos nem os de ficha escondida).
func is_visible_fact(id: String) -> bool:
	var found := fact_def(id)
	if found:
		return not found.hidden
	for prefix: String in INTERNAL_PREFIXES:
		if id.begins_with(prefix):
			return false
	return true


## Fatos para a tela, do mais novo para o mais antigo.
func known_facts() -> Array[String]:
	var result: Array[String] = []
	for id: Variant in facts().keys():
		if id is String and is_visible_fact(id):
			result.push_front(id)
	return result


func fact_title(id: String) -> String:
	var found := fact_def(id)
	if found and not found.title.is_empty():
		return Txt.t(found.title)
	return id.replace("_", " ").capitalize()


func fact_description(id: String) -> String:
	var found := fact_def(id)
	return Txt.t(found.description) if found else ""


## De onde veio: o que a ficha diz ou, sem isso, o que ficou gravado quando o grupo aprendeu.
func fact_source(id: String) -> String:
	var found := fact_def(id)
	if found and not found.source.is_empty():
		return Txt.t(found.source)
	var raw: Variant = facts().get(id)
	return source_text(raw if raw is String else "")


static func source_text(raw: String) -> String:
	var kind := raw.get_slice("|", 0)
	var what := Txt.t(raw.get_slice("|", 1)) if raw.contains("|") else ""
	match kind:
		"documento":
			return Txt.t("Lendo: %s") % what if not what.is_empty() else Txt.t("Lendo um documento")
		"conversa":
			return Txt.t("Conversa com %s") % what if not what.is_empty() else Txt.t("Numa conversa")
		"missao":
			return Txt.t("Missão: %s") % what if not what.is_empty() else Txt.t("Numa missão")
		"porta":
			return Txt.t("Abrindo uma porta")
		"terminal":
			return Txt.t("Invadindo um terminal")
		"lugar":
			return Txt.t("Explorando o lugar")
		"objeto":
			return Txt.t("Examinando algo")
	return Txt.t("Não lembra de onde")


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
		# Palavra em português ou a tradução dela (jogando em inglês: "water" acha "agua").
		for keyword in topic.keywords:
			for key in [normalize(keyword), normalize(Txt.t(keyword))]:
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
	learn(topic.teaches, "conversa|" + npc_name)
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


## Cada fato guarda de onde veio ("tipo|nome") ou true (saves antigos, ou sem origem).
func _add(fresh: Array, source := "") -> void:
	var known := facts()
	for id: String in fresh:
		known[id] = source if not source.is_empty() else true
	NetService.world["facts"] = known
	if multiplayer.is_server() and NetService.world.has("id"):
		SaveService.save_world(NetService.world)
	facts_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request(ids: Array, source: String) -> void:
	if multiplayer.is_server():
		learn(ids.filter(func(id: Variant) -> bool: return id is String and id.length() <= 64), source)


@rpc("authority", "call_remote", "reliable")
func _rpc_learned(ids: Array, source: String) -> void:
	_add(ids, source)
