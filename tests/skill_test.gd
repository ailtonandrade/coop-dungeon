extends SceneTree
## Teste das habilidades estilo Tibia: curva de uso, acertar com a arma treina a habilidade
## dela (facão -> Lâminas), o tiro treina Disparo, apanhar treina Vigor e Resiliência, cada
## nível aumenta dano/vida/armadura, aviso no chat, save do personagem e a janela pela roda
## dos painéis (I, Q, Q).
## Rodar: godot --headless --fixed-fps 60 --path coop-dungeon -s tests/skill_test.gd
## Atenção: cada passo é um quadro; dois passos no mesmo quadro fazem só o primeiro rodar.

const SECOND := 120

var _frames := 0
var _failed := false
var _enemy: Node3D
var _value := 0.0


func _process(_delta: float) -> bool:
	_frames += 1
	match _frames:
		1:
			root.get_node("SaveService").use_test_storage("test_saves_skills")
			Engine.set_meta("auto_pick_character", true)
			for character in root.get_node("SaveService").list_characters():
				root.get_node("SaveService").delete_character(character.id)
			_unit_checks()
			change_scene_to_file("res://world/world.tscn")
		SECOND:
			var p1 := _p1()
			_check(p1.weapon_skill("melee") == "laminas" and p1.weapon_skill("ranged") == "disparo", "facão treina Lâminas, besta treina Disparo")
			_enemy = _enemy_near(p1, Vector3(96, 0, 30))
			_value = p1.melee_damage()
			if _enemy:
				p1.teleport_to(_enemy.global_position + Vector3(0, 0, 1.4))
				p1._facing = Vector3(0, 0, -1)
		SECOND + 2:
			var p1 := _p1()
			p1._melee_hit(p1.COMBO[0])
		SECOND + 4:
			var p1 := _p1()
			_check(float(p1.progress.skills.get("laminas", {}).get("tries", 0.0)) >= 1.0, "golpe de facão que acerta treina Lâminas")
			# Tiro na criatura: o acerto treina Disparo.
			var from := p1.global_position + Vector3.UP * 1.1
			var dir: Vector3 = (_enemy.global_position + Vector3.UP - from).normalized() if is_instance_valid(_enemy) else Vector3.FORWARD
			load("res://combat/projectile.gd").fire(p1, from, dir, 20.0, 1.0, 4, Color.WHITE)
		SECOND + 40:
			var p1 := _p1()
			_check(float(p1.progress.skills.get("disparo", {}).get("tries", 0.0)) >= 1.0, "tiro que acerta treina Disparo")
			# Golpes recebidos: Vigor e Resiliência.
			p1.take_hit(12.0)
			_check(float(p1.progress.skills.get("vigor", {}).get("tries", 0.0)) > 0.0, "aguentar dano treina Vigor")
			_check(float(p1.progress.skills.get("resiliencia", {}).get("tries", 0.0)) >= 1.0, "apanhar treina Resiliência")
			# Subir de nível de verdade.
			_value = p1.melee_damage()
			var hp: float = p1.health.max_hp
			var armor: float = p1.armor()
			p1.train("laminas", 200.0)
			p1.train("vigor", 200.0)
			p1.train("resiliencia", 200.0)
			_check(p1.progress.skill_level("laminas") > 10 and p1.melee_damage() > _value, "Lâminas subiu e o dano com o facão também (%.1f -> %.1f)" % [_value, p1.melee_damage()])
			_check(p1.health.max_hp > hp, "Vigor subiu a vida máxima (%.0f -> %.0f)" % [hp, p1.health.max_hp])
			_check(p1.armor() > armor, "Resiliência subiu a armadura (%.1f -> %.1f)" % [armor, p1.armor()])
			var texts: Array = root.get_node("Chat").history.map(func(m: Dictionary) -> String: return m.text)
			_check(texts.any(func(t: String) -> bool: return t.contains("avançou em Lâminas")), "aviso no chat, estilo Tibia")
		SECOND + 44:
			var saved: Dictionary = root.get_node("SaveService").load_character(_p1().character_id)
			_check(int(saved.get("progress", {}).get("skills", {}).get("laminas", {}).get("level", 0)) > 10, "habilidades salvas no personagem")
			_key(KEY_I, true)
		SECOND + 46:
			_key(KEY_I, false)
		SECOND + 50:
			_key(KEY_Q, true)
		SECOND + 52:
			_key(KEY_Q, false)
		SECOND + 56:
			_key(KEY_Q, true)
		SECOND + 58:
			_key(KEY_Q, false)
		SECOND + 62:
			_check(_panel_is("skills_panel.gd"), "I, Q, Q abre a janela de Habilidades")
			_key(KEY_Q, true)
		SECOND + 64:
			_key(KEY_Q, false)
		SECOND + 68:
			_check(_panel_is("inventory_panel.gd"), "Q de novo volta ao inventário")
			_key(KEY_I, true)
		SECOND + 70:
			_key(KEY_I, false)
		SECOND + 74:
			_check(not root.get_node("InputService").is_blocked(0), "fechou e o herói voltou")
			print("HABILIDADES: ", "FALHOU" if _failed else "OK")
			quit(1 if _failed else 0)
	return false


func _unit_checks() -> void:
	var progression: Script = load("res://player/progression.gd")
	var p: RefCounted = progression.new()
	_check(p.skill_level("laminas") == 10, "habilidades começam no 10, como no Tibia")
	_check(progression.tries_to_next(10) == 15.0 and progression.tries_to_next(30) > progression.tries_to_next(20), "cada nível pede mais uso")
	_check(p.train("laminas", 14.0) == 0 and p.train("laminas", 1.0) == 1, "15 acertos: Lâminas 11")
	_check(is_equal_approx(p.skill_bonus("laminas"), 1.5), "+1,5% de dano por nível")
	_check(p.train("laminas", 1e12) > 0 and p.skill_level("laminas") == progression.SKILL_MAX, "para no máximo")
	var cheat: RefCounted = progression.from_dict({"skills": {"vigor": {"level": 999, "tries": 1e9}, "voar": {"level": 50}}})
	_check(cheat.skill_level("vigor") == progression.SKILL_MAX and not cheat.skills.has("voar"), "save adulterado: no máximo e sem habilidade inventada")


func _enemy_near(p1: Node3D, place: Vector3) -> Node3D:
	get_first_node_in_group("world_streamer").load_now(place)
	var best: Node3D = null
	for enemy in get_nodes_in_group("enemies"):
		if best == null or enemy.global_position.distance_to(place) < best.global_position.distance_to(place):
			best = enemy
	return best


func _panel_is(script_file: String) -> bool:
	var panel: Node = current_scene.get_node("HUD")._inventories.get(0)
	return panel != null and panel.get_script().resource_path.ends_with(script_file)


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
