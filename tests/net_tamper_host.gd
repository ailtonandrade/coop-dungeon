extends SceneTree
## Teste de rede (host): um convidado com mapa adulterado tenta entrar e tem que ser recusado,
## sem chegar a ter herói no mundo. Rodar com tests/run_net_test.sh.

const TIMEOUT := 25.0

var _failed := false
var _step := 0
var _t0 := 0.0
var _connected := false


func _initialize() -> void:
	_t0 = _now()


func _process(_delta: float) -> bool:
	var net := root.get_node("NetService")
	match _step:
		0:
			root.get_node("SaveService").use_test_storage("test_saves_tamper_host")
			net.port = int(OS.get_environment("NET_PORT"))
			net.multiplayer.peer_connected.connect(func(_id: int) -> void: _connected = true)
			net.play_world(root.get_node("SaveService").new_world("Mundo Original", 1, "private"))
			_step = 1
		1:
			if _connected:
				_t0 = _now()
				_step = 2
		2:
			if _now() - _t0 > 3.0:
				_check(get_nodes_in_group("players").size() == 1, "convidado com mapa adulterado não ganhou herói no mundo")
				_check(net.multiplayer.get_peers().is_empty(), "host derrubou a conexão dele")
				print("HOST ADULTERADO: ", "FALHOU" if _failed else "OK")
				quit(1 if _failed else 0)
	if _now() - _t0 > TIMEOUT:
		_check(false, "tempo esgotado no passo %d" % _step)
		print("HOST ADULTERADO: FALHOU")
		quit(1)
	return false


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _check(ok: bool, what: String) -> void:
	print(("  host ok   " if ok else "  host FAIL ") + what)
	_failed = _failed or not ok
