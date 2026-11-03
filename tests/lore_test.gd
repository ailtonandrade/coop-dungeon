extends SceneTree
## História escondida (Lore): o 1º elo na vila, jogado como um jogador faria.
## Caderno da Helena -> Dona Alda puxa assunto -> Zé Gato reconhece o código -> portão do
## Rafael abre -> terminal revela o D3M1URGO -> Seu Gouveia reage. Nada avisa na tela.
## Rodar: godot --headless --fixed-fps 60 --path coop-dungeon -s tests/lore_test.gd
## Sem tipos do jogo aqui: o script de teste compila antes dos serviços globais existirem.

const SECOND := 60

var _frames := 0
var _failed := false
var _lore: Node
var _gate: Node
var _chat_before := 0


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
			_gate = current_scene.find_child("PortaoRafael", true, false)
			_check(current_scene.find_child("CadernoHelena", true, false) != null and _gate != null, "a história da vila está no mapa (caderno e portão)")
			_check(_lore.facts().is_empty(), "mundo novo: o grupo não sabe nada")
			_check(_line("Dona Alda").begins_with("Peça boa"), "Dona Alda fala o de sempre")
			_check(_gate.get_node_or_null(".") and not _gate.open, "portão do Rafael trancado")
			_chat_before = root.get_node("Chat").history.size()
			# Vai até o caderno e aperta F.
			_player().teleport_to(_pos("CadernoHelena") + Vector3(0, 0, 1.2))
		SECOND + 20:
			_press_pickup()
		SECOND + 30:
			var reader: Node = _hud()._services.get(0)
			_check(reader != null and reader.get_class() == "PanelContainer" and reader.has_method("open_for") and not reader.has_method("_refresh"), "F perto do caderno abre a leitura")
			_check(_lore.knows("diario_helena"), "ler grava o que o grupo descobriu")
			_check(root.get_node("Chat").history.size() == _chat_before, "sem aviso nenhum na tela (nem no chat)")
			_check(_line("Dona Alda").contains("Helena comprava peça"), "Dona Alda agora fala da Helena")
			_check(_line("Brando").contains("filtro de água"), "Brando também lembra dela")
			_hud()._close_service(0)
			# Chega perto da Dona Alda: ela puxa assunto sozinha.
			_player().teleport_to(_npc("Dona Alda").global_position + Vector3(0, 0, 1.5))
		SECOND + 50:
			var bubbles := _npc("Dona Alda").find_children("*", "Label3D", false, false).filter(func(l: Label3D) -> bool: return l.text.contains("caderno vermelho"))
			_check(bubbles.size() == 1, "Dona Alda puxa assunto quando o grupo chega perto")
			_check(not _gate.open, "o portão ainda não abre (falta o código)")
			# Fala com o Zé Gato: ele reconhece o código do caderno.
			_player().teleport_to(_npc("Zé Gato").global_position + Vector3(0, 0, 1.5))
		SECOND + 70:
			_press_pickup()
		SECOND + 80:
			_check(_lore.knows("codigo_ze"), "Zé Gato reconheceu o código (o grupo sabe)")
			_check(_gate.open, "portão do Rafael abriu")
			_hud()._close_service(0)
			_player().teleport_to(_pos("TerminalRafael") + Vector3(0, 0, 1.2))
		SECOND + 100:
			_check(_player().global_position.distance_to(_pos("TerminalRafael")) < 2.0, "dá para entrar no barraco do Rafael")
			_press_pickup()
		SECOND + 110:
			_check(_lore.knows("sabe_nome_demiurgo"), "o terminal revela o nome D3M1URGO")
			_check(_line("Seu Gouveia").contains("D-3-M"), "Seu Gouveia reage ao nome")
			_check(_line("Zé Gato").contains("D3M1URGO"), "Zé Gato também")
			_hud()._close_service(0)
			# O que o grupo descobriu fica no save do mundo.
			var saved: Dictionary = root.get_node("SaveService").load_world("teste_lore") if root.get_node("SaveService").has_method("load_world") else root.get_node("NetService").world
			_check(saved.get("facts", {}).has("sabe_nome_demiurgo"), "as descobertas ficam salvas no mundo")
			print("HISTÓRIA: " + ("FALHOU" if _failed else "OK"))
			quit(1 if _failed else 0)
	return false


func _line(npc: String) -> String:
	var line: Resource = _lore.line_for(npc)
	return line.text if line else ""


func _npc(npc_name: String) -> Node3D:
	for npc in get_nodes_in_group("npcs"):
		if npc.npc_name == npc_name:
			return npc
	return null


func _pos(node_name: String) -> Vector3:
	return current_scene.find_child(node_name, true, false).global_position


func _hud() -> Node:
	return get_first_node_in_group("hud")


func _press_pickup() -> void:
	_hud()._try_open_service(0)


func _player() -> Node3D:
	for p in get_nodes_in_group("players"):
		if p.slot == 0:
			return p
	return null


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	_failed = _failed or not ok
