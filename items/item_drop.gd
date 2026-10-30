@tool
class_name ItemDrop
extends Resource
## Regra de loot de um item numa criatura: "o Bandido deixa cair 1 a 2 deste, 10% das vezes,
## sempre Remendado". Fica na ficha do item (ItemDef.drops).

const RARITY_CHOICES := ["random", "common", "rare", "unique"]

## Id da criatura (GameConfig.CREATURES).
@export var creature := "punk"
## Chance de cair a cada criatura morta.
@export_range(0.0, 100.0, 0.1, "suffix:%") var chance := 10.0
@export_range(1, 99) var min_count := 1
@export_range(1, 99) var max_count := 1
## "random" sorteia como o loot comum (Sucata, às vezes Remendado ou Protótipo).
@export var rarity := "random"
## Soma no poder do item (o poder base é o da criatura, que vem do perigo da região).
@export_range(-5, 20) var power_bonus := 0


func roll_rarity() -> String:
	return ItemDB.random_rarity() if rarity == "random" else rarity


func roll_count() -> int:
	return randi_range(min_count, maxi(min_count, max_count))


func summary() -> String:
	var who: String = GameConfig.CREATURES.get(creature, creature)
	var count := str(min_count) if max_count <= min_count else "%d-%d" % [min_count, max_count]
	var kind: String = "raridade sorteada" if rarity == "random" else ItemDB.RARITIES.get(rarity, {}).get("name", rarity)
	return "%s · %s%% · %s un. · %s" % [who, str(snappedf(chance, 0.1)), count, kind]


func _validate_property(property: Dictionary) -> void:
	match property.name:
		"creature":
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = ",".join(GameConfig.CREATURES.keys())
		"rarity":
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = ",".join(RARITY_CHOICES)
