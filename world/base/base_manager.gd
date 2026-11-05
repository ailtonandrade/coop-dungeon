class_name BaseManager
extends Node3D
## Bases dos jogadores (abrigos): cada herói instala um terminal de base (nível 3+) num pátio
## aberto longe das cidades; em volta dele fica uma área (BaseCatalog.BASE_RADIUS) contornada
## no chão, que é ZONA SEGURA (criaturas não entram nem miram quem está lá dentro) e onde só o
## dono constrói piso, parede, porta, teto e móveis com os materiais que juntou.
##
## Dados: NetService.world["bases"] = {dono: {owner, name, terminal, pieces: [...]}} — salvo
## com o mundo e mandado aos convidados (ao entrar e a cada mudança). Quem decide é o host:
## os pedidos chegam pelo inventário do herói (Player.apply_inventory_command "base_*").
## Aqui dentro só se monta o que está nos dados.

signal changed

var _nodes := {}  # dono -> Node3D da base


static func of(tree: SceneTree) -> BaseManager:
	return tree.get_first_node_in_group("base_manager") as BaseManager if tree else null


## Chave do dono: o personagem (fica igual entre sessões).
static func key_of(player: Node) -> String:
	var id := String(player.get("character_id"))
	return id if not id.is_empty() else String(player.get("display_name"))


static func bases() -> Dictionary:
	return NetService.world.get("bases", {})


## Posição salva (o save é JSON: [x, y, z]) como Vector3.
static func vec(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and (value as Array).size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


static func arr(value: Vector3) -> Array:
	return [snappedf(value.x, 0.01), snappedf(value.y, 0.01), snappedf(value.z, 0.01)]


## Centro (terminal) da base.
static func center_of(base: Dictionary) -> Vector3:
	return vec(base.get("terminal"))


static func base_of(key: String) -> Dictionary:
	return bases().get(key, {})


## Dentro da área de alguma base (zona segura)?
static func safe_at(position: Vector3) -> bool:
	return not base_at(position).is_empty()


## A base cuja área contém `position` ({} se nenhuma).
static func base_at(position: Vector3) -> Dictionary:
	for key: String in bases():
		var base: Dictionary = bases()[key]
		var center := center_of(base)
		if Vector2(position.x - center.x, position.z - center.z).length() <= BaseCatalog.BASE_RADIUS \
				and absf(position.y - center.y) < 8.0:
			return base
	return {}


## Criatura entrando numa área segura: volta para a borda.
static func push_out(position: Vector3) -> Vector3:
	var base := base_at(position)
	if base.is_empty():
		return position
	var center := center_of(base)
	var away := Vector3(position.x - center.x, 0.0, position.z - center.z)
	if away.length() < 0.01:
		away = Vector3.RIGHT
	var edge := center + away.normalized() * (BaseCatalog.BASE_RADIUS + 0.4)
	return Vector3(edge.x, position.y, edge.z)


## Onde o dono volta quando o grupo cai (a cama da base dele), ou Vector3.INF.
static func bed_of(key: String) -> Vector3:
	for piece: Dictionary in base_of(key).get("pieces", []):
		if piece.recipe == "cama":
			return vec(piece.pos) + Vector3(1.0, 0.0, 0.0).rotated(Vector3.UP, float(piece.yaw))
	return Vector3.INF


## Pode instalar o terminal aqui? "" = pode; senão o motivo.
static func terminal_problem(tree: SceneTree, position: Vector3, owner_key: String) -> String:
	if position.y < -1.0:
		return "Aqui embaixo não dá: o abrigo tem que ser a céu aberto."
	var streamer := tree.get_first_node_in_group("world_streamer")
	var world_map: WorldMap = streamer.world_map if streamer else null
	if world_map:
		for i in 9:
			var probe := position
			if i > 0:
				probe += Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 8.0) * BaseCatalog.BASE_RADIUS
			var region := world_map.region_at(probe)
			if region and region.safe:
				return "Muito perto da cidade: procure um pátio afastado."
	var places: Dictionary = Quests._places_map() if Quests else {}
	var too_close := func(other: Vector3, distance: float) -> bool:
		return Vector2(other.x - position.x, other.z - position.z).length() < distance
	for npc_position: Vector3 in places.get("npcs", {}).values():
		if too_close.call(npc_position, BaseCatalog.TOWN_DISTANCE):
			return "Muito perto da cidade: procure um pátio afastado."
	for npc: Node3D in tree.get_nodes_in_group("npcs"):
		if not npc.has_meta("base_chest") and too_close.call(npc.global_position, BaseCatalog.TOWN_DISTANCE):
			return "Muito perto da cidade: procure um pátio afastado."
	for spawner: Array in places.get("spawners", []):
		if too_close.call(spawner[0], BaseCatalog.BASE_RADIUS + 6.0):
			return "Ninho de criaturas perto demais."
	for key: String in bases():
		if key != owner_key and too_close.call(center_of(bases()[key]), BaseCatalog.BASE_RADIUS * 2.0 + 4.0):
			return "Perto demais do abrigo de outra pessoa."
	# Pátio aberto: quase nada sólido de pé na área (muros, casas, carcaças).
	var space := (tree.current_scene as Node3D).get_world_3d().direct_space_state if tree.current_scene is Node3D else null
	if space:
		var shape := BoxShape3D.new()
		var span := BaseCatalog.BASE_RADIUS * 1.2
		shape.size = Vector3(span, 2.4, span)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, position + Vector3.UP * 1.6)
		query.collision_mask = GameConfig.LAYER_WORLD
		var blocked := 0
		for hit: Dictionary in space.intersect_shape(query, 32):
			var body := hit.collider as Node
			if body and String(body.name) != "Ground" and not body.is_in_group("players"):
				blocked += 1
		if blocked > 3:
			return "Muito apertado aqui: procure um pátio mais aberto."
	return ""


func _ready() -> void:
	name = "Bases"
	add_to_group("base_manager")
	NetService.base_changed.connect(_rebuild)
	for key: String in bases():
		_rebuild(key)


## Host: instala o terminal (cria a base) do herói. Retorna "" ou o motivo de não poder.
func place_terminal(player: Node, position: Vector3) -> String:
	var key := key_of(player)
	if int(player.progress.level) < int(BaseCatalog.RECIPES.terminal.level):
		return Txt.t("O terminal de base libera no nível %d.") % BaseCatalog.RECIPES.terminal.level
	if not base_of(key).is_empty():
		return "Você já tem um abrigo (o terminal fica marcado no mapa)."
	var problem := terminal_problem(get_tree(), position, key)
	if not problem.is_empty():
		return problem
	var costs := BaseCatalog.cost("terminal", "")
	if not BaseCatalog.can_afford(player.inventory, costs):
		return Txt.t("Faltam materiais (%s).") % BaseCatalog.cost_text(costs)
	BaseCatalog.pay(player.inventory, costs)
	NetService.set_base(key, {
		"owner": key, "name": String(player.display_name), "terminal": arr(position.snapped(Vector3(0.5, 0.01, 0.5))),
		"pieces": [], "next_id": 1,
	})
	return ""


## Host: constrói uma peça na base do herói. "" ou o motivo.
func build_piece(player: Node, recipe: String, material: String, position: Vector3, yaw: float) -> String:
	var key := key_of(player)
	var base := base_of(key).duplicate(true)
	if base.is_empty():
		return "Instale o terminal de base primeiro."
	if not BaseCatalog.RECIPES.has(recipe) or recipe == "terminal":
		return "Receita desconhecida."
	if int(player.progress.level) < int(BaseCatalog.RECIPES[recipe].level):
		return Txt.t("%s libera no nível %d.") % [BaseCatalog.recipe_name(recipe), BaseCatalog.RECIPES[recipe].level]
	if BaseCatalog.is_structure(recipe) and not BaseCatalog.MATERIALS.has(material):
		return "Material desconhecido."
	var center := center_of(base)
	if Vector2(position.x - center.x, position.z - center.z).length() > BaseCatalog.BASE_RADIUS - 0.5:
		return "Fora da área do seu abrigo."
	if (base.pieces as Array).size() >= 400:
		return "Abrigo no limite de peças."
	var problem := overlap_problem(base, recipe, position, yaw)
	if not problem.is_empty():
		return problem
	var costs := BaseCatalog.cost(recipe, material)
	if not BaseCatalog.can_afford(player.inventory, costs):
		return Txt.t("Faltam materiais (%s).") % BaseCatalog.cost_text(costs)
	BaseCatalog.pay(player.inventory, costs)
	var id := int(base.get("next_id", 1))
	base["next_id"] = id + 1
	(base.pieces as Array).append({"id": id, "recipe": recipe, "material": material, "pos": arr(position), "yaw": snappedf(yaw, 0.001)})
	NetService.set_base(key, base)
	return ""


## Host: desmonta a peça mais perto de `position` (devolve metade do material). "" ou motivo.
func remove_piece(player: Node, position: Vector3) -> String:
	var key := key_of(player)
	var base := base_of(key).duplicate(true)
	if base.is_empty():
		return "Você não tem abrigo."
	var pieces: Array = base.pieces
	var best := -1
	var best_distance := 2.0
	for i in pieces.size():
		var distance := vec(pieces[i].pos).distance_to(position)
		if distance < best_distance:
			best = i
			best_distance = distance
	if best == -1:
		return "Nada seu aqui para desmontar."
	var piece: Dictionary = pieces[best]
	var refund := BaseCatalog.cost(piece.recipe, piece.material)
	for material: String in refund:
		player.inventory.add_ammo(material, int(refund[material]) / 2)
	pieces.remove_at(best)
	NetService.set_base(key, base)
	return ""


## Já tem peça no mesmo lugar? (paredes na mesma borda, piso/teto na mesma casa, móvel encostado)
static func overlap_problem(base: Dictionary, recipe: String, position: Vector3, yaw: float) -> String:
	var kind: String = BaseCatalog.RECIPES[recipe].kind
	var group := _slot_group(kind)
	for piece: Dictionary in base.get("pieces", []):
		var other_kind: String = BaseCatalog.RECIPES.get(piece.recipe, {}).get("kind", "")
		if _slot_group(other_kind) != group:
			continue
		var distance := vec(piece.pos).distance_to(position)
		if group == "furniture":
			if distance < 0.9:
				return "Já tem um móvel aí."
		elif distance < 0.3 and (group != "wall" or absf(angle_difference(float(piece.yaw), yaw)) < 0.3 or absf(angle_difference(float(piece.yaw), yaw + PI)) < 0.3):
			return "Já tem peça aí."
	var terminal := center_of(base)
	if group in ["wall", "furniture"] and Vector2(position.x - terminal.x, position.z - terminal.z).length() < 0.9:
		return "Em cima do terminal não dá."
	return ""


static func _slot_group(kind: String) -> String:
	match kind:
		"wall", "door":
			return "wall"
		"floor":
			return "floor"
		"roof":
			return "roof"
	return "furniture"


## Remonta a base `key` a partir dos dados (nova, mudou ou foi apagada).
func _rebuild(key: String) -> void:
	if _nodes.has(key):
		(_nodes[key] as Node).queue_free()
		_nodes.erase(key)
	var base := base_of(key)
	if base.is_empty():
		changed.emit()
		return
	var root := Node3D.new()
	root.name = "Base_%s" % key.validate_node_name()
	add_child(root)
	_nodes[key] = root
	var terminal := BasePieces.build("terminal", "")
	terminal.name = "Terminal"
	root.add_child(terminal)
	terminal.global_position = center_of(base)
	var label := WorldText.make(Txt.t("Abrigo de %s") % String(base.get("name", "")), 18, Color(0.45, 1.0, 0.85))
	label.position = Vector3(0, 2.6, 0)
	terminal.add_child(label)
	_zone_ring(root, center_of(base))
	for piece: Dictionary in base.get("pieces", []):
		var node := BasePieces.build(BaseCatalog.RECIPES.get(piece.recipe, {}).get("kind", ""), String(piece.material))
		node.name = "Peca_%d" % int(piece.id)
		node.set_meta("piece_id", int(piece.id))
		node.set_meta("base_owner", key)
		root.add_child(node)
		node.global_position = vec(piece.pos)
		node.rotation.y = float(piece.yaw)
	changed.emit()


## Contorno da área no chão: tracinhos verde-água acesos.
func _zone_ring(root: Node3D, center: Vector3) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.35, 1.0, 0.85, 0.55)
	var dash := BoxMesh.new()
	dash.size = Vector3(0.9, 0.04, 0.12)
	var count := 64
	var space := get_world_3d().direct_space_state
	for i in count:
		var angle := TAU * i / count
		var spot := center + Vector3(cos(angle), 0.0, sin(angle)) * BaseCatalog.BASE_RADIUS
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 3.0, spot + Vector3.DOWN * 4.0, GameConfig.LAYER_WORLD))
		if not hit.is_empty():
			spot.y = (hit.position as Vector3).y
		var mesh := MeshInstance3D.new()
		mesh.mesh = dash
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mesh)
		mesh.global_position = spot + Vector3.UP * 0.04
		mesh.rotation.y = -(angle + PI / 2.0)
