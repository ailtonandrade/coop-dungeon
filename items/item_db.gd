class_name ItemDB
extends RefCounted
## Catálogo de itens. Um item no jogo é um Dictionary simples (vai pela rede e pro save):
##   {"id": "sword", "uid": 123, "power": 4, "rarity": "rare", "refine": 2,
##    "enchants": {"afiado": 1}, "contents": [...]}
## "contents" só existe em recipientes (bolsas): um Array com null nas casas vazias.
## Moedas no chão são o item especial "gold", com "amount".
##
## Atributos escalam com raridade, poder e refino:
##   valor = base x raridade x (1 + 8% por poder acima de 1) x (1 + 10% por nível de refino)
## e os encantamentos somam por cima (cada um num atributo, por nível).

const DEFS := {
	"dagger": {"name": "Adaga", "slot": "melee", "price": 20, "damage": 8.0, "look": "dagger"},
	"sword": {"name": "Espada curta", "slot": "melee", "price": 35, "damage": 10.0, "look": "sword"},
	"axe": {"name": "Machado de batalha", "slot": "melee", "price": 50, "damage": 13.0, "look": "axe"},
	"hammer": {"name": "Martelo de guerra", "slot": "melee", "price": 65, "damage": 15.0, "look": "hammer"},
	"bow": {"name": "Arco curto", "slot": "ranged", "price": 30, "damage": 8.0, "look": "bow"},
	"longbow": {"name": "Arco longo", "slot": "ranged", "price": 50, "damage": 11.0, "look": "longbow"},
	"crossbow": {"name": "Besta", "slot": "ranged", "price": 70, "damage": 14.0, "look": "crossbow"},
	"leather_hood": {"name": "Capuz de couro", "slot": "head", "price": 15, "armor": 3.0, "look": "hood", "color": Color(0.5, 0.33, 0.2)},
	"iron_helmet": {"name": "Elmo de ferro", "slot": "head", "price": 40, "armor": 6.0, "look": "helmet", "color": Color(0.68, 0.7, 0.74)},
	"leather_vest": {"name": "Gibão de couro", "slot": "chest", "price": 25, "armor": 5.0, "look": "vest", "color": Color(0.5, 0.33, 0.2)},
	"chainmail": {"name": "Cota de malha", "slot": "chest", "price": 55, "armor": 9.0, "look": "vest", "color": Color(0.55, 0.57, 0.6)},
	"plate_armor": {"name": "Peitoral de placas", "slot": "chest", "price": 90, "armor": 13.0, "look": "plate", "color": Color(0.8, 0.82, 0.86)},
	"leather_pants": {"name": "Calça de couro", "slot": "legs", "price": 15, "armor": 3.0, "look": "legs", "color": Color(0.45, 0.3, 0.18)},
	"iron_greaves": {"name": "Grevas de ferro", "slot": "legs", "price": 40, "armor": 6.0, "look": "legs", "color": Color(0.68, 0.7, 0.74)},
	"leather_boots": {"name": "Botas de couro", "slot": "feet", "price": 12, "armor": 2.0, "look": "boots", "color": Color(0.4, 0.26, 0.15)},
	"iron_boots": {"name": "Botas de ferro", "slot": "feet", "price": 30, "armor": 4.0, "look": "boots", "color": Color(0.68, 0.7, 0.74)},
	"life_amulet": {"name": "Amuleto da vida", "slot": "amulet", "price": 80, "hp": 25.0, "look": "amulet", "color": Color(0.9, 0.2, 0.3)},
	"power_ring": {"name": "Anel de força", "slot": "ring", "price": 80, "damage_pct": 10.0, "look": "ring", "color": Color(1.0, 0.8, 0.2)},
	"pouch": {"name": "Bolsa", "slot": "bag", "price": 20, "capacity": 6, "look": "pouch", "color": Color(0.55, 0.38, 0.22)},
	"backpack": {"name": "Mochila", "slot": "bag", "price": 45, "capacity": 12, "look": "backpack", "color": Color(0.45, 0.3, 0.18)},
	"big_backpack": {"name": "Mochila grande", "slot": "bag", "price": 90, "capacity": 20, "look": "backpack", "color": Color(0.32, 0.36, 0.22)},
	"gold": {"name": "Moedas", "slot": "", "price": 1, "look": "coins", "color": Color(1.0, 0.82, 0.25)},
}

const RARITIES := {
	"common": {"name": "Comum", "color": Color(0.78, 0.78, 0.78), "mult": 1.0},
	"rare": {"name": "Raro", "color": Color(0.3, 0.62, 1.0), "mult": 1.25},
	"unique": {"name": "Único", "color": Color(1.0, 0.55, 0.15), "mult": 1.5},
}

## Atributos que somam no herói, com o nome que aparece na tela.
const STATS := {
	"damage": "Dano", "armor": "Armadura", "hp": "Vida", "damage_pct": "% de dano",
	"lifesteal_pct": "% de roubo de vida", "move_speed_pct": "% de velocidade", "capacity": "Espaços",
}

## Refino (ferreiro): até +9. Chance de dar certo ao ir para cada nível (índice = nível atual).
## Falhar gasta as moedas mas não estraga o item.
const MAX_REFINE := 9
const REFINE_CHANCE := [1.0, 1.0, 1.0, 0.8, 0.65, 0.5, 0.4, 0.3, 0.2]
const REFINE_BONUS := 0.1

## Encantamentos (encantador): até MAX_ENCHANTS por item, cada um até o nível MAX_ENCHANT_LEVEL.
## "stat" recebe "per_level" por nível; "slots" diz em que peças pode.
const MAX_ENCHANTS := 3
const MAX_ENCHANT_LEVEL := 3
const ENCHANTS := {
	"afiado": {"name": "Afiado", "slots": ["melee", "ranged"], "stat": "damage_pct", "per_level": 12.0},
	"vampirico": {"name": "Vampírico", "slots": ["melee"], "stat": "lifesteal_pct", "per_level": 3.0},
	"protetor": {"name": "Protetor", "slots": ["head", "chest", "legs", "feet"], "stat": "armor", "per_level": 3.0},
	"robusto": {"name": "Robusto", "slots": ["chest", "legs", "amulet"], "stat": "hp", "per_level": 12.0},
	"agil": {"name": "Ágil", "slots": ["feet", "legs"], "stat": "move_speed_pct", "per_level": 5.0},
}

## Venda ao comerciante: esta fração do valor.
const SELL_FACTOR := 0.3

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
	if item.get("id") == "gold":
		return "%d moedas" % int(item.get("amount", 0))
	var refine := int(item.get("refine", 0))
	return def(item).get("name", "?") + (" +%d" % refine if refine > 0 else "")


static func rarity_color(item: Dictionary) -> Color:
	return RARITIES.get(item.get("rarity", "common"), RARITIES.common).color


static func rarity_name(item: Dictionary) -> String:
	return RARITIES.get(item.get("rarity", "common"), RARITIES.common).name


static func stat(item: Dictionary, key: String) -> float:
	var base: float = def(item).get(key, 0.0)
	if key == "capacity":
		return base
	var value := 0.0
	if base != 0.0:
		var mult: float = RARITIES.get(item.get("rarity", "common"), RARITIES.common).mult
		value = base * mult * (1.0 + 0.08 * (int(item.get("power", 1)) - 1)) \
				* (1.0 + REFINE_BONUS * int(item.get("refine", 0)))
	var enchants: Dictionary = item.get("enchants", {})
	for enchant_id: String in enchants:
		var enchant: Dictionary = ENCHANTS.get(enchant_id, {})
		if enchant.get("stat") == key:
			value += float(enchant.per_level) * int(enchants[enchant_id])
	return snappedf(value, 0.1)


## Quanto o item vale (o comerciante vende por isso e compra por SELL_FACTOR disso).
static func value(item: Dictionary) -> int:
	if item.get("id") == "gold":
		return int(item.get("amount", 0))
	var mult: float = RARITIES.get(item.get("rarity", "common"), RARITIES.common).mult
	var enchant_levels := 0
	for level: int in item.get("enchants", {}).values():
		enchant_levels += level
	return int(def(item).get("price", 0) * mult * mult * (1.0 + 0.2 * (int(item.get("power", 1)) - 1))
			* (1.0 + 0.25 * int(item.get("refine", 0)))) + enchant_levels * 30


static func sell_price(item: Dictionary) -> int:
	return maxi(1, int(value(item) * SELL_FACTOR))


static func refine_cost(item: Dictionary) -> int:
	var next := int(item.get("refine", 0)) + 1
	return int(20 * next * next * (1.0 + 0.1 * int(item.get("power", 1))))


static func refine_chance(item: Dictionary) -> float:
	var level := int(item.get("refine", 0))
	return REFINE_CHANCE[level] if level < MAX_REFINE else 0.0


## Encantamentos que cabem nesse item (pela casa dele).
static func enchants_for(item: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for enchant_id: String in ENCHANTS:
		if slot_of(item) in ENCHANTS[enchant_id].slots:
			result.append(enchant_id)
	return result


## Pode pôr (ou subir) esse encantamento? Máximo de encantamentos e de nível.
static func can_enchant(item: Dictionary, enchant_id: String) -> bool:
	if enchant_id not in enchants_for(item):
		return false
	var enchants: Dictionary = item.get("enchants", {})
	if enchants.has(enchant_id):
		return int(enchants[enchant_id]) < MAX_ENCHANT_LEVEL
	return enchants.size() < MAX_ENCHANTS


static func enchant_cost(item: Dictionary, enchant_id: String) -> int:
	var next := int(item.get("enchants", {}).get(enchant_id, 0)) + 1
	return int(60 * next * (1.0 + 0.1 * int(item.get("power", 1))))


## Texto com os atributos do item (um por linha), mais encantamentos.
static func describe(item: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	for key: String in STATS:
		var amount := stat(item, key)
		if amount != 0.0:
			lines.append("%s: %s" % [STATS[key], str(amount)])
	var enchants: Dictionary = item.get("enchants", {})
	for enchant_id: String in enchants:
		lines.append("%s %d" % [ENCHANTS.get(enchant_id, {}).get("name", enchant_id), int(enchants[enchant_id])])
	return lines


static func make_gold(amount: int) -> Dictionary:
	return {"id": "gold", "uid": randi(), "amount": amount, "power": 1, "rarity": "common"}
