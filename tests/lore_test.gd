extends SceneTree
## História escondida (Lore) e conversa estilo Tibia, jogadas como um jogador faria.
## Caderno da Helena -> Dona Alda puxa assunto e destrava a caixa da Helena -> Zé Gato reconhece
## o código -> no Lab 4 (longe, no Lixão Alto) o portão de serviço abre digitando a chave no
## teclado -> terminal do Rafael revela o D3M1URGO -> sala do servidor abre pela invasão (senha) ->
## Seu Gouveia reage. Na vila, o lugar antigo do laboratório é entulho com o ofício de transferência.
## Palavra secreta do Zé Gato dá um item (uma vez). Nada avisa na tela.
## Rodar: godot --headless --fixed-fps 60 --path coop-dungeon -s tests/lore_test.gd
## Sem tipos do jogo aqui: o script de teste compila antes dos serviços globais existirem.

const SECOND := 60

var _frames := 0
var _failed := false
var _lore: Node
var _gate: Node
var _box: Node
var _chat_before := 0
## Portão do Lab 4 no mundo (bloco 2,2 do Lixão Alto).
const LAB_DOOR := Vector3(128 + 24, 0, 128 + 48)


func _process(_delta: float) -> bool:
	_frames += 1
	match _frames:
		1:
			root.get_node("SaveService").use_test_storage("test_saves_lore")
			Engine.set_meta("auto_pick_character", true)
			root.get_node("NetService").world = {"id": "teste_lore", "name": "Teste"}
			change_scene_to_file("res://world/world.tscn")
		10:
			root.get_node("InputService")._try_join(-1)
		SECOND:
			_lore = root.get_node("Lore")
			_box = current_scene.find_child("CaixaDaHelena", true, false)
			_check(current_scene.find_child("CadernoHelena", true, false) != null and _box != null,
					"a história da vila está no mapa (caderno, ofício no entulho, caixa)")
			_check(current_scene.find_child("PortaoRafael", true, false) == null, "o portão não fica mais no meio da vila")
			# Só o fato automático da região onde nasceu (visitou_vila).
			var discovered: Array = _lore.facts().keys().filter(func(f: String) -> bool: return not f.begins_with("visitou_"))
			_check(discovered.is_empty() and _box.is_locked(), "mundo novo: nada descoberto, caixa trancada")
			_check(_lore.knows("visitou_vila"), "entrar numa região grava o fato visitou_<região>")
			# Para o teste não depender de sobreviver aos androides do laboratório.
			_player().health.max_hp = 99999.0
			_player().health.hp = 99999.0
			_chat_before = root.get_node("Chat").history.size()
			# Conversa com a Dona Alda antes de tudo: cumprimento com personalidade, sem Helena.
			_talk("Dona Alda")
		SECOND + 10:
			var talk: Node = _hud()._services.get(0)
			_check(talk != null and talk.has_method("choose"), "LB / F abre a conversa (não a loja)")
			_check(_said(talk).contains("ferrugem não espera"), "ela cumprimenta com a cara dela")
			_check(not _labels(talk).has("Helena") and _labels(talk).has("Água"), "assuntos de agora (Helena ainda não aparece)")
			talk.say("Quero comprar")
		SECOND + 12:
			var shop: Node = _hud()._services.get(0)
			_check(shop != null and shop.has_method("_refresh") and not shop.has_method("choose"), "pedir loja abre as mercadorias")
			shop.close_requested.emit()
		SECOND + 16:
			var talk: Node = _hud()._services.get(0)
			_check(talk != null and talk.has_method("choose") and talk.visible, "fechar a loja volta para a conversa")
			talk.say("e a água?")
			_check(_said(talk).contains("gosto de moeda"), "palavra digitada (com acento e pontuação) acha o assunto")
			talk.say("xablau")
			_check(_said(talk).contains("surda de tanto martelo"), "palavra que ela não conhece: resposta dela")
			talk.say("tchau")
		SECOND + 20:
			_check(not _hud()._services.has(0), "tchau fecha a conversa")
			# Vai até o caderno e lê.
			_player().teleport_to(_pos("CadernoHelena") + Vector3(0, 0, 1.2))
		SECOND + 40:
			_hud()._try_open_service(0)
		SECOND + 45:
			_check(_lore.knows("diario_helena"), "ler o caderno grava o que o grupo descobriu")
			_check(root.get_node("Chat").history.size() == _chat_before, "sem aviso nenhum na tela (nem no chat)")
			_hud()._close_service(0)
			_player().teleport_to(_npc("Dona Alda").global_position + Vector3(0, 0, 1.5))
		SECOND + 65:
			var bubbles := _npc("Dona Alda").find_children("*", "Label3D", false, false).filter(func(l: Label3D) -> bool: return l.text.contains("caderno vermelho"))
			_check(bubbles.size() == 1, "Dona Alda puxa assunto quando o grupo chega perto")
			_talk("Dona Alda")
		SECOND + 70:
			var talk: Node = _hud()._services.get(0)
			_check(_said(talk).contains("leu coisa que não devia"), "o cumprimento muda com o que o grupo sabe")
			_check(_labels(talk).has("Helena") and _labels(talk).has("Coisas da Helena"), "assuntos novos apareceram")
			_check(not _labels(talk).has("Davi"), "palavra secreta não vira botão")
			talk.say("davi")
			_check(_said(talk).contains("menino do prédio"), "mas responde se digitar")
			_choose(talk, "Coisas da Helena")
		SECOND + 75:
			_check(not _box.is_locked(), "falar das coisas da Helena destrava a caixa dela (gatilho)")
			_hud()._close_service(0)
			_player().teleport_to(_box.global_position + Vector3(0, 0, 1.3))
		SECOND + 95:
			_check(_box.open_by(_player()), "a caixa abre")
			_talk("Zé Gato")
		SECOND + 100:
			var talk: Node = _hud()._services.get(0)
			_choose(talk, "O código do caderno")
			_check(_lore.knows("codigo_ze") and not _lore.knows("lab4_portao"), "Zé Gato reconhece o código (o portão continua trancado até digitar)")
			_check(not _labels(talk).has("O código do caderno") and _labels(talk).has("Rafael"), "o assunto já falado some e vem o próximo")
			var before: int = _count("power_ring")
			talk.say("e o gato?")
			talk.say("gato")
			_check(_count("power_ring") == before + 1, "palavra secreta dá o item, uma vez só")
			_check(_lore.has_item(_player(), "power_ring") and not _lore.has_item(_player(), "life_amulet"), "confere item na mochila (para assunto que exige item)")
			_hud()._close_service(0)
			# Viagem até o Lab 4, no Lixão Alto (bloco 2,2: longe da vila).
			get_first_node_in_group("world_streamer").load_now(LAB_DOOR)
			_player().teleport_to(LAB_DOOR + Vector3(-1.4, 0, 1.6))
		SECOND + 130:
			_gate = current_scene.find_child("PortaoLab4", true, false)
			_check(_gate != null and not _gate.open and _gate.lock == "codigo", "o laboratório fica longe e o portão de serviço tem teclado")
			_check(_gate.global_position.distance_to(Vector3(30, 0, 30)) > 120.0, "bem longe do centro da vila (%.0f m)" % _gate.global_position.distance_to(Vector3(30, 0, 30)))
			_hud()._try_open_service(0)
			var lock: Node = _hud()._services.get(0)
			_check(lock != null and lock.has_method("submit_code"), "LB / F perto do painel abre o teclado")
			lock._typed.text = "1234"
			_check(not lock.submit_code(), "chave errada não abre")
			lock._typed.text = "70 r alfa 9"
			_check(lock.submit_code(), "a chave do caderno abre (sem ligar para espaço e tracinho)")
		SECOND + 140:
			_check(_gate.open and _lore.knows("lab4_portao"), "portão abriu e o grupo fica sabendo")
			_hud()._close_service(0)
			_player().teleport_to(_pos("TerminalRafael") + Vector3(0, 0, 1.2))
		SECOND + 160:
			_hud()._try_open_service(0)
		SECOND + 165:
			_check(_lore.knows("sabe_nome_demiurgo"), "o terminal revela o nome D3M1URGO")
			_hud()._close_service(0)
			var server: Node = current_scene.find_child("PortaoServidor", true, false)
			_player().teleport_to(server.terminal_position() + Vector3(0, 0, 0.3))
		SECOND + 175:
			_hud()._try_open_service(0)
			var hack: Node = _hud()._services.get(0)
			_check(hack != null and hack.has_method("try_word") and hack._words.size() >= 8, "a sala do servidor pede invasão (lista de senhas)")
			var wrong := ""
			for word: String in hack._words:
				if word != hack._secret:
					wrong = word
					break
			_check(not hack.try_word(wrong) and hack._attempts == 3, "senha errada gasta tentativa")
			_check(hack._log.text.contains("SEMELHANÇA %d/6" % hack.likeness(wrong, hack._secret)), "e mostra a semelhança")
			_check(hack.try_word(hack._secret), "a senha certa libera")
		SECOND + 185:
			_check(current_scene.find_child("PortaoServidor", true, false).open, "a grade do servidor abre")
			_hud()._close_service(0)
			_talk("Seu Gouveia")
		SECOND + 190:
			var talk: Node = _hud()._services.get(0)
			_check(_said(talk).contains("terminal do Rafael"), "Seu Gouveia cumprimenta já sabendo")
			_choose(talk, "D-3-M")
			_check(_said(talk).contains("D-3-M"), "e conta dos depósitos de energia")
			_hud()._close_service(0)
			_check(root.get_node("NetService").world.get("facts", {}).has("sabe_nome_demiurgo"), "as descobertas ficam no mundo")
			# Conhecimento: fatos com ficha (título e onde) e origem gravada; internos ficam de fora.
			var known: Array = _lore.known_facts()
			_check(known.has("diario_helena") and known.has("codigo_ze") and not known.has("visitou_vila"), "a tela de conhecimento lista os fatos, sem os internos (%s)" % [known])
			_check(_lore.fact_title("codigo_ze").contains("70-R-ALFA-9"), "título vem da ficha do fato")
			_check(String(root.get_node("NetService").world.facts.get("codigo_ze")) == "conversa|Zé Gato", "grava de onde veio (conversa com o Zé Gato)")
			_check(String(root.get_node("NetService").world.facts.get("diario_helena")).begins_with("documento|"), "e de documento lido")
			_check(_lore.source_text("missao|Ferro de gangue").contains("Ferro de gangue"), "origem de missão em texto")
			var player: Node = _player()
			_hud()._toggle_inventory(player.slot)
			for i in 3:
				_hud()._switch_panel(player.slot)
			var panel: Node = _hud()._inventories.get(player.slot)
			_check(panel != null and panel.get_script().resource_path.ends_with("knowledge_panel.gd"), "a roda do inventário chega no Conhecimento")
			_check(panel != null and panel._list.get_child_count() == known.size(), "uma linha por fato")
			_hud()._close_inventory(player.slot)
			print("HISTÓRIA: " + ("FALHOU" if _failed else "OK"))
			quit(1 if _failed else 0)
	return false


func _talk(npc_name: String) -> void:
	_player().teleport_to(_npc(npc_name).global_position + Vector3(0, 0, 1.5))
	_hud()._try_open_service(0)


func _choose(talk: Node, label: String) -> void:
	for topic in _lore.topics_for(talk.npc.npc_name, talk.player):
		if topic.button_text() == label:
			talk.choose(topic)
			return
	_check(false, "assunto \"%s\" disponível" % label)


func _labels(talk: Node) -> Array:
	return _lore.topics_for(talk.npc.npc_name, talk.player).map(func(t: Resource) -> String: return t.button_text())


func _said(talk: Node) -> String:
	return "\n".join(talk.history())


func _count(item_id: String) -> int:
	return _player().inventory.all_items().filter(func(entry: Array) -> bool: return entry[1].id == item_id).size()


func _npc(npc_name: String) -> Node3D:
	for npc in get_nodes_in_group("npcs"):
		if npc.npc_name == npc_name:
			return npc
	return null


func _pos(node_name: String) -> Vector3:
	return current_scene.find_child(node_name, true, false).global_position


func _hud() -> Node:
	return get_first_node_in_group("hud")


func _player() -> Node3D:
	for p in get_nodes_in_group("players"):
		if p.slot == 0:
			return p
	return null


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	_failed = _failed or not ok
