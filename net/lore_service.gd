extends Node
## Conhecimento do grupo (a história escondida, sem questlog): fatos que o grupo descobriu lendo
## documentos e ouvindo NPCs. Ficam no save do mundo (NetService.world["facts"]), vão para os
## convidados junto com o mundo e a cada descoberta. O jogo não avisa nada: só passam a existir
## falas novas, NPCs que puxam assunto e acessos que abrem (LoreGate, Entrance.requires).

signal facts_changed

const BOOK_PATH := "res://world/lore/lore.tres"

var _book: LoreBook
## Falas de "puxar assunto" já ditas nesta sessão (não repetem).
var _said := {}


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


## Fala do NPC agora (a de maior prioridade que vale), ou null.
func line_for(npc_name: String, approach := false) -> NpcLine:
	var best: NpcLine = null
	for line in book().lines:
		if line == null or line.npc != npc_name or line.approach != approach:
			continue
		if allowed(line.requires, line.forbids) and (best == null or line.priority > best.priority):
			best = line
	return best


## Fala de "puxar assunto" ainda não dita nesta sessão, ou null.
func approach_line(npc_name: String) -> NpcLine:
	var line := line_for(npc_name, true)
	return line if line and not _said.has(line.key()) else null


func mark_said(line: NpcLine) -> void:
	_said[line.key()] = true


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
