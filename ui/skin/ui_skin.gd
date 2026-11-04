class_name UiSkin
extends RefCounted
## Paleta, fontes e peças da interface do Corrumpted (ferrugem + neon).
## O tema do projeto (corrumpted_theme.tres, gerado por tools/build_ui_skin.gd) já veste
## botões, painéis e campos sozinho; aqui ficam as cores e o que é desenhado por código.

const THEME := "res://ui/skin/corrumpted_theme.tres"

const INK := Color(0.03, 0.03, 0.04)
const TEXT := Color(0.93, 0.9, 0.84)
const DIM := Color(0.6, 0.6, 0.58)
const BRASS := Color(0.86, 0.64, 0.32)
const RUST := Color(0.62, 0.3, 0.13)
const NEON := Color(0.2, 0.95, 1.0)
const NEON_PINK := Color(1.0, 0.3, 0.75)
const AMBER := Color(1.0, 0.8, 0.32)
const LIFE := Color(0.92, 0.16, 0.22)
const LIFE_LIGHT := Color(1.0, 0.45, 0.4)
const SAFE := Color(0.4, 0.95, 0.55)
const DANGER := Color(1.0, 0.3, 0.22)

## Cores dos botões do controle (dicas na tela).
const BUTTON_COLORS := {"A": Color(0.4, 0.85, 0.3), "B": Color(0.95, 0.3, 0.25), "X": Color(0.3, 0.55, 1.0),
		"Y": Color(1.0, 0.82, 0.2), "RT": Color(0.7, 0.7, 0.72), "LB": Color(0.7, 0.7, 0.72)}


static func font(weight := "SemiBold") -> Font:
	return load("res://ui/fonts/ChakraPetch-%s.ttf" % weight)


## Fonte de título (estêncil de lata).
static func title_font() -> Font:
	return load("res://ui/fonts/BlackOpsOne-Regular.ttf")


static func theme() -> Theme:
	return load(THEME)


static func panel() -> StyleBox:
	return theme().get_stylebox("panel", "PanelContainer")


static func slot() -> StyleBox:
	return theme().get_stylebox("panel", "ItemIcon")


static func chip() -> StyleBox:
	var box := StyleBoxTexture.new()
	box.texture = load("res://ui/skin/chip.png")
	box.set_texture_margin_all(8)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


const MIN_FONT := 14


static func label(text: String, size: int, color := TEXT, weight := "SemiBold", outline := 6) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_override("font", font(weight))
	# Nada abaixo de 14 px: em janela menor que 1080p o texto ainda encolhe junto.
	result.add_theme_font_size_override("font_size", maxi(size, MIN_FONT))
	result.add_theme_color_override("font_color", color)
	result.add_theme_constant_override("outline_size", outline)
	return result


static func title(text: String, size: int, color := AMBER) -> Label:
	var result := label(text, size, color, "Bold", 8)
	result.add_theme_font_override("font", title_font())
	return result


## Contorno de um retângulo com cantos cortados (sup-esq e inf-dir), o formato da interface.
static func chamfer_points(r: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([r.position + Vector2(cut, 0), Vector2(r.end.x, r.position.y),
			r.end - Vector2(0, cut), r.end - Vector2(cut, 0), Vector2(r.position.x, r.end.y),
			r.position + Vector2(0, cut)])


## Etiqueta de botão do controle (círculo colorido com a letra).
## Teclas do teclado (desenhadas como tecla quadrada, não como botão redondo do controle).
const KEYBOARD_KEYS := ["J", "K", "C", "E", "Q", "F", "I", "Esc", "Shift", "Espaço"]


static func draw_button_hint(canvas: CanvasItem, center: Vector2, button: String, radius := 9.0) -> void:
	if button in KEYBOARD_KEYS:
		var f_key := font("Bold")
		var key_size := 12 if button.length() == 1 else 8
		var width := radius * 2.0 if button.length() == 1 else radius * 2.0 + float(button.length() - 1) * 4.0
		var rect := Rect2(center - Vector2(width / 2.0, radius), Vector2(width, radius * 2.0))
		canvas.draw_rect(rect.grow(1.5), INK)
		canvas.draw_rect(rect, Color(0.82, 0.8, 0.74))
		canvas.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 3), Vector2(rect.size.x, 3)), Color(0.55, 0.53, 0.48))
		canvas.draw_string(f_key, Vector2(rect.position.x, center.y + key_size * 0.33), button, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, key_size, INK)
		return
	var color: Color = BUTTON_COLORS.get(button, DIM)
	canvas.draw_circle(center, radius + 1.5, INK)
	canvas.draw_circle(center, radius, color.darkened(0.35))
	canvas.draw_arc(center, radius, 0, TAU, 16, color, 1.5)
	var f := font("Bold")
	var size := 12 if button.length() == 1 else 9
	canvas.draw_string(f, center + Vector2(-radius, size * 0.36), button, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, size, Color.WHITE)
