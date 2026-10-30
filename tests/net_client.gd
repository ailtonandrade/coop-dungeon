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
			root.get_node("SaveService").use_test_storage("test_saves_client")
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
				_check(true, "criaturas do host apareceram aqui (%d)" % enemies.size())
				var keys: Array = get_first_node_in_group("world_streamer").loaded_keys()
				_check(keys.size() == 9, "carreguei os 9 blocos em volta do meu jogador (%d)" % keys.size())
				_t0 = _now()
				_step = 5
		5:
			if not get_nodes_in_group("loot").is_empty():
				_check(true, "elmo que o host largou apareceu no chão aqui")
				_key(KEY_F, true)
				_step = 6
		6:
			_key(KEY_F, false)
			var path := _find_in_bag("iron_helmet")
			if not path.is_empty():
				_check(true, "elmo chegou na minha cópia do inventário")
				_me.request_inventory("equip", [path])
				_step = 7
		7:
			var head: Variant = _me.inventory.equipment.get("head")
			if head and head.id == "iron_helmet":
				_check(true, "equipei pelo inventário e o host confirmou")
				_check(not root.get_node("SaveService").load_player(0).is_empty(), "meu inventário ficou salvo aqui no cliente")
				_step = 10
		10:
			# O host me dá moedas e me leva até o comerciante: compro a 1ª coisa do estoque.
			if int(_me.inventory.gold) == 500 and _me.global_position.distance_to(Vector3(25, 0, 31.6)) < 1.0:
				_me.request_inventory("buy", [0])
				_step = 11
		11:
			if int(_me.inventory.gold) < 500:
				_check(true, "comprei do comerciante pela rede (sobrou %d moedas)" % _me.inventory.gold)
				_t0 = _now()
				_step = 8
		8:
			# O host leva meu jogador para longe: carrego só em volta dele e solto a vila.
			if _me.global_position.x > 140.0:
				_t0 = _now()
				_step = 9
		9:
			if _now() - _t0 > 1.5:
				var keys: Array = get_first_node_in_group("world_streamer").loaded_keys()
				_check(keys.has("2,2") and not keys.has("-1,-1"), "carreguei a área nova e soltei a vila (%d blocos)" % keys.size())
				var near := get_nodes_in_group("enemies").filter(func(e: Node) -> bool:
					return e.global_position.distance_to(_me.global_position) < 40.0 and e.get("_net_synced"))
				_check(not near.is_empty(), "recebo o estado das criaturas perto de mim lá (%d)" % near.size())
				_finish()
	if _now() - _t0 > TIMEOUT:
		_check(false, "tempo esgotado no passo %d" % _step)
		_finish()
	return false


func _find_in_bag(id: String) -> Array:
	var bag: Variant = _me.inventory.equipment.get("bag")
	if bag:
		for i in bag.contents.size():
			if bag.contents[i] and bag.contents[i].id == id:
				return ["bag", i]
	return []


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
