extends SceneTree
## Portas (madeira, metal, casebre, tampa de esgoto): abrir com LB / F, tranca por fatos e por
## código, animação, fato ao abrir para o grupo e porta como gatilho de missão.
## Rodar: godot --headless --fixed-fps 60 --path coop-dungeon -s tests/door_test.gd

const SECOND := 60

var _frames := 0
var _failed := false
var _doors := {}


func _process(_delta: float) -> bool:
	_frames += 1
	match _frames:
		1:
			root.get_node("SaveService").use_test_storage("test_saves_door")
			Engine.set_meta("auto_pick_character", true)
			root.get_node("NetService").world = {"id": "teste_door", "name": "Teste"}
			change_scene_to_file("res://world/world.tscn")
		10:
			root.get_node("InputService")._try_join(-1)
		SECOND:
			var chunk: Node3D = get_first_node_in_group("world_streamer").chunk_at(_player().global_position)[0]
			var base: Vector3 = _player().global_position + Vector3(0, 0, 6)
			var specs := [["PortaMadeira", "porta_madeira", "livre"], ["PortaMetal", "porta_metal", "fatos"],
					["PortaCasebre", "porta_casebre", "codigo"], ["TampaEsgoto", "tampa_de_esgoto", "livre"]]
			for i in specs.size():
				var door: Node3D = (load("res://world/prefabs/portas/%s.tscn" % specs[i][1]) as PackedScene).instantiate()
				door.name = specs[i][0]
				door.lock = specs[i][2]
				if specs[i][0] == "PortaMetal":
					door.requires.assign(["chave_metal"])
				if specs[i][0] == "PortaCasebre":
					door.code = "42"
					door.teaches.assign(["entrou_casebre"])
				chunk.add_child(door)
				door.global_position = base + Vector3(i * 4.0, 0, 0)
				_doors[specs[i][0]] = door
			# Missão: abrir a porta de madeira.
			var obj: Resource = load("res://world/quests/quest_objective.gd").new()
			obj.kind = "interagir"
			obj.target = "PortaMadeira"
			var quest: Resource = load("res://world/quests/quest_def.gd").new()
			quest.id = "teste_porta"
			quest.title = "Abrir a porta"
			quest.start = "gatilho"
			quest.start_target = "nada"
			quest.objectives.assign([obj])
			root.get_node("Quests").defs()["teste_porta"] = quest
			root.get_node("Quests")._accept("teste_porta")
			_go("PortaMadeira")
		SECOND + 10:
			var door: Node3D = _doors.PortaMadeira
			_check(not door.open and door._label.visible and door._label.text.contains("Abrir"), "de perto: aviso \"Abrir\"")
			_hud()._try_open_service(0)
		SECOND + 60:
			var door: Node3D = _doors.PortaMadeira
			_check(door.open and root.get_node("Lore").knows("abriu_porta_madeira"), "porta livre abre com LB / F e o grupo ganha o fato")
			_check(not is_equal_approx(door._leaf.rotation.y, 0.0) and door._collision.disabled, "animou (girou) e deixa passar")
			_check(root.get_node("Quests").state_of("teste_porta") == "entregue", "abrir a porta conta para a missão (interagir)")
			_go("PortaMetal")
		SECOND + 70:
			_hud()._try_open_service(0)
			_check(not _doors.PortaMetal.open, "porta trancada por fato não abre")
			root.get_node("Lore").learn(["chave_metal"])
			_hud()._try_open_service(0)
		SECOND + 120:
			var metal: Node3D = _doors.PortaMetal
			_check(metal.open and absf(metal._leaf.position.x - metal._closed_xform.origin.x) > 0.9, "sabendo o fato, abre (deslizou para o lado)")
			_go("PortaCasebre")
		SECOND + 130:
			_hud()._try_open_service(0)
			var lock: Node = _hud()._services.get(0)
			_check(lock != null and lock.has_method("submit_code"), "porta com código abre o teclado")
			lock._typed.text = "41"
			_check(not lock.submit_code(), "código errado não abre")
			lock._typed.text = "42"
			_check(lock.submit_code(), "código certo")
		SECOND + 190:
			_check(_doors.PortaCasebre.open and root.get_node("Lore").knows("entrou_casebre"), "casebre abriu e ensinou o fato a mais")
			_hud()._close_service(0)
			_go("TampaEsgoto")
		SECOND + 200:
			_hud()._try_open_service(0)
		SECOND + 250:
			var lid: Node3D = _doors.TampaEsgoto
			_check(lid.open and lid._leaf.position.x > 0.9, "tampa de esgoto desliza")
			print("PORTAS: " + ("FALHOU" if _failed else "OK"))
			quit(1 if _failed else 0)
	return false


func _go(door_name: String) -> void:
	_player().teleport_to(_doors[door_name].global_position + Vector3(0, 0, 1.2))


func _hud() -> Node:
	return get_first_node_in_group("hud")


func _player() -> Node:
	return get_nodes_in_group("players")[0]


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FALHOU ") + what)
	if not ok:
		_failed = true
