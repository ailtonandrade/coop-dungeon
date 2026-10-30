extends SceneTree
## Teste de rede (host com senha): convidado sem senha e com senha errada são recusados; com a
## senha certa entra e ganha herói. A senha não viaja para o convidado. Rodar com
## tests/run_net_test.sh.

const TIMEOUT := 40.0

var _failed := false
var _step := 0
var _t0 := 0.0


func _initialize() -> void:
	_t0 = _now()


func _process(_delta: float) -> bool:
	var net := root.get_node("NetService")
	match _step:
		0:
			root.get_node("SaveService").use_test_storage("test_saves_password_host")
			# Sem tela de escolha nos testes: entra com o personagem da vaga.
			Engine.set_meta("auto_pick_character", true)
			net.port = int(OS.get_environment("NET_PORT"))
			var world: Dictionary = root.get_node("SaveService").new_world("Mundo com senha", 3, "private")
			world["password"] = net.password_hash("ferro123")
			_check(net.play_world(world) == OK and net.has_password(), "host abriu o mundo com senha")
			_step = 1
		1:
			for player in get_nodes_in_group("players"):
				if player.owner_peer != 1:
					_check(true, "convidado com a senha certa entrou e ganhou herói")
					print("HOST SENHA: ", "FALHOU" if _failed else "OK")
					quit(1 if _failed else 0)
	if _now() - _t0 > TIMEOUT:
		_check(false, "tempo esgotado no passo %d" % _step)
		print("HOST SENHA: FALHOU")
		quit(1)
	return false


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _check(ok: bool, what: String) -> void:
	print(("  host ok   " if ok else "  host FAIL ") + what)
	_failed = _failed or not ok
