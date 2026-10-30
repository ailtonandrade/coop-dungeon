extends SceneTree
## Teste dos serviços da cidade no mundo de verdade: comerciante pela tela (teclado), ferreiro,
## encantador e banco pelos comandos, moedas do chão, e o host recusando serviço longe do NPC.
## Rodar: godot --headless --fixed-fps 60 --path coop-dungeon -s tests/services_test.gd
## Atenção: cada passo é um quadro; dois passos no mesmo quadro fazem só o primeiro rodar.

const SECOND := 60
const MERCHANT := Vector3(25, 0, 31.6)
const BLACKSMITH := Vector3(50, 0, 50.0)
const ENCHANTER := Vector3(39, 0, 31.6)
const BANK := Vector3(14, 0, 14.0)

var _frames := 0
var _failed := false
var _gold := 0
var _swords := 0


func _process(_delta: float) -> bool:
	_frames += 1
	match _frames:
		1:
			root.get_node("SaveService").use_test_storage("test_saves_services")
			# Sem tela de escolha nos testes: entra com o personagem da vaga.
			Engine.set_meta("auto_pick_character", true)
			change_scene_to_file("res://world/world.tscn")
		SECOND:
			var p1 := _p1()
			p1.inventory.add_gold(2000)
			p1.teleport_to(MERCHANT)
		SECOND + 10:
			# F perto do comerciante abre a tela dele para o P1.
			_key(KEY_F, true)
		SECOND + 12:
			_key(KEY_F, false)
			var hud := current_scene.get_node("HUD")
			_check(hud._services.has(0), "F perto do comerciante abre a tela de serviço")
			_check(root.get_node("InputService").is_blocked(0), "com a tela aberta, o herói não anda nem ataca")
			_gold = _p1().inventory.gold
			_swords = _count("sword")
			_key(KEY_SPACE, true)
		SECOND + 14:
			_key(KEY_SPACE, false)
		SECOND + 20:
			var p1 := _p1()
			_check(_count("sword") == _swords + 1, "Espaço compra a espada (1º item do estoque)")
			_check(p1.inventory.gold == _gold - load("res://items/item_db.gd").value(load("res://items/item_db.gd").make("sword", 2)),
					"compra cobra o preço (%d -> %d)" % [_gold, p1.inventory.gold])
			# Aba Vender: vende a 1ª coisa da mochila.
			_gold = p1.inventory.gold
			_key(KEY_D, true)
		SECOND + 22:
			_key(KEY_D, false)
		SECOND + 24:
			_key(KEY_SPACE, true)
		SECOND + 26:
			_key(KEY_SPACE, false)
		SECOND + 32:
			_check(_p1().inventory.gold > _gold, "vender na aba Vender paga (%d -> %d)" % [_gold, _p1().inventory.gold])
			_key(KEY_SHIFT, true)
		SECOND + 34:
			_key(KEY_SHIFT, false)
		SECOND + 36:
			_check(not current_scene.get_node("HUD")._services.has(0), "B/Shift fecha a tela")
			_check(not root.get_node("InputService").is_blocked(0), "tela fechada: herói volta a andar")
			# Longe do ferreiro, o host recusa o refino.
			_p1().request_inventory("refine", [["eq", "melee"]])
			_check(int(_p1().inventory.equipment.melee.get("refine", 0)) == 0, "longe do ferreiro: refino recusado")
			_p1().teleport_to(BLACKSMITH)
		SECOND + 40:
			var p1 := _p1()
			var before: float = p1.melee_damage()
			p1.request_inventory("refine", [["eq", "melee"]])
			_check(int(p1.inventory.equipment.melee.get("refine", 0)) == 1, "ferreiro refinou a espada para +1")
			_check(p1.melee_damage() > before, "refino aumentou o dano (%.1f -> %.1f)" % [before, p1.melee_damage()])
			p1.teleport_to(ENCHANTER)
		SECOND + 44:
			var p1 := _p1()
			p1.request_inventory("enchant", [["eq", "melee"], "afiado"])
			_check(p1.inventory.equipment.melee.get("enchants", {}).get("afiado") == 1, "encantador pôs Afiado 1")
			_check(p1.inventory.total("damage_pct") >= 12.0, "Afiado conta no dano do herói")
			p1.request_inventory("enchant", [["eq", "melee"], "protetor"])
			_check(not p1.inventory.equipment.melee.get("enchants", {}).has("protetor"), "encantamento de armadura recusado na espada")
			# Fora do banco não mexe no depósito.
			p1.request_inventory("deposit", [["bag", 1]])
			_check(p1.inventory.depot.contents[0] == null, "longe do banco: não guarda")
			p1.teleport_to(BANK)
		SECOND + 48:
			var p1 := _p1()
			var item: Dictionary = p1.inventory.get_item(["bag", 1])
			p1.request_inventory("deposit", [["bag", 1]])
			_check(p1.inventory.depot.contents[0] != null and p1.inventory.depot.contents[0].uid == item.uid, "banco guardou o item no depósito")
			p1.request_inventory("withdraw", [0])
			_check(p1.inventory.depot.contents[0] == null and _has_uid(item.uid), "banco devolveu o item para a mochila")
			# Moedas no chão: qualquer um pega com o botão.
			_gold = p1.inventory.gold
			load("res://items/loot.gd").drop(p1, load("res://items/item_db.gd").make_gold(37), p1.global_position + Vector3(0.5, 0, 0))
		SECOND + 52:
			_p1()._pick_up()
		SECOND + 54:
			_check(_p1().inventory.gold == _gold + 37, "pegou 37 moedas do chão")
			var saved: Dictionary = root.get_node("SaveService").load_character(_p1().character_id)
			_check(not saved.get("inventory", {}).is_empty(), "moedas e itens salvos no personagem")
			_check(int(saved.inventory.get("gold", 0)) == _gold + 37, "save tem as moedas certas")
			print("SERVIÇOS: ", "FALHOU" if _failed else "OK")
			quit(1 if _failed else 0)
	return false


func _p1() -> Node3D:
	for p in get_nodes_in_group("players"):
		if p.index == 0:
			return p
	return null


func _count(id: String) -> int:
	return _p1().inventory.all_items(["eq", "bag"]).filter(func(e: Array) -> bool: return e[1].id == id).size()


func _has_uid(uid: int) -> bool:
	return _p1().inventory.all_items(["eq", "bag"]).any(func(e: Array) -> bool: return e[1].uid == uid)


func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	_failed = _failed or not ok
