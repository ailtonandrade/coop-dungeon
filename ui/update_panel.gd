class_name UpdatePanel
extends CanvasLayer
## Aviso de versão nova no menu principal (Updater): cartão grande com as novidades e
## "Atualizar agora" (baixa com progresso e reinicia atualizado) ou "Depois". Fechado, fica um
## selo no canto do menu que abre o cartão de novo.

var _card: PanelContainer
var _title: Label
var _subtitle: Label
var _notes: RichTextLabel
var _bar: ProgressBar
var _status: Label
var _main_button: Button
var _later_button: Button
var _badge: Button
var _root: Control


func _ready() -> void:
	# Camada própria, por cima do menu, presa na janela inteira.
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build()
	Updater.changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	if Updater.phase == Updater.Phase.DOWNLOADING:
		_bar.value = Updater.progress()
		var total := Updater.asset_size / 1048576.0
		_status.text = Txt.t("Baixando... %.0f%%%s") % [Updater.progress() * 100.0,
				Txt.t("  (%.1f MB de %.1f MB)") % [total * Updater.progress(), total] if total > 0.0 else ""]


func _build() -> void:
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiSkin.panel())
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.anchor_top = 0.5
	_card.anchor_bottom = 0.5
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card.custom_minimum_size = Vector2(620, 0)
	_root.add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_card.add_child(column)
	_title = UiSkin.title("NOVA VERSÃO DISPONÍVEL", 30, UiSkin.NEON)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_subtitle = UiSkin.label("", 18, UiSkin.TEXT, "SemiBold", 3)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_subtitle)
	_notes = RichTextLabel.new()
	_notes.bbcode_enabled = true
	_notes.fit_content = true
	_notes.scroll_active = false
	_notes.custom_minimum_size = Vector2(0, 40)
	_notes.add_theme_font_size_override("normal_font_size", 16)
	column.add_child(_notes)
	_bar = ProgressBar.new()
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 18)
	column.add_child(_bar)
	_status = UiSkin.label("", 15, UiSkin.DIM, "Regular", 3)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	_main_button = Button.new()
	_main_button.custom_minimum_size = Vector2(280, 52)
	_main_button.pressed.connect(_on_main)
	row.add_child(_main_button)
	_later_button = Button.new()
	_later_button.text = "Depois"
	_later_button.custom_minimum_size = Vector2(160, 52)
	_later_button.pressed.connect(func() -> void:
		Updater.dismissed = Updater.latest
		_refresh())
	row.add_child(_later_button)

	_badge = Button.new()
	_badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_badge.offset_left = 24
	_badge.offset_bottom = -44
	_badge.add_theme_color_override("font_color", UiSkin.NEON)
	_badge.pressed.connect(func() -> void:
		Updater.dismissed = ""
		_refresh())
	_root.add_child(_badge)


func _refresh() -> void:
	var busy := Updater.phase in [Updater.Phase.DOWNLOADING, Updater.Phase.INSTALLING]
	var show := Updater.has_update() and (Updater.dismissed != Updater.latest or busy)
	_card.visible = show
	_badge.visible = Updater.has_update() and not show
	_badge.text = Txt.t("⬆ Versão %s disponível · atualizar") % Updater.latest
	if not show:
		return
	_subtitle.text = Txt.t("Versão %s  ·  você está na %s") % [Updater.latest, Updater.current]
	_notes.text = _short_notes(Updater.notes)
	_notes.visible = not _notes.text.is_empty()
	_bar.visible = busy
	_later_button.visible = not busy
	_main_button.visible = Updater.phase != Updater.Phase.INSTALLING
	_main_button.disabled = busy
	if Updater.is_dev_copy():
		_main_button.text = "Abrir a página da versão"
		_status.text = "Esta é a cópia de desenvolvimento (editor do Godot): atualize pelo Git."
	elif Updater.can_self_update():
		_main_button.text = "Baixando..." if busy else "Atualizar agora"
		_status.text = "O jogo baixa a versão nova, fecha e abre de novo já atualizado."
	else:
		_main_button.text = "Baixar no site"
		_status.text = "Baixe o .zip da versão nova, extraia e jogue por ele."
	if Updater.phase == Updater.Phase.INSTALLING:
		_status.text = Txt.t("Instalando... o jogo vai fechar e abrir de novo, já na versão %s.") % Updater.latest
	elif Updater.phase == Updater.Phase.ERROR:
		_status.text = Updater.error_text
		_main_button.text = "Tentar de novo"
		_main_button.disabled = false
	if not busy:
		_main_button.grab_focus.call_deferred()


func _on_main() -> void:
	if Updater.is_dev_copy():
		Updater.open_page()
	else:
		Updater.start_update()


## Novidades do release, só as primeiras linhas, sem a parte de "Como jogar".
static func _short_notes(body: String) -> String:
	var lines := PackedStringArray()
	for line in body.split("\n"):
		var clean := line.strip_edges()
		if clean.begins_with("**Como jogar") or clean.begins_with("## What's Changed") and lines.size() > 0:
			break
		if clean.is_empty() or clean.begins_with("**Full Changelog"):
			continue
		clean = clean.replace("**", "").trim_prefix("## ").trim_prefix("- ").trim_prefix("* ")
		if clean.begins_with("What's Changed"):
			clean = "Novidades:"
		lines.append(("• " if lines.size() > 0 and not clean.ends_with(":") else "") + clean.left(110))
		if lines.size() >= 7:
			break
	return "\n".join(lines)
