@tool
class_name WeaponCarry
extends RefCounted
## Porte das armas: o herói tem uma arma de corpo a corpo e uma à distância equipadas, mas só
## UMA fica na mão; a outra fica guardada no coldre dela (costas, cintura...). Bater com a de
## corpo a corpo põe ela na mão e guarda a outra; atirar faz o contrário (Player.draw_weapon).
##
## Tudo sobre onde cada arma fica está aqui:
## - HOLSTERS: os coldres que existem (osso, posição e giro no corpo parado; +Z frente, +Y cima,
##   o lado direito do personagem é -X). Para criar um novo, acrescente aqui.
## - DEFAULT_HOLSTER: coldre de cada tipo de arma (look). Arma sem tipo conhecido: corpo a corpo
##   nas costas, à distância cruzada nas costas.
## - AXIS_FIX: tipos de arma cujo modelo não fica "cabo na origem, ponta para +Y" (a besta é
##   comprida em +Z); o giro deixa ela no padrão antes de ir para o coldre.
## - Ficha do item (ItemDef): "holster" escolhe outro coldre e holster_position/holster_rotation
##   ajustam fino, como o encaixe da mão.

const WEAPON_SLOTS := ["melee", "ranged"]

const HOLSTERS := {
	# Na diagonal das costas: cabo por cima do ombro direito, ponta para o quadril esquerdo.
	"costas": ["Chest", Vector3(-0.15, 0.24, -0.17), Vector3(0, 0, -150)],
	# A outra diagonal (cruza com a de cima): cabo no ombro esquerdo.
	"costas_cruzado": ["Chest", Vector3(0.15, 0.24, -0.2), Vector3(0, 0, 150)],
	# Pendurada na cintura, ponta para baixo.
	"cintura_direita": ["Hips", Vector3(-0.19, 0.02, 0.02), Vector3(0, 0, 180)],
	"cintura_esquerda": ["Hips", Vector3(0.19, 0.02, 0.02), Vector3(0, 0, 180)],
}

const DEFAULT_HOLSTER := {
	"sword": "costas", "hammer": "costas", "axe": "cintura_esquerda", "dagger": "cintura_direita",
	"bow": "costas_cruzado", "longbow": "costas_cruzado", "crossbow": "costas_cruzado",
}

const AXIS_FIX := {
	"crossbow": Vector3(-90, 0, 0),
}

## Malhas que vêm presas em alguns modelos de personagem (o Swat e o Suit trazem uma pistola):
## escondidas, quem decide a arma é o equipamento.
const MODEL_WEAPON_MESHES := ["pistol", "gun", "rifle", "knife", "sword", "axe", "bat"]


## Coldre da arma: [osso, posição, giro], já com o ajuste da ficha. Vazio = não guarda (some).
static func holster_of(def: Dictionary) -> Array:
	var name: String = def.get("holster", "auto")
	if name == "nenhum":
		return []
	if name == "auto" or not HOLSTERS.has(name):
		name = DEFAULT_HOLSTER.get(def.get("look", ""), "costas" if def.get("slot", "") == "melee" else "costas_cruzado")
	var spot: Array = HOLSTERS[name].duplicate()
	var adjust: Array = def.get("holster_adjust", [])
	if adjust.size() == 2:
		spot[1] += adjust[0]
		spot[2] += adjust[1]
	return spot


## Giro extra do modelo para o padrão "ponta para +Y" (graus), conforme o tipo.
static func axis_fix(def: Dictionary) -> Vector3:
	return AXIS_FIX.get(def.get("look", ""), Vector3.ZERO) if not def.has("model") else Vector3.ZERO


## Mostra na mão a arma da casa `slot` e guarda a outra (no modelo já vestido por
## ItemVisuals.dress). Se a casa pedida está vazia, a outra arma vai para a mão.
static func set_drawn(model: Node, slot: String) -> void:
	if model == null:
		return
	model.set_meta("drawn_weapon", slot)
	var pieces := model.find_children("*", "BoneAttachment3D", true, false)
	var has := {}
	for piece in pieces:
		if piece.has_meta("weapon_slot"):
			has[piece.get_meta("weapon_slot")] = true
	var in_hand := slot if has.has(slot) else ("ranged" if slot == "melee" else "melee")
	for piece in pieces:
		if piece.has_meta("weapon_slot"):
			var hand: bool = piece.get_meta("weapon_pose") == "hand"
			piece.visible = hand == (piece.get_meta("weapon_slot") == in_hand)
