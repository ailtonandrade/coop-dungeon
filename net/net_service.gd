extends Node
## Sessão de jogo: offline, host ou cliente.
## - Offline e host rodam a simulação de verdade (inimigos, dano, loot).
## - O cliente manda os comandos dos seus jogadores locais e mostra o que o host replica.
## Sofá e online somam: cada máquina tem de 1 a 4 jogadores, a sala inteira até 4.
##
## Entrada de um cliente: conecta -> "olá" (versão e nome) -> host responde com o mundo
## (ou recusa: cheio, versão diferente) -> cliente carrega a fase -> avisa "pronto" ->
## host manda tudo que já existe e passa a mandar o estado ~30 vezes por segundo.

signal status_changed(text: String)
signal peer_ready(peer_id: int)

const GAME_VERSION := "0.10"
const DEFAULT_PORT := 7777
const LEVEL_SCENE := "res://world/world.tscn"
const MENU_SCENE := "res://ui/main_menu.tscn"

enum Mode { OFFLINE, HOST, CLIENT }

var mode := Mode.OFFLINE
## Ficha do mundo em jogo (no cliente, a que o host mandou).
var world: Dictionary = {}
var player_name := "Jogador"
var port := DEFAULT_PORT
## Última mensagem para o menu mostrar (ex.: por que a conexão caiu).
var last_message := ""

## Impressão digital do conteúdo desta instalação: o mapa (MapIntegrity) e as fichas de item
## (ItemDB). Calculada uma vez, na primeira vez que abre ou entra num mundo online.
var map_fingerprint := ""

## Senha que o convidado digitou para entrar (vai como resumo no "olá").
var _join_password := ""
var _ready_peers: Array[int] = []
var _peer_names := {}
var _remote_inputs := {}  # "peer:slot" -> PlayerInput
var _press_counts := {}   # cliente: slot local -> PackedByteArray
var _discovery: LanDiscovery
## Host com mundo aberto/privado: acesso pela internet (UPnP, código do mundo, CGNAT).
var internet: InternetAccess


func _ready() -> void:
	for variable in ["USERNAME", "USER"]:
		if OS.has_environment(variable):
			player_name = OS.get_environment(variable)
			break
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_host() -> bool:
	return multiplayer.is_server()


func is_online() -> bool:
	return mode != Mode.OFFLINE


func ready_peers() -> Array[int]:
	return _ready_peers


func player_count() -> int:
	return get_tree().get_nodes_in_group("players").size()


## Endereços IPv4 desta máquina na rede local (para passar a quem vai entrar por IP).
func local_addresses() -> PackedStringArray:
	var result := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.count(".") == 3 and not address.begins_with("127.") and not address.begins_with("169.254."):
			result.append(address)
	return result


## Senha do mundo

## Resumo da senha (o texto não fica salvo nem viaja pela rede).
static func password_hash(text: String) -> String:
	return ("corrumpted:" + text).sha256_text()


func has_password() -> bool:
	return not String(world.get("password", "")).is_empty()


## Host: troca a senha do mundo em jogo (vazio = sem senha) e salva.
func set_world_password(text: String) -> void:
	if text.strip_edges().is_empty():
		world.erase("password")
	else:
		world["password"] = password_hash(text)
	if is_host() and not world.is_empty():
		SaveService.save_world(world)


## Abrir mundo

## O navegador (versão Web, usada para testar no Xbox pelo Edge) não tem a rede do jogo:
## lá só existe o co-op de sofá.
func online_supported() -> bool:
	return not OS.has_feature("web")


func play_world(info: Dictionary) -> Error:
	world = info
	last_message = ""
	if info.get("visibility", "open") == "offline" or not online_supported():
		mode = Mode.OFFLINE
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		_go_to(LEVEL_SCENE)
		return OK

	_ensure_fingerprint()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, GameConfig.MAX_PLAYERS - 1)
	if err != OK:
		last_message = "Não deu pra abrir o mundo na porta %d (já está em uso?)" % port
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	internet = InternetAccess.new()
	add_child(internet)
	internet.start(port)
	if info.get("visibility") == "open":
		_discovery = LanDiscovery.new()
		add_child(_discovery)
		_discovery.start_advertising(_advert)
	_go_to(LEVEL_SCENE)
	return OK


func join(address: String, p_port := DEFAULT_PORT, password := "") -> Error:
	_ensure_fingerprint()
	_join_password = password
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, p_port)
	if err != OK:
		last_message = "Endereço inválido: %s" % address
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
	status_changed.emit("Conectando em %s:%d..." % [address, p_port])
	return OK


## Volta para o menu, fechando a sessão. `message` aparece no menu.
func leave_session(message := "") -> void:
	if is_host() and not world.is_empty():
		SaveService.save_world(world)
	if _discovery:
		_discovery.queue_free()
		_discovery = null
	if internet:
		internet.stop()
		internet.queue_free()
		internet = null
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.OFFLINE
	world = {}
	last_message = message
	_ready_peers.clear()
	_peer_names.clear()
	_remote_inputs.clear()
	_press_counts.clear()
	InputService.reset()
	_go_to(MENU_SCENE)


## Chamado pela fase quando termina de carregar.
func notify_level_ready() -> void:
	if mode == Mode.CLIENT:
		_rpc_client_ready.rpc_id(1)


## Jogadores

## Um jogador local escolheu o personagem: pede uma vaga para ele (ao host, se for cliente).
## Vai junto a ficha do personagem desta máquina (nome, visual, inventário, progressão).
func request_player(slot: int, character_id: String) -> void:
	var character := SaveService.load_character(character_id)
	if character.is_empty():
		return
	var save := {
		"character": character.id, "name": character.name, "model": character.model,
		"chip_color": character.chip_color, "inventory": character.get("inventory", {}),
		"progress": character.get("progress", {}),
	}
	if is_host():
		_add_player(1, slot, save)
	elif mode == Mode.CLIENT:
		_rpc_request_player.rpc_id(1, slot, save)


func request_leave(slot: int) -> void:
	if is_host():
		_remove_player(1, slot)
	elif mode == Mode.CLIENT:
		_rpc_request_leave.rpc_id(1, slot)


## Comandos de um jogador remoto, como o host enxerga.
func remote_input(peer: int, slot: int) -> PlayerInput:
	var key := "%d:%d" % [peer, slot]
	if not _remote_inputs.has(key):
		_remote_inputs[key] = PlayerInput.new()
	return _remote_inputs[key]


## Nome na tela: o do personagem; sem ele, o da conta (com o número da vaga no sofá).
func display_name(peer: int, slot: int, character_name := "") -> String:
	if not character_name.strip_edges().is_empty():
		return character_name.strip_edges().left(Characters.NAME_MAX)
	var base: String = player_name if peer == multiplayer.get_unique_id() else _peer_names.get(peer, "Convidado")
	return base if slot == 0 else "%s (%d)" % [base, slot + 1]


## Host: um baú/contêiner (LootContainer) foi aberto. Guarda no mundo (salva na hora) e avisa
## os convidados, que atualizam o visual.
func set_container_opened(container_id: String) -> void:
	var now := Time.get_unix_time_from_system()
	_apply_container(container_id, now)
	if not world.is_empty():
		SaveService.save_world(world)
	if mode == Mode.HOST:
		_rpc_container_opened.rpc(container_id, now)


func _apply_container(container_id: String, opened_at: float) -> void:
	var states: Dictionary = world.get("containers", {})
	states[container_id] = opened_at
	world["containers"] = states
	for container: Node in get_tree().get_nodes_in_group("containers"):
		if container.container_id == container_id:
			container.on_opened()


@rpc("authority", "call_remote", "reliable")
func _rpc_container_opened(container_id: String, opened_at: float) -> void:
	_apply_container(container_id, opened_at)


## Comando da tela de inventário de um jogador deste cliente, para o host executar.
func send_inventory_command(player: Node, command: String, args: Array) -> void:
	if player.has_meta("net_id"):
		_rpc_inventory_command.rpc_id(1, player.get_meta("net_id"), command, args)


func _add_player(peer: int, slot: int, save: Dictionary) -> void:
	var manager := get_tree().get_first_node_in_group("player_manager")
	if manager:
		manager.add_player(peer, slot, display_name(peer, slot, str(save.get("name", ""))), save)


func _remove_player(peer: int, slot: int) -> void:
	var manager := get_tree().get_first_node_in_group("player_manager")
	if manager:
		manager.remove_player(peer, slot)


func _physics_process(_delta: float) -> void:
	if mode != Mode.CLIENT or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	for slot in InputService.active_slots():
		var counts: PackedByteArray = _press_counts.get(slot, PackedByteArray())
		if counts.size() != InputService.Action.size():
			counts.resize(InputService.Action.size())
		for action: int in InputService.Action.values():
			if InputService.just_pressed(slot, action):
				counts[action] = (counts[action] + 1) % 256
		_press_counts[slot] = counts
		_rpc_input.rpc_id(1, slot, InputService.get_world_move(slot), InputService.get_aim(slot),
				InputService.get_down_mask(slot), counts)


## Conversa cliente <-> host

func _on_connected() -> void:
	status_changed.emit("Conectado. Entrando no mundo...")
	_rpc_hello.rpc_id(1, GAME_VERSION, player_name, map_fingerprint, password_hash(_join_password) if _join_password else "")


func _on_connection_failed() -> void:
	leave_session("Não foi possível conectar.")


func _on_server_disconnected() -> void:
	leave_session("O host fechou o mundo ou a conexão caiu.")


func _on_peer_disconnected(peer: int) -> void:
	_ready_peers.erase(peer)
	_peer_names.erase(peer)
	var manager := get_tree().get_first_node_in_group("player_manager")
	if manager:
		manager.remove_peer(peer)
	for key: String in _remote_inputs.keys():
		if key.begins_with("%d:" % peer):
			_remote_inputs.erase(key)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_hello(version: String, peer_name: String, fingerprint: String, password: String) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if version != GAME_VERSION:
		_reject(peer, "Versão diferente do jogo (host: %s, você: %s)." % [GAME_VERSION, version])
	elif fingerprint != map_fingerprint:
		_reject(peer, "O seu mapa ou os seus itens são diferentes dos do host (arquivos do jogo alterados ou atualização diferente).")
	elif has_password() and password != world.password:
		_reject(peer, "Senha errada." if password else "Este mundo tem senha: digite a senha antes de entrar.")
	elif player_count() >= GameConfig.MAX_PLAYERS:
		_reject(peer, "O mundo está cheio (%d jogadores)." % GameConfig.MAX_PLAYERS)
	else:
		_peer_names[peer] = peer_name.left(24)
		# A senha (resumo) fica só no host.
		var shared := world.duplicate()
		shared.erase("password")
		_rpc_welcome.rpc_id(peer, shared)


func _reject(peer: int, reason: String) -> void:
	_rpc_rejected.rpc_id(peer, reason)
	# Dá tempo da recusa chegar antes de derrubar a conexão.
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
			multiplayer.multiplayer_peer.disconnect_peer(peer))


@rpc("authority", "call_remote", "reliable")
func _rpc_welcome(info: Dictionary) -> void:
	world = info
	_go_to(LEVEL_SCENE)


@rpc("authority", "call_remote", "reliable")
func _rpc_rejected(reason: String) -> void:
	leave_session(reason)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_ready() -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not _ready_peers.has(peer):
		_ready_peers.append(peer)
		peer_ready.emit(peer)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_player(slot: int, save: Dictionary) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if _ready_peers.has(peer) and slot >= 0 and slot < GameConfig.MAX_PLAYERS:
		_add_player(peer, slot, save)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_inventory_command(net_id: int, command: String, args: Array) -> void:
	var replicator := get_tree().get_first_node_in_group("net_replicator")
	var player: Node = replicator.get_entity(net_id) if replicator else null
	# Só o dono mexe no inventário do próprio herói.
	if player is Player and player.owner_peer == multiplayer.get_remote_sender_id():
		player.apply_inventory_command(command, args)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_leave(slot: int) -> void:
	_remove_player(multiplayer.get_remote_sender_id(), slot)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_input(slot: int, move: Vector2, aim: Vector2, down: int, counts: PackedByteArray) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if _ready_peers.has(peer):
		remote_input(peer, slot).apply_remote(move, aim, down, counts)


func _ensure_fingerprint() -> void:
	if map_fingerprint.is_empty():
		map_fingerprint = (MapIntegrity.fingerprint(load(GameConfig.WORLD_MAP)) + ItemDB.fingerprint()).sha256_text()


func _advert() -> Dictionary:
	return {
		"world_id": world.get("id", ""),
		"name": world.get("name", "?"),
		"host": player_name,
		"players": player_count(),
		"max": GameConfig.MAX_PLAYERS,
		"port": port,
		"version": GAME_VERSION,
		"locked": has_password(),
	}


func _go_to(scene: String) -> void:
	get_tree().change_scene_to_file.call_deferred(scene)
