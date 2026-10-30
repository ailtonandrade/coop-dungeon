extends SceneTree
## Teste do mundo aberto (sem tela): carregamento de blocos, criaturas por região (casa,
## perseguição e limite), telhado que some, entrada e saída de masmorra e pausa bloqueando ataque.
## Rodar: godot --headless --fixed-fps 60 --path coop-dungeon -s tests/world_test.gd
## Sem tipos do jogo aqui: o script de teste compila antes dos serviços globais existirem.

const SECOND := 60
const CAVE_DOOR := Vector3(160, 0, 93.2)
const CAVE_EXIT := Vector3(4024, 0, 44)

var _frames := 0
var _failed := false
var _creature: Node3D
var _guests: Array[int] = []
## Segura a linha do tempo até a condição valer (carregamento em segundo plano não tem hora certa).
var _wait_until := Callable()
var _wait_left := 0


func _process(_delta: float) -> bool:
	if _wait_until.is_valid():
		_wait_left -= 1
		if not _wait_until.call() and _wait_left > 0:
			return false
		_wait_until = Callable()
	_frames += 1
	match _frames:
		1:
			root.get_node("SaveService").use_test_storage("test_saves_world")
			# Sem tela de escolha nos testes: entra com o personagem da vaga.
			Engine.set_meta("auto_pick_character", true)
			change_scene_to_file("res://world/world.tscn")
		10:
			root.get_node("InputService")._try_join(0)
		SECOND - 1:
			_wait(func() -> bool: return _streamer().loaded_keys().size() == 9)
		SECOND:
			var streamer := _streamer()
			_check(streamer != null, "mundo carregou com o WorldStreamer")
			var keys: Array = streamer.loaded_keys()
			_check(keys.size() == 9, "9 blocos carregados em volta da vila (%d)" % keys.size())
			for p in _players():
				_check(p.is_on_floor(), "P%d no chão da vila" % (p.index + 1))
			_check(streamer.region_at(_player(0).global_position).id == "vila", "região do ponto de partida é a vila")
			_check(get_nodes_in_group("npcs").size() == 4, "4 NPCs de serviço na vila (%d)" % get_nodes_in_group("npcs").size())
			_check(not get_nodes_in_group("enemies").is_empty(), "criaturas nasceram nos blocos vizinhos (%d)" % get_nodes_in_group("enemies").size())
			_check(_no_enemy_in_town(), "nenhuma criatura nasceu dentro da vila")
		SECOND + 1:
			# Dentro da casa do banco: o telhado dela some, o das outras não.
			_teleport_group(Vector3(14, 0, 15.5))
		SECOND + 30:
			_check(_house("House_14_14").target == 1.0, "dentro da casa: telhado some")
			var house := current_scene.find_child("House_14_14", true, false)
			var front: Node = house.get_node("FrontWalls")
			_check(front.target > 0.3 and front.target < 1.0, "dentro da casa: paredes da frente ficam translúcidas (%.2f), porta à vista" % front.target)
			_check(house.get_node("WallBack").is_visible_in_tree(), "dentro da casa: parede do fundo continua")
			_check(_house("House_50_50").target == 0.0, "telhado das outras casas continua")
			_teleport_group(Vector3(32, 0, 38))
		SECOND + 60:
			_check(_house("House_14_14").target == 0.0, "saiu da casa: telhado volta")
			# Caindo em cima da casa: o telhado segura (não se entra pelo telhado).
			_teleport_group(Vector3(14, 6, 15.5))
		SECOND + 85:
			var p0 := _player(0)
			_check(p0.global_position.y > 3.5 and p0.is_on_floor(), "em cima da casa: fica no telhado (y %.2f)" % p0.global_position.y)
			# Câmera estilo GTA (só com um na tela) dentro da casa: nada some nem fica translúcido.
			var input := root.get_node("InputService")
			for slot in range(1, 4):
				if input.is_active(slot):
					_guests.append(input.device_of(slot))
					input.leave(slot)
			root.get_node("Settings").camera_mode = "behind"
			_teleport_group(Vector3(14, 0, 15.5))
		SECOND + 110:
			_check(get_first_node_in_group("shared_camera").is_behind(), "câmera GTA com um jogador só")
			var house := current_scene.find_child("House_14_14", true, false)
			_check(_house("House_14_14").target == 0.0, "câmera GTA dentro da casa: telhado não some")
			_check(house.get_node("FrontWalls").target == 0.0, "câmera GTA dentro da casa: paredes sem transparência")
			root.get_node("Settings").camera_mode = "iso"
			for device: int in _guests:
				root.get_node("InputService")._try_join(device)
			# Atravessa o mapa: blocos em volta do novo lugar carregam, os longe descarregam.
			_teleport_group(Vector3(160, 0, 160))
		3 * SECOND - 1:
			_wait(func() -> bool:
				var loaded: Array = _streamer().loaded_keys()
				return loaded.has("1,1") and loaded.has("2,1") and loaded.has("1,2"))
		3 * SECOND:
			var keys: Array = _streamer().loaded_keys()
			_check(keys.has("2,2") and keys.has("1,1") and keys.has("2,1"), "blocos em volta do novo lugar carregaram")
			_check(not keys.has("-1,-1"), "bloco longe (-1,-1) descarregou")
			for p in _players():
				_check(p.is_on_floor(), "P%d no chão depois de atravessar o mapa" % (p.index + 1))
			var stray := get_nodes_in_group("enemies").filter(func(e: Node) -> bool:
				return not keys.has(_key_of(e.home)))
			_check(stray.is_empty(), "criaturas dos blocos descarregados sumiram (%d sobrando)" % stray.size())
			# Criatura deste bloco: o grupo chega perto da casa dela.
			for e in get_nodes_in_group("enemies"):
				if _key_of(e.home) == "2,2":
					_creature = e
					break
			_check(_creature != null, "achou uma criatura no bloco (2,2)")
			if _creature:
				_teleport_group(_creature.home + Vector3(3, 0, 0))
		4 * SECOND:
			if _creature:
				_check(_creature._target != null, "criatura percebeu o grupo perto da casa dela")
				# Longe da casa dela (além do limite): ela tem que desistir e voltar.
				_teleport_group(_creature.home + Vector3(0, 0, -30) if _creature.home.z > 140 else _creature.home + Vector3(0, 0, 30))
		7 * SECOND:
			if is_instance_valid(_creature) and _creature.is_targetable():
				_check(_creature._target == null, "criatura desistiu do grupo longe da casa")
				var back: float = Vector3(_creature.global_position.x, 0, _creature.global_position.z).distance_to(Vector3(_creature.home.x, 0, _creature.home.z))
				_check(back < 6.0, "criatura voltou para perto da casa (%.1f m)" % back)
			# Masmorra: o grupo da mesma tela entra junto ficando na porta.
			_teleport_group(CAVE_DOOR)
		9 * SECOND:
			for p in _players():
				_check(p.global_position.x > 3900, "P%d entrou na masmorra" % (p.index + 1))
				_check(p.is_on_floor(), "P%d no chão da masmorra" % (p.index + 1))
			_check(_streamer().is_loaded("i:caverna_velha"), "masmorra carregada")
			_check(_streamer().region_at(_player(0).global_position).id == "caverna", "região da masmorra")
			_player(0).teleport_to(CAVE_EXIT)
		11 * SECOND:
			for p in _players():
				_check(p.global_position.x < 1000 and p.is_on_floor(), "P%d saiu da masmorra para o mapa" % (p.index + 1))
			# Pausa aberta: teclado e mouse não atacam.
			current_scene.get_node("HUD")._toggle_pause()
			_key(KEY_J, true)
			_mouse(MOUSE_BUTTON_LEFT, true)
		11 * SECOND + 3:
			_key(KEY_J, false)
			_mouse(MOUSE_BUTTON_LEFT, false)
			_check(_player(0).state != 2, "com a pausa aberta, J e o mouse não atacam")
			current_scene.get_node("HUD")._toggle_pause()
		11 * SECOND + 6:
			_key(KEY_J, true)
		11 * SECOND + 9:
			_key(KEY_J, false)
			_check(_player(0).state == 2, "pausa fechada: J volta a atacar")
		13 * SECOND:
			# Borda do mapa (posta pelo jogo, não pelos blocos): empurrar para fora não passa.
			_teleport_group(Vector3(-62, 0, 32))
		13 * SECOND + 30:
			_axis(JOY_AXIS_LEFT_X, -1.0)
			_axis(JOY_AXIS_LEFT_Y, -1.0)
		15 * SECOND:
			_axis(JOY_AXIS_LEFT_X, 0.0)
			_axis(JOY_AXIS_LEFT_Y, 0.0)
			var p2 := _player(1)
			_check(p2.global_position.x > -64.3 and p2.is_on_floor(), "borda do mapa segura o jogador (x = %.1f)" % p2.global_position.x)
			print("MUNDO: ", "FALHOU" if _failed else "OK")
			quit(1 if _failed else 0)
	return false


func _wait(condition: Callable, max_seconds := 10) -> void:
	_wait_until = condition
	_wait_left = max_seconds * SECOND


func _streamer() -> Node:
	return get_first_node_in_group("world_streamer")


func _players() -> Array:
	return get_nodes_in_group("players")


func _player(index: int) -> Node3D:
	for p in _players():
		if p.index == index:
			return p
	return null


func _teleport_group(at: Vector3) -> void:
	_streamer().load_now(at)
	for p in _players():
		p.teleport_to(at + Vector3(1.2 * p.index, 0, 0))


## Telhado da casa (o que some quando alguém entra).
func _house(house_name: String) -> Node:
	return current_scene.find_child(house_name, true, false).get_node("Roof")


func _key_of(position: Vector3) -> String:
	return "%d,%d" % [floori(position.x / 64.0), floori(position.z / 64.0)]


func _no_enemy_in_town() -> bool:
	return get_nodes_in_group("enemies").all(func(e: Node) -> bool: return _key_of(e.home) != "0,0")


func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)


func _axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func _mouse(button: MouseButton, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = down
	Input.parse_input_event(event)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	_failed = _failed or not ok
