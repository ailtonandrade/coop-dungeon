extends Node
## Chat do mundo (autoload "Chat"): todo mundo da sala vê. O convidado manda ao host; o host
## confere (tamanho, frequência, mudo) e espalha para todos, ele incluso. Offline, a mensagem
## só aparece aqui (o sofá todo vê a mesma tela).
##
## Tipos de linha: "player" (alguém falou) e "system" (entrou, saiu, subiu de nível...).

signal message_added(message: Dictionary)

const MAX_LENGTH := 160
const HISTORY := 60
## Tempo mínimo entre duas mensagens do mesmo PC (contra spam).
const MIN_INTERVAL := 0.6
## Mensagens rápidas do controle (direcional para baixo).
const QUICK := [
	"Bora!", "Cuidado!", "Preciso de cura!", "Loot aqui!", "Espera aí!", "Vem comigo!",
	"Valeu!", "Boa!",
]

## Últimas mensagens: {from, color, text, kind, time}.
var history: Array[Dictionary] = []

var _last_message := {}  # peer -> segundos (host)


func _ready() -> void:
	multiplayer.peer_disconnected.connect(func(peer: int) -> void: _last_message.erase(peer))


## Um jogador local manda uma mensagem (nome e cor vêm do herói dele).
func send(player: Node, text: String) -> void:
	var clean := clean_text(text)
	if clean.is_empty() or player == null:
		return
	if not NetService.is_online():
		_add(player.display_name, player.index, clean, "player")
	elif NetService.is_host():
		_broadcast_player(multiplayer.get_unique_id(), player.display_name, player.index, clean)
	else:
		_rpc_send.rpc_id(1, player.get_meta("net_id", -1), clean)


## Aviso do sistema para a sala toda (só o host espalha; offline, só aqui).
func system(text: String) -> void:
	if NetService.is_online() and NetService.is_host():
		_rpc_message.rpc("", -1, text, "system")
		_add("", -1, text, "system")
	elif not NetService.is_online():
		_add("", -1, text, "system")


## Texto seguro: sem quebras, sem códigos de formatação, no tamanho máximo.
static func clean_text(text: String) -> String:
	var clean := text.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges()
	return clean.left(MAX_LENGTH)


func clear() -> void:
	history.clear()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_send(net_id: int, text: String) -> void:
	if not NetService.is_host():
		return
	var peer := multiplayer.get_remote_sender_id()
	var clean := clean_text(text)
	var now := Time.get_ticks_msec() / 1000.0
	if clean.is_empty() or now - float(_last_message.get(peer, -10.0)) < MIN_INTERVAL:
		return
	# Quem o host mutou para todos fica mudo também no chat.
	if Voice.muted_by_host.has(peer):
		return
	_last_message[peer] = now
	# Nome e cor do herói que ele controla (o convidado não escolhe o nome que aparece).
	var replicator := get_tree().get_first_node_in_group("net_replicator")
	var player: Node = replicator.get_entity(net_id) if replicator else null
	if player == null or player.owner_peer != peer:
		return
	_broadcast_player(peer, player.display_name, player.index, clean)


func _broadcast_player(_peer: int, from: String, color: int, text: String) -> void:
	_rpc_message.rpc(from, color, text, "player")
	_add(from, color, text, "player")


@rpc("authority", "call_remote", "reliable")
func _rpc_message(from: String, color: int, text: String, kind: String) -> void:
	_add(from, color, clean_text(text), kind)


func _add(from: String, color: int, text: String, kind: String) -> void:
	var time := Time.get_time_dict_from_system()
	var message := {"from": from, "color": color, "text": text, "kind": kind,
			"time": "%02d:%02d" % [time.hour, time.minute], "at": Time.get_ticks_msec() / 1000.0}
	history.append(message)
	if history.size() > HISTORY:
		history.remove_at(0)
	message_added.emit(message)
