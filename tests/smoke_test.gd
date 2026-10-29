extends SceneTree
## Teste de fumaça sem tela: carrega a fase, faz 2 jogadores entrarem e confere que
## nascem, andam pela física e que o save local faz ida e volta.
## Rodar: godot --headless --path coop-dungeon -s tests/smoke_test.gd

var _frames := 0
var _failed := false


func _initialize() -> void:
	change_scene_to_file("res://levels/level_01.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	var input := root.get_node("InputService")
	if _frames == 5:
		input._try_join(input.KEYBOARD)
		input._try_join(0)
	if _frames == 60:
		var players := current_scene.get_node("PlayerManager").get_children()
		_check(players.size() == 2, "2 jogadores em cena (achou %d)" % players.size())
		for p in players:
			_check(p.is_on_floor(), "P%d no chão (y=%.2f)" % [p.slot + 1, p.global_position.y])
		var save := root.get_node("SaveService")
		_check(save.save_player(0, {"level": 3}), "save_player escreveu")
		_check(save.load_player(0).get("level") == 3, "load_player leu o que foi salvo")
		print("SMOKE TEST: ", "FALHOU" if _failed else "OK")
		quit(1 if _failed else 0)
	return false


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	_failed = _failed or not ok
