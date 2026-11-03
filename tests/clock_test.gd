extends SceneTree
## Relógio do mundo (DayNight): hora anda, aparece certa, a luz não dá saltos entre as horas,
## postes acendem só de noite e a hora vai para o save do mundo.

var _failed := false
var _frames := 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		root.get_node("SaveService").use_test_storage("test_saves_clock")
		Engine.set_meta("auto_pick_character", true)
		root.get_node("NetService").world = {"id": "teste_relogio", "name": "x"}
		change_scene_to_file("res://world/world.tscn")
	elif _frames == 30:
		var clock: Node = get_first_node_in_group("day_night")
		_check(clock != null, "o mundo tem relógio")
		var DayNight: Script = load("res://world/day_night.gd")
		_check(absf(clock.hour - DayNight.START_HOUR) < 0.1, "mundo novo começa às %d h (%.2f)" % [DayNight.START_HOUR, clock.hour])
		clock.set_hour(6.5)
		_check(clock.clock_text() == "06:30", "hora na tela (%s)" % clock.clock_text())
		_check(not clock.is_night(), "6h30 é dia")
		clock.set_hour(23.0)
		_check(clock.is_night(), "23h é noite")
		_check(root.get_node("NetService").world.get("clock", -1.0) == 23.0, "a hora fica no save do mundo")
		# Luz sem saltos: de 5 em 5 minutos do jogo nada muda de repente.
		var worst := 0.0
		var previous: Dictionary = DayNight.sample(0.0)
		for i in range(1, 24 * 12 + 1):
			var now: Dictionary = DayNight.sample(i / 12.0)
			worst = maxf(worst, absf(now.sun_energy - previous.sun_energy) + absf(now.ambient_energy - previous.ambient_energy))
			previous = now
		_check(worst < 0.08, "a luz muda aos poucos ao longo do dia (maior passo %.3f)" % worst)
		_check(DayNight.street_lights_level(12.0) == 0.0 and DayNight.street_lights_level(0.0) == 1.0, "postes: apagados ao meio-dia, acesos à meia-noite")
		_check(DayNight.street_lights_level(19.1) > 0.0 and DayNight.street_lights_level(19.1) < 1.0, "postes acendem aos poucos no anoitecer")
		_check(DayNight.sun_angles(12.0).x < -50.0 and DayNight.sun_angles(6.0).x > -30.0, "sol alto ao meio-dia e baixo de manhã")
		var badge := get_first_node_in_group("hud").find_children("*", "HBoxContainer", true, false).filter(func(n: Node) -> bool: return n.get_script() == load("res://ui/clock_badge.gd"))
		_check(badge.size() == 1, "relógio na tela, embaixo do minimapa")
		print("RELÓGIO: " + ("FALHOU" if _failed else "OK"))
		quit(1 if _failed else 0)
	return false


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FALHOU ") + what)
	if not ok:
		_failed = true
