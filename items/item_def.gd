@tool
class_name ItemDef
extends Resource
## Ficha de um item (arma, armadura, bolsa...): um arquivo por item em items/defs/<id>.tres.
## Editada no painel "Itens" do editor (addons/item_editor) junto com o Inspector.
## O jogo lê todas pelo ItemDB e usa o Dictionary de sempre (to_dict); o item que vai pela
## rede e pro save continua só com o id, então mudar a ficha muda o item em todo lugar.

## Desenhos prontos: dão o ícone (quando não há ícone próprio), o modelo provisório de blocos
## (quando não há modelo 3D) e o encaixe padrão no corpo.
const LOOKS := ["sword", "dagger", "axe", "hammer", "bow", "longbow", "crossbow", "pistol", "rifle", "shotgun",
		"hood", "helmet", "vest", "plate", "legs", "boots", "amulet", "ring", "pouch", "backpack", "ammo_box", "grenade"]
## Ossos do esqueleto dos personagens (Quaternius) onde dá para prender uma peça.
const BONES := ["Wrist.R", "Wrist.L", "LowerArm.R", "LowerArm.L", "UpperArm.R", "UpperArm.L",
		"Shoulder.R", "Shoulder.L", "Head", "Neck", "Chest", "Torso", "Abdomen", "Hips",
		"UpperLeg.R", "UpperLeg.L", "LowerLeg.R", "LowerLeg.L", "Foot.R", "Foot.L"]
const STAT_FIELDS := ["damage", "armor", "hp", "damage_pct", "lifesteal_pct", "move_speed_pct", "capacity",
		"potion_heal_pct", "potion_cd_pct"]

## Lojas que existem no mapa (o painel preenche ao abrir), para a lista de "vendido por".
## Guardada no Engine (variável estática zera quando o script recompila).
static func known_shops() -> PackedStringArray:
	return Engine.get_meta("item_known_shops", PackedStringArray())


static func set_known_shops(shops: PackedStringArray) -> void:
	Engine.set_meta("item_known_shops", shops)

@export_group("Item")
## Identificador fixo (nome do arquivo e o que vai no save). Não mude depois de lançar.
@export var id := ""
@export var display_name := ""
@export var slot := "melee"
@export var look := "sword"
## Habilidade que esta arma treina e usa; vazio = pelo tipo de desenho (look).
@export var skill := ""
## Cor do modelo provisório e da pintura no corpo (peito, pernas, pés).
@export var color := Color(0.72, 0.74, 0.78)
## Preço base no comerciante (sobe com poder, raridade e refino).
@export_range(0, 100000) var price := 20
## Ícone do inventário; vazio = desenho do tipo (look). O painel gera a partir do modelo.
@export var icon: Texture2D

@export_group("Atributos (poder 1, Sucata)")
@export var damage := 0.0
@export var armor := 0.0
@export var hp := 0.0
@export var damage_pct := 0.0
@export var lifesteal_pct := 0.0
@export var move_speed_pct := 0.0
## Poção: mais cura (%) e menos recarga (%).
@export var potion_heal_pct := 0.0
@export var potion_cd_pct := 0.0
## Bolsas: quantas casas.
@export_range(0, 40) var capacity := 0

@export_group("Onde conseguir")
## NPCs comerciantes que vendem (nome da loja = shop_id do NPC, ou o nome dele).
@export var sold_by: Array[String] = []
## Pode cair de qualquer criatura no sorteio geral de loot.
@export var random_loot := true
## Criaturas que deixam cair este item, com chance, quantidade e raridade.
@export var drops: Array[ItemDrop] = []

@export_group("Modelo 3D")
## Cena importada (.glb, .gltf, .fbx, .obj, .blend). Vazio = modelo provisório de blocos.
## Armas: cabo na origem e ponta para +Y; 1 unidade = 1 metro.
@export var model: PackedScene
## Correção do próprio modelo (vale na mão, no chão e no ícone): tamanho, giro e posição.
## O botão "Ajuste automático" do painel calcula isso para modelos grandes ou tortos.
@export_range(0.001, 100.0, 0.001, "or_greater") var model_scale := 1.0
@export var model_rotation := Vector3.ZERO
@export var model_offset := Vector3.ZERO
## Vestir no corpo: o modelo tem ossos com os mesmos nomes do esqueleto dos personagens
## (feito no Blender sobre o esqueleto Quaternius) e dobra junto com as animações. Desligado,
## a peça vai presa num osso (rígida).
@export var wear_on_body := false
## Esconde a parte do corpo do personagem que fica por baixo da peça (para não vazar).
@export_flags("Tronco", "Pernas", "Pés") var hide_body := 0
## Tamanho a mais quando está no chão (loot).
@export_range(0.1, 5.0, 0.01) var ground_scale := 1.0
## Liga o encaixe abaixo; desligado = encaixe padrão do tipo (look).
@export var custom_mount := false
@export var mount_bone := "Wrist.R"
## Posição relativa ao osso, com o corpo parado (metros; +Z frente, +Y cima).
@export var mount_position := Vector3.ZERO
@export var mount_rotation := Vector3.ZERO

@export_group("Arma de longe")
## Munição que a arma gasta (ItemDB.AMMO_TYPES: pregos, 9mm, rifle, escopeta). Vazio = infinita.
@export var ammo := ""
## Segundos entre um tiro e outro (cadência).
@export_range(0.05, 3.0, 0.01, "suffix:s") var fire_interval := 0.45
## Projéteis por tiro (escopeta solta vários chumbos; o dano se divide entre eles).
@export_range(1, 12) var pellets := 1
## Abertura do leque dos chumbos (graus).
@export_range(0.0, 45.0, 0.5) var spread_deg := 0.0
## Velocidade do projétil (m/s; 0 = padrão).
@export_range(0.0, 150.0, 1.0) var projectile_speed := 0.0
## Alcance (segundos de voo; 0 = padrão, 3 s). Chumbo de escopeta voa pouco.
@export_range(0.0, 3.0, 0.05, "suffix:s") var projectile_life := 0.0
## Desenho do projétil.
@export_enum("prego", "bala", "chumbo") var projectile := "prego"
## Som do disparo (evento do SoundBank).
@export var shot_sound := "shot"

@export_group("Munição (item que vira munição ao pegar ou comprar)")
## Tipo de munição que este item dá (vazio = não é munição). Granada também entra aqui.
@export var ammo_type := ""
## Quantas unidades vêm na caixa (na loja; no loot vem menos).
@export_range(0, 999) var ammo_amount := 0

@export_group("Porte (arma guardada)")
## Onde a arma fica quando não está na mão (WeaponCarry.HOLSTERS). "auto" = o padrão do tipo.
@export_enum("auto", "costas", "costas_cruzado", "cintura_direita", "cintura_esquerda", "nenhum") var holster := "auto"
## Ajuste fino do coldre (somado ao do coldre escolhido).
@export var holster_position := Vector3.ZERO
@export var holster_rotation := Vector3.ZERO


## Formato que o jogo usa (ItemDB.def).
func to_dict() -> Dictionary:
	var result := {"name": display_name, "slot": slot, "price": price, "look": look, "color": color}
	if not skill.is_empty():
		result["skill"] = skill
	for stat: String in STAT_FIELDS:
		var value: Variant = get(stat)
		if value != 0:
			result[stat] = value
	if icon:
		result["icon"] = icon
	if model:
		result["model"] = model
		result["model_scale"] = model_scale
		if model_rotation != Vector3.ZERO:
			result["model_rotation"] = model_rotation
		if model_offset != Vector3.ZERO:
			result["model_offset"] = model_offset
		if wear_on_body:
			result["wear"] = true
	if hide_body:
		var parts := []
		for i in 3:
			if hide_body & (1 << i):
				parts.append(["body", "legs", "feet"][i])
		result["hide_body"] = parts
	if ground_scale != 1.0:
		result["ground_scale"] = ground_scale
	if custom_mount:
		result["mount"] = [mount_bone, mount_position, mount_rotation]
	if slot == "ranged":
		result["ammo"] = ammo
		result["fire_interval"] = fire_interval
		result["pellets"] = pellets
		result["spread_deg"] = spread_deg
		result["projectile_speed"] = projectile_speed
		result["projectile_life"] = projectile_life
		result["projectile"] = projectile
		result["shot_sound"] = shot_sound
	if not ammo_type.is_empty():
		result["ammo_type"] = ammo_type
		result["ammo_amount"] = ammo_amount
	if holster != "auto":
		result["holster"] = holster
	if holster_position != Vector3.ZERO or holster_rotation != Vector3.ZERO:
		result["holster_adjust"] = [holster_position, holster_rotation]
	return result


func _validate_property(property: Dictionary) -> void:
	match property.name:
		"slot":
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = ",".join(ItemDB.EQUIP_SLOTS + ["municao"])
		"look":
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = ",".join(LOOKS)
		"skill":
			property.hint = PROPERTY_HINT_ENUM_SUGGESTION
			property.hint_string = ",laminas,machados,impacto,disparo"
		"ammo":
			property.hint = PROPERTY_HINT_ENUM_SUGGESTION
			property.hint_string = ",pregos,9mm,rifle,escopeta"
		"ammo_type":
			property.hint = PROPERTY_HINT_ENUM_SUGGESTION
			property.hint_string = ",pregos,9mm,rifle,escopeta,granada"
		"mount_bone":
			property.hint = PROPERTY_HINT_ENUM_SUGGESTION
			property.hint_string = ",".join(BONES)
		"sold_by":
			if not known_shops().is_empty():
				property.hint = PROPERTY_HINT_TYPE_STRING
				property.hint_string = "%d/%d:%s" % [TYPE_STRING, PROPERTY_HINT_ENUM_SUGGESTION, ",".join(known_shops())]
