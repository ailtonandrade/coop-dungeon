class_name RegionBanner
extends Control
## Faixa com o nome da região ao entrar nela: título entre ornamentos de metal e neon,
## embaixo "área segura" ou o perigo em marcas. Aparece, espera e some sozinha.

const WIDTH := 640.0

var _title := ""
var _subtitle := ""
var _color := Color.WHITE
var _danger := 0
var _safe := false
var _tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, 110)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0


func show_region(region: RegionDef) -> void:
	_title = region.display_name.to_upper()
	_safe = region.safe
	_danger = region.danger
	_subtitle = "área segura" if region.safe else "perigo"
	_color = region.color
	queue_redraw()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	scale = Vector2(1.08, 1.08)
	pivot_offset = size / 2.0
	_tween.set_parallel()
	_tween.tween_property(self, "modulate:a", 1.0, 0.35)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(2.6)
	_tween.chain().tween_property(self, "modulate:a", 0.0, 0.9)


func _draw() -> void:
	if _title.is_empty():
		return
	var center_x := size.x / 2.0
	var f := UiSkin.title_font()
	var title_size := 40
	var text_width := f.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	var y := 52.0
	# Faixa escura atrás do texto, que some nas pontas.
	var band := Rect2(0, 12, size.x, 72)
	var clear := Color(0, 0, 0, 0)
	var dark := Color(0, 0, 0, 0.55)
	draw_polygon(PackedVector2Array([band.position, Vector2(center_x, band.position.y), Vector2(center_x, band.end.y), Vector2(band.position.x, band.end.y)]),
			PackedColorArray([clear, dark, dark, clear]))
	draw_polygon(PackedVector2Array([Vector2(center_x, band.position.y), Vector2(band.end.x, band.position.y), band.end, Vector2(center_x, band.end.y)]),
			PackedColorArray([dark, clear, clear, dark]))
	# Ornamentos: linha de latão, losango e filete de neon dos dois lados.
	var gap := text_width / 2.0 + 24.0
	for side: float in [-1.0, 1.0]:
		var inner := center_x + side * gap
		var outer := center_x + side * (size.x / 2.0 - 10.0)
		draw_line(Vector2(inner, y - 12), Vector2(outer, y - 12), Color(UiSkin.BRASS, 0.85), 2.0)
		draw_line(Vector2(inner + side * 10, y - 7), Vector2(outer - side * 60, y - 7), Color(_color, 0.7), 1.0)
		_diamond(Vector2(inner, y - 12), 6.0, UiSkin.BRASS)
		_diamond(Vector2(outer, y - 12), 3.5, _color)
	draw_string_outline(f, Vector2(0, y), _title, HORIZONTAL_ALIGNMENT_CENTER, size.x, title_size, 10, UiSkin.INK)
	draw_string(f, Vector2(0, y), _title, HORIZONTAL_ALIGNMENT_CENTER, size.x, title_size, _color.lightened(0.25))

	var sub_font := UiSkin.font("Bold")
	var sub_color := UiSkin.SAFE if _safe else UiSkin.DANGER
	var sub := _subtitle.to_upper() if _safe else "%s %d" % [_subtitle.to_upper(), _danger]
	var sub_width := sub_font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var marks := 0 if _safe else clampi(ceili(_danger / 2.0), 1, 5)
	var total := sub_width + marks * 14.0 + (8.0 if marks else 0.0)
	var x := center_x - total / 2.0
	draw_string_outline(sub_font, Vector2(x, y + 28), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 6, UiSkin.INK)
	draw_string(sub_font, Vector2(x, y + 28), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, sub_color)
	for i in marks:
		_diamond(Vector2(x + sub_width + 15.0 + i * 14.0, y + 22), 5.0, sub_color)


func _diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0),
			center + Vector2(0, radius), center + Vector2(-radius, 0)]), color)
