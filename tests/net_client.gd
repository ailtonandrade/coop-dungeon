extends SceneTree
## Teste de rede, lado cliente: acha o mundo pela busca na rede local, entra, segura D
## (andar) e confere o que chega do host.

const TIMEOUT := 30.0

var _failed := false
var _step := 0
var _t0 := 0.0
var _discovery: Node
var _me: Node3D
var _my_x := 0.0


func _initialize() -> void:
	_t0 = _now()


func _process(_delta: float) -> bool:
	var net := root.get_node("NetService")
	match _step:
		0:
			_discovery = load("res://net/lan_discovery.gd").new()
			root.add_child(_discovery)
			_check(_discovery.start_listening() == OK, "escutando a busca de mundos")
			_step = 1
		1:
			for info: Dictionary in _discovery.worlds.values():
				if info.name == "Mundo Teste":
					_check(true, "achou \"Mundo Teste\" na busca (%s:%d, %d/%d)" % [info.address, info.port, info.players, info.max])
					_check(net.join(info.address, int(info.port)) == OK, "conectando")
					_discovery.queue_free()
					_step = 2
		2:
			_me = _my_player()
			if _me and _me.get("_net_synced"):
				_check(true, "fase carregou e meu jogador chegou do host (P%d)" % (_me.index + 1))
				_check(get_nodes_in_group("players").size() == 2, "vejo os 2 jogadores da sala")
				_my_x = _me.global_position.x
				_key(KEY_D, true)
				_t0 = _now()
				_step = 3
		3:
			if _now() - _t0 > 3.0:
				_key(KEY_D, false)
				var moved := _me.global_position.x - _my_x
				_check(moved > 2.0, "meu jogador andou na minha tela, vindo do host (%.1f m)" % moved)
				_step = 4
		4:
			var enemies := get_nodes_in_group("enemies")
			if not enemies.is_empty():
				_check(true, "inimigos do host apareceram aqui (%d)" % enemies.size())
				var spawner := get_first_node_in_group("wave_spawner")
				_check(spawner.wave >= 1, "número da onda chegou (onda %d)" % spawner.wave)
				_finish()
	if _now() - _t0 > TIMEOUT:
		_check(false, "tempo esgotado no passo %d" % _step)
		_finish()
	return false


func _my_player() -> Node3D:
	for p in get_nodes_in_group("players"):
		if p.is_local():
			return p
	return null


func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)


func _finish() -> void:
	print("CLIENTE: ", "FALHOU" if _failed else "OK")
	quit(1 if _failed else 0)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _check(ok: bool, what: String) -> void:
	print(("  cliente ok   " if ok else "  cliente FAIL ") + what)
	_failed = _failed or not ok
