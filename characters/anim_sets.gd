class_name AnimSets
extends RefCounted
## Mapas de animação por tipo de corpo. O jogo pede AÇÕES ("move", "attack", "hit"...)
## e cada tipo de criatura diz quais clipes do modelo dela fazem cada ação, com alternativas
## em ordem (usa a primeira que o modelo tiver). Um cachorro, um rato ou um dragão ganham
## o próprio mapa (e o próprio esqueleto), sem mexer no código do herói nem da IA.
##
## "rig" identifica o esqueleto. Só o esqueleto humano dos modelos atuais recebe as
## animações montadas por código (ProceduralAnims); outros usam só os clipes do modelo.
## "loop" lista as ações que repetem.

const HUMANOID := {
	"rig": "quaternius_humanoid",
	"loop": ["idle", "idle_aim", "move", "move_back", "move_left", "move_right", "move_shoot", "fall"],
	"actions": {
		"idle": ["Idle"],
		"idle_aim": ["Idle_Gun_Pointing", "Idle"],
		"move": ["Run"],
		"move_back": ["Run_Back", "Run"],
		"move_left": ["Run_Left", "Run"],
		"move_right": ["Run_Right", "Run"],
		"move_shoot": ["Run_Shoot", "Run"],
		"jump": ["Jump"],
		"fall": ["Fall", "Jump"],
		"climb": ["Climb", "Interact"],
		"roll": ["Roll"],
		"slash": ["Sword_Slash", "Punch_Right"],
		"shoot": ["Gun_Shoot", "Interact"],
		"punch": ["Punch_Right"],
		"hit": ["HitRecieve", "HitRecieve_2"],
		"death": ["Death"],
	},
}

## Exemplo de como fica um quadrúpede (cachorro, lobo, rato) quando entrar um modelo dele:
## os nomes dos clipes dependem do pacote; ajuste para o que o modelo trouxer.
const QUADRUPED := {
	"rig": "quadruped",
	"loop": ["idle", "move"],
	"actions": {
		"idle": ["Idle"],
		"move": ["Gallop", "Run", "Walk"],
		"punch": ["Attack", "Bite", "Headbutt"],
		"hit": ["HitReact", "Hit"],
		"death": ["Death"],
	},
}
