extends SceneTree
## Teste da lógica do inventário (sem fase). Rodar:
## godot --headless --path coop-dungeon -s tests/inventory_test.gd

var _failed := false


func _initialize() -> void:
	var inv := Inventory.starter()
	_check(inv.equipment.has("melee") and inv.equipment.has("bag"), "kit inicial tem arma e mochila")
	_check(inv.get_item(["bag", 0]).id == "pouch", "bolsa dentro da mochila")

	_check(inv.equip(["bag", 1]) and inv.get_item(["eq", "head"]).id == "leather_hood", "equipar o capuz da mochila")
	_check(inv.get_item(["bag", 1]) == null, "casa da mochila ficou vazia")

	_check(inv.move(["eq", "melee"], ["bag", 2]), "guardar a espada na mochila")
	_check(inv.move(["bag", 2], ["bag", 0]), "soltar a espada em cima da bolsa")
	_check(inv.get_item(["bag", 0, 0]).id == "sword", "espada foi parar dentro da bolsa")

	_check(not inv.move(["bag", 0], ["bag", 0, 1]), "bolsa não entra nela mesma")
	_check(not inv.move(["eq", "bag"], ["bag", 3]), "mochila equipada não entra nela mesma")
	_check(not inv.move(["bag", 0, 0], ["eq", "head"]), "espada não vai na cabeça")
	_check(inv.move(["bag", 0, 0], ["eq", "melee"]), "espada volta pra mão")

	var count := 0
	while not inv.add_item(ItemDB.make("dagger")).is_empty():
		count += 1
	_check(count == 11 + 6, "cabem 17 adagas (11 livres na mochila + 6 na bolsa): coube %d" % count)

	inv.remove(["bag", 5])
	inv.add_item(ItemDB.make("big_backpack"))
	_check(inv.move(["bag", 5], ["eq", "bag"]), "equipar a mochila grande que estava dentro da atual")
	_check(inv.get_item(["eq", "bag"]).id == "big_backpack" and inv.get_item(["bag", 0]).id == "backpack",
			"mochila antiga foi pra dentro da nova")

	var copy := Inventory.from_dict(inv.to_dict())
	_check(copy.to_dict() == inv.to_dict(), "salvar e carregar mantém tudo igual")
	_check(Inventory.from_dict({"equipment": {"head": {"id": "sword"}}}).is_empty(), "item na casa errada é descartado ao carregar")

	var rare := ItemDB.make("sword", 5, "rare")
	_check(ItemDB.stat(rare, "damage") > ItemDB.stat(ItemDB.make("sword"), "damage"), "raro e poder 5 batem mais (%.1f)" % ItemDB.stat(rare, "damage"))

	# Moedas, depósito do banco, refino, encantamento, preços.
	var shop := Inventory.starter()
	shop.add_gold(100)
	_check(shop.spend_gold(60) and shop.gold == 40, "gastar moedas tendo o suficiente")
	_check(not shop.spend_gold(41) and shop.gold == 40, "não gasta o que não tem")
	_check(not shop.can_place(ItemDB.make_gold(5), ["bag", 4]), "moedas nunca ocupam casa da mochila")
	var stored := shop.add_to_depot(shop.remove(["bag", 1]))
	_check(stored == ["depot", 0] and shop.get_item(["depot", 0]).id == "leather_hood", "guardar no depósito do banco")
	_check(shop.move(["depot", 0], ["bag", 5]), "tirar do depósito para a mochila")
	var blade := ItemDB.make("sword", 3, "rare")
	var base_damage := ItemDB.stat(blade, "damage")
	blade["refine"] = 3
	_check(absf(ItemDB.stat(blade, "damage") - base_damage * 1.3) <= 0.11, "refino +3 dá +30%% de dano (%.1f -> %.1f)" % [base_damage, ItemDB.stat(blade, "damage")])
	_check(ItemDB.display_name(blade) == "Facão de serra +3", "nome mostra o upgrade (+3)")
	_check(ItemDB.refine_chance(blade) == 0.8 and ItemDB.refine_chance(ItemDB.make("sword")) == 1.0, "chance de refino cai depois do +3")
	_check(ItemDB.can_enchant(blade, "afiado") and not ItemDB.can_enchant(blade, "protetor"), "encantamento só na peça certa")
	blade["enchants"] = {"afiado": 2}
	_check(ItemDB.stat(blade, "damage_pct") == 24.0, "Afiado 2 dá +24% de dano")
	blade["enchants"] = {"afiado": 3, "vampirico": 1}
	_check(not ItemDB.can_enchant(blade, "afiado"), "encantamento para no nível 3")
	_check(ItemDB.value(blade) > ItemDB.value(ItemDB.make("sword")), "item refinado e encantado vale mais")
	_check(ItemDB.sell_price(ItemDB.make("sword")) < ItemDB.value(ItemDB.make("sword")), "comerciante paga menos do que cobra")
	shop.add_item(blade)
	var saved := Inventory.from_dict(shop.to_dict())
	_check(saved.to_dict() == shop.to_dict() and saved.gold == 40, "save guarda moedas, depósito, refino e encantamentos")
	var bad := Inventory.from_dict({"equipment": {"melee": {"id": "sword", "refine": 99, "enchants": {"x": 1, "afiado": 9}}}, "gold": -5})
	_check(bad.equipment.melee.refine == ItemDB.MAX_REFINE and bad.equipment.melee.enchants == {"afiado": 3} and bad.gold == 0,
			"save adulterado é corrigido ao carregar")

	print("INVENTARIO: ", "FALHOU" if _failed else "OK")
	quit(1 if _failed else 0)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	_failed = _failed or not ok
