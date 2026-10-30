extends SceneTree
## Teste da progressão do herói e da sensação de combate: XP por criatura (o time por perto
## ganha junto), subir de nível (vida cheia, som, efeito), painel Chip pirata pelo teclado,
## save do personagem, save adulterado barrado, número de dano e sons dos golpes.
## Rodar: godot --headless --fixed-fps 60 --path coop-dungeon -s tests/progress_test.gd
## Atenção: cada passo é um quadro; dois passos no mesmo quadro fazem só o primeiro rodar.

const SECOND := 120

var _frames := 0
var _failed := false
var _hp_before := 0.0
var _xp_before := 0


func _process(_delta: float) -> bool:
	_frames += 1
	match _frames:
		1:
			root.get_node("SaveService").use_test_storage("test_saves_progress")
			root.get_node("SaveService").save_player(0, {})
			_unit_checks()
			change_scene_to_file("res://world/world.tscn")
		SECOND:
			var p1 := _p1()
			_check(p1.progress.level == 1, "herói novo começa no nível 1")
			# Criatura derrotada perto: XP para o herói.
			var enemy := _nearest_enemy_spawned_at(p1, Vector3(96, 0, 30))
			_xp_before = p1.progress.xp
			if enemy:
				enemy.take_hit(9999.0, Vector3.FORWARD * 8.0)
		SECOND + 5:
			var p1 := _p1()
			_check(p1.progress.xp > _xp_before, "criatura derrotada perto dá XP (%d)" % p1.progress.xp)
			var labels := current_scene.get_children().filter(func(n: Node) -> bool: return n is Label3D and n.text.is_valid_int())
			_check(not labels.is_empty(), "o golpe mostrou o número do dano")
			var sound: Array = root.get_node("Sound").played
			_check(sound.has("hit_heavy") and sound.has("enemy_destroy") or sound.has("chip_burn"), "golpe pesado e morte tocaram som (%s)" % [sound])
			# Sobe 2 níveis de uma vez.
			p1.health.hp = 10.0
			_hp_before = p1.health.max_hp
			var progression: Script = load("res://player/progression.gd")
			p1.add_xp(progression.xp_to_next(1) + progression.xp_to_next(2))
		SECOND + 8:
			var p1 := _p1()
			_check(p1.progress.level == 3, "XP suficiente sobe 2 níveis (%d)" % p1.progress.level)
			_check(p1.health.max_hp > _hp_before and is_equal_approx(p1.health.hp, p1.health.max_hp), "subir de nível dá vida e enche a barra")
			_check(root.get_node("Sound").played.has("level_up"), "som de subir de nível")
			_check(p1.progress.points_free() == 2, "2 pontos de chip para instalar")
			var saved: Dictionary = root.get_node("SaveService").load_player(0)
			_check(int(saved.get("progress", {}).get("level", 0)) == 3, "nível salvo no personagem")
			_hp_before = p1.health.max_hp
			_key(KEY_I, true)
		SECOND + 10:
			_key(KEY_I, false)
		SECOND + 14:
			_check(_panel_is("inventory_panel.gd"), "I abre o inventário")
			_key(KEY_Q, true)
		SECOND + 16:
			_key(KEY_Q, false)
		SECOND + 20:
			_check(_panel_is("chip_panel.gd"), "Q no inventário abre o Chip pirata")
			_check(root.get_node("InputService").is_blocked(0), "com o painel aberto o herói fica parado")
			_key(KEY_SPACE, true)
		SECOND + 22:
			_key(KEY_SPACE, false)
		SECOND + 28:
			var p1 := _p1()
			_check(p1.progress.chip_level("carcaca") == 1, "Espaço instala um ponto na Carcaça reforçada")
			_check(p1.health.max_hp > _hp_before, "vida máxima subiu com o chip (%.0f -> %.0f)" % [_hp_before, p1.health.max_hp])
			_check(root.get_node("Sound").played.has("chip_install"), "som de chip instalado")
			_key(KEY_S, true)
		SECOND + 30:
			_key(KEY_S, false)
		SECOND + 32:
			_key(KEY_SPACE, true)
		SECOND + 34:
			_key(KEY_SPACE, false)
		SECOND + 40:
			var p1 := _p1()
			_check(p1.progress.chip_level("braco") == 1 and p1.progress.points_free() == 0, "S desce e instala no Braço hidráulico")
			_key(KEY_SPACE, true)
		SECOND + 42:
			_key(KEY_SPACE, false)
		SECOND + 48:
			_check(_p1().progress.points_spent() == 2, "sem pontos, não instala mais nada")
			_key(KEY_I, true)
		SECOND + 50:
			_key(KEY_I, false)
		SECOND + 56:
			_check(not _hud()._inventories.has(0), "I fecha o painel")
			_check(not root.get_node("InputService").is_blocked(0), "herói solto de novo")
			var saved: Dictionary = root.get_node("SaveService").load_player(0)
			_check(int(saved.get("progress", {}).get("chips", {}).get("braco", 0)) == 1, "chips salvos no personagem")
			print("PROGRESSÃO: ", "FALHOU" if _failed else "OK")
			quit(1 if _failed else 0)
	return false


## Regras da progressão sem o mundo.
func _unit_checks() -> void:
	var progression: Script = load("res://player/progression.gd")
	var p: RefCounted = progression.new()
	_check(progression.xp_to_next(1) == 60 and progression.xp_to_next(10) > progression.xp_to_next(9), "XP para subir cresce a cada nível")
	_check(p.add_xp(59) == 0 and p.level == 1, "59 XP ainda é nível 1")
	_check(p.add_xp(1) == 1 and p.level == 2 and p.xp == 0, "60 XP: nível 2")
	_check(p.install("motor") and not p.install("motor"), "1 ponto por nível")
	_check(is_equal_approx(p.bonus("speed_pct"), 2.5), "Motor nas pernas: +2,5% por ponto")
	var cheat: RefCounted = progression.from_dict({"level": 999, "xp": -5, "chips": {"carcaca": 50, "braco": 50, "hack": 3}})
	_check(cheat.level == progression.MAX_LEVEL and cheat.xp == 0, "save adulterado: nível e XP no limite")
	_check(cheat.chip_level("carcaca") == progression.MAX_CHIP and cheat.points_spent() <= cheat.points_total() and not cheat.chips.has("hack"),
			"save adulterado: chips no máximo, sem pontos a mais e sem chip inventado")


## Leva o P1 até a criatura mais perto de `place` e devolve ela.
func _nearest_enemy_spawned_at(p1: Node3D, place: Vector3) -> Node3D:
	get_first_node_in_group("world_streamer").load_now(place)
	var best: Node3D = null
	for enemy in get_nodes_in_group("enemies"):
		if best == null or enemy.global_position.distance_to(place) < best.global_position.distance_to(place):
			best = enemy
	if best:
		p1.teleport_to(best.global_position + Vector3(3, 0, 3))
	return best


func _panel_is(script_file: String) -> bool:
	var panel: Node = _hud()._inventories.get(0)
	return panel != null and panel.get_script().resource_path.ends_with(script_file)


func _hud() -> Node:
	return current_scene.get_node("HUD")


func _p1() -> Node3D:
	for p in get_nodes_in_group("players"):
		if p.index == 0:
			return p
	return null


func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)


func _check(ok: bool, text: String) -> void:
	print("  ", "ok  " if ok else "FALHOU", " ", text)
	if not ok:
		_failed = true
