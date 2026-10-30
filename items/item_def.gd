@tool
class_name ItemDef
extends Resource
## Ficha de um item (arma, armadura, bolsa...): um arquivo por item em items/defs/<id>.tres.
## Editada no painel "Itens" do editor (addons/item_editor) junto com o Inspector.
## O jogo lê todas pelo ItemDB e usa o Dictionary de sempre (to_dict); o item que vai pela
## rede e pro save continua só com o id, então mudar a ficha muda o item em todo lugar.

## Desenhos prontos: dão o ícone (quando não há ícone próprio), o modelo provisório de blocos
## (quando não há modelo 3D) e o encaixe padrão no corpo.
const LOOKS := ["sword", "dagger", "axe", "hammer", "bow", "longbow", "crossbow", "hood", "helmet",
		"vest", "plate", "legs", "boots", "amulet", "ring", "pouch", "backpack"]
## Ossos do esqueleto dos personagens (Quaternius) onde dá para prender uma peça.
const BONES := ["Wrist.R", "Wrist.L", "LowerArm.R", "LowerArm.L", "UpperArm.R", "UpperArm.L",
		"Shoulder.R", "Shoulder.L", "Head", "Neck", "Chest", "Torso", "Abdomen", "Hips",
		"UpperLeg.R", "UpperLeg.L", "LowerLeg.R", "LowerLeg.L", "Foot.R", "Foot.L"]
const STAT_FIELDS := ["damage", "armor", "hp", "damage_pct", "lifesteal_pct", "move_speed_pct", "capacity"]

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
@export_range(0.05, 10.0, 0.01) var model_scale := 1.0
## Tamanho a mais quando está no chão (loot).
@export_range(0.1, 5.0, 0.01) var ground_scale := 1.0
## Liga o encaixe abaixo; desligado = encaixe padrão do tipo (look).
@export var custom_mount := false
@export var mount_bone := "Wrist.R"
## Posição relativa ao osso, com o corpo parado (metros; +Z frente, +Y cima).
@export var mount_position := Vector3.ZERO
@export var mount_rotation := Vector3.ZERO


## Formato que o jogo usa (ItemDB.def).
func to_dict() -> Dictionary:
	var result := {"name": display_name, "slot": slot, "price": price, "look": look, "color": color}
	for stat: String in STAT_FIELDS:
		var value: Variant = get(stat)
		if value != 0:
			result[stat] = value
	if icon:
		result["icon"] = icon
	if model:
		result["model"] = model
		result["model_scale"] = model_scale
	if ground_scale != 1.0:
		result["ground_scale"] = ground_scale
	if custom_mount:
		result["mount"] = [mount_bone, mount_position, mount_rotation]
	return result


func _validate_property(property: Dictionary) -> void:
	match property.name:
		"slot":
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = ",".join(ItemDB.EQUIP_SLOTS)
		"look":
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = ",".join(LOOKS)
		"mount_bone":
			property.hint = PROPERTY_HINT_ENUM_SUGGESTION
			property.hint_string = ",".join(BONES)
		"sold_by":
			if not known_shops().is_empty():
				property.hint = PROPERTY_HINT_TYPE_STRING
				property.hint_string = "%d/%d:%s" % [TYPE_STRING, PROPERTY_HINT_ENUM_SUGGESTION, ",".join(known_shops())]
