extends Node
## Modo construtor: ferramenta do DONO DO JOGO para montar o mapa andando por ele e carimbando
## peças prontas, como no editor de mapa, só que de dentro do jogo. Jogadores não têm acesso:
## este arquivo nem vai no jogo exportado (filtro de exportação; o mundo só carrega se ele
## existir e se estiver rodando pelo editor do Godot), sem class_name para ninguém citar, e não
## aparece em menu nenhum. Liga e desliga digitando COMMAND no chat (a mensagem não vai para a sala).
## Peça física cai de DROP_HEIGHT, rola e, quando para, fica gravada ali, direto na cena do
## bloco (WorldEdits).
##
## Teclado e mouse: clique esquerdo coloca no cursor · Q/E ou rodinha troca a peça (dentro da
## categoria) · V próxima categoria (Shift+V volta) · R gira 45° (Shift+R volta) · Z desfaz a
## última · Delete apaga a peça do construtor no cursor · F edita o conteúdo do contêiner.
## Controle: X coloca à frente · direcional ◀ ▶ troca a peça · ▼ próxima categoria · Y gira ·
## B desfaz · RB edita o contêiner à frente.
## Categorias = subpastas de world/prefabs (PropBuilder.catalog).

## O que digitar no chat para entrar e sair.
## (O /construir é da construção da base dos jogadores; este editor de mapa é o /editar.)
const COMMAND := "/editar"

const MapWriter := preload("res://world/map_writer.gd")

const DROP_HEIGHT := 1.5
const AHEAD := 2.5
const REMOVE_RADIUS := 1.6
## Encaixe de estrutura: grade sem vizinha e distância máxima até a vizinha.
const GRID := 0.5
## Ajuste de altura: passo normal e fino (Shift), e o dedo que peça chata sobe sozinha.
const LIFT_STEP := 0.05
const LIFT_FINE := 0.01
const FLAT_LIFT := 0.02
const SNAP_REACH := 1.6
## Peça física que não parar sozinha em tanto tempo é gravada onde estiver.
const SETTLE_MAX := 6.0

var active := false
var slot := -1

var _catalog: Array[Dictionary] = []
var _index := 0
var _yaw := 0.0
var _ghost: Node3D
var _ghost_material: StandardMaterial3D
var _target := Vector3.ZERO
var _target_ok := false
## Peças físicas caindo: [nó, chave do bloco, segundos].
var _settling: Array = []
## Desfazer: ids colocados nesta sessão, do mais antigo ao mais novo.
var _undo: Array[String] = []
## Peça pega para mudar de lugar (G / ▲): o nó no mundo e a altura dele acima do chão.
var _carrying: Node3D = null
## Altura extra da peça (PgUp/PgDn, Shift+rodinha; R3/L3 no controle). Home zera.
var _lift := 0.0
var _carry_lift := 0.0
var _hud: CanvasLayer
var _title: Label
var _piece: Label
var _hint: Label
var _pad_was := {}
## Painel do conteúdo do contêiner (aberto sobre um contêiner do construtor).
var _loot_panel: PanelContainer
var _loot_items: ItemList
var _loot_inside: ItemList
var _loot_gold: Label
var _loot_target: Node
var _loot_lines: Array = []  # [[item, quantidade]...]
var _loot_gold_value := 0


## O modo construtor da cena, ou null (no jogo exportado ele nem existe).
static func of(node: Node) -> Node:
	return node.get_tree().get_first_node_in_group("god_mode") if node.is_inside_tree() else null


func _ready() -> void:
	add_to_group("god_mode")
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material.albedo_color = Color(0.3, 0.95, 1.0, 0.45)
	_build_hud()


## Só o dono do jogo: rodando pelo editor do Godot, mandando no mundo (sozinho, sofá ou host).
static func allowed() -> bool:
	return OS.has_feature("editor") and NetService.mode != NetService.Mode.CLIENT


static func is_command(text: String) -> bool:
	return text.strip_edges().to_lower() == COMMAND


func toggle(p_slot: int) -> void:
	if active:
		stop()
	else:
		start(p_slot)


func start(p_slot: int) -> void:
	if not allowed() or _player_of(p_slot) == null:
		return
	slot = p_slot
	active = true
	Player.set_editor_shield("editar", true)
	_catalog = PropBuilder.catalog(true)
	_index = clampi(_index, 0, maxi(_catalog.size() - 1, 0))
	_player_of(slot).building = true
	InputService.builder_slot = slot
	# Peças de verdade de volta (a decoração juntada não dá para mexer).
	var streamer := get_tree().get_first_node_in_group("world_streamer")
	if streamer and streamer.has_method("set_batching"):
		streamer.set_batching(false)
	_rebuild_ghost()
	_hud.visible = true
	QuestArea.show_markers = true
	_refresh_hud()
	Chat.local_note(Txt.t("Modo construtor ligado (%s de novo para sair).") % COMMAND)


func stop() -> void:
	cancel_carry()
	QuestArea.show_markers = false
	if not active:
		return
	Player.set_editor_shield("editar", false)
	if _loot_panel.visible:
		close_loot_editor()
	var player := _player_of(slot)
	if player:
		player.building = false
	InputService.builder_slot = -1
	active = false
	var streamer := get_tree().get_first_node_in_group("world_streamer")
	if streamer and streamer.has_method("set_batching"):
		streamer.set_batching(true)
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	_hud.visible = false
	Chat.local_note("Modo construtor desligado.")


## Peça escolhida agora ({path, name, kind, def}).
func current() -> Dictionary:
	return _catalog[_index] if _index < _catalog.size() else {}


## Troca a peça dentro da categoria atual (dá a volta nela).
func select_next(step: int) -> void:
	if _catalog.is_empty():
		return
	var same := _in_category(current_category())
	var at := same.find(_index)
	_index = same[wrapi(at + step, 0, same.size())]
	Sound.play("ui_move")
	_rebuild_ghost()
	_refresh_hud()


## Vai para a primeira peça da próxima categoria (pasta).
func next_category(step: int) -> void:
	if _catalog.is_empty():
		return
	var names := PropBuilder.categories(_catalog)
	var category: String = names[wrapi(names.find(current_category()) + step, 0, names.size())]
	_index = _in_category(category)[0]
	Sound.play("ui_move")
	_rebuild_ghost()
	_refresh_hud()


func current_category() -> String:
	return String(current().get("category", PropBuilder.GENERAL))


## Índices do catálogo que estão na categoria.
func _in_category(category: String) -> Array[int]:
	var result: Array[int] = []
	for i in _catalog.size():
		if _catalog[i].category == category:
			result.append(i)
	return result


## Sobe/desce a peça (antes de colocar). Mostra a altura na barra do construtor.
func change_lift(delta_m: float) -> void:
	_lift = snappedf(clampf(_lift + delta_m, -3.0, 30.0), 0.01)
	Sound.play("ui_move")
	_refresh_hud()


func rotate_piece(step_deg: float) -> void:
	# Estrutura (parede, piso...) gira de 90 em 90, para fechar cantos certinho.
	if _current_kind() == "estrutura":
		step_deg = 90.0 * signf(step_deg)
		_yaw = snappedf(_yaw, PI / 2.0)
	_yaw = wrapf(_yaw + deg_to_rad(step_deg), 0.0, TAU)


## Coloca a peça escolhida no ponto (global). Retorna o nó criado, ou null.
func place_at(point: Vector3) -> Node3D:
	if _carrying:
		var moved := _carrying
		return moved if drop_carried(point) else null
	var entry := current()
	var streamer := WorldStreamer.of(self)
	if entry.is_empty() or streamer == null:
		return null
	# Modelo de pack ainda solto: vira peça pronta (fixa) agora, na pasta do pack.
	if entry.get("raw", false):
		var made := PropBuilder.make_from_model(String(entry.path), String(entry.pack))
		if made.is_empty():
			Sound.play("ui_error")
			return null
		entry.path = made
		entry.raw = false
		entry.def = load(PropBuilder.DEF_DIR.path_join(made.get_file().get_basename() + ".tres"))
	var found: Array = streamer.chunk_at(point)
	var chunk: Node3D = found[0]
	if chunk == null:
		return null
	var scene := load(String(entry.path)) as PackedScene
	var node := scene.instantiate() as Node3D if scene else null
	if node == null:
		return null
	var id := WorldEdits.new_id()
	node.name = id
	if node is LootContainer:
		node.container_id = id
	var physics := node is RigidBody3D
	WorldEdits.parent_in(chunk).add_child(node)
	if physics:
		node.global_transform = Transform3D(Basis(Vector3.UP, _yaw), point + Vector3.UP * DROP_HEIGHT)
	else:
		node.global_transform = placement(point)
	Sound.play("ui_confirm", point)
	if physics:
		_settling.append([node, found[1], 0.0])
	else:
		_finalize(node, found[1])
	return node


## Desfaz a última peça colocada nesta sessão.
func undo() -> void:
	while not _undo.is_empty():
		var id: String = _undo.pop_back()
		if remove_piece(id):
			return


## Apaga a peça mais perto do ponto: as do construtor e também as do mapa (postes, letreiros,
## barris... qualquer peça pronta posta pelo editor de mapa). Casas, chão e NPCs não.
func remove_near(point: Vector3) -> bool:
	var best := piece_near(point)
	if best == null:
		Sound.play("ui_error")
		return false
	if _is_builder_piece(best):
		return remove_piece(String(best.name))
	return _remove_map_piece(best)


## Peça (do construtor ou do mapa) mais perto do ponto, no chão. Null se nenhuma perto.
func piece_near(point: Vector3) -> Node3D:
	var streamer := WorldStreamer.of(self)
	if streamer == null:
		return null
	var best: Node3D = null
	var best_distance := REMOVE_RADIUS
	for chunk: Node in streamer.get_children():
		for node: Node in chunk.find_children("*", "Node3D", true, false):
			if node == _carrying or not is_piece(node, chunk):
				continue
			var distance := Combat.flat((node as Node3D).global_position - point).length()
			if distance < best_distance:
				best = node
				best_distance = distance
	return best


## O que o construtor pode apagar e mover: peças dele e peças prontas (cenas) do mapa.
static func is_piece(node: Node, chunk: Node) -> bool:
	if not node is Node3D or (node as Node3D).get_parent() == null:
		return false
	if _is_builder_piece(node):
		return true
	var path := node.scene_file_path
	return node.owner == chunk and path.ends_with(".tscn") and not path.begins_with("res://world/lore/") \
			and not path.begins_with("res://world/interiors/") and not path.begins_with("res://world/chunks/")


static func _is_builder_piece(node: Node) -> bool:
	return String(node.name).begins_with(WorldEdits.ID_PREFIX)


func _chunk_of(node: Node) -> Node3D:
	var streamer := WorldStreamer.of(self)
	var current_node := node
	while current_node and current_node.get_parent() != streamer:
		current_node = current_node.get_parent()
	return current_node as Node3D


## Peça do mapa: sai da cena do bloco (o arquivo) e do mundo.
func _remove_map_piece(node: Node3D) -> bool:
	var chunk := _chunk_of(node)
	var streamer := WorldStreamer.of(self)
	if chunk == null or not WorldEdits.saves_in_map_files():
		Sound.play("ui_error")
		return false
	var key: String = streamer.key_of(chunk)
	if not MapWriter.remove_path(streamer.scene_path_of(key), chunk.get_path_to(node)):
		Sound.play("ui_error")
		return false
	node.queue_free()
	WorldStreamer.bake_navigation.call_deferred(chunk, true)
	Sound.play("ui_back")
	Chat.local_note(Txt.t("Apagado do mapa: %s") % String(node.name))
	return true


## Pega a peça perto do ponto para mudar de lugar (ou larga, se já está carregando uma).
func grab_near(point: Vector3) -> bool:
	if _carrying:
		cancel_carry()
		return false
	var node := piece_near(point)
	if node == null:
		Sound.play("ui_error")
		return false
	_carrying = node
	# Altura acima do chão (letreiro na parede continua na mesma altura no lugar novo).
	var space := node.get_world_3d().direct_space_state
	var from := node.global_position + Vector3.UP * 0.2
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 20.0, GameConfig.LAYER_SOLID)
	var hit := space.intersect_ray(query)
	_carry_lift = node.global_position.y - (hit.position as Vector3).y if not hit.is_empty() else 0.0
	_carry_lift = maxf(_carry_lift, 0.0)
	_yaw = node.global_rotation.y
	node.visible = false
	_rebuild_ghost()
	_refresh_hud()
	Sound.play("ui_move")
	return true


func cancel_carry() -> void:
	if is_instance_valid(_carrying):
		_carrying.visible = true
	_carrying = null
	_rebuild_ghost()
	_refresh_hud()


## Larga a peça carregada no ponto: muda de lugar no mundo e no arquivo.
func drop_carried(point: Vector3) -> bool:
	var node := _carrying
	if not is_instance_valid(node):
		_carrying = null
		return false
	var streamer := WorldStreamer.of(self)
	var found: Array = streamer.chunk_at(point)
	var target_chunk: Node3D = found[0]
	var old_chunk := _chunk_of(node)
	if target_chunk == null or old_chunk == null:
		Sound.play("ui_error")
		return false
	var wanted := Transform3D(Basis(Vector3.UP, _yaw) * Basis.from_scale(node.global_basis.get_scale()), point + Vector3.UP * (_carry_lift + _lift))
	if kind_of_node(node) == "estrutura":
		var snapped := placement(point)
		wanted = Transform3D(snapped.basis * Basis.from_scale(node.global_basis.get_scale()), snapped.origin)
	if _is_builder_piece(node):
		var old_key: String = streamer.key_of(old_chunk)
		if WorldEdits.saves_in_map_files():
			MapWriter.remove_from_scene(streamer.scene_path_of(old_key), String(node.name))
		NetService.remove_world_edit(String(node.name))
		if target_chunk != old_chunk:
			node.reparent(WorldEdits.parent_in(target_chunk))
		node.global_transform = wanted
		_finalize(node, found[1])
	else:
		# Peça do mapa: fica no mesmo bloco (o arquivo de cada bloco é separado).
		if target_chunk != old_chunk or not WorldEdits.saves_in_map_files():
			Sound.play("ui_error")
			Chat.local_note("Peça do mapa só muda de lugar dentro do mesmo bloco.")
			return false
		node.global_transform = wanted
		if not MapWriter.move_path(streamer.scene_path_of(streamer.key_of(old_chunk)), old_chunk.get_path_to(node), node.transform):
			Sound.play("ui_error")
			return false
		WorldStreamer.bake_navigation(old_chunk, true)
	node.visible = true
	_carrying = null
	_rebuild_ghost()
	_refresh_hud()
	Sound.play("ui_confirm", point)
	return true


func remove_piece(id: String) -> bool:
	var streamer := WorldStreamer.of(self)
	if streamer == null:
		return false
	var removed := false
	for chunk: Node3D in streamer.get_children():
		var node := WorldEdits.parent_in(chunk).get_node_or_null(NodePath(id))
		# Já apagada neste quadro (some no fim dele): não conta de novo.
		if node == null or node.is_queued_for_deletion():
			continue
		var key: String = streamer.chunk_at(node.global_position)[1]
		if WorldEdits.saves_in_map_files():
			MapWriter.remove_from_scene(streamer.scene_path_of(key), id)
		node.queue_free()
		WorldStreamer.bake_navigation.call_deferred(chunk, true)
		removed = true
	if removed:
		_settling = _settling.filter(func(item: Array) -> bool: return is_instance_valid(item[0]) and item[0].name != id)
		NetService.remove_world_edit(id)
		Sound.play("ui_back")
	return removed


## Grava a peça onde ela está agora.
func _finalize(node: Node3D, key: String) -> void:
	var streamer := WorldStreamer.of(self)
	var chunk: Node3D = streamer.chunk_at(node.global_position)[0] if streamer else null
	if chunk == null:
		return
	var entry := {
		"id": String(node.name),
		"key": key,
		"prefab": node.scene_file_path,
		"xform": WorldEdits.pack_xform(chunk.global_transform.affine_inverse() * node.global_transform),
	}
	var in_file := WorldEdits.saves_in_map_files() and MapWriter.save_to_scene(streamer.scene_path_of(key), entry)
	NetService.add_world_edit(entry, in_file)
	_undo.append(entry.id)
	WorldStreamer.bake_navigation(chunk, true)


## Encaixe

## Onde a peça escolhida (ou a carregada) fica se largar agora no ponto:
## - estrutura (parede, piso, telhado...): fica onde está, sem cair, e encaixa na estrutura
##   vizinha (lado com lado ou em cima, com o giro dela de 90 em 90); longe de outra, prende
##   numa grade de meio metro;
## - peça fixa, contêiner ou enfeite solto no ar: desce até o chão (ou o que tiver embaixo);
## - peça física: cai sozinha (nasce no alto, ver place_at).
func placement(point: Vector3) -> Transform3D:
	var basis := Basis(Vector3.UP, _yaw)
	var kind := kind_of_node(_carrying) if is_instance_valid(_carrying) else _current_kind()
	if kind == "estrutura":
		var box := _carried_box() if is_instance_valid(_carrying) else _entry_box(current())
		return _snap_structure(point, box)
	if kind != "fisico":
		point = _floor_below(point)
	return Transform3D(basis, point + Vector3.UP * _lift)


func _current_kind() -> String:
	if is_instance_valid(_carrying):
		return kind_of_node(_carrying)
	return String(current().get("kind", "fixo"))


## Tipo da peça já no mundo (pela ficha dela), "" se não tiver ficha.
static func kind_of_node(node: Node) -> String:
	if node == null or not node.has_meta("prop_def"):
		return ""
	var path := String(node.get_meta("prop_def"))
	if not _kind_cache.has(path):
		var def := load(path) as PropDef if ResourceLoader.exists(path) else null
		_kind_cache[path] = def.kind if def else ""
	return _kind_cache[path]


static var _kind_cache := {}
static var _box_cache := {}


## Caixa da peça (no espaço dela) pela colisão (as peças prontas têm a base no chão e o centro no meio).
static func box_of(node: Node) -> AABB:
	var collision := node.get_node_or_null("Collision") as CollisionShape3D
	if collision and collision.shape is BoxShape3D:
		var size := (collision.shape as BoxShape3D).size
		return AABB(collision.position - size / 2.0, size)
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var local := _relative(node, mesh) * mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box if not first else AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)


func _entry_box(entry: Dictionary) -> AABB:
	var path := String(entry.get("path", ""))
	if _box_cache.has(path):
		return _box_cache[path]
	var box := AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)
	if entry.get("raw", false):
		var preview := PropBuilder.preview_from_model(path)
		if preview:
			var raw := box_of(preview)
			# Ao carimbar, a peça fica com a base no chão e o centro no meio.
			box = AABB(Vector3(-raw.size.x / 2.0, 0, -raw.size.z / 2.0), raw.size)
			preview.free()
	elif ResourceLoader.exists(path):
		var node := (load(path) as PackedScene).instantiate()
		box = box_of(node)
		node.free()
	_box_cache[path] = box
	return box


func _carried_box() -> AABB:
	return box_of(_carrying)


func _floor_below(point: Vector3) -> Vector3:
	var space := get_viewport().world_3d.direct_space_state if get_viewport() else null
	if space == null:
		return point
	var from := point + Vector3.UP * 0.3
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0, GameConfig.LAYER_SOLID)
	if is_instance_valid(_carrying) and _carrying is CollisionObject3D:
		query.exclude = [(_carrying as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(query)
	return hit.position if not hit.is_empty() else point


## Estruturas já no mundo perto do ponto (as do mapa e as do construtor).
func _structures_near(point: Vector3, reach: float) -> Array[Node3D]:
	var found: Array[Node3D] = []
	var streamer := WorldStreamer.of(self)
	if streamer == null:
		return found
	for chunk: Node in streamer.get_children():
		for node: Node in chunk.find_children("*", "StaticBody3D", true, false):
			if node == _carrying or not node.has_meta("prop_def") or kind_of_node(node) != "estrutura":
				continue
			if (node as Node3D).global_position.distance_to(point) < reach:
				found.append(node)
	return found


## Encaixe de estrutura: lado com lado (paredes em fila, cantos) ou em cima (outro andar), na
## vizinha mais perto do ponto; sem vizinha perto, grade de meio metro.
func _snap_structure(point: Vector3, box: AABB) -> Transform3D:
	var half := box.size / 2.0
	var center_local := box.get_center()
	var want := point + Vector3.UP * half.y
	# Sem vizinha: grade, na altura do chão + o ajuste de altura (PgUp/PgDn). Peça bem chata (rua,
	# calçada, piso) sobe um dedo sozinha para não piscar com o chão.
	var flat := FLAT_LIFT if box.size.y < 0.15 else 0.0
	var best := Transform3D(Basis(Vector3.UP, snappedf(_yaw, PI / 2.0)),
			Vector3(snappedf(point.x, GRID), point.y + _lift + flat, snappedf(point.z, GRID)))
	var best_distance := SNAP_REACH + maxf(box.size.x, box.size.z) * 0.5
	for neighbor in _structures_near(point, 14.0):
		var n_xform := neighbor.global_transform.orthonormalized()
		var n_box := box_of(neighbor)
		var n_scale := neighbor.global_basis.get_scale()
		n_box = AABB(n_box.position * n_scale, n_box.size * n_scale)
		var n_center := n_box.get_center()
		var n_half := n_box.size / 2.0
		var n_yaw := n_xform.basis.get_euler().y
		# Giro da peça nova relativo à vizinha, sempre de 90 em 90.
		var turns := roundi(wrapf(_yaw - n_yaw, -PI, PI) / (PI / 2.0))
		var relative := Basis(Vector3.UP, turns * PI / 2.0)
		var new_half := (relative * half).abs()
		var new_center_offset := relative * center_local
		var spots: Array[Vector3] = [
			Vector3(n_center.x + n_half.x + new_half.x, n_center.y - n_half.y + new_half.y, n_center.z),
			Vector3(n_center.x - n_half.x - new_half.x, n_center.y - n_half.y + new_half.y, n_center.z),
			Vector3(n_center.x, n_center.y - n_half.y + new_half.y, n_center.z + n_half.z + new_half.z),
			Vector3(n_center.x, n_center.y - n_half.y + new_half.y, n_center.z - n_half.z - new_half.z),
			Vector3(n_center.x, n_center.y + n_half.y + new_half.y, n_center.z),
		]
		# Canto: parede girada 90° encosta na ponta da vizinha.
		if turns % 2 != 0:
			for side: float in [-1.0, 1.0]:
				for depth: float in [-1.0, 1.0]:
					spots.append(Vector3(n_center.x + side * (n_half.x - new_half.x), n_center.y - n_half.y + new_half.y,
							n_center.z + depth * (n_half.z + new_half.z)))
		for spot in spots:
			var world_center: Vector3 = n_xform * spot
			# Lugar já ocupado por outra estrutura igual: pula.
			if world_center.distance_to(n_xform * n_center) < 0.05:
				continue
			var distance := world_center.distance_to(want)
			if distance < best_distance:
				best_distance = distance
				var basis := n_xform.basis * relative
				best = Transform3D(basis, n_xform * (spot - new_center_offset))
	return best


func _physics_process(delta: float) -> void:
	for item: Array in _settling.duplicate():
		var body := item[0] as RigidBody3D
		if not is_instance_valid(body):
			_settling.erase(item)
			continue
		item[2] += delta
		if (item[2] > 0.5 and body.sleeping) or item[2] > SETTLE_MAX:
			_settling.erase(item)
			_finalize(body, item[1])
	if not active:
		return
	var player := _player_of(slot)
	if player == null:
		stop()
		return
	_update_target(player)
	_read_pad()
	if _ghost:
		_ghost.visible = _target_ok
		_ghost.global_transform = placement(_target) if not is_instance_valid(_carrying) or kind_of_node(_carrying) == "estrutura" \
				else Transform3D(Basis(Vector3.UP, _yaw), _target)


## Ponto onde a peça vai: o cursor do mouse no chão (teclado) ou à frente do herói (controle).
func _update_target(player: Node3D) -> void:
	var space := player.get_world_3d().direct_space_state
	var camera := get_viewport().get_camera_3d()
	var from: Vector3
	var to: Vector3
	if InputService.device_of(slot) == InputService.KEYBOARD and camera:
		var screen := get_viewport().get_mouse_position()
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			screen = get_viewport().get_visible_rect().size / 2.0
		from = camera.project_ray_origin(screen)
		to = from + camera.project_ray_normal(screen) * 80.0
	else:
		var ahead: Vector3 = player.global_position + (-player.global_basis.z) * AHEAD
		from = ahead + Vector3.UP * 4.0
		to = ahead + Vector3.DOWN * 6.0
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, GameConfig.LAYER_SOLID))
	_target_ok = not hit.is_empty()
	if _target_ok:
		_target = hit.position


func _unhandled_input(event: InputEvent) -> void:
	if not active or InputService.device_of(slot) != InputService.KEYBOARD or InputService.screen_menu_open or _loot_panel.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if _target_ok:
					place_at(_target)
			MOUSE_BUTTON_WHEEL_UP:
				if event.shift_pressed:
					change_lift(LIFT_STEP)
				else:
					select_next(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.shift_pressed:
					change_lift(-LIFT_STEP)
				else:
					select_next(1)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_Q:
				select_next(-1)
			KEY_E:
				select_next(1)
			KEY_R:
				rotate_piece(-45.0 if event.shift_pressed else 45.0)
			KEY_V:
				next_category(-1 if event.shift_pressed else 1)
			KEY_Z:
				if _carrying:
					cancel_carry()
				else:
					undo()
			KEY_DELETE, KEY_BACKSPACE:
				if _carrying:
					cancel_carry()
				elif _target_ok:
					remove_near(_target)
			KEY_PAGEUP:
				change_lift(LIFT_FINE if event.shift_pressed else LIFT_STEP)
			KEY_PAGEDOWN:
				change_lift(-(LIFT_FINE if event.shift_pressed else LIFT_STEP))
			KEY_HOME:
				change_lift(-_lift)
			KEY_G:
				if _target_ok or _carrying:
					grab_near(_target)
			KEY_F:
				open_loot_editor(_container_near(_target) if _target_ok else null)
			_:
				return
		get_viewport().set_input_as_handled()


func _read_pad() -> void:
	var device := InputService.device_of(slot)
	if device < 0 or InputService.screen_menu_open:
		return
	if _loot_panel.visible:
		if InputService.raw_just_pressed(slot, InputService.Action.DODGE):
			close_loot_editor()
		return
	if InputService.raw_just_pressed(slot, InputService.Action.MELEE) and _target_ok:
		place_at(_target)
	if InputService.raw_just_pressed(slot, InputService.Action.POTION):
		rotate_piece(45.0)
	if InputService.raw_just_pressed(slot, InputService.Action.DODGE):
		if _loot_panel.visible:
			close_loot_editor()
		elif _carrying:
			cancel_carry()
		else:
			undo()
	if InputService.raw_just_pressed(slot, InputService.Action.PICKUP) and _target_ok and not _carrying:
		remove_near(_target)
	if InputService.raw_just_pressed(slot, InputService.Action.ARTIFACT) and not _loot_panel.visible:
		open_loot_editor(_container_near(_target) if _target_ok else null)
	for stick: JoyButton in [JOY_BUTTON_RIGHT_STICK, JOY_BUTTON_LEFT_STICK]:
		var pressed := Input.is_joy_button_pressed(device, stick)
		if pressed and not _pad_was.get(stick, false):
			change_lift(LIFT_STEP if stick == JOY_BUTTON_RIGHT_STICK else -LIFT_STEP)
		_pad_was[stick] = pressed
	for button: JoyButton in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_UP]:
		var down := Input.is_joy_button_pressed(device, button)
		if down and not _pad_was.get(button, false):
			if button == JOY_BUTTON_DPAD_UP:
				if _target_ok or _carrying:
					grab_near(_target)
			elif button == JOY_BUTTON_DPAD_DOWN:
				next_category(1)
			else:
				select_next(-1 if button == JOY_BUTTON_DPAD_LEFT else 1)
		_pad_was[button] = down


## Contêiner do construtor perto do ponto (os do editor de mapa se editam no editor).
func _container_near(point: Vector3) -> Node:
	var best: Node = null
	var best_distance := 2.5
	for container: Node in get_tree().get_nodes_in_group("containers"):
		if String(container.name).begins_with(WorldEdits.ID_PREFIX):
			var distance := Combat.flat((container as Node3D).global_position - point).length()
			if distance < best_distance:
				best = container
				best_distance = distance
	return best


## Abre o painel do conteúdo de um contêiner colocado pelo construtor.
func open_loot_editor(container: Node) -> void:
	if container == null:
		Sound.play("ui_error")
		return
	_loot_target = container
	_loot_lines = []
	for line: ContainerItem in container.contents:
		if line:
			_loot_lines.append([line.item_id, line.count])
	_loot_gold_value = int(container.gold)
	_loot_items.clear()
	for id: String in ItemDB.ids():
		if id != "gold":
			var index := _loot_items.add_item(ItemDB.display_name({"id": id}))
			_loot_items.set_item_metadata(index, id)
	_refresh_loot()
	_loot_panel.visible = true
	InputService.set_blocked(slot, true)
	_loot_items.grab_focus()
	if _loot_items.item_count > 0:
		_loot_items.select(0)


## Põe mais um do item no contêiner.
func loot_add(item_id: String) -> void:
	for pair: Array in _loot_lines:
		if pair[0] == item_id:
			pair[1] = mini(int(pair[1]) + 1, 99)
			_refresh_loot()
			return
	_loot_lines.append([item_id, 1])
	_refresh_loot()


## Tira um da linha `index` do conteúdo.
func loot_remove(index: int) -> void:
	if index < 0 or index >= _loot_lines.size():
		return
	_loot_lines[index][1] = int(_loot_lines[index][1]) - 1
	if _loot_lines[index][1] <= 0:
		_loot_lines.remove_at(index)
	_refresh_loot()


func loot_gold(delta_gold: int) -> void:
	_loot_gold_value = clampi(_loot_gold_value + delta_gold, 0, 100000)
	_refresh_loot()


## Fecha o painel e grava o conteúdo (na cena do bloco ou no save do mundo).
func close_loot_editor() -> void:
	_loot_panel.visible = false
	if slot >= 0:
		InputService.set_blocked(slot, false)
	if not is_instance_valid(_loot_target):
		return
	var entry := NetService.world_edit(String(_loot_target.name))
	if entry.is_empty():
		return
	entry["loot"] = _loot_lines.duplicate(true)
	entry["gold"] = _loot_gold_value
	WorldEdits.apply_loot(_loot_target, entry)
	var streamer := WorldStreamer.of(self)
	if WorldEdits.saves_in_map_files() and NetService.session_edits.has(entry) and streamer:
		MapWriter.save_loot_to_scene(streamer.scene_path_of(String(entry.key)), entry)
	else:
		NetService.world_edit_changed(entry)
	Sound.play("ui_confirm")


func _refresh_loot() -> void:
	_loot_inside.clear()
	for pair: Array in _loot_lines:
		_loot_inside.add_item(Txt.t("%dx %s") % [pair[1], ItemDB.display_name({"id": pair[0]})])
	_loot_gold.text = Txt.t("Parafusos: %d") % _loot_gold_value


func _build_loot_panel() -> void:
	_loot_panel = PanelContainer.new()
	_loot_panel.add_theme_stylebox_override("panel", UiSkin.panel())
	_loot_panel.visible = false
	_loot_panel.set_anchors_preset(Control.PRESET_CENTER)
	_loot_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_loot_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_hud.add_child(_loot_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_loot_panel.add_child(column)
	column.add_child(UiSkin.label("CONTEÚDO DO CONTÊINER", 20, UiSkin.NEON, "Bold", 3))
	var lists := HBoxContainer.new()
	lists.add_theme_constant_override("separation", 14)
	column.add_child(lists)
	var left := VBoxContainer.new()
	lists.add_child(left)
	left.add_child(UiSkin.label("Itens (clique duplo / A põe)", 15, UiSkin.DIM, "SemiBold", 3))
	_loot_items = ItemList.new()
	_loot_items.custom_minimum_size = Vector2(300, 320)
	_loot_items.item_activated.connect(func(index: int) -> void: loot_add(_loot_items.get_item_metadata(index)))
	left.add_child(_loot_items)
	var right := VBoxContainer.new()
	lists.add_child(right)
	right.add_child(UiSkin.label("Dentro (clique duplo tira um)", 15, UiSkin.DIM, "SemiBold", 3))
	_loot_inside = ItemList.new()
	_loot_inside.custom_minimum_size = Vector2(300, 270)
	_loot_inside.item_activated.connect(loot_remove)
	right.add_child(_loot_inside)
	_loot_gold = UiSkin.label("", 16, UiSkin.AMBER, "Bold", 3)
	right.add_child(_loot_gold)
	var gold_row := HBoxContainer.new()
	right.add_child(gold_row)
	for amount: int in [-50, 50, 500]:
		var button := Button.new()
		button.text = "%+d" % amount
		button.pressed.connect(loot_gold.bind(amount))
		gold_row.add_child(button)
	var done := Button.new()
	done.text = "Pronto (B / Esc)"
	done.pressed.connect(close_loot_editor)
	column.add_child(done)


func _input(event: InputEvent) -> void:
	if _loot_panel and _loot_panel.visible and event is InputEventKey and event.pressed \
			and event.physical_keycode == KEY_ESCAPE:
		close_loot_editor()
		get_viewport().set_input_as_handled()


func _player_of(p_slot: int) -> Player:
	for player: Player in get_tree().get_nodes_in_group("players"):
		if player.is_local() and player.slot == p_slot:
			return player
	return null


## Fantasma da peça: só o visual, translúcido, sem colisão nem scripts.
func _rebuild_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
	_ghost = Node3D.new()
	_ghost.name = "FantasmaDaPeca"
	add_child(_ghost)
	if is_instance_valid(_carrying):
		for mesh: MeshInstance3D in _carrying.find_children("*", "MeshInstance3D", true, false):
			var piece := MeshInstance3D.new()
			piece.mesh = mesh.mesh
			piece.material_override = _ghost_material
			piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			piece.transform = Transform3D(Basis.from_scale(_carrying.global_basis.get_scale()), Vector3.UP * _carry_lift) * _relative(_carrying, mesh)
			_ghost.add_child(piece)
		# Peça sem malha (só texto/luz, ex.: letreiro sem placa): uma caixinha marca o lugar.
		if _ghost.get_child_count() == 0:
			var marker := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.6, 0.3, 0.1)
			marker.mesh = box
			marker.material_override = _ghost_material
			marker.position = Vector3.UP * _carry_lift
			_ghost.add_child(marker)
		return
	var entry := current()
	if entry.is_empty():
		return
	var source: Node
	if entry.get("raw", false):
		source = PropBuilder.preview_from_model(String(entry.path))
	else:
		var scene := load(String(entry.path)) as PackedScene
		source = scene.instantiate() if scene else null
	if source == null:
		return
	# Peças que se montam por código (porta...): monta o visual para o fantasma.
	if source.has_method("ghost_build"):
		source.ghost_build()
	var model: Variant = source.get("model")
	if source is LootContainer and model is PackedScene:
		var visual := (model as PackedScene).instantiate() as Node3D
		visual.scale = Vector3.ONE * float(source.get("model_scale"))
		source.add_child(visual)
	for mesh: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		var copy := MeshInstance3D.new()
		copy.mesh = mesh.mesh
		copy.material_override = _ghost_material
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		copy.transform = _relative(source, mesh)
		_ghost.add_child(copy)
	source.free()
	# Peça montada por código (gatilho e área de missão, letreiro...): uma caixinha marca o lugar.
	if _ghost.get_child_count() == 0:
		var marker := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.6, 0.3, 0.6)
		marker.mesh = box
		marker.material_override = _ghost_material
		marker.position.y = 0.15
		_ghost.add_child(marker)


static func _relative(root: Node, node: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current_node: Node = node
	while current_node and current_node != root:
		if current_node is Node3D:
			xform = (current_node as Node3D).transform * xform
		current_node = current_node.get_parent()
	return xform


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 5
	_hud.visible = false
	add_child(_hud)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiSkin.panel())
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -150
	_hud.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	_title = UiSkin.label("MODO CONSTRUTOR", 16, UiSkin.NEON, "Bold", 3)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_piece = UiSkin.label("", 22, UiSkin.TEXT, "Bold", 4)
	_piece.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_piece)
	_hint = UiSkin.label("", 14, UiSkin.DIM, "Regular", 3)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hint)
	_build_loot_panel()


func _refresh_hud() -> void:
	var entry := current()
	if entry.is_empty():
		_piece.text = "Nenhuma peça em world/prefabs"
		return
	var kind_text: String = {"fixo": "fixo (cai até o chão)", "conteiner": "contêiner", "fisico": "físico (cai e rola)", "atravessavel": "enfeite", "estrutura": "estrutura (encaixa)"}.get(entry.kind, "peça pronta")
	if entry.get("raw", false):
		kind_text = "do pack (vira peça fixa ao carimbar)"
	var same := _in_category(current_category())
	var at := same.find(_index)
	var names := PropBuilder.categories(_catalog)
	var before: String = _catalog[same[wrapi(at - 1, 0, same.size())]].name
	var after: String = _catalog[same[wrapi(at + 1, 0, same.size())]].name
	_piece.text = "◀ %s   [ %s ]   %s ▶" % [before, entry.name, after] if same.size() > 1 else "[ %s ]" % entry.name
	_title.text = Txt.t("MODO CONSTRUTOR · %s (%d/%d) · peça %d/%d · %s") % [current_category().to_upper(),
			names.find(current_category()) + 1, names.size(), at + 1, same.size(), kind_text]
	var keyboard := InputService.device_of(slot) == InputService.KEYBOARD
	if is_instance_valid(_carrying):
		_title.text = Txt.t("MODO CONSTRUTOR · mudando de lugar: %s") % String(_carrying.name)
		_hint.text = ("Clique larga aqui · R gira · G ou Delete desiste" if keyboard else "X larga aqui · Y gira · ▲ ou B desiste")
		return
	_hint.text = (Txt.t("Clique coloca · Q/E ou rodinha troca · V categoria · R gira · PgUp/PgDn altura (Shift fino, Home zera) · Z desfaz · Delete apaga · G pega e muda de lugar · F conteúdo do contêiner · %s no chat sai") % COMMAND if keyboard
			else Txt.t("X coloca · ◀ ▶ troca · ▼ categoria · Y gira · R3/L3 altura · B desfaz · LB apaga · ▲ pega e muda de lugar · RB conteúdo do contêiner · %s no chat sai") % COMMAND)
	if absf(_lift) > 0.001:
		_title.text += Txt.t(" · altura %+.2f m") % _lift
	_hint.text += "\nGrava direto nas cenas dos blocos (mapa oficial)."
