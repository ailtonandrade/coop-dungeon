class_name Player
extends CharacterBody3D
## Herói controlado por um slot do InputService. Movimento relativo à câmera isométrica.

## Modelo provisório por slot (Quaternius, CC0). Para trocar, basta outro .glb na mesma
## escala (1 unidade = 1 m, pé na origem) com animações Idle, Run e Roll.
const MODELS: Array[PackedScene] = [
	preload("res://assets/characters/Adventurer.glb"),
	preload("res://assets/characters/Swat.glb"),
	preload("res://assets/characters/Farmer.glb"),
	preload("res://assets/characters/Worker.glb"),
]
const ANIM_BLEND := 0.15

var slot := 0

var _facing := Vector3.FORWARD
var _dodge_dir := Vector3.ZERO
var _dodge_timer := 0.0
var _dodge_cooldown := 0.0
var _anim: AnimationPlayer

@onready var _ring: MeshInstance3D = $Ring
@onready var _tag: Label3D = $Tag


func _ready() -> void:
	var color := GameConfig.PLAYER_COLORS[slot]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = material
	_tag.text = "P%d" % (slot + 1)
	_tag.modulate = color

	var model := MODELS[slot % MODELS.size()].instantiate()
	$Model.add_child(model)
	_anim = model.find_child("AnimationPlayer", true, false)
	if _anim:
		for anim_name in ["Idle", "Run"]:
			if _anim.has_animation(anim_name):
				_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR


func is_dodging() -> bool:
	return _dodge_timer > 0.0


func teleport_to(target: Vector3) -> void:
	global_position = target
	velocity = Vector3.ZERO
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)

	var move := InputService.get_move(slot)
	var dir := Vector3(move.x, 0.0, move.y).rotated(Vector3.UP, deg_to_rad(GameConfig.CAMERA_YAW_DEG))
	if dir.length_squared() > 0.0001:
		_facing = dir.normalized()

	if InputService.just_pressed(slot, InputService.Action.DODGE) and _dodge_cooldown == 0.0:
		_dodge_dir = _facing
		_dodge_timer = GameConfig.DODGE_TIME
		_dodge_cooldown = GameConfig.DODGE_COOLDOWN
		_play("Roll", GameConfig.DODGE_TIME)

	if is_dodging():
		_dodge_timer -= delta
		velocity.x = _dodge_dir.x * GameConfig.DODGE_SPEED
		velocity.z = _dodge_dir.z * GameConfig.DODGE_SPEED
	else:
		var target := Vector2(dir.x, dir.z) * GameConfig.PLAYER_SPEED
		var horizontal := Vector2(velocity.x, velocity.z).move_toward(target, GameConfig.PLAYER_ACCEL * delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.y

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GameConfig.GRAVITY * delta
	move_and_slide()

	var target_basis := Basis.looking_at(_facing)
	basis = basis.slerp(target_basis, minf(GameConfig.PLAYER_TURN_SPEED * delta, 1.0)).orthonormalized()

	if not is_dodging():
		_play("Run" if Vector2(velocity.x, velocity.z).length() > 0.5 else "Idle")


## Toca uma animação do modelo. Com `duration`, acelera ou desacelera para durar esse tempo.
func _play(anim_name: String, duration := 0.0) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if _anim.current_animation == anim_name and duration == 0.0:
		return
	var speed := 1.0
	if duration > 0.0:
		speed = _anim.get_animation(anim_name).length / duration
	_anim.play(anim_name, ANIM_BLEND, speed)
