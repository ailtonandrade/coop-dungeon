extends SceneTree
## Teste de rede, lado host. Rodar com tests/run_net_test.sh (sobe host e cliente juntos).
## Sem tipos Player/Enemy aqui: o script de teste compila antes dos autoloads existirem.

const TIMEOUT := 40.0

var _failed := false
var _step := 0
var _t0 := 0.0
var _remote: Node3D
var _remote_x := 0.0


func _initialize() -> void:
	_t0 = _now()


func _process(_delta: float) -> bool:
	var net := root.get_node("NetService")
	match _step:
		0:
			net.port = int(OS.get_environment("NET_PORT"))
			var world: Dictionary = root.get_node("SaveService").new_world("Mundo Teste", 42, "open")
			_check(net.play_world(world) == OK, "host abriu o mundo na porta %d" % net.port)
			_step = 1
		1:
			_remote = _remote_player()
			if _remote:
				_check(true, "jogador do cliente nasceu no host (%s)" % _remote.display_name)
				_remote_x = _remote.global_position.x
				_t0 = _now()
				_step = 2
		2:
			if _now() - _t0 > 3.0:
				var moved := _remote.global_position.x - _remote_x
				_check(moved > 2.0, "comando do cliente moveu o jogador dele no host (%.1f m)" % moved)
				_step = 3
		3:
			if _remote_player() == null:
				_check(true, "cliente saiu e o jogador dele sumiu")
				_finish()
	if _now() - _t0 > TIMEOUT:
		_check(false, "tempo esgotado no passo %d" % _step)
		_finish()
	return false


func _remote_player() -> Node3D:
	for p in get_nodes_in_group("players"):
		if p.owner_peer != 1:
			return p
	return null


func _finish() -> void:
	print("HOST: ", "FALHOU" if _failed else "OK")
	quit(1 if _failed else 0)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _check(ok: bool, what: String) -> void:
	print(("  host ok   " if ok else "  host FAIL ") + what)
	_failed = _failed or not ok
