extends SceneTree
## Conversa com NPC no controle: cada controle mexe só na conversa do seu jogador (sem o foco
## global do Godot); ◀ ▶ em ordem, ▲ ▼ para a linha de cima/baixo, A escolhe, B tchau.
## Rodar: godot --headless --fixed-fps 60 --path coop-dungeon -s tests/dialogue_pad_test.gd
## Sem tipos do jogo aqui: o script de teste compila antes dos serviços globais existirem.

var _frames := 0
var _failed := false
var _talk: Node
var _steps := [
	[JOY_BUTTON_DPAD_RIGHT, "Helena", "◀ ▶ anda em ordem"],
	[JOY_BUTTON_DPAD_RIGHT, "Nome", "de novo"],
	[JOY_BUTTON_DPAD_DOWN, "A vila", "▼ vai para o botão mais perto na linha de baixo"],
	[JOY_BUTTON_DPAD_DOWN, "Ver mercadorias", "▼ chega nos botões de serviço"],
	[JOY_BUTTON_DPAD_UP, "A vila", "▲ volta para a linha de cima"],
	[JOY_BUTTON_DPAD_LEFT, "Água", "◀ dentro da linha"],
]


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		root.get_node("SaveService").use_test_storage("test_saves_dialogue_pad")
		Engine.set_meta("auto_pick_character", true)
		root.get_node("NetService").world = {"id": "teste_pad", "name": "x", "facts": {"diario_helena": true}}
		change_scene_to_file("res://world/world.tscn")
	elif _frames == 40:
		_pad(JOY_BUTTON_X, true)
	elif _frames == 42:
		_pad(JOY_BUTTON_X, false)
		_check(root.get_node("InputService").device_of(0) == 0, "P1 está no controle")
		for npc in get_nodes_in_group("npcs"):
			if npc.npc_name == "Dona Alda":
				get_nodes_in_group("players")[0].teleport_to(npc.global_position + Vector3(0, 0, 1.5))
	elif _frames == 60:
		var hud := get_first_node_in_group("hud")
		hud._try_open_service(0)
		_talk = hud._services[0]
	elif _frames == 64:
		_check(not _talk._typing.visible and _talk.selected().text == "Coisas da Helena", "abre com o 1º assunto marcado e sem campo de digitar")
		_check(root.gui_get_focus_owner() == null or not _talk.is_ancestor_of(root.gui_get_focus_owner()), "não usa o foco global (outro controle não mexe aqui)")
	elif _frames >= 70 and _frames < 70 + _steps.size() * 8:
		var i := (_frames - 70) / 8
		var phase := (_frames - 70) % 8
		if phase == 0:
			_pad(_steps[i][0], true)
		elif phase == 2:
			_pad(_steps[i][0], false)
		elif phase == 4:
			_check(_talk.selected().text == _steps[i][1], "%s (%s)" % [_steps[i][2], _talk.selected().text])
	elif _frames == 130:
		_pad(JOY_BUTTON_A, true)
	elif _frames == 132:
		_pad(JOY_BUTTON_A, false)
	elif _frames == 136:
		_check("\n".join(_talk.history()).contains("gosto de moeda"), "A escolhe o assunto marcado (Água)")
		_pad(JOY_BUTTON_B, true)
	elif _frames == 138:
		_pad(JOY_BUTTON_B, false)
	elif _frames == 142:
		_check(not get_first_node_in_group("hud")._services.has(0), "B dá tchau e fecha")
		print("CONVERSA NO CONTROLE: " + ("FALHOU" if _failed else "OK"))
		quit(1 if _failed else 0)
	return false


func _pad(button: int, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = down
	Input.parse_input_event(event)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	_failed = _failed or not ok
