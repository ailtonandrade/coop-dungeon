extends SceneTree
## Teste de rede (convidado num mundo com senha): sem senha -> recusado; senha errada ->
## recusado; senha certa -> entra. Rodar com tests/run_net_test.sh.

const TIMEOUT := 40.0

var _failed := false
var _step := 0
var _t0 := 0.0
var _wait := 0.0


func _initialize() -> void:
	_t0 = _now()


func _process(delta: float) -> bool:
	var net := root.get_node("NetService")
	var port := int(OS.get_environment("NET_PORT"))
	_wait -= delta
	match _step:
		0:
			root.get_node("SaveService").use_test_storage("test_saves_password_client")
			# Sem tela de escolha nos testes: entra com o personagem da vaga.
			Engine.set_meta("auto_pick_character", true)
			net.join("127.0.0.1", port)
			_step = 1
		1:
			if net.last_message.contains("tem senha"):
				_check(true, "sem senha: recusado (%s)" % net.last_message)
				_wait = 1.0
				_step = 2
		2:
			if _wait <= 0.0:
				net.join("127.0.0.1", port, "errada")
				_step = 3
		3:
			if net.last_message.contains("Senha errada"):
				_check(true, "senha errada: recusado")
				_wait = 1.0
				_step = 4
		4:
			if _wait <= 0.0:
				net.join("127.0.0.1", port, "ferro123")
				_step = 5
		5:
			for player in get_nodes_in_group("players"):
				if player.is_local() and player.get("_net_synced"):
					_check(true, "senha certa: entrei no mundo")
					_check(not net.world.has("password"), "a senha do host não veio para cá")
					_step = 6
					_wait = 1.0
		6:
			if _wait <= 0.0:
				print("CLIENTE SENHA: ", "FALHOU" if _failed else "OK")
				quit(1 if _failed else 0)
	if _now() - _t0 > TIMEOUT:
		_check(false, "tempo esgotado no passo %d (mensagem: %s)" % [_step, net.last_message])
		print("CLIENTE SENHA: FALHOU")
		quit(1)
	return false


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _check(ok: bool, what: String) -> void:
	print(("  cliente ok   " if ok else "  cliente FAIL ") + what)
	_failed = _failed or not ok
