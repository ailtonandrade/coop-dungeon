class_name IconStudio
extends Node
## Fotografa o modelo 3D dos itens para o ícone do inventário, sozinho e na hora em que o ícone
## aparece pela primeira vez. Assim o ícone é sempre igual ao item no chão e na mão (mesmo
## modelo, tamanho, giro e posição da ficha), sem precisar gerar ícone no editor de itens.
## Fica na raiz do jogo (criado sozinho); as fotos ficam guardadas enquanto o jogo está aberto.

signal icon_ready(item_id: String)

const SIZE := 128

static var _cache := {}  # id -> Texture2D (ou null: não deu para fotografar, usa o desenho)
var _queue: Array[String] = []
var _busy := false
var _studio: SubViewport
var _holder: Node3D
var _camera: Camera3D


## Foto do item (ou null enquanto não está pronta / sem modelo / sem placa de vídeo).
static func icon_for(item_id: String) -> Texture2D:
	if _cache.has(item_id):
		return _cache[item_id]
	var studio := instance()
	if studio:
		studio._request(item_id)
	return null


static func instance() -> IconStudio:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or DisplayServer.get_name() == "headless":
		return null
	var found := tree.root.get_node_or_null("IconStudio") as IconStudio
	if found == null:
		found = IconStudio.new()
		found.name = "IconStudio"
		tree.root.add_child.call_deferred(found)
	return found


## Item com modelo 3D: o ícone é a foto dele (a menos que a ficha tenha um ícone desenhado à
## mão, fora da pasta dos ícones automáticos).
static func uses_photo(def: Dictionary) -> bool:
	if not def.get("model") is PackedScene:
		return false
	var icon: Variant = def.get("icon")
	return not icon is Texture2D or (icon as Texture2D).resource_path.begins_with("res://items/icons/")


func _request(item_id: String) -> void:
	if not _queue.has(item_id):
		_queue.append(item_id)
	if not _busy:
		_shoot.call_deferred()


func _ready() -> void:
	_studio = SubViewport.new()
	_studio.size = Vector2i(SIZE, SIZE)
	_studio.transparent_bg = true
	_studio.own_world_3d = true
	_studio.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_studio)
	for angles: Vector3 in [Vector3(-40, 30, 0), Vector3(-20, -150, 0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = angles
		light.light_energy = 1.2 if angles.y > 0 else 0.5
		_studio.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.78)
	_studio.add_child(env)
	_holder = Node3D.new()
	_studio.add_child(_holder)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_studio.add_child(_camera)


## Fotografa a fila, um item por vez (do mesmo jeito do "Gerar ícone" do editor de itens).
func _shoot() -> void:
	if _busy or not is_inside_tree():
		return
	_busy = true
	while not _queue.is_empty():
		var item_id: String = _queue.pop_front()
		if _cache.has(item_id):
			continue
		for child in _holder.get_children():
			child.free()
		var piece := ItemVisuals.build({"id": item_id, "rarity": "common", "power": 1})
		_holder.add_child(piece)
		var def := ItemDB.def({"id": item_id})
		# Armas na diagonal; o resto meio de lado (igual ao editor de itens).
		piece.rotation_degrees = Vector3(0, 90, -45) if def.get("slot", "") in ["melee", "ranged"] else Vector3(15, -30, 0)
		var box := _bounds(_holder)
		_camera.size = maxf(box.size.x, box.size.y) * 1.15 + 0.01
		_camera.position = box.get_center() + Vector3(0, 0, box.size.z + 2.0)
		_camera.make_current()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image := _studio.get_texture().get_image()
		_cache[item_id] = ImageTexture.create_from_image(image) if image and not image.is_empty() else null
		icon_ready.emit(item_id)
	_busy = false


static func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for visual: VisualInstance3D in root.find_children("*", "VisualInstance3D", true, false):
		var global := visual.global_transform * visual.get_aabb()
		box = global if first else box.merge(global)
		first = false
	return box if not first else AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
