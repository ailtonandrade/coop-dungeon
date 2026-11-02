@tool
extends SubViewportContainer
## Prévia 3D girando da peça escolhida no editor de mapa (mundo próprio, câmera que enquadra).

var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D


func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(0, 190)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.13, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.7)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 35, 0)
	_viewport.add_child(light)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_camera = Camera3D.new()
	_camera.fov = 35.0
	_viewport.add_child(_camera)


func show_scene(path: String) -> void:
	for child in _pivot.get_children():
		child.queue_free()
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var scene := load(path) as PackedScene
	if scene == null:
		return
	var instance := scene.instantiate()
	# Só o visual: nada de física, sons ou scripts do jogo rodando na prévia.
	_pivot.add_child(instance)
	_frame.call_deferred(instance)


func _frame(instance: Node) -> void:
	if not is_instance_valid(instance):
		return
	var box := AABB()
	var first := true
	for visual: VisualInstance3D in instance.find_children("*", "VisualInstance3D", true, false):
		if visual is Light3D:
			continue
		var local := visual.global_transform * visual.get_aabb()
		box = local if first else box.merge(local)
		first = false
	if first:
		box = AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)
	var radius := maxf(maxf(box.size.x, maxf(box.size.y, box.size.z)) * 0.62, 0.15)
	var center := box.get_center()
	var distance := radius / tan(deg_to_rad(_camera.fov * 0.5))
	_camera.position = center + Vector3(0, radius * 0.6, distance)
	_camera.look_at(center)
	_camera.near = maxf(distance - radius * 2.0, 0.01)
	_camera.far = distance + radius * 3.0


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_pivot.rotation.y += delta * 0.8
