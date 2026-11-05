class_name MaterialsBadge
extends Control
## Materiais de construção do herói desta tela (metal, madeira, fibra de vidro), ao lado do
## minimapa: ícone, nome e quantidade. Com mais de um herói no sofá, mostra os do primeiro.

const ROW := 26.0
const WIDTH := 170.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, ROW * BaseCatalog.MATERIALS.size() + 12)


func _process(_delta: float) -> void:
	visible = _player() != null
	queue_redraw()


func _draw() -> void:
	var player := _player()
	if player == null:
		return
	var plate := Rect2(Vector2.ZERO, custom_minimum_size)
	draw_colored_polygon(UiSkin.chamfer_points(plate, 8), Color(0.03, 0.035, 0.05, 0.78))
	draw_polyline(_closed(UiSkin.chamfer_points(plate, 8)), Color(UiSkin.BRASS, 0.5), 1.2)
	var font := UiSkin.font("SemiBold")
	var bold := UiSkin.font("Bold")
	var y := 6.0
	for material: String in BaseCatalog.MATERIALS:
		var color: Color = ItemDB.AMMO_TYPES[material].color
		ItemIcon.draw_glyph(self, "material", Rect2(8, y + 2, 20, 20), color, 1.0)
		var name := ItemDB.ammo_name(material)
		draw_string_outline(font, Vector2(34, y + 18), name, HORIZONTAL_ALIGNMENT_LEFT, WIDTH - 80, 15, 4, UiSkin.INK)
		draw_string(font, Vector2(34, y + 18), name, HORIZONTAL_ALIGNMENT_LEFT, WIDTH - 80, 15, UiSkin.TEXT)
		var amount := str(player.inventory.ammo_of(material))
		draw_string_outline(bold, Vector2(0, y + 18), amount, HORIZONTAL_ALIGNMENT_RIGHT, WIDTH - 10, 17, 4, UiSkin.INK)
		draw_string(bold, Vector2(0, y + 18), amount, HORIZONTAL_ALIGNMENT_RIGHT, WIDTH - 10, 17, UiSkin.AMBER)
		y += ROW


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	closed.append(points[0])
	return closed


func _player() -> Player:
	var best: Player = null
	for candidate: Player in get_tree().get_nodes_in_group("players"):
		if candidate.is_local() and (best == null or candidate.slot < best.slot):
			best = candidate
	return best
