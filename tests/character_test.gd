extends SceneTree
## Teste dos personagens: o save antigo vira personagem, a escolha abre ao entrar no mundo,
## personalizar ali (visual e cor do chip), criar um novo, entrar com ele, lembrar a escolha, e
## o 2º jogador do sofá não poder pegar o mesmo personagem.
## Rodar: godot --headless --fixed-fps 60 --path coop-dungeon -s tests/character_test.gd
## Atenção: cada passo é um quadro; dois passos no mesmo quadro fazem só o primeiro rodar.

const SECOND := 60

var _frames := 0
var _failed := false
var _hero_id := ""
var _model_before := ""
var _color_before := 0


func _process(_delta: float) -> bool:
	_frames += 1
	var save := root.get_node("SaveService")
	match _frames:
		1:
			save.use_test_storage("test_saves_characters")
			Engine.set_meta("auto_pick_character", false)
			for character in save.list_characters():
				save.delete_character(character.id)
			root.get_node("Settings").last_character = ["", "", "", ""]
			# Save do jeito antigo (um por vaga do sofá), com moedas.
			save._write("player_" + root.get_node("PlatformService").get_profile_id(0), {"inventory": {"gold": 321, "equipment": {"melee": {"id": "axe", "uid": 5, "power": 2, "rarity": "rare"}}}, "progress": {"level": 4}})
			var characters: Array = save.list_characters()
			_check(characters.size() == 1 and characters[0].name == "Herói 1", "save antigo virou o personagem 'Herói 1'")
			_check(int(characters[0].inventory.get("gold", 0)) == 321 and int(characters[0].progress.level) == 4, "com as moedas e o nível de antes")
			_check(save.list_characters().size() == 1, "migra uma vez só")
			_hero_id = characters[0].id
			change_scene_to_file("res://world/world.tscn")
		SECOND:
			_check(get_nodes_in_group("players").is_empty(), "ninguém nasce antes de escolher")
			_check(_hud()._selects.has(0), "a escolha de personagem abriu para o P1")
			var marked: Dictionary = _select(0)._current()
			_check(marked.get("id") == _hero_id, "já vem marcado o personagem existente")
			_model_before = marked.model
			_color_before = marked.chip_color
			_key(KEY_D, true)
		SECOND + 2:
			_key(KEY_D, false)
		SECOND + 6:
			_key(KEY_E, true)
		SECOND + 8:
			_key(KEY_E, false)
		SECOND + 12:
			var stored: Dictionary = save.load_character(_hero_id)
			_check(stored.model != _model_before, "D troca o visual (%s -> %s) e salva" % [_model_before, stored.model])
			_check(stored.chip_color != _color_before, "E troca a cor do chip e salva")
			_key(KEY_S, true)
		SECOND + 14:
			_key(KEY_S, false)
		SECOND + 18:
			_check(_select(0)._current().is_empty(), "S desce para 'Novo personagem'")
			_key(KEY_SPACE, true)
		SECOND + 20:
			_key(KEY_SPACE, false)
		SECOND + 24:
			_check(save.list_characters().size() == 2, "Espaço cria um personagem novo")
			_key(KEY_W, true)
		SECOND + 26:
			_key(KEY_W, false)
		SECOND + 30:
			_key(KEY_SPACE, true)
		SECOND + 32:
			_key(KEY_SPACE, false)
		SECOND + 50:
			var p1 := _player(0)
			_check(p1 != null and p1.character_id == _hero_id, "P1 entrou com o personagem escolhido")
			_check(p1 != null and p1.display_name == "Herói 1", "com o nome dele")
			_check(p1 != null and int(p1.inventory.gold) == 321 and p1.inventory.equipment.melee.id == "axe" and p1.progress.level == 4, "com o inventário e o nível dele")
			_check(p1 != null and p1.model_id == save.load_character(_hero_id).model, "com o visual escolhido")
			_check(p1 != null and p1.find_child("ChipPirata", true, false) != null, "chip pirata aceso na cabeça")
			_check(root.get_node("Settings").last_character[0] == _hero_id, "escolha lembrada para a próxima vez")
			# P2 no controle 0: o personagem do P1 está em jogo; tenta, é recusado, desce e entra com o outro.
			root.get_node("InputService")._try_join(0)
		SECOND + 56:
			_check(_hud()._selects.has(1), "a escolha abriu para o P2")
			_check(_select(1).taken.has(_hero_id), "o personagem do P1 aparece como 'já em jogo'")
			_joy(JOY_BUTTON_DPAD_DOWN, true)
		SECOND + 58:
			_joy(JOY_BUTTON_DPAD_DOWN, false)
		SECOND + 62:
			_joy(JOY_BUTTON_A, true)
		SECOND + 64:
			_joy(JOY_BUTTON_A, false)
		SECOND + 84:
			var p2 := _player(1)
			_check(p2 != null and p2.character_id != _hero_id and not p2.character_id.is_empty(), "P2 entrou com o outro personagem")
			_check(not _hud()._selects.has(0) and not _hud()._selects.has(1), "telas de escolha fechadas")
			Engine.set_meta("auto_pick_character", true)
			print("PERSONAGENS: ", "FALHOU" if _failed else "OK")
			quit(1 if _failed else 0)
	return false


func _hud() -> Node:
	return current_scene.get_node("HUD")


func _select(slot: int) -> Node:
	return _hud()._selects.get(slot)


func _player(slot: int) -> Node3D:
	for p in get_nodes_in_group("players"):
		if p.slot == slot:
			return p
	return null


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
