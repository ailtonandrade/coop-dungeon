extends SceneTree
## Munição e granada: contadores (save antigo ganha a inicial), tiro gasta e acaba (clique
## seco), escopeta solta vários chumbos, caixa no chão vira munição, compra na Dona Alda, granada
## fere inimigo em volta e o braço fica esticado atirando de costas.
## godot --headless --fixed-fps 60 --path coop-dungeon -s tests/ammo_test.gd

const SECOND := 60

var _frames := 0
var _failed := false
var _spot := Vector3(60, 0, 20)
var _projectiles_before := 0
var _enemy: Node3D
var _enemy_hp := 0.0
var _arm_max := 0.0


func _process(_delta: float) -> bool:
	_frames += 1
	match _frames:
		1:
			var old := Inventory.from_dict({"equipment": {}, "gold": 5})
			_check(old.ammo_of("pregos") == 60 and old.ammo_of("granada") == 2, "save antigo sem munição ganha a inicial")
			var inventory := Inventory.from_dict({"equipment": {}, "ammo": {"9mm": 5}})
			_check(inventory.ammo_of("9mm") == 5 and inventory.ammo_of("pregos") == 0, "munição salva volta igual")
			inventory.add_ammo("granada", 50)
			_check(inventory.ammo_of("granada") == 10, "granada tem limite (10)")
			_check(inventory.use_ammo("9mm") and inventory.ammo_of("9mm") == 4, "tiro gasta uma")
			root.get_node("SaveService").use_test_storage("test_saves_ammo")
			Engine.set_meta("auto_pick_character", true)
			root.get_node("Settings").camera_mode = "iso"
			root.get_node("NetService").world = {"id": "teste_ammo", "name": "Teste"}
			change_scene_to_file("res://world/world.tscn")
		10:
			root.get_node("InputService")._try_join(-1)
		SECOND:
			_watch_projectiles()
			var p := _player()
			p.teleport_to(_spot)
			p.inventory.equipment["ranged"] = ItemDB.make("pistola_9mm")
			p.inventory.ammo = {"9mm": 3, "granada": 1}
			p.inventory.touch()
			_projectiles_before = _count("projectile")
			_key(KEY_K, true)
		SECOND * 3:
			_key(KEY_K, false)
			var p := _player()
			_check(_count("projectile") - _projectiles_before >= 3 or p.inventory.ammo_of("9mm") == 0, "atirou as 3 balas")
			_check(p.inventory.ammo_of("9mm") == 0, "e a munição acabou (%d)" % p.inventory.ammo_of("9mm"))
			# Escopeta: um tiro, sete chumbos, um cartucho.
			p.inventory.equipment["ranged"] = ItemDB.make("escopeta")
			p.inventory.ammo["escopeta"] = 2
			p.inventory.touch()
			p._arrow_cooldown = 0.0
			_projectiles_before = _count("projectile")
			p._shoot_arrow()
			_check(_count("projectile") - _projectiles_before == 7, "escopeta solta 7 chumbos (%d)" % (_count("projectile") - _projectiles_before))
			_check(p.inventory.ammo_of("escopeta") == 1, "gastando um cartucho só")
			# Caixa de munição no chão: pega e vira contador.
			load("res://items/loot.gd").drop(p, ItemDB.make_ammo("municao_9mm", 12), p.global_position + Vector3(0.6, 0, 0))
		SECOND * 3 + 20:
			_key(KEY_F, true)
		SECOND * 3 + 24:
			_key(KEY_F, false)
		SECOND * 4:
			var p := _player()
			_check(p.inventory.ammo_of("9mm") == 12, "pegou a caixa do chão (+12 de 9mm, tem %d)" % p.inventory.ammo_of("9mm"))
			# Compra na Dona Alda.
			p.teleport_to(Vector3(25, 0, 31.6))
		SECOND * 4 + 30:
			var p := _player()
			var alda: Node = null
			for npc: Node in get_nodes_in_group("npcs"):
				if npc.npc_name == "Dona Alda":
					alda = npc
			var index: int = alda.stock().find("municao_rifle") if alda else -1
			p.inventory.add_gold(100)
			var gold: int = p.inventory.gold
			var result: Array = load("res://world/services.gd").run(p, "buy", [index])
			_check(index != -1 and result[0] and p.inventory.ammo_of("rifle") == 12, "comprou munição de rifle na Dona Alda (%s)" % result[1])
			_check(gold - p.inventory.gold == 30, "pagou o preço da caixa (30)")
			# Granada: inimigo parado a 6 m na frente.
			p.teleport_to(_spot)
		SECOND * 5:
			var p := _player()
			var forward: Vector3 = p._facing
			_enemy = get_first_node_in_group("net_replicator").spawn("enemy", {"kind": 0, "pos": p.global_position + forward * 5.5, "aggro": 0.1, "leash": 0.1, "power": 1})
		SECOND * 5 + 10:
			_enemy_hp = _enemy.health.hp
			_key(KEY_Q, true)
		SECOND * 5 + 14:
			_key(KEY_Q, false)
		SECOND * 8:
			var p := _player()
			_check(p.inventory.ammo_of("granada") == 0, "jogou a granada")
			_check(not is_instance_valid(_enemy) or _enemy.health.hp < _enemy_hp, "explosão feriu o inimigo")
			# Correndo de costas atirando: braço esticado.
			p.inventory.equipment["ranged"] = ItemDB.make("bow")
			p.inventory.ammo["pregos"] = 50
			p.inventory.touch()
			_key(KEY_K, true)
	# Correndo de costas (só dá mirando com o mouse/analógico; aqui força a animação): com o tiro
	# apertado, o braço da arma sobe por cima da corrida.
	if _frames == SECOND * 8 + 20:
		var p := _player()
		p.set_physics_process(false)
		p._animator.play("move_back")
	if _frames > SECOND * 8 + 30 and _frames < SECOND * 10:
		var p := _player()
		if p._aim_arm_node:
			_arm_max = maxf(_arm_max, p._aim_arm_node.influence)
	if _frames == SECOND * 10:
		_key(KEY_K, false)
		_check(_arm_max > 0.9, "correndo de costas atirando o braço fica esticado (%.2f, anim %s)" % [_arm_max, _player()._animator.current])
		print("MUNIÇÃO: " + ("FALHOU" if _failed else "OK"))
		quit(1 if _failed else 0)
	return false


func _count(_prefix: String) -> int:
	return _seen_projectiles


var _seen_projectiles := 0


func _watch_projectiles() -> void:
	var replicator: Node = get_first_node_in_group("net_replicator")
	(replicator.fx_root as Node).child_entered_tree.connect(func(node: Node) -> void:
		if String(node.name).begins_with("projectile"):
			_seen_projectiles += 1)


func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)


func _player() -> Node:
	return get_nodes_in_group("players")[0]


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FALHOU ") + what)
	if not ok:
		_failed = true
