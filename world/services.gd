class_name Services
extends RefCounted
## Regras dos serviços do assentamento, executadas no host: sucateiro (comprar/vender),
## mecânico (upgrade = refino), hacker de chips (mods = encantamentos) e cofre (depósito). Cada comando confere que o jogador está perto de
## um NPC do serviço certo e que tem os parafusos; o resultado aparece como texto sobre o herói.
## Serviço novo = um comando novo aqui + uma aba no ServicePanel.

const MERCHANT := 0
const BLACKSMITH := 1
const ENCHANTER := 2
const BANK := 3

const OK_COLOR := Color(0.6, 1.0, 0.6)
const BAD_COLOR := Color(1.0, 0.5, 0.4)

## Comandos que são de serviço (o resto do inventário segue no Player).
const COMMANDS := ["buy", "sell", "refine", "enchant", "deposit", "withdraw"]


## Executa e retorna [deu certo, mensagem, cor].
static func run(player: Node3D, command: String, args: Array) -> Array:
	var inventory: Inventory = player.inventory
	match command:
		"buy":
			var npc := _npc(player, MERCHANT)
			if npc == null:
				return _fail("Longe do sucateiro")
			var item := npc.shop_item(int(args[0]))
			if item.is_empty():
				return _fail("Item indisponível")
			var price := ItemDB.value(item)
			if inventory.gold < price:
				return _fail("Faltam parafusos (%d)" % price)
			if inventory.add_item(item).is_empty():
				return _fail("Mochila cheia")
			inventory.spend_gold(price)
			return _ok("Comprou %s (-%d)" % [ItemDB.display_name(item), price])
		"sell":
			if _npc(player, MERCHANT) == null:
				return _fail("Longe do sucateiro")
			var item: Variant = inventory.get_item(args[0])
			if item == null or args[0] == ["eq", "bag"]:
				return _fail("Não dá para vender isso")
			if ItemDB.is_container(item) and item.contents.any(func(i: Variant) -> bool: return i != null):
				return _fail("Esvazie a bolsa antes de vender")
			inventory.remove(args[0])
			var price := ItemDB.sell_price(item)
			inventory.add_gold(price)
			return _ok("Vendeu %s (+%d)" % [ItemDB.display_name(item), price])
		"refine":
			if _npc(player, BLACKSMITH) == null:
				return _fail("Longe do mecânico")
			var item: Variant = inventory.get_item(args[0])
			if item == null or ItemDB.is_container(item) or ItemDB.slot_of(item) == "":
				return _fail("Essa peça não tem upgrade")
			if int(item.get("refine", 0)) >= ItemDB.MAX_REFINE:
				return _fail("Já está no máximo (+%d)" % ItemDB.MAX_REFINE)
			var cost := ItemDB.refine_cost(item)
			if not inventory.spend_gold(cost):
				return _fail("Faltam parafusos (%d)" % cost)
			if randf() >= ItemDB.refine_chance(item):
				return _fail("O upgrade falhou (-%d)" % cost)
			item["refine"] = int(item.get("refine", 0)) + 1
			inventory.touch()
			return _ok("%s! (-%d)" % [ItemDB.display_name(item), cost])
		"enchant":
			if _npc(player, ENCHANTER) == null:
				return _fail("Longe do hacker")
			var item: Variant = inventory.get_item(args[0])
			var enchant_id: String = args[1]
			if item == null or not ItemDB.can_enchant(item, enchant_id):
				return _fail("Esse mod não encaixa aqui")
			var cost := ItemDB.enchant_cost(item, enchant_id)
			if not inventory.spend_gold(cost):
				return _fail("Faltam parafusos (%d)" % cost)
			var enchants: Dictionary = item.get("enchants", {})
			enchants[enchant_id] = int(enchants.get(enchant_id, 0)) + 1
			item["enchants"] = enchants
			inventory.touch()
			return _ok("%s %d em %s (-%d)" % [ItemDB.ENCHANTS[enchant_id].name, enchants[enchant_id], ItemDB.display_name(item), cost])
		"deposit":
			if _npc(player, BANK) == null:
				return _fail("Longe do cofre")
			var item: Variant = inventory.get_item(args[0])
			if item == null or args[0][0] == "depot" or args[0] == ["eq", "bag"]:
				return _fail("Não dá para guardar isso")
			if not inventory.depot.contents.has(null):
				return _fail("Cofre cheio")
			inventory.add_to_depot(inventory.remove(args[0]))
			return _ok("Guardou %s" % ItemDB.display_name(item))
		"withdraw":
			if _npc(player, BANK) == null:
				return _fail("Longe do cofre")
			var item: Variant = inventory.get_item(["depot", int(args[0])])
			if item == null:
				return _fail("Casa vazia")
			if inventory.add_item(item).is_empty():
				return _fail("Mochila cheia")
			inventory.depot.contents[int(args[0])] = null
			inventory.touch()
			return _ok("Retirou %s" % ItemDB.display_name(item))
	return _fail("Comando desconhecido")


static func _npc(player: Node3D, service: int) -> WorldNpc:
	return WorldNpc.nearest(player.get_tree(), player.global_position, service, WorldNpc.TALK_RANGE + 0.6)


static func _ok(text: String) -> Array:
	return [true, text, OK_COLOR]


static func _fail(text: String) -> Array:
	return [false, text, BAD_COLOR]
