@tool
class_name QuestItem
extends LootContainer
## Item de missão no mapa (diário, carta, chave...): o próprio item no chão. Perto, LB / F pega e
## ele vai direto para a mochila de quem pegou (sem lugar, cai no chão do lado). Some depois de
## pego (uma vez por mundo). Missão com início "item" desse id começa ao pegar; objetivo "pegar"
## conta; se o item é de ler, ler pelo inventário conta para "ler".
##
## O que ele dá é o conteúdo de contêiner de sempre: no /editar, F em cima dele escolhe o item
## (no editor do Godot, `contents` no Inspector). O primeiro item define o visual.

const PICK_RANGE := 1.6


func _init() -> void:
	open_range = PICK_RANGE
	open_sound = "pickup"
	title = "Item"


func _ready() -> void:
	super()
	if not Engine.is_editor_hint():
		add_to_group("quest_items")


## Id do item que ele dá (o primeiro do conteúdo), ou "".
func item_id() -> String:
	for line: ContainerItem in contents:
		if line and ItemDB.has(line.item_id):
			return line.item_id
	return ""


func refresh() -> void:
	super()
	visible = not _opened or Engine.is_editor_hint()


func open_by(player: Node3D) -> bool:
	if _opened or is_locked() or _flat(player.global_position - global_position).length() > open_range:
		return false
	var loot: Script = load(LOOT_SCRIPT)
	for line: ContainerItem in contents:
		if line == null or not ItemDB.has(line.item_id):
			continue
		for i in maxi(line.count, 1):
			var item := ItemDB.make(line.item_id, maxi(line.power, 1), "common" if line.rarity == "random" else line.rarity)
			if not player.has_method("give_item") or not player.give_item(item):
				loot.drop(self, item, _flat(global_position + Vector3(0.6, 0, 0)))
	if gold > 0 and player.has_method("give_item"):
		player.give_item(ItemDB.make_gold(gold))
	_net().set_container_opened(container_id)
	return true


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _label == null:
		return
	var near := false
	if not _opened:
		for player: Node3D in get_tree().get_nodes_in_group("players"):
			if player.is_local() and _flat(player.global_position - global_position).length() <= open_range:
				near = true
				break
	var name_text := ItemDB.display_name({"id": item_id()}) if not item_id().is_empty() else Txt.t(title)
	_label.text = (InputService.pickup_text(Txt.t("%s\n[LB / F] pegar")) % name_text if not is_locked() else Txt.t("%s\n(trancado)") % name_text) if near else ""


## O conteúdo mudou (/editar): o visual vira o item novo.
func rebuild_visual() -> void:
	if is_inside_tree():
		_build_visual()


func _build_visual() -> void:
	if _visual:
		_visual.queue_free()
		_visual = null
	if model:
		super()
		return
	var id := item_id()
	_visual = Node3D.new()
	add_child(_visual)
	if id.is_empty():
		# Sem item escolhido ainda: uma caixinha de marcador (só no editor e no /editar).
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.25, 0.25, 0.25)
		mesh.mesh = box
		mesh.position.y = 0.12
		_visual.add_child(mesh)
		return
	var shown := ItemVisuals.build(ItemDB.make(id))
	shown.scale = Vector3.ONE * 0.9 * float(ItemDB.def({"id": id}).get("ground_scale", 1.0))
	shown.position.y = 0.02
	_visual.add_child(shown)
