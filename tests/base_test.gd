extends SceneTree
## Base do jogador: terminal só longe da cidade e com nível, peças cobram material e respeitam
## nível/área/sobreposição, desmontar devolve metade, baú abre o cofre, cama é onde volta, zona
## segura protege e criatura não entra, save do mundo guarda tudo (JSON), modo de construção e
## mapa completo abrem.
## godot --headless --fixed-fps 60 --path coop-dungeon -s tests/base_test.gd

const SECOND := 60

var _frames := 0
var _failed := false
var _spot := Vector3.INF
var _enemy: Node3D


func _process(_delta: float) -> bool:
	_frames += 1
	match _frames:
		1:
			root.get_node("SaveService").use_test_storage("test_saves_base")
			Engine.set_meta("auto_pick_character", true)
			root.get_node("Settings").camera_mode = "iso"
			root.get_node("NetService").world = {"id": "teste_base", "name": "Teste"}
			change_scene_to_file("res://world/world.tscn")
		10:
			root.get_node("InputService")._try_join(-1)
		SECOND:
			var p := _player()
			var manager: Node = get_first_node_in_group("base_manager")
			_check(manager != null, "o mundo tem o gerenciador de abrigos")
			p.progress.level = 2
			p.inventory.ammo = {"metal": 60, "madeira": 60, "fibra": 30}
			var village := Vector3(25, 0, 30)
			p.teleport_to(village)
			p.apply_inventory_command("base_terminal", [village])
			_check(_base().is_empty(), "nível 2 não instala terminal")
			p.progress.level = 3
			p.apply_inventory_command("base_terminal", [village])
			_check(_base().is_empty(), "no meio da vila não pode (%s)" % _manager_class().terminal_problem(self, village, "x"))
			# Procura um pátio aberto longe da cidade.
			var streamer: Node = get_first_node_in_group("world_streamer")
			for x in range(-56, 190, 12):
				for z in range(-56, 190, 12):
					var candidate := Vector3(x, 0, z)
					if (_manager_class().terminal_problem(self, candidate, "x") as String).is_empty():
						streamer.load_now(candidate)
						if (_manager_class().terminal_problem(self, candidate, "x") as String).is_empty():
							_spot = candidate
							break
				if _spot != Vector3.INF:
					break
			_check(_spot != Vector3.INF, "achou um pátio aberto longe da cidade (%s)" % _spot)
		SECOND + 20:
			var p := _player()
			p.teleport_to(_spot)
		SECOND * 2:
			var p := _player()
			var ground: Vector3 = p.global_position
			p.apply_inventory_command("base_terminal", [ground])
			_check(not _base().is_empty(), "instalou o terminal de base")
			_check(p.inventory.ammo_of("metal") == 50 and p.inventory.ammo_of("fibra") == 26, "pagou o terminal (10 metal, 4 fibra)")
			var center: Vector3 = _manager_class().center_of(_base())
			var g := 3.0
			p.apply_inventory_command("base_build", ["piso", "madeira", center + Vector3(g, 0, 0), 0.0])
			_check(_pieces().size() == 1 and p.inventory.ammo_of("madeira") == 56, "piso de madeira (-4 madeira)")
			p.apply_inventory_command("base_build", ["piso", "metal", center + Vector3(g, 0, 0), 0.0])
			_check(_pieces().size() == 1, "dois pisos no mesmo lugar não")
			p.apply_inventory_command("base_build", ["parede", "metal", center + Vector3(g, 0, g / 2.0), 0.0])
			p.apply_inventory_command("base_build", ["porta", "fibra", center + Vector3(g, 0, -g / 2.0), 0.0])
			_check(_pieces().size() == 3, "parede de metal e porta de fibra")
			p.apply_inventory_command("base_build", ["teto", "metal", center + Vector3(g, 0, 0), 0.0])
			_check(_pieces().size() == 3, "teto antes do nível 5 não")
			p.progress.level = 7
			p.apply_inventory_command("base_build", ["teto", "metal", center + Vector3(g, 0, 0), 0.0])
			p.apply_inventory_command("base_build", ["cama", "", center + Vector3(-g, 0, 0), 0.0])
			p.apply_inventory_command("base_build", ["bau", "", center + Vector3(-g, 0, g), 0.0])
			p.apply_inventory_command("base_build", ["luminaria", "", center + Vector3(0, 0, -g), 0.0])
			_check(_pieces().size() == 7, "teto, cama, baú e luminária no nível 7 (%d peças)" % _pieces().size())
			p.apply_inventory_command("base_build", ["parede", "madeira", center + Vector3(40, 0, 0), 0.0])
			_check(_pieces().size() == 7, "fora da área do abrigo não")
			var metal_before: int = p.inventory.ammo_of("metal")
			p.apply_inventory_command("base_remove", [center + Vector3(g, 0, g / 2.0)])
			_check(_pieces().size() == 6 and p.inventory.ammo_of("metal") == metal_before + 2, "desmontar a parede devolve metade (+2 metal)")
		SECOND * 2 + 20:
			var p := _player()
			var center: Vector3 = _manager_class().center_of(_base())
			_check(get_first_node_in_group("base_manager").find_children("Peca_*", "", true, false).size() == 6, "as peças aparecem no mundo")
			# Baú = cofre do banco.
			p.teleport_to(center + Vector3(-3, 0, 2.0))
		SECOND * 3:
			var p := _player()
			var center: Vector3 = _manager_class().center_of(_base())
			p.inventory.add_item(ItemDB.make("dagger"))
			var path: Array = []
			for entry: Array in p.inventory.all_items(["bag"]):
				if entry[1].id == "dagger":
					path = entry[0]
			var result: Array = load("res://world/services.gd").run(p, "deposit", [path])
			_check(result[0], "baú do abrigo guarda no cofre (%s)" % result[1])
			# Cama: onde volta quando o grupo cai.
			var bed: Vector3 = _manager_class().bed_of(_manager_class().key_of(p))
			_check(bed != Vector3.INF, "a cama marca onde o dono volta")
			# Zona segura.
			_check(not p.is_targetable(), "dentro do abrigo as criaturas não miram o herói")
			var hp: float = p.health.hp
			p.take_hit(30.0)
			_check(p.health.hp == hp, "dentro do abrigo nada fere")
			_enemy = get_first_node_in_group("net_replicator").spawn("enemy", {"kind": 0, "pos": center + Vector3(2, 0, 2), "power": 1})
			# Save do mundo: JSON (posições como lista).
			var json := JSON.stringify(root.get_node("NetService").world.get("bases", {}))
			var back: Variant = JSON.parse_string(json)
			_check(back is Dictionary and (back as Dictionary).size() == 1 and _manager_class().center_of(back.values()[0]).distance_to(center) < 0.05, "abrigo vai e volta pelo save (JSON)")
		SECOND * 4:
			var center: Vector3 = _manager_class().center_of(_base())
			var flat := Vector2(_enemy.global_position.x - center.x, _enemy.global_position.z - center.z).length()
			_check(flat >= 15.0, "criatura não fica dentro da área segura (%.1f m do centro)" % flat)
			# Modo de construção e mapa abrem.
			var hud: Node = get_first_node_in_group("hud")
			hud.toggle_base_build(_player().slot)
		SECOND * 4 + 20:
			var hud: Node = get_first_node_in_group("hud")
			_check(hud.is_base_building(_player().slot), "modo de construção abriu")
			var mode: Node = hud._builds[_player().slot]
			_check(mode.current_recipe() == "piso" or mode.recipes().has("piso"), "com as receitas do nível (%s)" % [mode.recipes()])
			_check(mode._ghost != null, "fantasma da peça à frente")
			hud.toggle_base_build(_player().slot)
			_key(KEY_M, true)
		SECOND * 4 + 24:
			_key(KEY_M, false)
		SECOND * 4 + 40:
			var hud: Node = get_first_node_in_group("hud")
			_check(hud._world_map != null and is_instance_valid(hud._world_map), "M abre o mapa completo")
			_check(not hud.is_base_building(_player().slot), "e a construção fechou")
			print("ABRIGO: " + ("FALHOU" if _failed else "OK"))
			quit(1 if _failed else 0)
	return false


func _manager_class() -> GDScript:
	return load("res://world/base/base_manager.gd")


func _base() -> Dictionary:
	return _manager_class().base_of(_manager_class().key_of(_player()))


func _pieces() -> Array:
	return _base().get("pieces", [])


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
