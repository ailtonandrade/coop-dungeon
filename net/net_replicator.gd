class_name NetReplicator
extends Node
## Replica as entidades da fase (jogadores, inimigos, projéteis).
## Só o host cria e simula. Os outros recebem "nasceu", "sumiu" e um retrato do
## estado (snapshot) ~30 vezes por segundo, e só desenham.
##
## Uma entidade replicada implementa:
## - get_net_state() -> Array  (host)
## - apply_net_state(state: Array)  (cliente)
## Efeitos visuais (piscar, tremer câmera, rastro do golpe) passam por broadcast_fx().

const SNAPSHOT_RATE := 30.0
const PLAYER_SCENE := preload("res://player/player.tscn")

@export var player_root: Node3D
@export var enemy_root: Node3D
@export var fx_root: Node3D

var _entities := {}  # net_id -> Node
var _next_id := 1
var _snapshot_timer := 0.0


static func of(node: Node) -> NetReplicator:
	return node.get_tree().get_first_node_in_group("net_replicator")


func _ready() -> void:
	add_to_group("net_replicator")
	NetService.peer_ready.connect(_on_peer_ready)


## Host: cria a entidade aqui e em todos os clientes prontos.
## `data` precisa ter só tipos simples (vai pela rede); "pos" posiciona ao nascer.
func spawn(type: String, data: Dictionary) -> Node:
	var id := _next_id
	_next_id += 1
	var node := _create(id, type, data)
	for peer in NetService.ready_peers():
		_rpc_spawn.rpc_id(peer, id, type, data)
	return node


## Roda `method` só na máquina `peer` (ex.: o inventário vai só para o dono do herói).
func send_to_peer(peer: int, node: Node, method: String, args: Array) -> void:
	if peer == multiplayer.get_unique_id():
		node.callv(method, args)
	elif node.has_meta("net_id") and NetService.ready_peers().has(peer):
		_rpc_fx.rpc_id(peer, node.get_meta("net_id"), method, args)


func get_entity(id: int) -> Node:
	return _entities.get(id)


## Roda `method` com `args` na entidade aqui e nos clientes.
func broadcast_fx(node: Node, method: String, args: Array) -> void:
	node.callv(method, args)
	if not node.has_meta("net_id"):
		return
	for peer in NetService.ready_peers():
		_rpc_fx.rpc_id(peer, node.get_meta("net_id"), method, args)


func _create(id: int, type: String, data: Dictionary) -> Node:
	var node: Node3D
	var parent: Node3D
	match type:
		"player":
			node = PLAYER_SCENE.instantiate()
			node.setup(data)
			parent = player_root
		"enemy":
			node = Enemy.create(data.kind)
			parent = enemy_root
		"projectile":
			node = Projectile.build(data)
			parent = fx_root
		"loot":
			node = Loot.build(data)
			parent = fx_root
		_:
			push_error("Tipo de entidade desconhecido: %s" % type)
			return null
	node.name = "%s_%d" % [type, id]
	node.set_meta("net_id", id)
	node.set_meta("net_type", type)
	node.set_meta("net_data", data)
	_entities[id] = node
	node.tree_exiting.connect(_on_entity_exiting.bind(id))
	parent.add_child(node)
	if data.has("pos"):
		node.global_position = data.pos
		node.reset_physics_interpolation()
	return node


func _on_entity_exiting(id: int) -> void:
	_entities.erase(id)
	if is_queued_for_deletion() or not is_inside_tree() or not multiplayer.is_server():
		return
	for peer in NetService.ready_peers():
		_rpc_despawn.rpc_id(peer, id)


func _on_peer_ready(peer: int) -> void:
	# Quem acabou de chegar recebe tudo que já existe.
	for id: int in _entities:
		var node: Node = _entities[id]
		_rpc_spawn.rpc_id(peer, id, node.get_meta("net_type"), _current_data(node))


func _current_data(node: Node3D) -> Dictionary:
	var data: Dictionary = node.get_meta("net_data").duplicate()
	data["pos"] = node.global_position
	return data


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or NetService.ready_peers().is_empty():
		return
	_snapshot_timer -= delta
	if _snapshot_timer > 0.0:
		return
	_snapshot_timer = 1.0 / SNAPSHOT_RATE
	var states := []
	for id: int in _entities:
		var node: Node = _entities[id]
		if node.has_method("get_net_state"):
			states.append(id)
			states.append(node.get_net_state())
	var shared := {}
	for node in get_tree().get_nodes_in_group("net_static"):
		shared[String(node.name)] = node.get_net_state()
	for peer in NetService.ready_peers():
		_rpc_snapshot.rpc_id(peer, states, shared)


@rpc("authority", "call_remote", "reliable")
func _rpc_spawn(id: int, type: String, data: Dictionary) -> void:
	if not _entities.has(id):
		_create(id, type, data)


@rpc("authority", "call_remote", "reliable")
func _rpc_despawn(id: int) -> void:
	if _entities.has(id):
		_entities[id].queue_free()
		_entities.erase(id)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_snapshot(states: Array, shared: Dictionary) -> void:
	for i in range(0, states.size(), 2):
		var node: Node = _entities.get(states[i])
		if node:
			node.apply_net_state(states[i + 1])
	for node in get_tree().get_nodes_in_group("net_static"):
		if shared.has(String(node.name)):
			node.apply_net_state(shared[String(node.name)])


@rpc("authority", "call_remote", "reliable")
func _rpc_fx(id: int, method: String, args: Array) -> void:
	var node: Node = _entities.get(id)
	if node:
		node.callv(method, args)
