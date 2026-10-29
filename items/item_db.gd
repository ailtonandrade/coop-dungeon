class_name ItemDB
extends RefCounted
## Catálogo de itens. Um item no jogo é um Dictionary simples (vai pela rede e pro save):
##   {"id": "sword", "uid": 123, "power": 4, "rarity": "rare", "contents": [...]}
## "contents" só existe em recipientes (bolsas): um Array com null nas casas vazias.
##
## Atributos escalam com raridade e poder: valor = base x raridade x (1 + 8% por poder acima de 1).

const DEFS := {
	"dagger": {"name": "Adaga", "slot": "melee", "damage": 8.0, "look": "dagger"},
	"sword": {"name": "Espada curta", "slot": "melee", "damage": 10.0, "look": "sword"},
	"axe": {"name": "Machado de batalha", "slot": "melee", "damage": 13.0, "look": "axe"},
	"hammer": {"name": "Martelo de guerra", "slot": "melee", "damage": 15.0, "look": "hammer"},
	"bow": {"name": "Arco curto", "slot": "ranged", "damage": 8.0, "look": "bow"},
	"longbow": {"name": "Arco longo", "slot": "ranged", "damage": 11.0, "look": "longbow"},
	"crossbow": {"name": "Besta", "slot": "ranged", "damage": 14.0, "look": "crossbow"},
	"leather_hood": {"name": "Capuz de couro", "slot": "head", "armor": 3.0, "look": "hood", "color": Color(0.5, 0.33, 0.2)},
	"iron_helmet": {"name": "Elmo de ferro", "slot": "head", "armor": 6.0, "look": "helmet", "color": Color(0.68, 0.7, 0.74)},
	"leather_vest": {"name": "Gibão de couro", "slot": "chest", "armor": 5.0, "look": "vest", "color": Color(0.5, 0.33, 0.2)},
	"chainmail": {"name": "Cota de malha", "slot": "chest", "armor": 9.0, "look": "vest", "color": Color(0.55, 0.57, 0.6)},
	"plate_armor": {"name": "Peitoral de placas", "slot": "chest", "armor": 13.0, "look": "plate", "color": Color(0.8, 0.82, 0.86)},
	"leather_pants": {"name": "Calça de couro", "slot": "legs", "armor": 3.0, "look": "legs", "color": Color(0.45, 0.3, 0.18)},
	"iron_greaves": {"name": "Grevas de ferro", "slot": "legs", "armor": 6.0, "look": "legs", "color": Color(0.68, 0.7, 0.74)},
	"leather_boots": {"name": "Botas de couro", "slot": "feet", "armor": 2.0, "look": "boots", "color": Color(0.4, 0.26, 0.15)},
	"iron_boots": {"name": "Botas de ferro", "slot": "feet", "armor": 4.0, "look": "boots", "color": Color(0.68, 0.7, 0.74)},
	"life_amulet": {"name": "Amuleto da vida", "slot": "amulet", "hp": 25.0, "look": "amulet", "color": Color(0.9, 0.2, 0.3)},
	"power_ring": {"name": "Anel de força", "slot": "ring", "damage_pct": 10.0, "look": "ring", "color": Color(1.0, 0.8, 0.2)},
	"pouch": {"name": "Bolsa", "slot": "bag", "capacity": 6, "look": "pouch", "color": Color(0.55, 0.38, 0.22)},
	"backpack": {"name": "Mochila", "slot": "bag", "capacity": 12, "look": "backpack", "color": Color(0.45, 0.3, 0.18)},
	"big_backpack": {"name": "Mochila grande", "slot": "bag", "capacity": 20, "look": "backpack", "color": Color(0.32, 0.36, 0.22)},
}

const RARITIES := {
	"common": {"name": "Comum", "color": Color(0.78, 0.78, 0.78), "mult": 1.0},
	"rare": {"name": "Raro", "color": Color(0.3, 0.62, 1.0), "mult": 1.25},
	"unique": {"name": "Único", "color": Color(1.0, 0.55, 0.15), "mult": 1.5},
}

## Atributos que somam no herói, com o nome que aparece na tela.
const STATS := {
	"damage": "Dano", "armor": "Armadura", "hp": "Vida", "damage_pct": "% de dano", "capacity": "Espaços",
}

## Ordem das casas de equipamento no "boneco" 3x3 do inventário (estilo Tibia).
const EQUIP_SLOTS := ["amulet", "head", "bag", "melee", "chest", "ranged", "ring", "legs", "feet"]
const SLOT_NAMES := {
	"amulet": "Amuleto", "head": "Cabeça", "bag": "Mochila", "melee": "Corpo a corpo", "chest": "Peito",
	"ranged": "À distância", "ring": "Anel", "legs": "Pernas", "feet": "Pés",
}

## Itens que podem cair dos inimigos (bolsas incluídas).
const DROP_POOL := [
	"dagger", "sword", "axe", "hammer", "bow", "longbow", "crossbow",
	"leather_hood", "iron_helmet", "leather_vest", "chainmail", "plate_armor",
	"leather_pants", "iron_greaves", "leather_boots", "iron_boots",
	"life_amulet", "power_ring", "pouch", "backpack", "big_backpack",
]


static func make(id: String, power := 1, rarity := "common") -> Dictionary:
	var item := {"id": id, "uid": randi(), "power": power, "rarity": rarity}
	var capacity: int = DEFS[id].get("capacity", 0)
	if capacity > 0:
		var contents := []
		contents.resize(capacity)
		item["contents"] = contents
	return item


## Item aleatório para loot: quanto maior o poder, melhor; raridade por sorteio.
static func random_drop(power: int) -> Dictionary:
	var roll := randf()
	var rarity := "unique" if roll < 0.05 else ("rare" if roll < 0.25 else "common")
	return make(DROP_POOL.pick_random(), maxi(power, 1), rarity)


static func starter_kit() -> Dictionary:
	var backpack := make("backpack")
	backpack.contents[0] = make("pouch")
	backpack.contents[1] = make("leather_hood")
	return {
		"melee": make("sword"),
		"ranged": make("bow"),
		"chest": make("leather_vest"),
		"bag": backpack,
	}


static func def(item: Dictionary) -> Dictionary:
	return DEFS.get(item.get("id", ""), {})


static func is_valid(item: Variant) -> bool:
	return item is Dictionary and DEFS.has(item.get("id", ""))


static func is_container(item: Variant) -> bool:
	return item is Dictionary and item.has("contents")


static func slot_of(item: Dictionary) -> String:
	return def(item).get("slot", "")


static func display_name(item: Dictionary) -> String:
	return def(item).get("name", "?")


static func rarity_color(item: Dictionary) -> Color:
	return RARITIES.get(item.get("rarity", "common"), RARITIES.common).color


static func rarity_name(item: Dictionary) -> String:
	return RARITIES.get(item.get("rarity", "common"), RARITIES.common).name


static func stat(item: Dictionary, key: String) -> float:
	var base: float = def(item).get(key, 0.0)
	if base == 0.0 or key == "capacity":
		return base
	var mult: float = RARITIES.get(item.get("rarity", "common"), RARITIES.common).mult
	return snappedf(base * mult * (1.0 + 0.08 * (int(item.get("power", 1)) - 1)), 0.1)


## Texto com os atributos do item (um por linha).
static func describe(item: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	for key: String in STATS:
		var value := stat(item, key)
		if value != 0.0:
			lines.append("%s: %s" % [STATS[key], str(value)])
	return lines
