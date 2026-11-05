class_name BaseCatalog
extends RefCounted
## Receitas da base do jogador (modo de construção, /construir): o que cada uma faz, em que
## nível do herói libera e quanto custa. Estruturas (piso, parede, porta, teto) são feitas no
## material escolhido (metal, madeira ou fibra de vidro); móveis têm custo fixo.
## Materiais são contadores do herói (Inventory.ammo, tipos com "material" em ItemDB.AMMO_TYPES):
## caem das criaturas e dos baús/contêineres do mapa.

const MATERIALS := ["madeira", "metal", "fibra"]

## Grade das peças (m), altura da parede e raio da área do terminal.
const GRID := 3.0
const WALL_HEIGHT := 2.8
const FLOOR_HEIGHT := 0.12
const BASE_RADIUS := 15.0
## Longe das cidades: distância mínima de qualquer NPC e de outra base.
const TOWN_DISTANCE := 40.0

## id -> nome, nível, tipo, custo. Custo de estrutura = unidades do material escolhido.
const RECIPES := {
	"terminal": {"name": "Terminal de base", "level": 3, "kind": "terminal", "cost": {"metal": 10, "fibra": 4}},
	"piso": {"name": "Piso", "level": 3, "kind": "floor", "per_material": 4},
	"parede": {"name": "Parede", "level": 3, "kind": "wall", "per_material": 4},
	"porta": {"name": "Parede com porta", "level": 3, "kind": "door", "per_material": 3},
	"cama": {"name": "Cama", "level": 3, "kind": "bed", "cost": {"madeira": 6, "fibra": 2}},
	"teto": {"name": "Teto", "level": 5, "kind": "roof", "per_material": 4},
	"luminaria": {"name": "Luminária", "level": 5, "kind": "lamp", "cost": {"metal": 2, "fibra": 2}},
	"bau": {"name": "Baú", "level": 7, "kind": "chest", "cost": {"madeira": 6, "metal": 2}},
}
## Ordem no modo de construção.
const ORDER := ["terminal", "piso", "parede", "porta", "teto", "cama", "luminaria", "bau"]


static func is_structure(recipe: String) -> bool:
	return RECIPES.get(recipe, {}).has("per_material")


## Custo da receita no material escolhido: {"madeira": 4}.
static func cost(recipe: String, material: String) -> Dictionary:
	var entry: Dictionary = RECIPES.get(recipe, {})
	if entry.has("per_material"):
		return {material: int(entry.per_material)}
	return entry.get("cost", {})


## Receitas que o herói desse nível já sabe, na ordem do modo de construção.
static func unlocked(level: int) -> Array:
	return ORDER.filter(func(id: String) -> bool: return level >= int(RECIPES[id].level))


## Receitas que liberam exatamente neste nível (aviso ao subir).
static func new_at(level: int) -> Array:
	return ORDER.filter(func(id: String) -> bool: return int(RECIPES[id].level) == level)


static func recipe_name(recipe: String) -> String:
	return Txt.t(RECIPES.get(recipe, {}).get("name", recipe))


static func cost_text(costs: Dictionary) -> String:
	var parts := PackedStringArray()
	for material: String in costs:
		parts.append("%d %s" % [costs[material], ItemDB.ammo_name(material).to_lower()])
	return ", ".join(parts)


static func can_afford(inventory: Inventory, costs: Dictionary) -> bool:
	for material: String in costs:
		if inventory.ammo_of(material) < int(costs[material]):
			return false
	return true


static func pay(inventory: Inventory, costs: Dictionary) -> void:
	for material: String in costs:
		inventory.ammo[material] = inventory.ammo_of(material) - int(costs[material])
	inventory.touch()
