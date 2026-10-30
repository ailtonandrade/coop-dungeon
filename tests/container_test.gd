extends SceneTree
## Teste dos baús/contêineres com saque no mundo de verdade: o baú da vila abre com F, larga o
## conteúdo no chão (item fixo, parafusos), não abre de novo, fica salvo no mundo, volta a
## encher depois do tempo, e a validação do mapa acha id repetido.
## Rodar: godot --headless --fixed-fps 60 --path coop-dungeon -s tests/container_test.gd
## Atenção: cada passo é um quadro; dois passos no mesmo quadro fazem só o primeiro rodar.

const SECOND := 60
const CHEST := Vector3(39, 0, 41)

var _frames := 0
var _failed := false
var _loot_before := 0


func _process(_delta: float) -> bool:
	_frames += 1
	match _frames:
		1:
			root.get_node("SaveService").use_test_storage("test_saves_containers")
			var net := root.get_node("NetService")
			net.world = root.get_node("SaveService").new_world("Teste baú", 1, "offline")
			change_scene_to_file("res://world/world.tscn")
		SECOND:
			var chest := _chest()
			_check(chest != null, "o baú da vila carregou com o bloco")
			_check(chest != null and not chest.is_open(), "começa fechado")
			_p1().teleport_to(CHEST + Vector3(0, 0, 1.5))
			_loot_before = get_nodes_in_group("loot").size()
		SECOND + 10:
			_key(KEY_F, true)
		SECOND + 12:
			_key(KEY_F, false)
		SECOND + 20:
			var loot := get_nodes_in_group("loot")
			var ids := loot.map(func(l: Node) -> String: return l.item.id)
			_check(loot.size() > _loot_before, "F perto do baú larga o saque no chão (%d itens)" % (loot.size() - _loot_before))
			_check(ids.has("iron_helmet"), "o item fixo do baú (capacete) caiu")
			_check(ids.has("gold"), "os parafusos do baú caíram")
			_check(_chest().is_open(), "baú fica aberto")
			var states: Dictionary = root.get_node("NetService").world.get("containers", {})
			_check(states.has("vila_bau_inicial"), "abertura guardada no mundo")
			var saved: Array = root.get_node("SaveService").list_worlds().filter(func(w: Dictionary) -> bool: return w.get("containers", {}).has("vila_bau_inicial"))
			_check(saved.size() == 1, "e já salva no disco (não depende de sair do jogo)")
			# Junta tudo do chão, para o F seguinte só poder abrir o baú.
			for item in loot:
				item.queue_free()
		SECOND + 24:
			_key(KEY_F, true)
		SECOND + 26:
			_key(KEY_F, false)
		SECOND + 34:
			_check(get_nodes_in_group("loot").is_empty(), "baú aberto não dá saque de novo")
			# Reabastecer: com 30 min, passa a fechar de novo depois do tempo.
			var chest := _chest()
			chest.refill_minutes = 30.0
			var now := Time.get_unix_time_from_system()
			_check(chest.is_open(now + 29 * 60), "com reabastecer de 30 min: aos 29 min ainda vazio")
			_check(not chest.is_open(now + 31 * 60), "aos 31 min está cheio de novo")
			# Conteúdo: chance 0 nunca sai; poder 0 usa o da região.
			var line: Resource = load("res://world/container_item.gd").new()
			line.item_id = "axe"
			line.chance = 0.0
			chest.contents.clear()
			chest.contents.append(line)
			chest.gold = 0
			chest.random_items = 0
			_check(chest.roll_contents(3).is_empty(), "item com chance 0% não sai")
			line.chance = 100.0
			line.count = 3
			var rolled: Array = chest.roll_contents(3)
			_check(rolled.size() == 3 and rolled.all(func(i: Dictionary) -> bool: return i.power == 3), "3 machados no poder da região")
			_check_validation()
			print("BAÚS: ", "FALHOU" if _failed else "OK")
			quit(1 if _failed else 0)
	return false


## Validação do mapa: id repetido entre dois baús é erro.
func _check_validation() -> void:
	var tools: Script = load("res://addons/map_editor/map_tools.gd")
	var map: Resource = load("res://world/test_world.tres")
	var issues: Array = tools.container_issues(map)
	_check(issues.filter(func(i: Dictionary) -> bool: return i.level == "erro").is_empty(), "baús do mapa sem erro de id")


func _chest() -> Node:
	for container in get_nodes_in_group("containers"):
		if container.container_id == "vila_bau_inicial":
			return container
	return null


func _p1() -> Node:
	for player in get_nodes_in_group("players"):
		if player.slot == 0:
			return player
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
