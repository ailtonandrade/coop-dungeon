class_name InternetAccess
extends Node
## Deixa o mundo do host alcançável pela internet, sem mexer no roteador quando der:
## - UPnP (embutido no Godot): pede ao roteador para abrir a porta do jogo sozinho;
## - descobre o IP de fora e monta o **código do mundo** (o IP e a porta num código curto,
##   tipo "K7Q2-9XM", para o amigo digitar em "Buscar mundos");
## - percebe CGNAT (o provedor divide um IP entre vários clientes, comum no Brasil): aí nenhuma
##   porta abre e o jeito é uma VPN de jogo (Radmin VPN, ZeroTier, Tailscale) ou, no futuro,
##   os servidores de passagem da Steam/Xbox.
## A conversa com o roteador demora uns segundos: roda numa thread e avisa por `changed`.

signal changed

enum State { CHECKING, OPEN, MANUAL, CGNAT, FAILED }

## Código: base 32 sem letras que confundem (sem I, L, O, U).
const ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
const DEFAULT_PORT := 7777
const DISCOVER_TIMEOUT_MS := 2500
const IP_SERVICE := "https://api.ipify.org"

var state := State.CHECKING
var external_ip := ""
var code := ""
var port := DEFAULT_PORT

var _thread: Thread
var _upnp: UPNP
var _mapped := false


func start(p_port: int) -> void:
	port = p_port
	_thread = Thread.new()
	_thread.start(_open_port)


## Fecha a porta que o UPnP abriu (ao sair do mundo).
func stop() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	if _mapped and _upnp:
		_upnp.delete_port_mapping(port, "UDP")
		_mapped = false


func _exit_tree() -> void:
	stop()


## Texto para a tela (pausa e menu).
func describe() -> String:
	match state:
		State.CHECKING:
			return "Abrindo o mundo para a internet..."
		State.OPEN:
			return "Aberto pela internet (o roteador abriu a porta sozinho). Código do mundo: %s" % code
		State.MANUAL:
			return "O roteador não abriu a porta sozinho (UPnP desligado). Libere a porta %d (UDP) no roteador; aí o código %s funciona." % [port, code]
		State.CGNAT:
			return "Seu provedor usa CGNAT: amigos de fora não conseguem entrar direto. Use uma VPN de jogo (Radmin VPN, ZeroTier ou Tailscale) e passe o IP dela."
	return "Não deu para abrir pela internet. Na mesma rede funciona normal."


## Thread: acha o roteador, abre a porta e pergunta o IP de fora.
func _open_port() -> void:
	var upnp := UPNP.new()
	var result := upnp.discover(DISCOVER_TIMEOUT_MS, 2, "InternetGatewayDevice")
	var gateway := upnp.get_gateway() if result == UPNP.UPNP_RESULT_SUCCESS else null
	if gateway and gateway.is_valid_gateway():
		var mapped := upnp.add_port_mapping(port, port, "Corrumpted", "UDP", 0) == UPNP.UPNP_RESULT_SUCCESS
		var address := upnp.query_external_address()
		_finish.call_deferred(upnp, mapped, address)
	else:
		_finish.call_deferred(null, false, "")


func _finish(upnp: UPNP, mapped: bool, address: String) -> void:
	_upnp = upnp
	_mapped = mapped
	if not address.is_empty():
		_apply_address(address, State.OPEN if mapped else State.MANUAL)
		return
	# Sem UPnP: pergunta o IP de fora para um serviço público (só para montar o código).
	var request := HTTPRequest.new()
	request.timeout = 6.0
	add_child(request)
	request.request_completed.connect(func(result: int, response: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		request.queue_free()
		var text := body.get_string_from_utf8().strip_edges()
		if result == HTTPRequest.RESULT_SUCCESS and response == 200 and text.count(".") == 3:
			_apply_address(text, State.MANUAL)
		else:
			state = State.FAILED
			changed.emit())
	if request.request(IP_SERVICE) != OK:
		request.queue_free()
		state = State.FAILED
		changed.emit()


func _apply_address(address: String, new_state: State) -> void:
	external_ip = address
	# IP "de fora" que na verdade é de rede interna: há outro NAT na frente (CGNAT do provedor
	# ou dois roteadores em cascata).
	state = State.CGNAT if is_private(address) else new_state
	code = encode(address, port) if state != State.CGNAT else ""
	changed.emit()


## IPv4 de rede interna ou de CGNAT (100.64.0.0/10).
static func is_private(address: String) -> bool:
	var parts := address.split(".")
	if parts.size() != 4:
		return false
	var a := int(parts[0])
	var b := int(parts[1])
	return a == 10 or a == 127 or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168) \
			or (a == 100 and b >= 64 and b <= 127) or (a == 169 and b == 254)


## Código do mundo: o IPv4 (e a porta, se não for a padrão) em base 32, em grupos.
## Porta padrão: 7 letras ("K7Q2-9XM"); outra porta: 10 ("K7Q29-XMB3H").
static func encode(address: String, p_port := DEFAULT_PORT) -> String:
	var parts := address.split(".")
	if parts.size() != 4:
		return ""
	var value := 0
	for part in parts:
		value = (value << 8) | (int(part) & 0xFF)
	var length := 7
	if p_port != DEFAULT_PORT:
		value = (value << 16) | (p_port & 0xFFFF)
		length = 10
	var text := ""
	for i in length:
		text = ALPHABET[value & 31] + text
		value >>= 5
	var split := 4 if length == 7 else 5
	return text.substr(0, split) + "-" + text.substr(split)


## Volta o código para [IP, porta], ou [] se não for um código válido.
static func decode(text: String) -> Array:
	var clean := text.strip_edges().to_upper().replace("-", "").replace(" ", "")
	clean = clean.replace("O", "0").replace("I", "1").replace("L", "1")
	if clean.length() != 7 and clean.length() != 10:
		return []
	var value := 0
	for c in clean:
		var digit := ALPHABET.find(c)
		if digit == -1:
			return []
		value = (value << 5) | digit
	var p_port := DEFAULT_PORT
	if clean.length() == 10:
		p_port = value & 0xFFFF
		value >>= 16
	if value >> 32 != 0:
		return []
	var address := "%d.%d.%d.%d" % [(value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF]
	return [address, p_port]


## O que o jogador digitou para entrar: código do mundo, "IP", "IP:porta" -> [IP, porta] ou [].
static func parse_address(text: String) -> Array:
	var clean := text.strip_edges()
	if clean.is_empty():
		return []
	if clean.count(".") == 3:
		var pieces := clean.split(":")
		var p_port := int(pieces[1]) if pieces.size() == 2 and pieces[1].is_valid_int() else DEFAULT_PORT
		return [pieces[0], p_port] if pieces[0].is_valid_ip_address() else []
	if clean.is_valid_ip_address():
		return [clean, DEFAULT_PORT]  # IPv6
	return decode(clean)
