extends SceneTree
## "Continuar" no menu: o personagem volta para o último mundo em que jogou, onde parou.
## Rodar: godot --headless --fixed-fps 60 --path coop-dungeon -s tests/continue_test.gd
## Sem tipos do jogo aqui: o script de teste compila antes dos serviços globais existirem.

const SECOND := 60
const SPOT := Vector3(30, 0, 40)

var _frames := 0
var _failed := false
var _world: Dictionary
var _hero := ""


func _process(_delta: float) -> bool:
	_frames += 1
	var save := root.get_node("SaveService")
	match _frames:
		1:
			save.use_test_storage("test_saves_continue")
			for world in save.list_worlds():
				save.delete_world(world.id)
			for character in save.list_characters():
				save.delete_character(character.id)
			var hero: Dictionary = load("res://core/characters.gd").create("Nina Solda", "Beach", 1)
			save.save_character(hero)
			_hero = hero.id
			root.get_node("Settings").set_active_character(_hero)
			change_scene_to_file("res://ui/main_menu.tscn")
		20:
			_check(not _menu()._continue_button.visible, "personagem que nunca jogou: sem Continuar")
			_world = save.new_world("Vila da Nina", 7, "offline")
			save.save_world(_world)
			root.get_node("NetService").play_world(_world)
		SECOND + 20:
			var player := _player()
			_check(player != null, "entrou no mundo")
			player.teleport_to(SPOT)
		SECOND + 40:
			current_scene.save_places()
			var spot: Variant = save.character_place(_hero, _world.id)
			_check(spot is Vector3 and spot.distance_to(SPOT) < 0.5, "guardou onde o personagem está (%s)" % spot)
			_check(save.last_world_of(_hero).get("id") == _world.id, "guardou o último mundo dele")
			root.get_node("NetService").leave_session()
		SECOND + 70:
			var menu := _menu()
			_check(menu._continue_button.visible and menu._continue_button.text.contains("Vila da Nina"), "menu mostra Continuar · Vila da Nina (%s)" % menu._continue_button.text)
			_check(root.gui_get_focus_owner() == menu._continue_button, "e ele já vem marcado (A entra direto)")
			menu._continue_button.pressed.emit()
		2 * SECOND + 60:
			var player := _player()
			_check(player != null and str(root.get_node("NetService").world.get("id")) == _world.id, "Continuar entrou no último mundo")
			_check(player != null and player.global_position.distance_to(SPOT) < 3.0, "e o herói apareceu onde tinha parado (%s)" % (player.global_position if player else "-"))
			print("CONTINUAR: " + ("FALHOU" if _failed else "OK"))
			quit(1 if _failed else 0)
	return false


func _menu() -> Node:
	return current_scene


func _player() -> Node3D:
	for p in get_nodes_in_group("players"):
		if p.slot == 0:
			return p
	return null


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	_failed = _failed or not ok
