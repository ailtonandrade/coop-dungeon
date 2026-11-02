class_name WorldText
extends Label3D
## Texto no mundo (dano, nomes de NPC e de loot, avisos) com tamanho de tela fixo, em pixels de
## uma tela 1080p, que acompanha o "Tamanho dos textos" da interface. Sem isso o texto muda de
## tamanho com a câmera: a isométrica tem lente fechada (30°) e deixava tudo enorme.
##
## `see_through`: aparece por cima de paredes (dano, avisos); nomes de coisas paradas, não.

## Altura do texto na tela, em pixels de 1080p, com o tamanho da interface em 100%.
var screen_px := 22.0


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
	_fit()


func _process(_delta: float) -> void:
	_fit()


func _fit() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var lens := 2.0 * tan(deg_to_rad(camera.fov) / 2.0) if camera.projection == Camera3D.PROJECTION_PERSPECTIVE else 1.0
	pixel_size = screen_px * get_tree().root.content_scale_factor / 1080.0 * lens / font_size
