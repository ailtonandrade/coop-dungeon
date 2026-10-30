class_name ItemIcon
extends Control
## Casa do inventário: fundo, borda na cor da raridade, desenho do item e o poder no canto.
## Casa vazia de equipamento mostra a silhueta apagada do que vai nela (como no Tibia).

const SIZE := 56

var item: Variant = null
## Silhueta quando vazia (tipo do desenho: "sword", "helmet"...); "" = nenhuma.
var placeholder := ""
var selected := false
var cursor_color := Color.WHITE
## Item "na mão" do cursor sai daqui (desenha meio apagado).
var lifted := false


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.08, 0.09, 0.11, 0.92))
	var border := Color(0.35, 0.36, 0.4)
	if item != null:
		border = ItemDB.rarity_color(item)
	draw_rect(rect.grow(-1), border, false, 2.0)
	if item != null:
		var look: String = ItemDB.def(item).get("look", "")
		var tint: Color = ItemDB.def(item).get("color", Color(0.8, 0.82, 0.86))
		draw_glyph(self, look, rect.grow(-9), tint, 0.4 if lifted else 1.0)
		draw_string_outline(get_theme_default_font(), Vector2(4, size.y - 5), str(item.get("power", 1)),
				HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8, 15, 4, Color.BLACK)
		draw_string(get_theme_default_font(), Vector2(4, size.y - 5), str(item.get("power", 1)),
				HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8, 15, Color.WHITE)
	elif placeholder:
		draw_glyph(self, placeholder, rect.grow(-12), Color(1, 1, 1, 0.12), 1.0)
	if selected:
		draw_rect(rect.grow(-2), cursor_color, false, 4.0)


## Desenho simples de cada tipo, dentro de `r`.
static func draw_glyph(canvas: CanvasItem, look: String, r: Rect2, color: Color, alpha: float) -> void:
	var c := Color(color, color.a * alpha)
	var dark := Color(color.darkened(0.45), color.a * alpha)
	var wood := Color(Color(0.55, 0.36, 0.2), color.a * alpha)
	var p := r.position
	var s := r.size
	var at := func(x: float, y: float) -> Vector2: return p + Vector2(x * s.x, y * s.y)
	match look:
		"sword", "dagger":
			var tip := 0.08 if look == "sword" else 0.32
			canvas.draw_line(at.call(0.25, 0.75), at.call(0.85 - tip * 0.6, tip + 0.07), c, 5.0)
			canvas.draw_line(at.call(0.12, 0.62), at.call(0.38, 0.88), wood, 4.0)
			canvas.draw_line(at.call(0.25, 0.75), at.call(0.1, 0.9), wood, 4.0)
		"axe", "hammer":
			canvas.draw_line(at.call(0.2, 0.9), at.call(0.7, 0.2), wood, 4.0)
			if look == "axe":
				canvas.draw_colored_polygon(PackedVector2Array([at.call(0.55, 0.1), at.call(0.95, 0.25),
						at.call(0.8, 0.55), at.call(0.62, 0.38)]), c)
			else:
				canvas.draw_rect(Rect2(at.call(0.45, 0.05), s * Vector2(0.45, 0.32)), c)
		"bow", "longbow":
			canvas.draw_arc(at.call(0.25, 0.5), s.x * 0.5, -PI / 2.6, PI / 2.6, 12, wood, 4.0)
			canvas.draw_line(at.call(0.62, 0.08), at.call(0.62, 0.92), Color(1, 1, 1, 0.8 * alpha), 1.5)
		"crossbow":
			canvas.draw_line(at.call(0.5, 0.15), at.call(0.5, 0.95), wood, 5.0)
			canvas.draw_arc(at.call(0.5, 0.6), s.x * 0.42, PI * 1.1, PI * 1.9, 12, c, 4.0)
		"hood", "helmet":
			canvas.draw_arc(at.call(0.5, 0.62), s.x * 0.38, PI, TAU, 14, c, 8.0)
			canvas.draw_rect(Rect2(at.call(0.1, 0.6), s * Vector2(0.8, 0.12)), dark)
		"vest", "plate":
			canvas.draw_colored_polygon(PackedVector2Array([at.call(0.25, 0.1), at.call(0.75, 0.1),
					at.call(0.95, 0.35), at.call(0.8, 0.45), at.call(0.8, 0.92), at.call(0.2, 0.92),
					at.call(0.2, 0.45), at.call(0.05, 0.35)]), c)
			if look == "plate":
				canvas.draw_line(at.call(0.5, 0.2), at.call(0.5, 0.85), dark, 2.0)
		"legs":
			canvas.draw_rect(Rect2(at.call(0.2, 0.08), s * Vector2(0.6, 0.18)), c)
			canvas.draw_rect(Rect2(at.call(0.2, 0.2), s * Vector2(0.26, 0.72)), c)
			canvas.draw_rect(Rect2(at.call(0.54, 0.2), s * Vector2(0.26, 0.72)), c)
		"boots":
			for x: float in [0.08, 0.52]:
				canvas.draw_rect(Rect2(at.call(x, 0.2), s * Vector2(0.18, 0.55)), c)
				canvas.draw_rect(Rect2(at.call(x, 0.68), s * Vector2(0.38, 0.2)), c)
		"amulet":
			canvas.draw_arc(at.call(0.5, 0.25), s.x * 0.3, 0.2, PI - 0.2, 10, Color(0.85, 0.75, 0.4, alpha), 2.0)
			canvas.draw_circle(at.call(0.5, 0.65), s.x * 0.2, c)
		"ring":
			canvas.draw_arc(at.call(0.5, 0.55), s.x * 0.3, 0.0, TAU, 16, c, 5.0)
		"coins":
			for i in 3:
				canvas.draw_circle(at.call(0.35 + 0.15 * i, 0.65 - 0.12 * i), s.x * 0.18, c)
				canvas.draw_arc(at.call(0.35 + 0.15 * i, 0.65 - 0.12 * i), s.x * 0.18, 0.0, TAU, 12, dark, 1.5)
		"pouch", "backpack":
			var w := 0.6 if look == "pouch" else 0.76
			var x0 := (1.0 - w) / 2.0
			canvas.draw_rect(Rect2(at.call(x0, 0.25), s * Vector2(w, 0.68)), c)
			canvas.draw_rect(Rect2(at.call(x0, 0.25), s * Vector2(w, 0.22)), dark)
			canvas.draw_arc(at.call(0.5, 0.25), s.x * 0.18, PI, TAU, 8, dark, 3.0)
