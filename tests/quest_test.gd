extends SceneTree
## Missões (questLog): pegar com o NPC na conversa, contar as criaturas da classe certa, aparecer
## no canto da tela, ficar pronta, entregar e receber a recompensa. Missão com fato exigido só
## aparece depois.
## Rodar: godot --headless --fixed-fps 60 --path coop-dungeon -s tests/quest_test.gd

const SECOND := 60

var _frames := 0
var _failed := false
var _quests: Node
var _gold := 0
var _xp := 0
var _area: Node3D
var _trigger: Node3D
var _box_trigger: Node3D
var _door: StaticBody3D

const QUEST_TRIGGER := preload("res://world/quests/quest_trigger.gd")


## Missões montadas no teste (sem arquivo): uma começa na área, pede para falar duas palavras em
## ordem com o Zé Gato e usar um gatilho que some com uma porta; outra começa num gatilho.
func _setup_custom() -> void:
	var def_script: Script = load("res://world/quests/quest_def.gd")
	var obj_script: Script = load("res://world/quests/quest_objective.gd")
	var talk_obj: Resource = obj_script.new()
	talk_obj.kind = "falar"
	talk_obj.npc = "Zé Gato"
	talk_obj.keywords = PackedStringArray(["sinal", "antena"])
	talk_obj.replies = PackedStringArray(["Que sinal? ...Tá, eu ouvi também. Pergunta da antena.", "A antena da torre velha. Ninguém sobe lá faz tempo."])
	var use_obj: Resource = obj_script.new()
	use_obj.kind = "interagir"
	use_obj.target = "gatilho_teste"
	use_obj.reaction = "sumir"
	use_obj.reaction_target = "PortaTeste"
	var quest: Resource = def_script.new()
	quest.id = "teste_area"
	quest.title = "Teste da área"
	quest.start = "area"
	quest.start_target = "area_teste"
	quest.objectives.assign([talk_obj, use_obj])
	quest.reward_gold = 50
	quest.reward_xp = 10
	_quests.defs()["teste_area"] = quest
	var second: Resource = def_script.new()
	second.id = "teste_gatilho"
	second.title = "Teste do gatilho"
	second.start = "gatilho"
	second.start_target = "caixa_inicio"
	second.start_item = "pouch"
	second.objectives.assign([use_obj.duplicate()])
	_quests.defs()["teste_gatilho"] = second
	var chunk: Node3D = get_first_node_in_group("world_streamer").chunk_at(_player().global_position)[0]
	var base: Vector3 = _player().global_position
	_area = load("res://world/quests/quest_area.gd").new()
	_area.name = "area_teste"
	chunk.add_child(_area)
	_area.global_position = base + Vector3(6, 0, 4)
	_trigger = QUEST_TRIGGER.new()
	_trigger.name = "gatilho_teste"
	chunk.add_child(_trigger)
	_trigger.global_position = base + Vector3(-5, 0, 5)
	_box_trigger = QUEST_TRIGGER.new()
	_box_trigger.name = "caixa_inicio"
	_box_trigger.look = "caixa"
	chunk.add_child(_box_trigger)
	_box_trigger.global_position = base + Vector3(-8, 0, -4)
	_door = StaticBody3D.new()
	_door.name = "PortaTeste"
	chunk.add_child(_door)
	_door.global_position = base + Vector3(-5, 0, 8)


func _hud() -> Node:
	return get_first_node_in_group("hud")


func _count(item_id: String) -> int:
	return _player().inventory.all_items().filter(func(e: Array) -> bool: return e[1] is Dictionary and e[1].get("id") == item_id).size()


func _process(_delta: float) -> bool:
	_frames += 1
	match _frames:
		1:
			root.get_node("SaveService").use_test_storage("test_saves_quest")
			Engine.set_meta("auto_pick_character", true)
			root.get_node("NetService").world = {"id": "teste_quest", "name": "Teste"}
			change_scene_to_file("res://world/world.tscn")
		10:
			root.get_node("InputService")._try_join(-1)
		SECOND:
			_quests = root.get_node("Quests")
			_check(_quests.def("brando_ferro_de_gangue") != null, "missão do Brando carregada da pasta world/quests")
			_check(_log() != null and not _log().visible, "questLog vazio (escondido) sem missão")
			_check(_quests.offers("Seu Gouveia").is_empty(), "missão do Seu Gouveia escondida até o grupo entrar no Lab 4")
			_talk("Brando")
		SECOND + 8:
			var talk: Node = _talk_panel()
			var offer := _button(talk, "Trabalho: Ferro de gangue")
			_check(offer != null, "Brando oferece o trabalho na conversa")
			offer.pressed.emit()
		SECOND + 10:
			var talk: Node = _talk_panel()
			_check("\n".join(talk.history()).contains("bandidos de cano"), "ele explica o trabalho")
			var yes := _button(talk, "Aceito")
			_check(yes != null and _button(talk, "Agora não") != null, "dá para aceitar ou recusar")
			yes.pressed.emit()
		SECOND + 14:
			_check(_quests.state_of("brando_ferro_de_gangue") == "ativa", "missão aceita (ativa)")
			_check(_log().visible and _log_text().contains("FERRO DE GANGUE") and _log_text().contains("0/6"), "questLog mostra a missão e o contador")
			var quest: Resource = _quests.def("brando_ferro_de_gangue")
			var target: Variant = _quests.target_of(quest, _player().global_position)
			var spawners: Array = _quests._places_map().spawners.filter(func(sp: Array) -> bool: return (sp[1] as PackedInt32Array).has(0))
			_check(target is Vector3 and spawners.any(func(sp: Array) -> bool: return (sp[0] as Vector3).is_equal_approx(target)),
					"o destino da missão é um acampamento de bandidos de cano (%s)" % str(target))
			_check(_quests._places_map().npcs.has("Brando") and _quests._places_map().npcs.has("Zé Gato"), "o mapa inteiro é lido (NPCs de todos os blocos)")
			# Criatura de outra classe não conta; a certa conta.
			_quests.on_kill("atirador")
			for i in 5:
				_quests.on_kill("punk")
		SECOND + 16:
			_check(_quests.count_of("brando_ferro_de_gangue", 0) == 5 and _log_text().contains("5/6"), "só conta a classe pedida (5/6)")
			_quests.on_kill("punk")
			_quests.on_kill("punk")
		SECOND + 18:
			_check(_quests.state_of("brando_ferro_de_gangue") == "pronta" and _quests.count_of("brando_ferro_de_gangue", 0) == 6, "chegou a 6: pronta (não passa do total)")
			_check(_log_text().contains("Volte para Brando"), "questLog manda voltar para o Brando")
			var back: Variant = _quests.target_of(_quests.def("brando_ferro_de_gangue"), _player().global_position)
			_check(back is Vector3 and (back as Vector3).distance_to(Vector3(50, 0, 48.5)) < 1.0, "pronta: o destino vira o Brando")
			var talk: Node = _talk_panel()
			var turn_in := _button(talk, "Entregar: Ferro de gangue")
			_check(turn_in != null, "na conversa aparece entregar")
			_gold = _player().inventory.gold
			_xp = _player().progress.xp + _player().progress.level * 100000
			turn_in.pressed.emit()
		SECOND + 22:
			_check(_quests.state_of("brando_ferro_de_gangue") == "entregue", "missão entregue")
			_check(_player().inventory.gold == _gold + 150, "recompensa em parafusos (%d -> %d)" % [_gold, _player().inventory.gold])
			_check(_player().progress.xp + _player().progress.level * 100000 > _xp, "e experiência")
			_check(not _log().visible, "some do questLog")
			_check(_button(_talk_panel(), "Trabalho: Ferro de gangue") != null, "repetível: o Brando oferece de novo")
			# Com espera para repetir: some e ele avisa quanto falta; passou o tempo, volta.
			var ferro: Resource = _quests.def("brando_ferro_de_gangue")
			ferro.repeat_cooldown = 5
			_check(_quests.offers("Brando").is_empty() and _quests.waiting("Brando").has(ferro), "com espera, não oferece logo depois de entregar")
			_check(_quests.cooldown_left(ferro) > 240 and _quests.cooldown_left(ferro) <= 300, "faltam ~5 minutos (%d s)" % _quests.cooldown_left(ferro))
			_talk_panel()._refresh_topics()
			_check(root.get_node("NetService").world.get("quests", {}).has("brando_ferro_de_gangue"), "missões ficam no save do mundo")
			_check(_button(_talk_panel(), "volte em 5 min") != null, "na conversa: \"volte em 5 min\"")
			root.get_node("NetService").world.quests["brando_ferro_de_gangue"]["done_at"] = int(Time.get_unix_time_from_system()) - 301
			_check(_quests.offers("Brando").has(ferro) and _quests.cooldown_left(ferro) == 0, "passou a espera: oferece de novo")
			ferro.repeat_cooldown = 0
			root.get_node("Lore").learn(["lab4_portao"])
			_check(_quests.offers("Seu Gouveia").size() == 1, "depois do Lab 4, o Seu Gouveia tem trabalho")
			_hud()._close_service(0)
			_setup_custom()
		SECOND + 26:
			# Entrar na área começa a missão sozinha.
			_player().teleport_to(_area.global_position)
		SECOND + 40:
			_check(_quests.state_of("teste_area") == "ativa", "entrar na área começa a missão (sem NPC)")
			_check(_log_text().contains("TESTE DA ÁREA"), "e ela entra no questLog")
			_talk("Zé Gato")
		SECOND + 46:
			var talk: Node = _talk_panel()
			_check(_button(talk, "Sinal") != null and _button(talk, "Antena") == null, "só a próxima palavra vira botão")
			talk.say("antena")
			_check(_quests.count_of("teste_area", 0) == 0, "palavra fora de ordem não vale")
			talk.say("e o sinal?")
			_check(_quests.count_of("teste_area", 0) == 1 and "\n".join(talk.history()).contains("Que sinal"), "a primeira palavra: ele revela algo")
			talk.say("antena")
			_check(_quests.objective_done(_quests.def("teste_area"), 0) and "\n".join(talk.history()).contains("torre velha"), "a segunda (que dependia da primeira): objetivo cumprido")
			_hud()._close_service(0)
			_gold = _player().inventory.gold
			_player().teleport_to(_trigger.global_position + Vector3(0, 0, 0.8))
		SECOND + 60:
			_check(_door.visible, "porta ainda lá antes do gatilho")
			_hud()._try_open_service(0)
		SECOND + 64:
			_check(not _door.visible and _door.collision_layer == 0, "usar o gatilho: a porta some (reação)")
			_check(_quests.state_of("teste_area") == "entregue" and _player().inventory.gold == _gold + 50, "missão sem NPC conclui na hora, com recompensa")
			_check(root.get_node("NetService").world.get("quest_reactions", {}).get("PortaTeste") == "sumir", "a reação fica no save do mundo")
			_check(QUEST_TRIGGER.nearest(self, _trigger.global_position) == null, "gatilho de uso único não aparece mais")
			# Missão que começa num gatilho e dá um item.
			_player().teleport_to(_box_trigger.global_position + Vector3(0, 0, 0.8))
		SECOND + 78:
			var before := _count("pouch")
			_hud()._try_open_service(0)
			_check(_quests.state_of("teste_gatilho") == "ativa" and _count("pouch") == before + 1, "gatilho começa outra missão e entrega o item inicial")
			print("MISSÕES: " + ("FALHOU" if _failed else "OK"))
			quit(1 if _failed else 0)
	return false


func _talk(npc_name: String) -> void:
	for npc in get_nodes_in_group("npcs"):
		if npc.npc_name == npc_name:
			_player().teleport_to(npc.global_position + Vector3(0, 0, 1.5))
	get_first_node_in_group("hud")._try_open_service(0)


func _talk_panel() -> Node:
	return get_first_node_in_group("hud")._services.get(0)


func _button(talk: Node, text: String) -> Button:
	for child in talk._topics.get_children():
		if child is Button and not child.is_queued_for_deletion() and child.text.contains(text):
			return child
	return null


func _log() -> Node:
	for node in get_first_node_in_group("hud").find_children("*", "VBoxContainer", true, false):
		if node.get_script() == load("res://ui/quest_log.gd"):
			return node
	return null


func _log_text() -> String:
	var text := ""
	for label in _log().find_children("*", "Label", true, false):
		if not label.is_queued_for_deletion():
			text += label.text + "\n"
	return text


func _player() -> Node:
	return get_nodes_in_group("players")[0]


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FALHOU ") + what)
	if not ok:
		_failed = true
