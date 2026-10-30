class_name Characters
extends RefCounted
## Personagens de cada máquina (até MAX): nome, visual (modelo do corpo e cor do chip pirata),
## inventário e progressão. Ficam no save da máquina (SaveService) e cada um do sofá escolhe o
## seu ao apertar Start no mundo. As regras e listas ficam aqui; o save, no SaveService.

const MAX := 5
## Modelos de corpo que o jogador pode escolher (id do arquivo em assets/characters -> nome).
## Os das criaturas (Punk, Casual_Hoodie, Casual_2) ficam de fora para não confundir.
const MODELS := {
	"Adventurer": "Andarilho",
	"Worker": "Operário",
	"Farmer": "Catador",
	"Swat": "Ex-segurança",
	"Beach": "Surfista do lixão",
	"Suit": "Ex-executivo da Sinapse",
	"King": "Rei do ferro-velho",
}
## Cor do chip pirata (luzinha na cabeça do herói).
const CHIP_COLORS: Array[Color] = [
	Color(0.2, 0.95, 1.0), Color(1.0, 0.3, 0.75), Color(1.0, 0.75, 0.2),
	Color(0.4, 1.0, 0.45), Color(1.0, 0.25, 0.2), Color(0.65, 0.4, 1.0),
]
const CHIP_COLOR_NAMES := ["ciano", "magenta", "âmbar", "verde", "vermelho", "roxo"]
const NAMES := [
	"Zé Parafuso", "Nina Solda", "Tico Fusível", "Dandara Chip", "Biu Gambiarra", "Lia Faísca",
	"Juca Sucata", "Rita Neon", "Tonho Prego", "Mari Curto", "Kiko Rebite", "Jussara Cabo",
	"Neno Pistão", "Cris Ferrugem", "Duda Bateria", "Lelo Antena",
]
const NAME_MAX := 20

## Testes e mundos sem tela de escolha: entra direto com o último personagem da vaga.
static func auto_pick() -> bool:
	return Engine.get_meta("auto_pick_character", false)


static func set_auto_pick(on: bool) -> void:
	Engine.set_meta("auto_pick_character", on)


## Ficha nova (ainda sem inventário: o jogo dá o kit inicial ao nascer).
static func create(name := "", model := "", chip_color := -1) -> Dictionary:
	return sanitize({
		"id": "%08x%06x" % [Time.get_unix_time_from_system(), randi() % 0x1000000],
		"name": name if name else random_name(),
		"model": model if model else MODELS.keys().pick_random(),
		"chip_color": chip_color if chip_color >= 0 else randi() % CHIP_COLORS.size(),
		"created_at": Time.get_unix_time_from_system(),
	})


## Confere a ficha (vinda do save ou da rede): nome limpo, modelo e cor que existem.
static func sanitize(data: Dictionary) -> Dictionary:
	var clean := data.duplicate()
	var name := String(data.get("name", "")).strip_edges().left(NAME_MAX)
	clean["name"] = name if name else "Herói"
	if not MODELS.has(data.get("model", "")):
		clean["model"] = MODELS.keys()[0]
	clean["chip_color"] = clampi(int(data.get("chip_color", 0)), 0, CHIP_COLORS.size() - 1)
	return clean


static func random_name() -> String:
	return NAMES.pick_random()


static func model_scene(model: String) -> PackedScene:
	return load("res://assets/characters/%s.glb" % (model if MODELS.has(model) else MODELS.keys()[0]))


static func chip_color(index: int) -> Color:
	return CHIP_COLORS[clampi(index, 0, CHIP_COLORS.size() - 1)]


## Nível salvo do personagem (para mostrar na lista).
static func level_of(data: Dictionary) -> int:
	return int(data.get("progress", {}).get("level", 1))


## Próximo/anterior modelo da lista (para as setas da personalização).
static func step_model(model: String, step: int) -> String:
	var keys := MODELS.keys()
	return keys[wrapi(keys.find(model) + step, 0, keys.size())]


## Chip pirata: luzinha na têmpora do herói, presa no osso da cabeça.
static func attach_chip(model: Node, color: Color) -> void:
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton: Skeleton3D = skeletons[0]
	var old := skeleton.get_node_or_null("ChipPirata")
	if old:
		old.free()
	var attachment := BoneAttachment3D.new()
	attachment.name = "ChipPirata"
	attachment.bone_name = "Head"
	skeleton.add_child(attachment)
	var chip := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.035, 0.07)
	chip.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	chip.material_override = material
	chip.position = Vector3(0.13, 0.12, 0.02)
	attachment.add_child(chip)
