class_name Graphics
extends RefCounted
## Qualidade gráfica desta máquina (Settings.graphics_quality): sombra do sol, antisserrilhado,
## resolução 3D, brilho do neon e até onde se enxerga objetos pequenos e criaturas.
## Na primeira vez a qualidade vem da placa (suggested_quality): integrada começa na baixa.
##
## O que mais pesa no mundo é a quantidade de coisas desenhadas (cada personagem tem ~13
## partes, e os 9 blocos carregados têm dezenas de criaturas). Objetos pequenos (até
## SMALL_SIZE metros) somem além do alcance de visão; chão e casas grandes ficam sempre.

const LEVELS := ["baixa", "media", "alta"]
const LABELS := {"baixa": "Baixa (PC fraco)", "media": "Média", "alta": "Alta"}
## Até onde se vê criaturas e objetos pequenos (metros da câmera).
const VIEW_RANGE := {"baixa": 45.0, "media": 65.0, "alta": 95.0}
## Resolução do 3D (a interface fica sempre nítida).
const RENDER_SCALE := {"baixa": 0.6, "media": 0.85, "alta": 1.0}
const SMALL_SIZE := 12.0


## Qualidade sugerida na primeira vez, pela placa de vídeo: integrada (Intel HD/UHD/Iris,
## AMD Radeon de APU "Vega/Graphics", placa de software) começa na baixa; o resto na média.
static func suggested_quality() -> String:
	var adapter := RenderingServer.get_video_adapter_name().to_lower()
	var vendor := RenderingServer.get_video_adapter_vendor().to_lower()
	if adapter.is_empty():
		return "media"
	for weak: String in ["intel", "llvmpipe", "softpipe", "swiftshader", "microsoft basic", "radeon(tm) graphics", "vega 3", "vega 6", "vega 8", "radeon r5", "radeon r7", "mali", "adreno"]:
		if adapter.contains(weak) or vendor.contains(weak):
			return "baixa"
	return "media"


## Liga o alcance de visão num objeto recém-criado (chamado para cada nó que entra na árvore).
static func on_node_added(node: Node, quality: String) -> void:
	var geometry := node as GeometryInstance3D
	if geometry == null or geometry.visibility_range_end > 0.0 or not _in_game_world(geometry):
		return
	var size := geometry.get_aabb().size
	if maxf(size.x, maxf(size.y, size.z)) > SMALL_SIZE:
		return
	geometry.visibility_range_end = VIEW_RANGE[quality]
	geometry.visibility_range_end_margin = 4.0
	geometry.set_meta("graphics_range", true)


## Pré-visualizações (cartões de personagem, editor de itens) ficam de fora: só o mundo do jogo.
static func _in_game_world(node: Node) -> bool:
	var viewport := node.get_viewport()
	return viewport != null and viewport == node.get_tree().root


## Aplica a qualidade em tudo que já existe (trocou na tela de configurações).
static func apply(tree: SceneTree, quality: String) -> void:
	var root := tree.root
	root.scaling_3d_scale = RENDER_SCALE[quality]
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if quality != "alta" else Viewport.SCALING_3D_MODE_BILINEAR
	root.msaa_3d = Viewport.MSAA_2X if quality == "alta" else Viewport.MSAA_DISABLED
	for sun: Node in tree.get_nodes_in_group("sun"):
		apply_sun(sun as DirectionalLight3D, quality)
	# Baixa: sem o brilho do neon (pós-processamento que pesa na placa integrada).
	for world_env: Node in root.find_children("*", "WorldEnvironment", true, false):
		var env := (world_env as WorldEnvironment).environment
		if env:
			env.glow_enabled = quality != "baixa"
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		if node.has_meta("graphics_range"):
			(node as GeometryInstance3D).visibility_range_end = VIEW_RANGE[quality]


static func apply_sun(sun: DirectionalLight3D, quality: String) -> void:
	if sun == null:
		return
	sun.shadow_enabled = quality != "baixa"
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if quality == "alta" \
			else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 60.0 if quality == "alta" else 40.0
