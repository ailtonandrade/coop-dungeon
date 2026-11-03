@tool
extends Node3D
## Raiz da cena "Ajustar no 3D" (FitScene): ao abrir no editor, põe o herói na pose de
## referência (1º quadro do Idle), a mesma em que o jogo encaixa as peças.


func _ready() -> void:
	var anim: AnimationPlayer = find_child("AnimationPlayer", true, false)
	if anim and anim.has_animation("Idle"):
		anim.play("Idle")
		anim.seek(0.0, true)
		anim.pause()
