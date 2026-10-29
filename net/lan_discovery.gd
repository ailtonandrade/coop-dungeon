class_name LanDiscovery
extends Node
## Anúncio e busca de mundos na rede local, por broadcast UDP.
## O host anuncia a cada segundo; quem está na tela "Buscar mundos" escuta.
## Na versão de lançamento, a busca pela internet vem do PlayFab Lobby com esta mesma ideia.

signal worlds_changed

const PORT := 7779
const INTERVAL := 1.0
## Mundo que parou de anunciar some da lista depois deste tempo.
const EXPIRE := 3.5

## Mundos encontrados: chave -> {name, host, players, max, port, version, address, seen}
var worlds := {}

var _udp := PacketPeerUDP.new()
var _advert := Callable()
var _listening := false
var _timer := 0.0


## Começa a anunciar. `advert` devolve o Dictionary do anúncio (é chamado a cada envio).
func start_advertising(advert: Callable) -> void:
	_advert = advert
	_udp.set_broadcast_enabled(true)
	_timer = 0.0


func start_listening() -> Error:
	var err := _udp.bind(PORT)
	_listening = err == OK
	return err


func stop() -> void:
	_advert = Callable()
	_listening = false
	_udp.close()
	worlds.clear()


func _exit_tree() -> void:
	_udp.close()


func _process(delta: float) -> void:
	if _advert.is_valid():
		_timer -= delta
		if _timer <= 0.0:
			_timer = INTERVAL
			_send(JSON.stringify(_advert.call()).to_utf8_buffer())
	if _listening:
		_receive()


func _send(bytes: PackedByteArray) -> void:
	# Broadcast para a rede e loopback para achar o mundo aberto na mesma máquina.
	for target in ["255.255.255.255", "127.0.0.1"]:
		_udp.set_dest_address(target, PORT)
		_udp.put_packet(bytes)


func _receive() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var changed := false
	while _udp.get_available_packet_count() > 0:
		var bytes := _udp.get_packet()
		var address := _udp.get_packet_ip()
		var info: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if not (info is Dictionary and info.has("name") and info.has("port")):
			continue
		var key := "%s|%s" % [info.get("world_id", ""), info.get("host", "")]
		var known: Dictionary = worlds.get(key, {})
		# A mesma máquina chega pela rede e pelo loopback: fica o endereço de rede.
		if address == "127.0.0.1" and known.has("address") and known.address != "127.0.0.1":
			address = known.address
		info["address"] = address
		info["seen"] = now
		changed = changed or not worlds.has(key) or known.get("players") != info.get("players")
		worlds[key] = info
	for key: String in worlds.keys():
		if now - float(worlds[key].seen) > EXPIRE:
			worlds.erase(key)
			changed = true
	if changed:
		worlds_changed.emit()
