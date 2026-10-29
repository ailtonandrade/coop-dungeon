class_name WorldStreamer
extends Node3D
## Carrega em segundo plano os blocos do mapa em volta de cada jogador e descarrega os longe.
## - Host (ou offline): em volta de TODOS os jogadores, porque ele simula o mundo inteiro.
## - Cliente: só em volta dos jogadores desta máquina (o resto ele não precisa desenhar).
## Interiores (masmorras) carregam quando alguém está dentro deles.
##
## Garantia: o bloco onde um jogador está fica pronto antes da física rodar nele.
## O primeiro carregamento e o destino de um teleporte são carregados na hora (load_now);
## os vizinhos chegam em segundo plano antes de alguém andar até eles.

signal chunk_loaded(key: String)
signal chunk_unloaded(key: String)

## Blocos em volta de cada jogador que ficam carregados (1 = 3x3).
const LOAD_RADIUS := 1
## Só descarrega quando passa disso (folga para não carregar e descarregar na borda).
const UNLOAD_RADIUS := 2

@export var world_map: WorldMap

var _loaded := {}   # chave -> Node3D
var _loading := {}  # chave -> caminho sendo carregado em segundo plano


static func of(node: Node) -> WorldStreamer:
	return node.get_tree().get_first_node_in_group("world_streamer") if node.is_inside_tree() else null


func _ready() -> void:
	add_to_group("world_streamer")


func loaded_keys() -> Array:
	return _loaded.keys()


func is_loaded(key: String) -> bool:
	return _loaded.has(key)


## Tem chão carregado embaixo de `position`?
func is_ready_at(position: Vector3) -> bool:
	return _loaded.has(_key_at(position))


func region_at(position: Vector3) -> RegionDef:
	return world_map.region_at(position) if world_map else null


## Carrega já (sem esperar) o que existe em volta de `position`. Usado no começo e antes
## de teleportar alguém para longe (entrada de masmorra).
func load_now(position: Vector3) -> void:
	for key in _wanted_around(position, 0):
		_load_sync(key)
	for key in _wanted_around(position, LOAD_RADIUS):
		_request(key)


func _physics_process(_delta: float) -> void:
	if world_map == null:
		return
	var anchors := _anchors()
	var wanted := {}
	for anchor in anchors:
		for key in _wanted_around(anchor, LOAD_RADIUS):
			wanted[key] = true
		# O bloco onde o jogador está não pode esperar o segundo plano.
		_load_sync(_key_at(anchor))
	for key: String in wanted:
		_request(key)
	_finish_loads()
	if anchors.is_empty():
		return
	for key: String in _loaded.keys():
		if not _within(key, anchors, UNLOAD_RADIUS):
			_unload(key)


func _anchors() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for player: Player in get_tree().get_nodes_in_group("players"):
		if multiplayer.is_server() or player.is_local():
			result.append(player.global_position)
	return result


## Chaves: "x,z" para blocos do mapa de fora, "i:<id>" para interiores.
func _key_at(position: Vector3) -> String:
	var interior := world_map.interior_at(position)
	if interior:
		return "i:" + interior
	var c := world_map.chunk_at(position)
	return "%d,%d" % [c.x, c.y]


func _wanted_around(position: Vector3, radius: int) -> Array[String]:
	var keys: Array[String] = []
	var interior := world_map.interior_at(position)
	if interior:
		keys.append("i:" + interior)
		return keys
	var center := world_map.chunk_at(position)
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			var coords := center + Vector2i(dx, dz)
			if world_map.chunks.has(coords):
				keys.append("%d,%d" % [coords.x, coords.y])
	return keys


func _within(key: String, anchors: Array[Vector3], radius: int) -> bool:
	for anchor in anchors:
		if key.begins_with("i:"):
			if _key_at(anchor) == key:
				return true
			continue
		var parts := key.split(",")
		var coords := Vector2i(int(parts[0]), int(parts[1]))
		if world_map.interior_at(anchor) == "":
			var d := (coords - world_map.chunk_at(anchor)).abs()
			if maxi(d.x, d.y) <= radius:
				return true
	return false


func _path_and_origin(key: String) -> Array:
	if key.begins_with("i:"):
		var info: Dictionary = world_map.interiors.get(key.substr(2), {})
		return [info.get("path", ""), info.get("origin", Vector3.ZERO)]
	var parts := key.split(",")
	var coords := Vector2i(int(parts[0]), int(parts[1]))
	return [world_map.chunks.get(coords, ""), world_map.chunk_origin(coords)]


func _request(key: String) -> void:
	if _loaded.has(key) or _loading.has(key):
		return
	var path: String = _path_and_origin(key)[0]
	if path.is_empty():
		return
	ResourceLoader.load_threaded_request(path)
	_loading[key] = path


func _finish_loads() -> void:
	for key: String in _loading.keys():
		var status := ResourceLoader.load_threaded_get_status(_loading[key])
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_spawn(key, ResourceLoader.load_threaded_get(_loading[key]))
			_loading.erase(key)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Bloco do mundo não carregou: %s" % _loading[key])
			_loading.erase(key)


func _load_sync(key: String) -> void:
	if _loaded.has(key):
		return
	var info := _path_and_origin(key)
	if info[0] == "":
		return
	if _loading.has(key):
		# Já pedido em segundo plano: espera terminar (load_threaded_get bloqueia até ficar pronto).
		_spawn(key, ResourceLoader.load_threaded_get(_loading[key]))
		_loading.erase(key)
	else:
		_spawn(key, load(info[0]))


func _spawn(key: String, scene: PackedScene) -> void:
	if scene == null or _loaded.has(key):
		return
	var chunk := scene.instantiate() as Node3D
	chunk.name = "Chunk_" + key.replace(",", "_").replace(":", "_")
	# Posição antes de entrar na cena: o que nasce no bloco já nasce no lugar certo.
	chunk.position = _path_and_origin(key)[1]
	add_child(chunk)
	_loaded[key] = chunk
	chunk_loaded.emit(key)


func _unload(key: String) -> void:
	var chunk: Node3D = _loaded[key]
	_loaded.erase(key)
	chunk.queue_free()
	chunk_unloaded.emit(key)
