@tool
extends ConfirmationDialog
## Ficha de uma peça do cenário (PropDef): nome, tipo, tamanho, giro e o que muda por tipo.
## Salvar gera a peça pronta em world/prefabs.

signal saved(prefab_path: String)

var def: PropDef

var _name: LineEdit
var _kind: OptionButton
var _scale: SpinBox
var _rot_x: SpinBox
var _rot_y: SpinBox
var _rot_z: SpinBox
var _mass: SpinBox
var _title: LineEdit
var _gold: SpinBox
var _items: SpinBox
var _physics_box: Control
var _container_box: Control
var _model_label: Label


func _init() -> void:
	title = "Ficha da peça"
	ok_button_text = "Salvar peça"
	min_size = Vector2i(460, 0)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 6)
	add_child(form)
	_model_label = Label.new()
	_model_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(_model_label)
	_name = _line(form, "Nome")
	_kind = OptionButton.new()
	for kind: String in PropDef.KINDS:
		_kind.add_item(PropDef.KIND_NAMES[kind])
	_kind.item_selected.connect(func(_i: int) -> void: _update_visibility())
	_row(form, "Tipo", _kind)
	_scale = _spin(form, "Tamanho (x)", 0.01, 100.0, 0.01)
	var rotation_row := HBoxContainer.new()
	_rot_x = _spin_in(rotation_row, -180, 180, 1)
	_rot_y = _spin_in(rotation_row, -180, 180, 1)
	_rot_z = _spin_in(rotation_row, -180, 180, 1)
	_row(form, "Giro X / Y / Z (°)", rotation_row)
	_physics_box = VBoxContainer.new()
	form.add_child(_physics_box)
	_mass = _spin(_physics_box, "Peso (kg)", 0.1, 2000.0, 0.1)
	_container_box = VBoxContainer.new()
	form.add_child(_container_box)
	_title = _line(_container_box, "Nome ao abrir")
	_gold = _spin(_container_box, "Parafusos (moedas)", 0, 100000, 1)
	_items = _spin(_container_box, "Itens sorteados", 0, 10, 1)
	var hint := Label.new()
	hint.text = "Itens fixos do contêiner: depois de colocar no mapa, no Inspetor (Contents)."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(1, 1, 1, 0.6)
	_container_box.add_child(hint)
	confirmed.connect(_on_confirmed)


func edit(p_def: PropDef) -> void:
	def = p_def
	_model_label.text = "Modelo: %s" % (def.model.resource_path if def.model else "?")
	_name.text = def.display_name
	_kind.select(maxi(PropDef.KINDS.find(def.kind), 0))
	_scale.value = def.scale
	_rot_x.value = def.rotation_deg.x
	_rot_y.value = def.rotation_deg.y
	_rot_z.value = def.rotation_deg.z
	_mass.value = def.mass
	_title.text = def.container_title
	_gold.value = def.gold
	_items.value = def.random_items
	_update_visibility()
	popup_centered()


func _update_visibility() -> void:
	var kind: String = PropDef.KINDS[_kind.selected]
	_physics_box.visible = kind == "fisico"
	_container_box.visible = kind == "conteiner"


func _on_confirmed() -> void:
	def.display_name = _name.text.strip_edges()
	if def.id.is_empty():
		def.id = PropBuilder.id_from(def.display_name)
	def.kind = PropDef.KINDS[_kind.selected]
	def.scale = _scale.value
	def.rotation_deg = Vector3(_rot_x.value, _rot_y.value, _rot_z.value)
	def.mass = _mass.value
	def.container_title = _title.text
	def.gold = int(_gold.value)
	def.random_items = int(_items.value)
	saved.emit(PropBuilder.save(def))


func _line(parent: Control, text: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row(parent, text, edit)
	return edit


func _spin(parent: Control, text: String, low: float, high: float, step: float) -> SpinBox:
	var row := HBoxContainer.new()
	var spin := _spin_in(row, low, high, step)
	_row(parent, text, row)
	return spin


func _spin_in(parent: Control, low: float, high: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spin)
	return spin


func _row(parent: Control, text: String, field: Control) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
