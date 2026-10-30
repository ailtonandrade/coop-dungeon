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

## Fichas dos itens: um arquivo ItemDef por item nesta pasta (painel "Itens" do editor).
const DEFS_DIR := "res://items/defs/"
## Moedas no chão: item interno, fora das fichas.
const GOLD := {"name": "Parafusos", "slot": "", "price": 1, "look": "coins", "color": Color(1.0, 0.82, 0.25)}

const RARITIES := {
	"common": {"name": "Sucata", "color": Color(0.78, 0.78, 0.78), "mult": 1.0},
	"rare": {"name": "Remendado", "color": Color(0.3, 0.62, 1.0), "mult": 1.25},
	"unique": {"name": "Protótipo", "color": Color(1.0, 0.55, 0.15), "mult": 1.5},
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

## Mods (instalados pelo hacker de chips; no código ainda chamados de "enchants"): até
## MAX_ENCHANTS por item, cada um até o nível MAX_ENCHANT_LEVEL. Os ids não mudam (saves).
## "stat" recebe "per_level" por nível; "slots" diz em que peças pode.
const MAX_ENCHANTS := 3
const MAX_ENCHANT_LEVEL := 3
const ENCHANTS := {
	"afiado": {"name": "Lâmina Térmica", "slots": ["melee", "ranged"], "stat": "damage_pct", "per_level": 12.0},
	"vampirico": {"name": "Drenagem", "slots": ["melee"], "stat": "lifesteal_pct", "per_level": 3.0},
	"protetor": {"name": "Blindagem", "slots": ["head", "chest", "legs", "feet"], "stat": "armor", "per_level": 3.0},
	"robusto": {"name": "Reforço", "slots": ["chest", "legs", "amulet"], "stat": "hp", "per_level": 12.0},
	"agil": {"name": "Servo-motor", "slots": ["feet", "legs"], "stat": "move_speed_pct", "per_level": 5.0},
}

## Venda ao sucateiro: esta fração do valor.
const SELL_FACTOR := 0.3

## Dinheiro do jogo (o item interno continua "gold" por causa dos saves).
const CURRENCY := "parafusos"

## Ordem das casas de equipamento no "boneco" 3x3 do inventário (estilo Tibia).
const EQUIP_SLOTS := ["amulet", "head", "bag", "melee", "chest", "ranged", "ring", "legs", "feet"]
const SLOT_NAMES := {
	"amulet": "Amuleto", "head": "Cabeça", "bag": "Mochila", "melee": "Corpo a corpo", "chest": "Peito",
	"ranged": "À distância", "ring": "Anel", "legs": "Pernas", "feet": "Pés",
}

## Onde fica a lista de pastas lidas (os testes acrescentam a pasta deles). Guardada no Engine
## e não numa variável estática: ler uma ficha recém-criada pode recompilar este script, o que
## zera as variáveis estáticas.
const DIRS_META := "item_defs_dirs"

static var _defs := {}  # id -> Dictionary (formato do jogo)
static var _sources := {}  # id -> ItemDef


## Troca as pastas lidas e relê (os testes usam para acrescentar a pasta deles).
static func use_dirs(dirs: PackedStringArray) -> void:
	Engine.set_meta(DIRS_META, dirs)
	reload()


static func defs_dirs() -> PackedStringArray:
	return Engine.get_meta(DIRS_META, PackedStringArray([DEFS_DIR]))


## Todas as fichas, já no formato do jogo (lidas na primeira vez).
static func catalog() -> Dictionary:
	if _defs.is_empty():
		reload()
	return _defs


## Relê as fichas (o painel chama depois de salvar).
static func reload() -> void:
	_defs = {"gold": GOLD}
	_sources = {}
	for dir in defs_dirs():
		if not DirAccess.dir_exists_absolute(dir):
			continue
		# Lista direto do disco (a lista do ResourceLoader guarda cache e não vê ficha recém-criada).
		# No jogo exportado as fichas aparecem como "x.tres.remap".
		for entry in DirAccess.get_files_at(dir):
			var file := entry.trim_suffix(".remap")
			if not (file.ends_with(".tres") or file.ends_with(".res")):
				continue
			# Carga normal (com cache): o painel edita e salva a própria instância do cache.
			var source := load(dir.path_join(file)) as ItemDef
			if source and not source.id.is_empty():
				_defs[source.id] = source.to_dict()
				_sources[source.id] = source


## Recalcula a ficha `id` a partir da instância em memória (o painel chama a cada mudança,
## antes de salvar, para a prévia acompanhar na hora).
static func refresh(id: String) -> void:
	var item := source(id)
	if item:
		_defs[id] = item.to_dict()


static func has(id: String) -> bool:
	return catalog().has(id)


## Ficha original (ItemDef) de um item, ou null.
static func source(id: String) -> ItemDef:
	catalog()
	return _sources.get(id)


## Ids das fichas em ordem alfabética (sem as moedas).
static func ids() -> Array:
	catalog()
	var result := _sources.keys()
	result.sort()
	return result


## Itens do sorteio geral de loot (qualquer criatura).
static func drop_pool() -> Array:
	return ids().filter(func(id: String) -> bool: return _sources[id].random_loot)


## Regras de loot de uma criatura: [[id, ItemDrop], ...].
static func creature_drops(creature: String) -> Array:
	var result := []
	for id: String in ids():
		for rule: ItemDrop in _sources[id].drops:
			if rule and rule.creature == creature:
				result.append([id, rule])
	return result


## Itens que as fichas dizem ser vendidos pela loja `shop`.
static func sold_by(shop: String) -> PackedStringArray:
	var result := PackedStringArray()
	for id: String in ids():
		if _sources[id].sold_by.has(shop):
			result.append(id)
	return result


## Resumo das fichas (entra na impressão digital do online: todos com os mesmos itens).
static func fingerprint() -> String:
	var parts := PackedStringArray()
	for id: String in ids():
		var entry: Dictionary = catalog()[id].duplicate()
		for key in ["model", "icon"]:
			if entry.has(key):
				entry[key] = (entry[key] as Resource).resource_path
		var keys := entry.keys()
		keys.sort()
		parts.append("%s{%s}" % [id, ",".join(keys.map(func(k: String) -> String: return "%s=%s" % [k, var_to_str(entry[k])]))])
		for rule: ItemDrop in _sources[id].drops:
			if rule:
				parts.append(rule.summary())
		parts.append(",".join(_sources[id].sold_by))
	return "\n".join(parts).sha256_text()




static func make(id: String, power := 1, rarity := "common") -> Dictionary:
	var item := {"id": id, "uid": randi(), "power": power, "rarity": rarity}
	var capacity: int = catalog()[id].get("capacity", 0)
	if capacity > 0:
		var contents := []
		contents.resize(capacity)
		item["contents"] = contents
	return item


## Raridade sorteada do loot: quase sempre Sucata, às vezes Remendado, raramente Protótipo.
static func random_rarity() -> String:
	var roll := randf()
	return "unique" if roll < 0.05 else ("rare" if roll < 0.25 else "common")


## Item aleatório do sorteio geral: quanto maior o poder, melhor. Vazio se não há nenhum.
static func random_drop(power: int) -> Dictionary:
	var pool := drop_pool()
	if pool.is_empty():
		return {}
	return make(pool.pick_random(), maxi(power, 1), random_rarity())


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
	return catalog().get(item.get("id", ""), {})


static func is_valid(item: Variant) -> bool:
	return item is Dictionary and catalog().has(item.get("id", ""))


static func is_container(item: Variant) -> bool:
	return item is Dictionary and item.has("contents")


static func slot_of(item: Dictionary) -> String:
	return def(item).get("slot", "")


static func display_name(item: Dictionary) -> String:
	if item.get("id") == "gold":
		return money(int(item.get("amount", 0)))
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


## "37 parafusos"
static func money(amount: int) -> String:
	return "%d %s" % [amount, CURRENCY]


static func make_gold(amount: int) -> Dictionary:
	return {"id": "gold", "uid": randi(), "amount": amount, "power": 1, "rarity": "common"}
