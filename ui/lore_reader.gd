class_name LoreReader
extends PanelContainer
## Tela de leitura de um documento da história (caderno, terminal...). Abre pelo LB / F perto
## de um LoreNote; quem abriu passa a saber os fatos do documento. Cima/baixo rola · B / Esc /
## LB / F fecha.

signal close_requested

var slot := 0
var _text: RichTextLabel
## O mesmo aperto que abriu não fecha: espera um instante antes de ler os botões.
var _guard := 0.2


## `reader_name`: o nome do herói que lê, no lugar de {nome} no texto (o diário pessoal).
func open_for(p_slot: int, doc: LoreDocument, terminal := false, reader_name := "") -> void:
	slot = p_slot
	InputService.set_blocked(slot, true)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.04, 0.96) if terminal else Color(0.13, 0.11, 0.08, 0.97)
	style.border_color = Color(0.2, 0.9, 0.55, 0.6) if terminal else Color(0.55, 0.45, 0.3)
	style.set_border_width_all(2)
	style.set_content_margin_all(22)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(720, 520)
	var ink := Color(0.55, 1.0, 0.7) if terminal else Color(0.92, 0.88, 0.78)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var who := reader_name if not reader_name.is_empty() else "?"
	column.add_child(UiSkin.label(Txt.t(doc.title).replace("{nome}", who), 24, ink, "Bold", 3))
	if doc.author:
		column.add_child(UiSkin.label(Txt.t(doc.author).replace("{nome}", who), 15, Color(ink, 0.65), "Regular", 2))
	_text = RichTextLabel.new()
	_text.bbcode_enabled = false
	_text.text = Txt.t(doc.text).replace("{nome}", who).replace("{companhia}", _company_text())
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 18)
	_text.add_theme_color_override("default_color", ink)
	if terminal:
		_text.add_theme_font_override("normal_font", SystemFont.new())
	column.add_child(_text)
	column.add_child(UiSkin.label("Cima/baixo rola · B / Esc fecha", 13, Color(1, 1, 1, 0.5), "Regular", 2))
	Sound.play("ui_confirm")


## {companhia} no diário: sozinho ou com o grupo que entrou junto.
func _company_text() -> String:
	var others := maxi(get_tree().get_nodes_in_group("players").size() - 1, 0) if is_inside_tree() else 0
	if others == 0:
		return Txt.t("Vim por conta própria. Melhor assim: ninguém para dividir os parafusos, ninguém para me atrasar.")
	return Txt.t("Não vim só. Vieram comigo uns conhecidos tão sem rumo quanto eu. Um bando de tontos, mas é o bando que eu tenho, e com mais gente a sucata pesa menos.")


func _exit_tree() -> void:
	InputService.set_blocked(slot, false)


func _physics_process(delta: float) -> void:
	if not InputService.is_active(slot):
		return
	_guard -= delta
	if _guard > 0.0:
		return
	var move := InputService.raw_move(slot)
	if absf(move.y) > 0.3:
		_text.get_v_scroll_bar().value += move.y * 600.0 * delta
	if InputService.back_just_pressed(slot) or InputService.raw_just_pressed(slot, InputService.Action.PICKUP) \
			or InputService.raw_just_pressed(slot, InputService.Action.PAUSE):
		close_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE \
			and InputService.device_of(slot) == InputService.KEYBOARD:
		get_viewport().set_input_as_handled()
		close_requested.emit()
