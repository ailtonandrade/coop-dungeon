extends SceneTree
## Teste de rede (convidado com mapa adulterado): tem que ser recusado com a mensagem do mapa.

const TIMEOUT := 20.0

var _failed := false
var _step := 0
var _t0 := 0.0


func _initialize() -> void:
	_t0 = _now()


func _process(_delta: float) -> bool:
	var net := root.get_node("NetService")
	match _step:
		0:
			root.get_node("SaveService").use_test_storage("test_saves_tamper_client")
			# Sem tela de escolha nos testes: entra com o personagem da vaga.
			Engine.set_meta("auto_pick_character", true)
			# Como se os arquivos do mapa tivessem sido mexidos nesta instalação.
			net.map_fingerprint = "mapa-adulterado"
			net.join("127.0.0.1", int(OS.get_environment("NET_PORT")))
			_step = 1
		1:
			if net.last_message.contains("mapa"):
				_check(true, "recusado: \"%s\"" % net.last_message)
				_check(get_nodes_in_group("players").is_empty(), "não entrou no mundo do host")
				print("CLIENTE ADULTERADO: ", "FALHOU" if _failed else "OK")
				quit(1 if _failed else 0)
	if _now() - _t0 > TIMEOUT:
		_check(false, "não foi recusado (passo %d, mensagem: %s)" % [_step, net.last_message])
		print("CLIENTE ADULTERADO: FALHOU")
		quit(1)
	return false


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _check(ok: bool, what: String) -> void:
	print(("  cliente ok   " if ok else "  cliente FAIL ") + what)
	_failed = _failed or not ok
