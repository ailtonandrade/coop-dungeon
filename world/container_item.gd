@tool
class_name ContainerItem
extends Resource
## Uma linha do conteúdo de um baú/contêiner (LootContainer): qual item, quantos, poder,
## raridade e a chance de estar lá.

@export var item_id := "sword"
@export_range(1, 99) var count := 1
## 0 = poder do perigo da região onde o baú está.
@export_range(0, 50) var power := 0
## "random" sorteia como o loot comum.
@export var rarity := "random"
@export_range(0.0, 100.0, 0.1, "suffix:%") var chance := 100.0


func _validate_property(property: Dictionary) -> void:
	match property.name:
		"item_id":
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = ",".join(ItemDB.ids())
		"rarity":
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = "random,common,rare,unique"
