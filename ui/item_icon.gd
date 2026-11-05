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
	draw_style_box(UiSkin.slot(), rect)
	if item != null:
		draw_rect(rect.grow(-2), Color(ItemDB.rarity_color(item), 0.85), false, 2.0)
		# Brilho da raridade vindo de baixo.
		var glow := Color(ItemDB.rarity_color(item), 0.18)
		draw_polygon(PackedVector2Array([Vector2(3, size.y * 0.5), Vector2(size.x - 3, size.y * 0.5), size - Vector2(3, 3), Vector2(3, size.y - 3)]),
				PackedColorArray([Color(glow, 0.0), Color(glow, 0.0), glow, glow]))
	if item != null:
		draw_item(self, item, rect.grow(-7), 0.4 if lifted else 1.0)
		draw_string_outline(get_theme_default_font(), Vector2(4, size.y - 5), str(item.get("power", 1)),
				HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8, 15, 4, Color.BLACK)
		draw_string(get_theme_default_font(), Vector2(4, size.y - 5), str(item.get("power", 1)),
				HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8, 15, Color.WHITE)
	elif placeholder:
		draw_glyph(self, placeholder, rect.grow(-12), Color(1, 1, 1, 0.12), 1.0)
	if selected:
		draw_rect(rect.grow(-2), cursor_color, false, 4.0)


## Ícone de um item em `r`: com modelo 3D, a foto dele (IconStudio, igual ao chão e à mão);
## senão o ícone da ficha, se tiver; senão o desenho do tipo.
static func draw_item(canvas: CanvasItem, item: Dictionary, r: Rect2, alpha := 1.0) -> void:
	var def := ItemDB.def(item)
	if IconStudio.uses_photo(def):
		var photo := IconStudio.icon_for(str(item.get("id", "")))
		if photo:
			canvas.draw_texture_rect(photo, r, false, Color(1, 1, 1, alpha))
			return
		# Foto ainda saindo: redesenha quando ficar pronta (uma espera por casa).
		var studio := IconStudio.instance()
		if studio and canvas.is_inside_tree() and not canvas.has_meta("waiting_icon"):
			canvas.set_meta("waiting_icon", true)
			var target: WeakRef = weakref(canvas)
			studio.icon_ready.connect(func(_id: String) -> void:
				var alive: CanvasItem = target.get_ref()
				if alive:
					alive.remove_meta("waiting_icon")
					alive.queue_redraw(), CONNECT_ONE_SHOT)
	var icon: Variant = def.get("icon")
	if icon is Texture2D:
		canvas.draw_texture_rect(icon, r, false, Color(1, 1, 1, alpha))
		return
	draw_glyph(canvas, def.get("look", ""), r.grow(-2), def.get("color", Color(0.8, 0.82, 0.86)), alpha)


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
		# Armas de prego (de perfil, cano para a direita): corpo de ferramenta, bico de aço,
		# cabo de borracha e a fita de pregos.
		"bow", "longbow", "crossbow":
			var paint := Color(Color(0.74, 0.58, 0.16) if look != "longbow" else Color(0.62, 0.2, 0.12), alpha)
			var steel := Color(Color(0.36, 0.37, 0.4), alpha)
			var rubber := Color(Color(0.26, 0.26, 0.28), alpha)
			var brass := Color(Color(0.78, 0.6, 0.3), alpha)
			var long := look != "bow"
			if look == "longbow":
				canvas.draw_colored_polygon(PackedVector2Array([at.call(0.02, 0.34), at.call(0.26, 0.38),
						at.call(0.26, 0.5), at.call(0.04, 0.6)]), wood)
			canvas.draw_rect(Rect2(at.call(0.2 if long else 0.12, 0.3), s * Vector2(0.48 if long else 0.52, 0.2)), paint)
			canvas.draw_rect(Rect2(at.call(0.68 if long else 0.64, 0.35), s * Vector2(0.3 if long else 0.2, 0.09)), steel)
			canvas.draw_colored_polygon(PackedVector2Array([at.call(0.3, 0.5), at.call(0.44, 0.5),
					at.call(0.38, 0.86), at.call(0.24, 0.86)]), rubber)
			canvas.draw_colored_polygon(PackedVector2Array([at.call(0.46, 0.5), at.call(0.66, 0.5),
					at.call(0.6, 0.64), at.call(0.44, 0.6)]), brass)
			if look == "crossbow":
				canvas.draw_rect(Rect2(at.call(0.46, 0.52), s * Vector2(0.3, 0.14)), Color(Color(0.22, 0.4, 0.26), alpha))
		"pistol":
			var gun := Color(Color(0.3, 0.31, 0.33), alpha)
			canvas.draw_rect(Rect2(at.call(0.12, 0.3), s * Vector2(0.66, 0.16)), gun)
			canvas.draw_colored_polygon(PackedVector2Array([at.call(0.16, 0.44), at.call(0.38, 0.44),
					at.call(0.32, 0.86), at.call(0.12, 0.86)]), Color(Color(0.16, 0.16, 0.17), alpha))
			canvas.draw_rect(Rect2(at.call(0.15, 0.62), s * Vector2(0.2, 0.08)), Color(Color(0.35, 0.37, 0.4), alpha))
		"rifle", "shotgun":
			var barrel := Color(Color(0.32, 0.33, 0.35), alpha)
			var wood_dark := Color(wood.darkened(0.15), alpha)
			if look == "rifle":
				canvas.draw_rect(Rect2(at.call(0.3, 0.42), s * Vector2(0.68, 0.06)), barrel)
				canvas.draw_rect(Rect2(at.call(0.36, 0.3), s * Vector2(0.24, 0.07)), Color(Color(0.12, 0.12, 0.13), alpha))
				canvas.draw_colored_polygon(PackedVector2Array([at.call(0.02, 0.5), at.call(0.42, 0.44),
						at.call(0.42, 0.56), at.call(0.04, 0.72)]), wood)
			else:
				canvas.draw_rect(Rect2(at.call(0.34, 0.38), s * Vector2(0.56, 0.07)), barrel)
				canvas.draw_rect(Rect2(at.call(0.34, 0.46), s * Vector2(0.56, 0.07)), barrel)
				canvas.draw_colored_polygon(PackedVector2Array([at.call(0.1, 0.42), at.call(0.38, 0.38),
						at.call(0.38, 0.56), at.call(0.14, 0.8)]), wood_dark)
		"ammo_box":
			canvas.draw_rect(Rect2(at.call(0.15, 0.35), s * Vector2(0.7, 0.45)), c)
			canvas.draw_rect(Rect2(at.call(0.15, 0.45), s * Vector2(0.7, 0.1)), dark)
			for i in 3:
				canvas.draw_rect(Rect2(at.call(0.25 + i * 0.18, 0.16), s * Vector2(0.08, 0.2)), Color(Color(0.8, 0.62, 0.3), alpha))
		"material":
			canvas.draw_rect(Rect2(at.call(0.12, 0.55), s * Vector2(0.76, 0.12)), c)
			canvas.draw_rect(Rect2(at.call(0.18, 0.4), s * Vector2(0.7, 0.12)), Color(color.darkened(0.15), alpha))
			canvas.draw_rect(Rect2(at.call(0.1, 0.25), s * Vector2(0.66, 0.12)), Color(color.lightened(0.1), alpha))
		"grenade":
			canvas.draw_rect(Rect2(at.call(0.3, 0.3), s * Vector2(0.4, 0.58)), Color(Color(0.3, 0.42, 0.25), alpha))
			canvas.draw_rect(Rect2(at.call(0.28, 0.52), s * Vector2(0.44, 0.1)), Color(Color(0.18, 0.2, 0.22), alpha))
			canvas.draw_rect(Rect2(at.call(0.42, 0.16), s * Vector2(0.16, 0.14)), Color(Color(0.45, 0.46, 0.5), alpha))
			canvas.draw_arc(at.call(0.66, 0.2), s.x * 0.08, 0.0, TAU, 10, Color(Color(0.75, 0.76, 0.8), alpha), 2.0)
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
