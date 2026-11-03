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
			_check(root.get_node("NetService").world.get("quests", {}).has("brando_ferro_de_gangue"), "missões ficam no save do mundo")
			root.get_node("Lore").learn(["lab4_portao"])
			_check(_quests.offers("Seu Gouveia").size() == 1, "depois do Lab 4, o Seu Gouveia tem trabalho")
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
