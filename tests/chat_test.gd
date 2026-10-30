extends SceneTree
## Teste do chat do mundo pela HUD: Enter abre para o teclado, digitar não aciona o jogo (o "i"
## não abre o inventário, o herói não anda), Enter manda; no controle, direcional para baixo
## abre as mensagens rápidas e A manda; avisos do sistema e texto limpo.
## Rodar: godot --headless --fixed-fps 60 --path coop-dungeon -s tests/chat_test.gd
## Atenção: cada passo é um quadro; dois passos no mesmo quadro fazem só o primeiro rodar.

const SECOND := 60

var _frames := 0
var _failed := false
var _start := Vector3.ZERO


func _process(_delta: float) -> bool:
	_frames += 1
	var chat := root.get_node("Chat")
	match _frames:
		1:
			root.get_node("SaveService").use_test_storage("test_saves_chat")
			Engine.set_meta("auto_pick_character", true)
			_check(chat.clean_text("  oi\ncom quebra  ") == "oi com quebra", "texto limpo (sem quebra de linha)")
			_check(chat.clean_text("x".repeat(400)).length() == chat.MAX_LENGTH, "mensagem cortada no tamanho máximo")
			change_scene_to_file("res://world/world.tscn")
		SECOND:
			_check(chat.history.any(func(m: Dictionary) -> bool: return m.kind == "system" and m.text.contains("entrou")), "aviso de quem entrou no mundo")
			_start = _p(0).global_position
			_key(KEY_ENTER, true)
		SECOND + 2:
			_key(KEY_ENTER, false)
		SECOND + 4:
			_check(_hud()._chat.is_open(), "Enter abre o chat")
			_check(root.get_node("InputService").is_blocked(_p(0).slot), "digitando, o herói fica parado")
			for c in "oi i bora":
				_type(c)
			_key(KEY_D, true)
		SECOND + 20:
			_key(KEY_D, false)
		SECOND + 24:
			_check(not _hud()._inventories.has(0), "o \"i\" digitado não abriu o inventário")
			_check(_p(0).global_position.distance_to(_start) < 0.5, "o \"d\" digitado não andou")
			_key(KEY_ENTER, true)
		SECOND + 26:
			_key(KEY_ENTER, false)
		SECOND + 30:
			var last: Dictionary = chat.history[-1]
			_check(last.text.contains("oi i bora") and last.from == _p(0).display_name, "Enter mandou com o nome do personagem (%s)" % last.text)
			_check(not _hud()._chat.is_open() and not root.get_node("InputService").is_blocked(0), "chat fechou e o herói voltou")
			root.get_node("InputService")._try_join(0)
		SECOND + 50:
			_joy(JOY_BUTTON_DPAD_DOWN, true)
		SECOND + 52:
			_joy(JOY_BUTTON_DPAD_DOWN, false)
		SECOND + 56:
			_check(_hud()._chat.is_open(), "direcional para baixo abre as mensagens rápidas")
			_joy(JOY_BUTTON_DPAD_DOWN, true)
		SECOND + 58:
			_joy(JOY_BUTTON_DPAD_DOWN, false)
		SECOND + 62:
			_joy(JOY_BUTTON_A, true)
		SECOND + 64:
			_joy(JOY_BUTTON_A, false)
		SECOND + 70:
			var last: Dictionary = chat.history[-1]
			_check(last.text == chat.QUICK[1] and last.from == _p(1).display_name, "A mandou \"%s\" pelo P2" % last.text)
			_check(_hud()._chat.visible, "a caixa do chat aparece com mensagens novas")
			print("CHAT: ", "FALHOU" if _failed else "OK")
			quit(1 if _failed else 0)
	return false


func _hud() -> Node:
	return current_scene.get_node("HUD")


func _p(slot: int) -> Node3D:
	for p in get_nodes_in_group("players"):
		if p.slot == slot:
			return p
	return null


func _type(c: String) -> void:
	var code := OS.find_keycode_from_string(c.to_upper()) if c != " " else KEY_SPACE
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.unicode = c.unicode_at(0) if pressed else 0
		event.pressed = pressed
		Input.parse_input_event(event)


func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)


func _joy(button: JoyButton, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = down
	Input.parse_input_event(event)


func _check(ok: bool, text: String) -> void:
	print("  ", "ok  " if ok else "FALHOU", " ", text)
	if not ok:
		_failed = true
