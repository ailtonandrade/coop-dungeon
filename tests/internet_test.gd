extends SceneTree
## Teste do acesso pela internet: código do mundo (ida e volta, letras que confundem),
## endereço digitado (código, IP, IP:porta), reconhecer CGNAT/rede interna, e o host abrindo
## um mundo sem roteador com UPnP (o caso deste teste) sem travar nem quebrar.
## Rodar: godot --headless --path coop-dungeon -s tests/internet_test.gd

var _failed := false
var _frames := 0
var _waited := 0.0


func _process(delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_unit_checks()
		root.get_node("SaveService").use_test_storage("test_saves_internet")
		var net := root.get_node("NetService")
		net.port = 7790
		var world: Dictionary = root.get_node("SaveService").new_world("Mundo internet", 1, "private")
		_check(net.play_world(world) == OK, "host abriu o mundo")
		_check(net.internet != null, "começou a abrir para a internet")
		return false
	var net := root.get_node("NetService")
	_waited += delta
	if net.internet and net.internet.state != 0 or _waited > 15.0:
		_check(net.internet != null and net.internet.state != 0, "terminou de tentar sem travar o jogo (estado %s)" % (net.internet.state if net.internet else -1))
		_check(not net.internet.describe().is_empty(), "explica para o jogador: %s" % net.internet.describe())
		net.leave_session()
		print("INTERNET: ", "FALHOU" if _failed else "OK")
		quit(1 if _failed else 0)
	return false


func _unit_checks() -> void:
	var access: Script = load("res://net/internet_access.gd")
	var code: String = access.encode("187.45.200.13")
	_check(code.length() == 8 and code[4] == "-", "código com porta padrão tem 7 letras (%s)" % code)
	_check(access.decode(code) == ["187.45.200.13", 7777], "código volta para o IP")
	var other: String = access.encode("201.17.3.250", 7790)
	_check(access.decode(other) == ["201.17.3.250", 7790], "com outra porta: %s" % other)
	_check(access.decode(code.to_lower().replace("-", "")) == ["187.45.200.13", 7777], "aceita minúsculas e sem traço")
	_check(access.decode("ABCD-EF") == [] or access.decode("ABCD-EF").size() == 2, "código curto inválido não quebra")
	_check(access.decode("XXXX-XXU") == [], "letra que não existe no código é recusada")
	_check(access.parse_address("192.168.0.10") == ["192.168.0.10", 7777], "IP sem porta")
	_check(access.parse_address("192.168.0.10:7800") == ["192.168.0.10", 7800], "IP com porta")
	_check(access.parse_address(code) == ["187.45.200.13", 7777], "código no campo de entrar")
	_check(access.parse_address("999.1.1.1") == [], "IP inválido recusado")
	_check(access.is_private("100.72.1.9") and access.is_private("192.168.1.1") and access.is_private("10.0.0.2"), "reconhece CGNAT e rede interna")
	_check(not access.is_private("187.45.200.13"), "IP público não é privado")


func _check(ok: bool, text: String) -> void:
	print("  ", "ok  " if ok else "FALHOU", " ", text)
	if not ok:
		_failed = true
