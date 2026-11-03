@tool
class_name QuestObjective
extends Resource
## Um objetivo de missão. Por enquanto: derrotar `amount` criaturas do tipo `target`
## (id em GameConfig.CREATURES: punk, atirador, corrompido, androide).

@export_enum("matar") var kind := "matar"
@export var target := "punk":
	set(value):
		target = value
		notify_property_list_changed()
@export_range(1, 999) var amount := 5
## Como aparece no questLog (vazio = nome da criatura).
@export var label := ""


func _validate_property(property: Dictionary) -> void:
	if property.name == "target":
		property.hint = PROPERTY_HINT_ENUM_SUGGESTION
		property.hint_string = "punk,atirador,corrompido,androide"


func text() -> String:
	return label if not label.is_empty() else String({"punk": "Bandidos de cano", "atirador": "Atiradores de pregos",
			"corrompido": "Corrompidos", "androide": "Androides de segurança"}.get(target, target))
