extends SceneTree
## Teste da lógica do inventário (sem fase). Rodar:
## godot --headless --path coop-dungeon -s tests/inventory_test.gd

var _failed := false


func _initialize() -> void:
	var inv := Inventory.starter()
	_check(inv.equipment.has("melee") and inv.equipment.has("bag"), "kit inicial tem arma e mochila")
	_check(ItemDB.display_name(inv.get_item(["bag", 0])) == "Bolsa", "bolsa dentro da mochila")

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

	print("INVENTARIO: ", "FALHOU" if _failed else "OK")
	quit(1 if _failed else 0)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	_failed = _failed or not ok
