extends SceneTree
## Teste de fumaça sem tela: carrega a fase, faz 2 jogadores entrarem e confere o loop
## principal (nascer, escalada, malha de navegação, ondas, golpe, inimigos atacando, save).
## Rodar: godot --headless --fixed-fps 60 --path coop-dungeon -s tests/smoke_test.gd
## Sem tipos Player/Enemy aqui: o script de teste compila antes dos autoloads existirem.

const SECOND := 60

var _frames := 0
var _failed := false
var _enemy: Node3D
var _enemy_hp := 0.0
var _armor_before := 0.0


func _process(_delta: float) -> bool:
	_frames += 1
	var input := root.get_node("InputService")
	match _frames:
		1:
			root.get_node("SaveService").use_test_storage("test_saves_smoke")
			change_scene_to_file("res://levels/level_01.tscn")
		5:
			input._try_join(input.KEYBOARD)
			input._try_join(0)
		SECOND:
			var players := get_nodes_in_group("players")
			_check(players.size() == 2, "2 jogadores em cena (achou %d)" % players.size())
			for p in players:
				_check(p.is_on_floor(), "P%d no chão (y=%.2f)" % [p.slot + 1, p.global_position.y])
			var nav: NavigationRegion3D = current_scene.find_children("*", "NavigationRegion3D", true, false)[0]
			var polygons := nav.navigation_mesh.get_polygon_count()
			_check(polygons > 0, "malha de navegação gerada (%d polígonos)" % polygons)
		SECOND + 10:
			# Escalada: pulando ao lado do pilar de 2 m, sobe; do chão no contêiner (2,6 m)
			# e na borda da arena, não.
			var p1 := _player(0)
			p1.teleport_to(Vector3(-5.4, 0.8, -7.0))
			p1._facing = Vector3.LEFT
			_check(p1._try_mantle(), "escalada aceita no pilar de 2 m em pleno pulo")
			var p2 := _player(1)
			p2.teleport_to(Vector3(5.2, 0.0, -9.0))
			p2._facing = Vector3.RIGHT
			_check(not p2._try_mantle(), "contêiner alto demais para escalar do chão")
			p2.teleport_to(Vector3(15.4, 0.4, 0.0))
			_check(not p2._try_mantle(), "borda da arena não deixa escalar para fora")
			p2.teleport_to(Vector3(2.0, 0.0, 0.0))
		SECOND + 50:
			var p1 := _player(0)
			_check(absf(p1.global_position.y - 2.0) < 0.1 and p1.state == 0,
					"P1 terminou em cima do pilar (y=%.2f)" % p1.global_position.y)
			p1.teleport_to(Vector3.ZERO)
		SECOND + 60:
			# Loot: cai no chão, o P1 pega com o botão e equipa.
			var p1 := _player(0)
			_armor_before = p1.armor()
			var plate: Dictionary = load("res://items/item_db.gd").make("plate_armor", 3, "rare")
			load("res://items/loot.gd").drop(p1, plate, p1.global_position + Vector3(0.6, 0, 0))
		SECOND + 65:
			var p1 := _player(0)
			_check(get_nodes_in_group("loot").size() == 1, "item caiu no chão e todos veem")
			p1._pick_up()
		SECOND + 70:
			var p1 := _player(0)
			_check(get_nodes_in_group("loot").is_empty(), "P1 pegou o item do chão")
			var path := []
			var bag: Dictionary = p1.inventory.equipment.bag
			for i in bag.contents.size():
				if bag.contents[i] and bag.contents[i].id == "plate_armor":
					path = ["bag", i]
			_check(not path.is_empty(), "peitoral foi para a mochila")
			p1.apply_inventory_command("equip", [path])
			_check(p1.inventory.equipment.chest.id == "plate_armor", "peitoral equipado")
			_check(p1.armor() > _armor_before, "armadura subiu (%.1f -> %.1f)" % [_armor_before, p1.armor()])
			_check(p1._visual.any(func(v: Dictionary) -> bool: return v.id == "plate_armor"), "peitoral aparece no boneco")
			_check(not root.get_node("SaveService").load_player(0).is_empty(), "inventário salvo na conta do P1")
		SECOND + 75:
			# Daqui em diante, tudo pelos botões de verdade (teclado = P1, controle 0 = P2).
			_key(KEY_SPACE, true)
		SECOND + 78:
			_key(KEY_SPACE, false)
			var p1 := _player(0)
			_check(p1._animator.current == "jump" and not p1.is_on_floor(), "Espaço: P1 pulou com a animação de pulo (%s)" % p1._animator.current)
		SECOND + 80:
			# P2 mira para a direita da tela e anda para a esquerda: de costas, olhando para a mira.
			_axis(JOY_AXIS_RIGHT_X, 1.0)
			_axis(JOY_AXIS_LEFT_X, -1.0)
		SECOND + 105:
			var p2 := _player(1)
			var aim := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(45.0))
			_check(p2._facing.dot(aim) > 0.95, "analógico direito: P2 olha para a mira")
			_check(p2._animator.current == "move_back", "andando contra a mira: animação de costas (%s)" % p2._animator.current)
			_axis(JOY_AXIS_RIGHT_X, 0.0)
			_axis(JOY_AXIS_LEFT_X, 0.0)
		SECOND + 110:
			# Limite do sofá: P2 longe do P1 tentando se afastar mais.
			var p1 := _player(0)
			p1.teleport_to(Vector3(0, 0, 0))
			_player(1).teleport_to(Vector3(-12.5, 0, 0).rotated(Vector3.UP, deg_to_rad(45.0)))
			_axis(JOY_AXIS_LEFT_X, -1.0)
		SECOND + 160:
			_axis(JOY_AXIS_LEFT_X, 0.0)
			var gap := _player(0).global_position.distance_to(_player(1).global_position)
			_check(gap < 13.6, "sofá: P2 não passa do limite de distância (%.1f m)" % gap)
			_player(1).teleport_to(Vector3(3, 0, 0))
		3 * SECOND:
			var enemies := get_nodes_in_group("enemies")
			_check(enemies.size() == 3, "onda 1 com 3 inimigos (achou %d)" % enemies.size())
			# Põe um inimigo colado no P1 e manda golpear.
			var p1 := _player(0)
			_enemy = enemies[0]
			_enemy.global_position = p1.global_position + p1.global_basis.z * -1.2
			_enemy_hp = _enemy.health.hp
			_key(KEY_J, true)
		3 * SECOND + 2:
			_key(KEY_J, false)
			_check(_player(0)._animator.current == "slash", "J: P1 ataca com a espadada")
		3 * SECOND + 30:
			_check(_enemy.health.hp < _enemy_hp, "golpe (pelo botão) tirou vida do inimigo (%.0f -> %.0f)" % [_enemy_hp, _enemy.health.hp])
		12 * SECOND:
			var hurt := get_nodes_in_group("players").filter(func(p: Node) -> bool: return p.health.hp < p.health.max_hp)
			_check(not hurt.is_empty(), "inimigos chegaram e bateram nos jogadores parados")
			var save := root.get_node("SaveService")
			_check(save.save_player(0, {"level": 3}), "save_player escreveu")
			_check(save.load_player(0).get("level") == 3, "load_player leu o que foi salvo")
			print("SMOKE TEST: ", "FALHOU" if _failed else "OK")
			quit(1 if _failed else 0)
	return false


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


func _player(slot: int) -> Node3D:
	for p in get_nodes_in_group("players"):
		if p.slot == slot:
			return p
	return null


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	_failed = _failed or not ok
