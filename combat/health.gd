class_name Health
extends Node
## Vida de qualquer coisa que apanha. O dono escuta os sinais e decide o que fazer.

signal damaged(amount: float)
signal died

@export var max_hp := 100.0

var hp := 100.0
var invulnerable := false


func _ready() -> void:
	hp = max_hp


func is_dead() -> bool:
	return hp <= 0.0


## Retorna true se o golpe contou (não estava invulnerável nem morto).
func take_hit(amount: float) -> bool:
	if invulnerable or is_dead():
		return false
	hp = maxf(hp - amount, 0.0)
	damaged.emit(amount)
	if is_dead():
		died.emit()
	return true


func heal(amount: float) -> void:
	if not is_dead():
		hp = minf(hp + amount, max_hp)


func reset(fraction := 1.0) -> void:
	hp = max_hp * fraction
