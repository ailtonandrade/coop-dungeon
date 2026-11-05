class_name WorldText
extends Label3D
## Texto no mundo (dano, nomes de NPC e de loot, avisos, P1) com tamanho de tela fixo, em pixels
## de uma tela 1080p, que acompanha o "Tamanho dos textos" da interface.
##
## No jogo o texto é DESENHADO NA TELA (por cima, como a interface) e só segue a posição deste
## nó: assim fica nítido mesmo com o 3D em resolução menor (qualidade Baixa desenha o 3D em 60%
## e o texto 3D ficava borrado). O Label3D em si fica invisível (camada 0) mas continua sendo o
## "dono" das propriedades (texto, cor, visível, contorno, largura), então quem cria não muda nada.
## Fora do mundo do jogo (prévias em SubViewport) continua como texto 3D comum.
##
## `see_through` (no_depth_test): aparece por cima de paredes (dano, avisos, P1); nomes de coisas
## paradas somem quando uma parede fica na frente (raio da câmera, algumas vezes por segundo).

## Altura do texto na tela, em pixels de 1080p, com o tamanho da interface em 100%.
var screen_px := 22.0

const LAYER_NAME := "WorldTextLayer"
const OCCLUSION_CHECK := 0.2

var _overlay: Label
var _occluded := false
var _check := 0.0


static func make(text_value: String, px: float, color: Color, see_through := false) -> WorldText:
	var label := WorldText.new()
	label.text = text_value
	label.screen_px = px
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.no_depth_test = see_through
	label.font_size = 48
	label.outline_size = 12
	label.layers = 2
	return label


func _ready() -> void:
	if _in_game_view():
		layers = 0
		_overlay = Label.new()
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_overlay.add_theme_font_override("font", UiSkin.font("Bold"))
		_layer().add_child(_overlay)
		_sync()
	else:
		_fit()


func _exit_tree() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null


func _process(delta: float) -> void:
	if _overlay:
		_check -= delta
		if _check <= 0.0:
			_check = OCCLUSION_CHECK
			_occluded = not no_depth_test and _behind_wall()
		_sync()
	else:
		_fit()


## Copia texto, cor e tamanho para o texto da tela e põe ele em cima do ponto do mundo.
func _sync() -> void:
	var camera := get_viewport().get_camera_3d()
	# Some/aparece tanto pela cor (modulate) quanto pela transparência do nó (o loot usa esta).
	var alpha := modulate.a * (1.0 - transparency)
	var show := camera != null and is_visible_in_tree() and not _occluded and not text.is_empty() \
			and alpha > 0.01 and not camera.is_position_behind(global_position)
	_overlay.visible = show
	if not show:
		return
	var scale_ui := get_tree().root.content_scale_factor
	var px := maxi(8, roundi(screen_px * scale_ui))
	var outline := maxi(1, roundi(px * float(outline_size) / maxf(float(font_size), 1.0)))
	_overlay.add_theme_font_size_override("font_size", px)
	_overlay.add_theme_constant_override("outline_size", outline)
	_overlay.add_theme_color_override("font_color", Color(modulate, alpha))
	_overlay.add_theme_color_override("font_outline_color", Color(outline_modulate, outline_modulate.a * alpha))
	_overlay.text = text
	if autowrap_mode != TextServer.AUTOWRAP_OFF and width > 0.0:
		_overlay.autowrap_mode = autowrap_mode
		_overlay.custom_minimum_size.x = width * px / maxf(float(font_size), 1.0)
	else:
		_overlay.autowrap_mode = TextServer.AUTOWRAP_OFF
		_overlay.custom_minimum_size.x = 0.0
	_overlay.reset_size()
	# Coordenada da tela do jogo (o 3D pode estar em resolução menor; a interface não).
	var point := camera.unproject_position(global_position)
	_overlay.position = (point - _overlay.size / 2.0).round()


func _behind_wall() -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var from := camera.global_position
	var to := global_position
	var query := PhysicsRayQueryParameters3D.create(from, to - (to - from).normalized() * 0.6, GameConfig.LAYER_WORLD)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _in_game_view() -> bool:
	return get_viewport() == get_tree().root


static var _shared_layer: CanvasLayer


## Camada da tela para os textos do mundo (abaixo dos painéis da interface). Entra na árvore no
## fim do quadro (pode ser criada no meio da montagem de uma cena).
func _layer() -> CanvasLayer:
	if not is_instance_valid(_shared_layer):
		_shared_layer = CanvasLayer.new()
		_shared_layer.name = LAYER_NAME
		_shared_layer.layer = 0
		get_tree().root.add_child.call_deferred(_shared_layer)
	return _shared_layer


func _fit() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var lens := 2.0 * tan(deg_to_rad(camera.fov) / 2.0) if camera.projection == Camera3D.PROJECTION_PERSPECTIVE else 1.0
	pixel_size = screen_px * get_tree().root.content_scale_factor / 1080.0 * lens / font_size
