extends SceneTree
## Gera a skin da interface (ui/skin/): as texturas das molduras (placas de metal rebitadas,
## botões, casas do inventário) e o tema do Godot que usa elas (corrumpted_theme.tres),
## ligado no projeto inteiro (Projeto > Configurações > GUI > Tema).
##
## As texturas são o ponto de troca da arte: dá para pintar por cima delas (ou trocar por
## arte de verdade) mantendo o tamanho e as bordas; o tema continua funcionando.
##
## Rodar (duas vezes na primeira: a segunda acha as texturas importadas e monta o tema):
##   godot --headless --path coop-dungeon -s tools/build_ui_skin.gd
##   godot --headless --path coop-dungeon --import
##   godot --headless --path coop-dungeon -s tools/build_ui_skin.gd

const DIR := "res://ui/skin/"
const THEME_PATH := "res://ui/skin/corrumpted_theme.tres"

const INK := Color(0.03, 0.03, 0.04)
const STEEL := Color(0.085, 0.09, 0.11)
const STEEL_LIGHT := Color(0.16, 0.17, 0.2)
const RUST := Color(0.55, 0.26, 0.11)
const BRASS := Color(0.78, 0.56, 0.27)
const NEON := Color(0.2, 0.95, 1.0)
const NEON_PINK := Color(1.0, 0.3, 0.75)

var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_noise.seed = 7
	_noise.frequency = 0.09
	_rng.seed = 42
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))

	_save(_panel(96, 96), "panel")
	_save(_button(64, 44, "normal"), "button")
	_save(_button(64, 44, "hover"), "button_hover")
	_save(_button(64, 44, "pressed"), "button_pressed")
	_save(_button(64, 44, "disabled"), "button_disabled")
	_save(_focus(64, 44), "button_focus")
	_save(_inset(64, 64, 6, Color(0.3, 0.3, 0.34)), "slot")
	_save(_inset(64, 44, 6, NEON), "input")
	_save(_chip(48, 32), "chip")

	if ResourceLoader.exists(DIR + "panel.png") and ResourceLoader.exists("res://ui/fonts/ChakraPetch-SemiBold.ttf"):
		_build_theme()
	else:
		print("Texturas novas: rode --import e depois este script de novo para montar o tema.")
	quit()


## Desenho

## Distância do pixel até a borda de um retângulo com cantos cortados (chanfros:
## sup-esq, sup-dir, inf-dir, inf-esq). Negativo = fora.
func _edge(x: int, y: int, w: int, h: int, c: Vector4) -> float:
	var rx := w - 1 - x
	var by := h - 1 - y
	var d := minf(minf(x, y), minf(rx, by))
	d = minf(d, (x + y - c.x) / sqrt(2.0))
	d = minf(d, (rx + y - c.y) / sqrt(2.0))
	d = minf(d, (rx + by - c.z) / sqrt(2.0))
	d = minf(d, (x + by - c.w) / sqrt(2.0))
	return d


func _grain(color: Color, amount: float) -> Color:
	var g := _rng.randf_range(-amount, amount)
	return Color(color.r + g, color.g + g, color.b + g, color.a)


## Metal da moldura: latão com manchas de ferrugem, mais claro em cima.
func _frame_metal(x: int, y: int, h: int, depth: float) -> Color:
	var rust := clampf(_noise.get_noise_2d(x, y) * 1.6 + 0.35, 0.0, 1.0)
	var base := BRASS.lerp(RUST, rust)
	base = base.lightened(0.18 * (1.0 - float(y) / h)).darkened(0.12 * depth)
	return _grain(base, 0.035)


func _rivet(img: Image, center: Vector2, radius: float) -> void:
	for y in range(int(center.y - radius - 1), int(center.y + radius + 2)):
		for x in range(int(center.x - radius - 1), int(center.x + radius + 2)):
			var d := Vector2(x, y).distance_to(center)
			if d > radius + 0.5:
				continue
			var light := clampf(1.0 - Vector2(x, y).distance_to(center - Vector2(radius, radius) * 0.4) / (radius * 1.6), 0.0, 1.0)
			var color := Color(0.25, 0.22, 0.2).lerp(Color(0.9, 0.82, 0.66), light)
			if d > radius - 0.6:
				color = INK
			img.set_pixel(x, y, color)


func _panel(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c := Vector4(12, 12, 12, 12)
	for y in h:
		for x in w:
			var d := _edge(x, y, w, h, c)
			var color := Color(0, 0, 0, 0)
			if d >= 0.0 and d < 1.0:
				color = INK
			elif d >= 1.0 and d < 7.0:
				color = _frame_metal(x, y, h, (d - 1.0) / 6.0)
				if d < 2.0:
					color = color.lightened(0.25)
			elif d >= 7.0 and d < 8.5:
				color = INK.lightened(0.04)
			elif d >= 8.5:
				var fill := STEEL.lerp(STEEL_LIGHT, 0.35 * (1.0 - float(y) / h))
				fill = _grain(fill, 0.012)
				color = Color(fill, 0.95)
			img.set_pixel(x, y, color)
	for corner in [Vector2(16, 16), Vector2(w - 17, 16), Vector2(w - 17, h - 17), Vector2(16, h - 17)]:
		_rivet(img, corner, 2.6)
	# Filete de neon no corte do canto superior esquerdo.
	for i in range(3, 10):
		img.set_pixel(i, 12 - i + 1, NEON)
		img.set_pixel(i + 1, 12 - i + 1, Color(NEON, 0.5))
	return img


func _button(w: int, h: int, state: String) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c := Vector4(9, 0, 9, 0)
	var edge := {"normal": BRASS.darkened(0.25), "hover": NEON, "pressed": NEON_PINK, "disabled": Color(0.3, 0.3, 0.32)}[state] as Color
	var top := {"normal": Color(0.2, 0.2, 0.23), "hover": Color(0.17, 0.25, 0.3), "pressed": Color(0.08, 0.08, 0.1), "disabled": Color(0.12, 0.12, 0.13)}[state] as Color
	var bottom := top.darkened(0.45)
	for y in h:
		for x in w:
			var d := _edge(x, y, w, h, c)
			var color := Color(0, 0, 0, 0)
			if d >= 0.0 and d < 1.0:
				color = INK
			elif d >= 1.0 and d < 3.0:
				color = edge if state != "normal" else _frame_metal(x, y, h, 0.3)
			elif d >= 3.0:
				var t := float(y) / h
				if state == "pressed":
					t = 1.0 - t
				color = _grain(top.lerp(bottom, t), 0.015)
				# Brilho de neon por dentro quando em foco.
				if state == "hover" and d < 7.0:
					color = color.lerp(NEON, 0.35 * (1.0 - (d - 3.0) / 4.0))
				# Faixa de luz na parte de cima.
				if d < 4.0 and y < h / 2 and state != "pressed":
					color = color.lightened(0.15)
			img.set_pixel(x, y, color)
	return img


## Moldura de foco (controle): só a borda de neon com brilho para dentro, centro vazio.
func _focus(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c := Vector4(9, 0, 9, 0)
	for y in h:
		for x in w:
			var d := _edge(x, y, w, h, c)
			var color := Color(0, 0, 0, 0)
			if d >= 0.0 and d < 3.0:
				color = NEON.lightened(0.3)
			elif d >= 3.0 and d < 9.0:
				color = Color(NEON, 0.4 * (1.0 - (d - 3.0) / 6.0))
			img.set_pixel(x, y, color)
	return img


## Casa afundada (inventário, campo de texto): sombra em cima/esquerda, luz embaixo/direita.
func _inset(w: int, h: int, chamfer: int, accent: Color) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c := Vector4(chamfer, chamfer, chamfer, chamfer)
	for y in h:
		for x in w:
			var d := _edge(x, y, w, h, c)
			var color := Color(0, 0, 0, 0)
			if d >= 0.0 and d < 1.0:
				color = Color(0.32, 0.3, 0.28) if x + y > (w + h) / 2 else INK
			elif d >= 1.0 and d < 2.0:
				color = INK
			elif d >= 2.0:
				var shade := 0.06 + 0.04 * clampf(d / 10.0, 0.0, 1.0)
				color = _grain(Color(shade, shade * 1.05, shade * 1.15, 0.92), 0.01)
			img.set_pixel(x, y, color)
	# Risco de acento embaixo (a cor mostra o tipo da casa).
	for x in range(chamfer + 2, w - chamfer - 2):
		img.set_pixel(x, h - 3, Color(accent, 0.55))
	return img


func _chip(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c := Vector4(6, 0, 6, 0)
	for y in h:
		for x in w:
			var d := _edge(x, y, w, h, c)
			var color := Color(0, 0, 0, 0)
			if d >= 0.0 and d < 1.0:
				color = Color(NEON, 0.8)
			elif d >= 1.0:
				color = Color(0.02, 0.03, 0.05, 0.78)
			img.set_pixel(x, y, color)
	return img


func _save(img: Image, file: String) -> void:
	img.save_png(ProjectSettings.globalize_path(DIR + file + ".png"))


## Tema

func _box(file: String, margin: int, content: Vector4) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(DIR + file + ".png")
	box.set_texture_margin_all(margin)
	box.content_margin_left = content.x
	box.content_margin_top = content.y
	box.content_margin_right = content.z
	box.content_margin_bottom = content.w
	return box


func _build_theme() -> void:
	var theme := Theme.new()
	var regular: Font = load("res://ui/fonts/ChakraPetch-Regular.ttf")
	var semibold: Font = load("res://ui/fonts/ChakraPetch-SemiBold.ttf")
	var bold: Font = load("res://ui/fonts/ChakraPetch-Bold.ttf")
	theme.default_font = semibold
	theme.default_font_size = 20
	var text := Color(0.93, 0.9, 0.84)
	var dim := Color(0.55, 0.55, 0.55)

	var panel := _box("panel", 24, Vector4(20, 18, 20, 18))
	for type in ["PanelContainer", "Panel", "PopupPanel", "PopupMenu", "TooltipPanel"]:
		theme.set_stylebox("panel", type, panel)

	var normal := _box("button", 12, Vector4(22, 8, 22, 8))
	var hover := _box("button_hover", 12, Vector4(22, 8, 22, 8))
	var pressed := _box("button_pressed", 12, Vector4(22, 10, 22, 6))
	var disabled := _box("button_disabled", 12, Vector4(22, 8, 22, 8))
	for type in ["Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton"]:
		theme.set_stylebox("normal", type, normal)
		theme.set_stylebox("hover", type, hover)
		theme.set_stylebox("pressed", type, pressed)
		theme.set_stylebox("hover_pressed", type, pressed)
		theme.set_stylebox("disabled", type, disabled)
		theme.set_stylebox("focus", type, _box("button_focus", 12, Vector4(22, 8, 22, 8)))
		theme.set_font("font", type, bold)
		theme.set_color("font_color", type, text)
		theme.set_color("font_hover_color", type, Color.WHITE)
		theme.set_color("font_focus_color", type, Color.WHITE)
		theme.set_color("font_pressed_color", type, NEON_PINK.lightened(0.3))
		theme.set_color("font_hover_pressed_color", type, NEON_PINK.lightened(0.3))
		theme.set_color("font_disabled_color", type, dim)
		theme.set_color("font_outline_color", type, INK)
		theme.set_constant("outline_size", type, 4)

	var field := _box("input", 10, Vector4(14, 6, 14, 6))
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", _box("button_hover", 12, Vector4(14, 6, 14, 6)))
	theme.set_stylebox("read_only", "LineEdit", field)
	theme.set_font("font", "LineEdit", regular)
	theme.set_color("font_color", "LineEdit", text)
	theme.set_color("font_placeholder_color", "LineEdit", dim)
	theme.set_color("caret_color", "LineEdit", NEON)
	theme.set_color("selection_color", "LineEdit", Color(NEON, 0.35))

	theme.set_stylebox("hover", "PopupMenu", hover)
	theme.set_color("font_color", "PopupMenu", text)
	theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	theme.set_font("font", "PopupMenu", semibold)

	theme.set_color("font_color", "Label", text)
	theme.set_color("font_outline_color", "Label", INK)
	theme.set_constant("outline_size", "Label", 4)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.45))
	theme.set_constant("shadow_offset_y", "Label", 2)
	theme.set_constant("shadow_offset_x", "Label", 0)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.45)
	track.content_margin_left = 5
	track.content_margin_right = 5
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = BRASS.darkened(0.2)
	var grabber_hot := StyleBoxFlat.new()
	grabber_hot.bg_color = NEON
	for type in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", type, track)
		theme.set_stylebox("grabber", type, grabber)
		theme.set_stylebox("grabber_highlight", type, grabber_hot)
		theme.set_stylebox("grabber_pressed", type, grabber_hot)

	theme.set_stylebox("panel", "ItemIcon", _box("slot", 10, Vector4(4, 4, 4, 4)))

	var err := ResourceSaver.save(theme, THEME_PATH)
	print("Tema salvo em %s (%s)" % [THEME_PATH, error_string(err)])
