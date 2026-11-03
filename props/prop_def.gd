@tool
class_name PropDef
extends Resource
## Ficha de uma peça do cenário (poste, cone, carcaça de carro, caixa d'água...): de que modelo
## 3D ela é feita e como se comporta no jogo. O editor de mapa ("Importar objeto 3D") cria a
## ficha e, a partir dela, a peça pronta em world/prefabs (PropBuilder), que aparece na lista
## de peças, no carimbo e no modo construtor dentro do jogo.

const KINDS := ["fixo", "conteiner", "fisico", "atravessavel", "estrutura"]
const KIND_NAMES := {
	"fixo": "Fixo (sólido, ninguém mexe)",
	"estrutura": "Estrutura (parede, piso, telhado: encaixa na vizinha)",
	"conteiner": "Contêiner (abre e solta itens)",
	"fisico": "Físico (cai, rola, dá para empurrar)",
	"atravessavel": "Atravessável (enfeite, sem colisão)",
}

## Nome do arquivo da peça (sem espaços). Não mude depois de usar no mapa.
@export var id := ""
@export var display_name := ""
## Modelo: cena (.glb/.gltf/.fbx importados) ou malha (.obj).
@export var model: Resource
@export_enum("fixo", "conteiner", "fisico", "atravessavel", "estrutura") var kind := "fixo"
## Tamanho e giro do modelo dentro da peça (a base sempre fica no chão).
@export_range(0.01, 100.0, 0.01, "or_greater") var scale := 1.0
@export var rotation_deg := Vector3.ZERO

@export_group("Físico")
@export_range(0.1, 2000.0, 0.1, "suffix:kg") var mass := 10.0

@export_group("Contêiner")
@export var container_title := "Caixa"
@export_range(0, 100000) var gold := 0
@export_range(0, 10) var random_items := 1


## Peças de prédio nos packs (paredes, pisos, telhados, colunas...) viram "estrutura" sozinhas.
const STRUCTURE_WORDS := ["wall", "brick", "floor", "roof", "column", "cornice", "trim", "door", "window",
	"stairs", "sidewalk", "street", "entrance", "metal_plain", "metal_full", "metal_first", "building", "parede", "piso", "telhado"]


static func looks_structural(model_name: String) -> bool:
	var lower := model_name.to_lower()
	for word: String in STRUCTURE_WORDS:
		if lower.contains(word):
			return true
	return false


func kind_name() -> String:
	return KIND_NAMES.get(kind, kind)
