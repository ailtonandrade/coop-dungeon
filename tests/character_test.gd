extends SceneTree
## Teste dos personagens: o save antigo vira personagem; o primeiro jogador cai direto no mundo
## com o personagem ativo do menu; o 2º do sofá entra segurando Y na pausa, escolhe em cards
## (o do P1 aparece em jogo), cria um novo (visual, cor) e entra com ele.
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
			# Escolhido no menu principal (personagem ativo).
			root.get_node("Settings").active_character = _hero_id
			change_scene_to_file("res://world/world.tscn")
		SECOND:
			var p1 := _player(0)
			_check(not _hud()._selects.has(0), "o primeiro jogador não passa pela escolha")
			_check(p1 != null and p1.character_id == _hero_id, "P1 caiu direto no mundo com o personagem ativo do menu")
			_check(p1 != null and p1.display_name == "Herói 1", "com o nome dele")
			_check(p1 != null and int(p1.inventory.gold) == 321 and p1.inventory.equipment.melee.id == "axe" and p1.progress.level == 4, "com o inventário e o nível dele")
			_check(p1 != null and p1.find_child("ChipPirata", true, false) != null, "chip pirata aceso na cabeça")
			# A no 2º controle fora da pausa: não entra (agora é segurando Y na pausa).
			_joy(JOY_BUTTON_A, true)
		SECOND + 2:
			_joy(JOY_BUTTON_A, false)
		SECOND + 6:
			_check(get_nodes_in_group("players").size() == 1 and _hud()._selects.is_empty(), "A no 2º controle não faz ninguém entrar")
			_key(KEY_ESCAPE, true)
		SECOND + 8:
			_key(KEY_ESCAPE, false)
		SECOND + 12:
			_check(_hud()._pause.visible, "Esc pausa")
			_joy(JOY_BUTTON_Y, true)
		SECOND + 60:
			_check(not _hud()._selects.has(1), "segurando Y por menos de 2 s ainda não entra")
		SECOND + 140:
			_joy(JOY_BUTTON_Y, false)
		SECOND + 144:
			_check(_hud()._selects.has(1), "segurou Y 2 s na pausa: abriu a escolha do P2")
			_check(not _hud()._pause.visible, "a pausa fechou sozinha")
			_check(_select(1).taken.has(_hero_id), "o personagem do P1 aparece como em jogo")
			_check(_select(1)._cursor == _select(1)._characters.size(), "sem nenhum livre, já começa no card Novo")
			_joy(JOY_BUTTON_A, true)
		SECOND + 146:
			_joy(JOY_BUTTON_A, false)
		SECOND + 150:
			_check(_select(1)._creating, "A no card Novo abre a criação")
			_model_before = _select(1)._draft.model
			_color_before = _select(1)._draft.chip_color
			_joy(JOY_BUTTON_DPAD_RIGHT, true)
		SECOND + 152:
			_joy(JOY_BUTTON_DPAD_RIGHT, false)
		SECOND + 156:
			_joy(JOY_BUTTON_Y, true)
		SECOND + 158:
			_joy(JOY_BUTTON_Y, false)
		SECOND + 162:
			_check(_select(1)._draft.model != _model_before, "direita troca o visual")
			_check(_select(1)._draft.chip_color != _color_before, "Y troca a cor do chip")
			_joy(JOY_BUTTON_A, true)
		SECOND + 164:
			_joy(JOY_BUTTON_A, false)
		SECOND + 184:
			var p2 := _player(1)
			_check(p2 != null and p2.character_id != _hero_id and not p2.character_id.is_empty(), "P2 entrou com o personagem novo")
			_check(save.list_characters().size() == 2, "o novo ficou salvo neste PC")
			_check(_hud()._selects.is_empty(), "escolha fechada")
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
