class_name PlayerCard
extends Control
## Cartão de um jogador no rodapé: retrato hexagonal com a cor dele, barra de vida com rastro
## de dano (o pedaço perdido some devagar), atalhos com recarga e os parafusos.
## Vaga vazia mostra "aperte START" piscando.

const SIZE := Vector2(380, 104)
const PORTRAIT_RADIUS := 38.0
const BAR := Rect2(96, 36, 264, 22)
const HOTBAR_Y := 68.0
const XP_BAR := Rect2(96, 61, 264, 4)
const HOTBAR_SLOT := 32.0

var index := 0
var player: Player
## Mostra o convite para entrar quando a vaga está livre nesta máquina.
var invite := false

var _shown_hp := 1.0
var _ghost_hp := 1.0
var _hit_flash := 0.0
var _time := 0.0


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	if is_instance_valid(player):
		var ratio := clampf(player.health.hp / player.health.max_hp, 0.0, 1.0)
		if ratio < _shown_hp - 0.001:
			_hit_flash = 1.0
		_shown_hp = ratio
		# O rastro espera um pouco e desce até a vida atual (como no LoL).
		if _ghost_hp > _shown_hp:
			_ghost_hp = maxf(_shown_hp, _ghost_hp - delta * (0.6 if _hit_flash < 0.4 else 0.0))
		else:
			_ghost_hp = _shown_hp
		_hit_flash = maxf(_hit_flash - delta * 2.0, 0.0)
	else:
		player = null
	queue_redraw()


func _draw() -> void:
	var color := GameConfig.PLAYER_COLORS[index]
	if player == null:
		_draw_empty(color)
		return
	var plate := Rect2(Vector2(40, 14), Vector2(SIZE.x - 40, SIZE.y - 14))
	draw_colored_polygon(UiSkin.chamfer_points(plate, 14), Color(0.03, 0.035, 0.05, 0.82))
	draw_polyline(_closed(UiSkin.chamfer_points(plate, 14)), Color(UiSkin.BRASS, 0.55), 1.5)
	draw_line(plate.position + Vector2(14, 0), Vector2(plate.end.x, plate.position.y), color, 3.0)

	var downed := not player.is_targetable()
	var f := UiSkin.font("Bold")
	var name_text := player.display_name
	draw_string_outline(f, Vector2(BAR.position.x, 30), name_text, HORIZONTAL_ALIGNMENT_LEFT, BAR.size.x - 80, 19, 6, UiSkin.INK)
	draw_string(f, Vector2(BAR.position.x, 30), name_text, HORIZONTAL_ALIGNMENT_LEFT, BAR.size.x - 80, 19, UiSkin.TEXT)
	if player.is_local():
		_draw_money(Vector2(BAR.end.x, 30))
	_draw_voice(Vector2(BAR.position.x + f.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, BAR.size.x - 80, 19).x + 14, 23))

	_draw_bar(downed)
	_draw_xp()
	_draw_hotbar()
	_draw_portrait(Vector2(44, 56), color, downed)
	_draw_level_badge(Vector2(72, 86))


func _draw_empty(color: Color) -> void:
	if not invite:
		return
	var plate := Rect2(Vector2(40, 30), Vector2(SIZE.x - 80, 56))
	draw_colored_polygon(UiSkin.chamfer_points(plate, 10), Color(0.02, 0.02, 0.03, 0.55))
	draw_polyline(_closed(UiSkin.chamfer_points(plate, 10)), Color(color, 0.35), 1.5)
	var pulse := 0.55 + 0.45 * sin(_time * 3.0)
	var f := UiSkin.font("Bold")
	var text := "P%d · aperte START" % (index + 1)
	draw_string(f, Vector2(plate.position.x, plate.position.y + 26), text, HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 18, Color(color.lightened(0.3), pulse))
	draw_string(UiSkin.font("Regular"), Vector2(plate.position.x, plate.end.y - 10), "teclado: Enter", HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 13, Color(UiSkin.DIM, 0.6 + 0.4 * pulse))


func _draw_portrait(center: Vector2, color: Color, downed: bool) -> void:
	var outer := _hexagon(center, PORTRAIT_RADIUS + 5)
	var ring := _hexagon(center, PORTRAIT_RADIUS)
	var inner := _hexagon(center, PORTRAIT_RADIUS - 5)
	draw_colored_polygon(outer, UiSkin.INK)
	draw_colored_polygon(ring, UiSkin.BRASS.darkened(0.15))
	draw_polyline(_closed(ring), UiSkin.BRASS.lightened(0.3), 1.5)
	var fill := Color(0.25, 0.04, 0.04) if downed else color.darkened(0.55)
	draw_colored_polygon(inner, fill)
	# Brilho de cima no vidro do retrato.
	draw_colored_polygon(PackedVector2Array([inner[3], inner[4], inner[5]]), Color(1, 1, 1, 0.08))
	draw_polyline(_closed(inner), color if not downed else UiSkin.DANGER, 2.5)
	if downed:
		draw_rect(Rect2(center + Vector2(-5, -16), Vector2(10, 32)), UiSkin.DANGER)
		draw_rect(Rect2(center + Vector2(-16, -5), Vector2(32, 10)), UiSkin.DANGER)
	else:
		var f := UiSkin.title_font()
		var text := "P%d" % (index + 1)
		draw_string_outline(f, center + Vector2(-PORTRAIT_RADIUS, 11), text, HORIZONTAL_ALIGNMENT_CENTER, PORTRAIT_RADIUS * 2, 30, 6, UiSkin.INK)
		draw_string(f, center + Vector2(-PORTRAIT_RADIUS, 11), text, HORIZONTAL_ALIGNMENT_CENTER, PORTRAIT_RADIUS * 2, 30, color.lightened(0.45))
	if downed and player.revive_progress > 0.0:
		draw_arc(center, PORTRAIT_RADIUS + 9, -PI / 2, -PI / 2 + TAU * player.revive_progress, 32, UiSkin.SAFE, 4.0)


func _draw_bar(downed: bool) -> void:
	var back := UiSkin.chamfer_points(BAR.grow(3), 8)
	draw_colored_polygon(back, UiSkin.INK)
	draw_polyline(_closed(back), UiSkin.BRASS.darkened(0.2), 1.5)
	var inner := BAR
	draw_rect(inner, Color(0.12, 0.03, 0.04))
	if _ghost_hp > _shown_hp:
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * _ghost_hp, inner.size.y)), Color(1.0, 0.85, 0.55, 0.85))
	if _shown_hp > 0.0:
		var fill := Rect2(inner.position, Vector2(inner.size.x * _shown_hp, inner.size.y))
		var top := UiSkin.LIFE_LIGHT if not downed else Color(0.45, 0.45, 0.45)
		var bottom := UiSkin.LIFE.darkened(0.35) if not downed else Color(0.2, 0.2, 0.2)
		draw_polygon(PackedVector2Array([fill.position, Vector2(fill.end.x, fill.position.y), fill.end, Vector2(fill.position.x, fill.end.y)]),
				PackedColorArray([top, top, bottom, bottom]))
		draw_rect(Rect2(fill.position + Vector2(0, 2), Vector2(fill.size.x, 3)), Color(1, 1, 1, 0.22))
		if _hit_flash > 0.0:
			draw_rect(fill, Color(1, 1, 1, _hit_flash * 0.35))
	# Marcas a cada 25 de vida.
	var step := 25.0 / player.health.max_hp
	var mark := step
	while mark < 0.999:
		var x := inner.position.x + inner.size.x * mark
		draw_line(Vector2(x, inner.position.y), Vector2(x, inner.position.y + inner.size.y * 0.45), Color(0, 0, 0, 0.55), 2.0)
		mark += step
	var f := UiSkin.font("Bold")
	var text := "%d / %d" % [ceili(player.health.hp), roundi(player.health.max_hp)]
	if downed:
		text = "CAÍDO · chegue perto pra reviver"
	draw_string_outline(f, inner.position + Vector2(0, 16), text, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 14, 5, UiSkin.INK)
	draw_string(f, inner.position + Vector2(0, 16), text, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, 14, Color.WHITE)


## Microfone ao lado do nome: aceso enquanto essa pessoa fala; cortado se o host mutou.
func _draw_voice(center: Vector2) -> void:
	var muted: bool = Voice.muted_by_host.has(player.owner_peer)
	var speaking: bool = Voice.is_speaking(player.owner_peer)
	if not muted and not speaking:
		return
	var color := UiSkin.DANGER if muted else UiSkin.SAFE.lerp(Color.WHITE, 0.3 * (0.5 + 0.5 * sin(_time * 12.0)))
	draw_rect(Rect2(center + Vector2(-3.5, -7), Vector2(7, 10)), color)
	draw_arc(center + Vector2(0, 1), 6.0, 0.0, PI, 10, color, 1.5)
	draw_line(center + Vector2(0, 7), center + Vector2(0, 10), color, 1.5)
	if muted:
		draw_line(center + Vector2(-7, -8), center + Vector2(7, 9), UiSkin.INK, 3.0)
		draw_line(center + Vector2(-7, -8), center + Vector2(7, 9), color, 1.5)


## Barra fina de experiência embaixo da vida (neon).
func _draw_xp() -> void:
	draw_rect(XP_BAR.grow(1), UiSkin.INK)
	draw_rect(XP_BAR, Color(0.05, 0.12, 0.14))
	var ratio := player.progress.xp_ratio()
	if ratio > 0.0:
		draw_rect(Rect2(XP_BAR.position, Vector2(XP_BAR.size.x * ratio, XP_BAR.size.y)), UiSkin.NEON)
		draw_rect(Rect2(XP_BAR.position, Vector2(XP_BAR.size.x * ratio, 1)), Color(1, 1, 1, 0.5))


## Selo do nível no canto do retrato; pisca em âmbar com pontos de chip para instalar.
func _draw_level_badge(center: Vector2) -> void:
	var free := player.progress.points_free() if player.is_local() else 0
	var glow := 0.5 + 0.5 * sin(_time * 5.0)
	var ring := UiSkin.AMBER.lerp(Color.WHITE, glow * 0.4) if free > 0 else UiSkin.BRASS
	draw_circle(center, 14.0, UiSkin.INK)
	draw_circle(center, 12.0, Color(0.08, 0.08, 0.1))
	draw_arc(center, 12.0, 0, TAU, 24, ring, 2.5 if free > 0 else 1.5)
	var f := UiSkin.font("Bold")
	var text := str(player.progress.level)
	draw_string(f, center + Vector2(-14, 5), text, HORIZONTAL_ALIGNMENT_CENTER, 28, 14, UiSkin.TEXT)
	if free > 0:
		var hint := "+%d chip" % free
		draw_string_outline(f, center + Vector2(16, 5), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, UiSkin.INK)
		draw_string(f, center + Vector2(16, 5), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UiSkin.AMBER, 0.6 + 0.4 * glow))


func _draw_hotbar() -> void:
	var entries := [
		["X", player.equipped("melee"), 0.0, 0.0],
		["RT", player.equipped("ranged"), 0.0, 0.0],
		["Y", "potion", player.potion_cooldown, GameConfig.POTION_COOLDOWN * player.cooldown_factor()],
		["B", "dodge", player.dodge_cooldown_left(), GameConfig.DODGE_COOLDOWN * player.cooldown_factor()],
	]
	var x := BAR.position.x
	for entry: Array in entries:
		var rect := Rect2(x, HOTBAR_Y, HOTBAR_SLOT, HOTBAR_SLOT)
		draw_style_box(UiSkin.slot(), rect)
		var content: Variant = entry[1]
		var icon_rect := rect.grow(-6)
		if content is Dictionary:
			ItemIcon.draw_item(self, content, icon_rect)
			draw_rect(rect.grow(-1), Color(ItemDB.rarity_color(content), 0.6), false, 1.5)
		elif content == "potion":
			_draw_flask(icon_rect)
		elif content == "dodge":
			_draw_roll(icon_rect)
		var cooldown: float = entry[2]
		if cooldown > 0.0 and entry[3] > 0.0:
			_draw_cooldown(rect, cooldown / entry[3], cooldown)
		UiSkin.draw_button_hint(self, rect.position + Vector2(rect.size.x - 2, rect.size.y - 2), entry[0], 7.5)
		x += HOTBAR_SLOT + 12


## Varredura escura de recarga (sentido horário) e os segundos que faltam.
func _draw_cooldown(rect: Rect2, ratio: float, seconds: float) -> void:
	var center := rect.get_center()
	var radius := rect.size.x * 0.75
	var points := PackedVector2Array([center])
	var start := -PI / 2 + TAU * (1.0 - ratio)
	var steps := 24
	for i in steps + 1:
		var angle := start + (TAU * ratio) * i / steps
		var p := center + Vector2(cos(angle), sin(angle)) * radius
		points.append(Vector2(clampf(p.x, rect.position.x + 2, rect.end.x - 2), clampf(p.y, rect.position.y + 2, rect.end.y - 2)))
	if points.size() >= 3:
		draw_colored_polygon(points, Color(0, 0, 0, 0.62))
	if seconds >= 1.0:
		var f := UiSkin.font("Bold")
		draw_string_outline(f, rect.position + Vector2(0, 21), str(ceili(seconds)), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 15, 4, UiSkin.INK)
		draw_string(f, rect.position + Vector2(0, 21), str(ceili(seconds)), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 15, Color.WHITE)


func _draw_flask(r: Rect2) -> void:
	var c := r.get_center() + Vector2(0, r.size.y * 0.12)
	draw_circle(c, r.size.x * 0.36, Color(0.9, 0.15, 0.3))
	draw_circle(c + Vector2(-3, -3), r.size.x * 0.12, Color(1, 0.7, 0.75, 0.8))
	draw_rect(Rect2(r.get_center() + Vector2(-3, -r.size.y * 0.5), Vector2(6, r.size.y * 0.32)), Color(0.75, 0.8, 0.85))
	draw_rect(Rect2(r.get_center() + Vector2(-4, -r.size.y * 0.55), Vector2(8, 3)), UiSkin.BRASS)


func _draw_roll(r: Rect2) -> void:
	var c := r.get_center()
	draw_arc(c, r.size.x * 0.36, PI * 0.15, PI * 1.6, 14, UiSkin.NEON, 3.0)
	var tip := c + Vector2(cos(PI * 0.15), sin(PI * 0.15)) * r.size.x * 0.36
	draw_colored_polygon(PackedVector2Array([tip + Vector2(-6, -2), tip + Vector2(4, -4), tip + Vector2(1, 6)]), UiSkin.NEON)


## Parafusos: ícone de parafuso e a quantia, alinhados à direita em `at`.
func _draw_money(at: Vector2) -> void:
	var f := UiSkin.font("Bold")
	var text := str(player.inventory.gold)
	var width := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var bolt := at + Vector2(-width - 14, -6)
	_draw_bolt(bolt, 7.0)
	draw_string_outline(f, Vector2(at.x - width, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, UiSkin.INK)
	draw_string(f, Vector2(at.x - width, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiSkin.AMBER)


func _draw_bolt(center: Vector2, radius: float) -> void:
	var hexagon := PackedVector2Array()
	for i in 6:
		hexagon.append(center + Vector2.from_angle(TAU * i / 6.0) * radius)
	draw_colored_polygon(hexagon, UiSkin.AMBER.darkened(0.2))
	draw_polyline(_closed(hexagon), UiSkin.INK, 1.5)
	draw_line(center + Vector2(-radius * 0.5, 0), center + Vector2(radius * 0.5, 0), UiSkin.INK, 2.0)


func _hexagon(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 6:
		points.append(center + Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * radius)
	return points


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	result.append(points[0])
	return result
