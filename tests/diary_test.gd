extends SceneTree
## Diário do jogador e missão de inventário: herói novo (e herói antigo, pelo upgrade do kit)
## começa com mochila e diário; ter o diário começa a primeira missão; ler pelo inventário
## (Y / E) abre a leitura com o nome do herói, conclui a missão e ensina o fato; a tela de
## missões mostra a concluída; Item de missão no mapa vai direto para a mochila, some e começa
## a missão de início "item" (objetivo "pegar").
## godot --headless --fixed-fps 60 --path coop-dungeon -s tests/diary_test.gd

const SECOND := 60

var _frames := 0
var _failed := false
var _piece: Node3D


func _process(_delta: float) -> bool:
	_frames += 1
	match _frames:
		1:
			root.get_node("SaveService").use_test_storage("test_saves_diario")
			Engine.set_meta("auto_pick_character", true)
			root.get_node("Settings").camera_mode = "iso"
			root.get_node("NetService").world = {"id": "teste_diario", "name": "Teste"}
			change_scene_to_file("res://world/world.tscn")
		10:
			root.get_node("InputService")._try_join(-1)
		SECOND:
			var p := _player()
			var quests: Node = root.get_node("Quests")
			_check(p.inventory.has_bag() and p.inventory.has_item_id("diario_pessoal"), "herói novo tem mochila e diário")
			_check(quests.state_of("quem_sou_eu") == "ativa", "ter o diário começa a primeira missão (%s)" % quests.state_of("quem_sou_eu"))
			_check(quests.target_of(quests.def("quem_sou_eu"), p.global_position) == null, "sem ponto no mapa (é no inventário)")
			# Herói antigo, sem mochila: ganha mochila e diário.
			var old: RefCounted = load("res://items/inventory.gd").from_dict({"equipment": {}})
			old.upgrade_kit()
			_check(old.has_bag() and old.has_item_id("diario_pessoal") and old.to_dict().kit == 1, "herói antigo ganha mochila e diário (uma vez)")
			# Abre o inventário e lê o diário (Y / E em cima dele).
			_hud()._toggle_inventory(p.slot)
			var panel: Node = _hud()._inventories.get(p.slot)
			var path: Array = []
			for entry: Array in p.inventory.all_items(["bag"]):
				if entry[1].id == "diario_pessoal":
					path = entry[0]
			_check(panel != null and not path.is_empty(), "o diário está na mochila (%s)" % [path])
			panel._section = "bag"
			panel._container_path = path.slice(0, path.size() - 1)
			panel._cursor = path[-1]
			_check(panel._describe().contains("ler"), "o inventário diz que dá para ler")
			panel._quick()
		SECOND + 10:
			var p := _player()
			var quests: Node = root.get_node("Quests")
			var reader: Node = _hud()._services.get(p.slot)
			_check(reader != null and reader.get_script().resource_path.ends_with("lore_reader.gd"), "Y / E no diário abre a leitura")
			if reader:
				var text: String = reader._text.text
				_check(text.contains(String(p.display_name)) and not text.contains("{nome}") and not text.contains("{companhia}"), "o diário fala o nome do herói")
				_check(text.contains("por conta própria"), "jogando só, o diário diz que veio por conta própria")
			_check(not _hud()._inventories.has(p.slot), "o inventário fechou para ler")
			_check(quests.state_of("quem_sou_eu") == "entregue", "ler o diário conclui a missão (%s)" % quests.state_of("quem_sou_eu"))
			_check(root.get_node("Lore").knows("sabe_quem_sou"), "e o grupo sabe quem é")
			_check(p.inventory.has_item_id("diario_pessoal"), "o diário continua na mochila")
			_hud()._close_service(p.slot)
		SECOND + 20:
			var p := _player()
			# Tela de missões na roda do inventário (Inventário -> Chip -> Habilidades -> Conhecimento -> Missões).
			_hud()._toggle_inventory(p.slot)
			for i in 4:
				_hud()._switch_panel(p.slot)
			var panel: Node = _hud()._inventories.get(p.slot)
			_check(panel != null and panel.get_script().resource_path.ends_with("quests_panel.gd"), "a roda chega na tela de missões")
			_check(panel != null and panel._header.text.contains("1 principais"), "conta as principais feitas (%s)" % (panel._header.text if panel else ""))
			_hud()._close_inventory(p.slot)
			# Item de missão no mapa + missão que começa ao pegar o item.
			var quest := QuestDef.new()
			quest.id = "teste_pegar"
			quest.title = "Teste pegar"
			quest.start = "item"
			quest.start_target = "dagger"
			quest.return_to_giver = false
			var objective := QuestObjective.new()
			objective.kind = "pegar"
			objective.target = "dagger"
			var objectives: Array[QuestObjective] = [objective]
			quest.objectives = objectives
			root.get_node("Quests").defs()["teste_pegar"] = quest
			_piece = load("res://world/prefabs/missoes/item_de_missao.tscn").instantiate()
			_piece.container_id = "teste_item_missao"
			var line := ContainerItem.new()
			line.item_id = "dagger"
			var lines: Array[ContainerItem] = [line]
			_piece.contents = lines
			current_scene.add_child(_piece)
			_piece.global_position = p.global_position + Vector3(0.8, 0, 0)
		SECOND + 30:
			var p := _player()
			_check(_piece.visible and _piece._visual != null and _piece._visual.get_child_count() > 0, "o item de missão aparece no chão com o modelo do item")
			p._pick_up()
		SECOND + 40:
			var p := _player()
			var quests: Node = root.get_node("Quests")
			_check(p.inventory.has_item_id("dagger"), "pegar põe o item direto na mochila")
			_check(not _piece.visible, "e o item some do mapa")
			_check(quests.state_of("teste_pegar") == "entregue", "início \"item\" + objetivo \"pegar\" (%s)" % quests.state_of("teste_pegar"))
			print("DIÁRIO: " + ("FALHOU" if _failed else "OK"))
			quit(1 if _failed else 0)
	return false


func _hud() -> Node:
	return get_first_node_in_group("hud")


func _player() -> Node:
	return get_nodes_in_group("players")[0]


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FALHOU ") + what)
	if not ok:
		_failed = true
