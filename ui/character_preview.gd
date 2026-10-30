class_name CharacterPreview
extends SubViewportContainer
## Prévia 3D de um personagem girando devagar (escolha e criação de personagem).

var _viewport: SubViewport
var _holder: Node3D
var _model: Node3D
var _shown := ""


func _init() -> void:
	stretch = true
	custom_minimum_size = Vector2(220, 260)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	add_child(_viewport)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 30, 0)
	_viewport.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -150, 0)
	fill.light_energy = 0.4
	_viewport.add_child(fill)
	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.position = Vector3(0, 1.0, 4.2)
	_viewport.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(0, 0.9, 0))
	_holder = Node3D.new()
	_viewport.add_child(_holder)


## Mostra o personagem (troca o modelo só se mudou).
func show_character(data: Dictionary) -> void:
	var key := "%s|%s" % [data.get("model", ""), data.get("chip_color", 0)]
	if key == _shown:
		return
	_shown = key
	if _model:
		_model.queue_free()
	if data.is_empty():
		_model = null
		return
	_model = Characters.model_scene(data.get("model", "")).instantiate()
	_holder.add_child(_model)
	Characters.attach_chip(_model, Characters.chip_color(int(data.get("chip_color", 0))))
	var anim: AnimationPlayer = _model.find_child("AnimationPlayer", true, false)
	if anim and anim.has_animation("Idle"):
		anim.play("Idle")


func _process(delta: float) -> void:
	_holder.rotation.y += delta * 0.6
