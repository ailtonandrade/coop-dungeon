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


func _initialize() -> void:
	change_scene_to_file("res://levels/level_01.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	var input := root.get_node("InputService")
	match _frames:
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
		3 * SECOND:
			var enemies := get_nodes_in_group("enemies")
			_check(enemies.size() == 3, "onda 1 com 3 inimigos (achou %d)" % enemies.size())
			# Põe um inimigo colado no P1 e manda golpear.
			var p1 := _player(0)
			_enemy = enemies[0]
			_enemy.global_position = p1.global_position + p1.global_basis.z * -1.2
			_enemy_hp = _enemy.health.hp
			p1._start_attack(0, Vector3.ZERO)
		3 * SECOND + 30:
			_check(_enemy.health.hp < _enemy_hp, "golpe do P1 tirou vida do inimigo (%.0f -> %.0f)" % [_enemy_hp, _enemy.health.hp])
		12 * SECOND:
			var hurt := get_nodes_in_group("players").filter(func(p: Node) -> bool: return p.health.hp < p.health.max_hp)
			_check(not hurt.is_empty(), "inimigos chegaram e bateram nos jogadores parados")
			var save := root.get_node("SaveService")
			_check(save.save_player(0, {"level": 3}), "save_player escreveu")
			_check(save.load_player(0).get("level") == 3, "load_player leu o que foi salvo")
			print("SMOKE TEST: ", "FALHOU" if _failed else "OK")
			quit(1 if _failed else 0)
	return false


func _player(slot: int) -> Node3D:
	for p in get_nodes_in_group("players"):
		if p.slot == slot:
			return p
	return null


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	_failed = _failed or not ok
