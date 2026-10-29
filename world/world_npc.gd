class_name WorldNpc
extends Node3D
## Personagem fixo do mapa que presta um serviço (comerciante, ferreiro, encantador, banco).
## Fica sempre no mesmo lugar, para o jogador aprender onde encontrar cada serviço.
## Por enquanto só aparece com o nome; a tela de cada serviço vem no marco M9.

enum Service { MERCHANT, BLACKSMITH, ENCHANTER, BANK }

const SERVICE_NAMES := {
	Service.MERCHANT: "Comerciante", Service.BLACKSMITH: "Ferreiro (refino)",
	Service.ENCHANTER: "Encantador", Service.BANK: "Banco",
}

@export var service := Service.MERCHANT
@export var npc_name := ""
@export var model: PackedScene


func _ready() -> void:
	add_to_group("npcs")
	if model:
		var body := model.instantiate()
		var pivot := Node3D.new()
		pivot.rotation.y = PI  # modelos olham para +Z; a frente do jogo é -Z
		add_child(pivot)
		pivot.add_child(body)
		CharacterAnimator.new(body, AnimSets.HUMANOID).play("idle")
	var label := Label3D.new()
	label.text = "%s\n%s" % [npc_name, SERVICE_NAMES[service]] if npc_name else SERVICE_NAMES[service]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 30
	label.outline_size = 8
	label.modulate = Color(0.75, 1.0, 0.75)
	label.layers = 2
	label.position.y = 2.5
	add_child(label)
