extends SceneTree
## Teste de rede, lado host. Rodar com tests/run_net_test.sh (sobe host e cliente juntos).
## Sem tipos Player/Enemy aqui: o script de teste compila antes dos autoloads existirem.

const TIMEOUT := 40.0
const FAR_POINT := Vector3(160, 0, 160)

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
			root.get_node("SaveService").use_test_storage("test_saves_host")
			# Sem tela de escolha nos testes: entra com o personagem da vaga.
			Engine.set_meta("auto_pick_character", true)
			net.port = int(OS.get_environment("NET_PORT"))
			var world: Dictionary = root.get_node("SaveService").new_world("Mundo Teste", 42, "open")
			_check(net.play_world(world) == OK, "host abriu o mundo na porta %d" % net.port)
			_step = 1
		1:
			_remote = _remote_player()
			if _remote:
				_check(true, "jogador do cliente nasceu no host (%s)" % _remote.display_name)
				# Voz: o host "fala" (tom no lugar do microfone) e o convidado tem que ouvir.
				root.get_node("Voice").inject_mic(_tone(0.5))
				_remote_x = _remote.global_position.x
				_t0 = _now()
				_step = 2
		2:
			if _now() - _t0 > 3.0:
				var voice := root.get_node("Voice")
				_check(int(voice.heard.get(_remote.owner_peer, 0)) >= 3, "voz do convidado chegou no host (%d pacotes)" % int(voice.heard.get(_remote.owner_peer, 0)))
				voice.set_muted_for_all(_remote.owner_peer, true)
				var moved := _remote.global_position.x - _remote_x
				_check(moved > 2.0, "comando do cliente moveu o jogador dele no host (%.1f m)" % moved)
				var helmet: Dictionary = load("res://items/item_db.gd").make("iron_helmet", 2, "rare")
				load("res://items/loot.gd").drop(_remote, helmet, _remote.global_position + Vector3(0.5, 0, 0))
				_step = 4
		4:
			var head: Variant = _remote.inventory.equipment.get("head")
			if head and head.id == "iron_helmet":
				_check(true, "cliente pegou o elmo do chão e equipou (visto no host)")
				_check(_remote.armor() > 5.0, "armadura do cliente subiu no host (%.1f)" % _remote.armor())
				# XP: o host dá experiência ao jogador do cliente (sobe para o nível 2).
				_remote.add_xp(70)
				# Comerciante: o cliente ganha moedas e vai até ele para comprar.
				_remote.inventory.add_gold(500)
				_remote.teleport_to(Vector3(25, 0, 31.6))
				_t0 = _now()
				_step = 6
		6:
			if int(_remote.inventory.gold) < 500:
				_check(true, "cliente comprou do comerciante e o host cobrou (%d moedas)" % _remote.inventory.gold)
				# Baú da vila: o jogador do cliente abre (o host decide e avisa o cliente).
				var chest: Node = null
				for container in get_nodes_in_group("containers"):
					if container.container_id == "vila_bau_inicial":
						chest = container
				_remote.teleport_to(Vector3(39, 0, 42.5))
				_check(chest != null and chest.open_by(_remote), "jogador do cliente abriu o baú da vila (no host)")
				# O jogador do cliente vai para a outra ponta do mapa; o do host fica na vila.
				var streamer := get_first_node_in_group("world_streamer")
				streamer.load_now(FAR_POINT)
				_remote.teleport_to(FAR_POINT)
				_t0 = _now()
				_step = 5
		5:
			if _now() - _t0 > 2.0:
				var keys: Array = get_first_node_in_group("world_streamer").loaded_keys()
				_check(keys.has("0,0") and keys.has("2,2"), "host mantém carregadas a vila (dele) e a área longe (do cliente)")
				_step = 3
		3:
			if _remote_player() == null:
				_check(true, "cliente saiu e o jogador dele sumiu")
				_finish()
	if _now() - _t0 > TIMEOUT:
		_check(false, "tempo esgotado no passo %d" % _step)
		_finish()
	return false


## Meio segundo de um tom de voz (no lugar do microfone, que não existe no teste).
func _tone(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	for i in int(seconds * 16000):
		samples.append(sin(TAU * 220.0 * i / 16000.0) * 0.3)
	return samples


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
