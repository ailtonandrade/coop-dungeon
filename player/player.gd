class_name Player
extends CharacterBody3D
## Herói controlado por um slot do InputService. Movimento relativo à câmera isométrica.

signal downed
signal revived

## Modelo provisório por slot (Quaternius, CC0). Para trocar, basta outro .glb na mesma
## escala (1 unidade = 1 m, pé na origem) com animações Idle, Run, Roll, Sword_Slash e Death.
const MODELS: Array[PackedScene] = [
	preload("res://assets/characters/Adventurer.glb"),
	preload("res://assets/characters/Swat.glb"),
	preload("res://assets/characters/Farmer.glb"),
	preload("res://assets/characters/Worker.glb"),
]
const ANIM_BLEND := 0.15
## Golpes do combo corpo a corpo, em ordem. Apertar ataque durante um golpe encadeia o próximo.
const COMBO: Array[Dictionary] = [
	{"damage": 10.0, "knockback": 3.0, "windup": 0.12, "recovery": 0.22, "lunge": 2.5},
	{"damage": 10.0, "knockback": 3.0, "windup": 0.12, "recovery": 0.22, "lunge": 2.5},
	{"damage": 22.0, "knockback": 8.0, "windup": 0.2, "recovery": 0.4, "lunge": 4.0},
]

enum State { NORMAL, DODGING, ATTACKING, DOWNED }

static var _arc_mesh: ArrayMesh

var slot := 0
var state := State.NORMAL
var health := Health.new()
var revive_progress := 0.0
var potion_cooldown := 0.0

var _facing := Vector3.FORWARD
var _move := Vector3.ZERO
var _knockback := Vector3.ZERO
var _state_timer := 0.0
var _dodge_dir := Vector3.ZERO
var _dodge_cooldown := 0.0
var _arrow_cooldown := 0.0
var _combo_step := 0
var _combo_queued := false
var _hit_done := false
var _hitstop := 0.0
var _anim_lock := 0.0
var _anim: AnimationPlayer
var _model: Node3D

@onready var _ring: MeshInstance3D = $Ring
@onready var _tag: Label3D = $Tag


func _ready() -> void:
	add_to_group("players")
	collision_layer = GameConfig.LAYER_PLAYERS
	collision_mask = GameConfig.LAYER_WORLD | GameConfig.LAYER_ENEMIES
	health.max_hp = GameConfig.PLAYER_MAX_HP
	add_child(health)
	health.died.connect(_on_died)

	var color := GameConfig.PLAYER_COLORS[slot]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = material
	_tag.modulate = color

	_model = MODELS[slot % MODELS.size()].instantiate()
	$Model.add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false)
	if _anim:
		for anim_name in ["Idle", "Run"]:
			if _anim.has_animation(anim_name):
				_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR


func is_targetable() -> bool:
	return state != State.DOWNED


func is_dodging() -> bool:
	return state == State.DODGING


func teleport_to(target: Vector3) -> void:
	global_position = target
	velocity = Vector3.ZERO
	_move = Vector3.ZERO
	reset_physics_interpolation()


func take_hit(amount: float, knockback := Vector3.ZERO) -> void:
	# A rolada dá invulnerabilidade, como no gênero.
	if state == State.DODGING or state == State.DOWNED:
		return
	if health.take_hit(amount):
		_knockback = Combat.flat(knockback)
		Combat.flash(_model, Color(1.0, 0.2, 0.2, 0.6), null)
		Combat.shake_camera(self, 0.25)


func revive(fraction: float) -> void:
	health.reset(fraction)
	revive_progress = 0.0
	state = State.NORMAL
	_play("Idle")
	revived.emit()


func _process(_delta: float) -> void:
	_tag.text = "P%d" % (slot + 1)
	if state == State.DOWNED:
		_tag.text += "  ✚ %d%%" % int(revive_progress * 100.0)


func _physics_process(delta: float) -> void:
	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	_arrow_cooldown = maxf(_arrow_cooldown - delta, 0.0)
	potion_cooldown = maxf(potion_cooldown - delta, 0.0)
	_anim_lock = maxf(_anim_lock - delta, 0.0)

	# Hit-stop: congela o atacante um instante quando o golpe conecta, pra dar peso.
	if _hitstop > 0.0:
		_hitstop -= delta
		if _anim:
			_anim.speed_scale = 0.0
		return
	if _anim:
		_anim.speed_scale = 1.0

	var dir := _input_dir()
	var desired := Vector3.ZERO
	match state:
		State.NORMAL:
			desired = _update_normal(delta, dir)
		State.ATTACKING:
			desired = _update_attack(delta, dir)
		State.DODGING:
			desired = _update_dodge(delta)
		State.DOWNED:
			_update_downed(delta)

	_knockback = _knockback.move_toward(Vector3.ZERO, 30.0 * delta)
	velocity.x = desired.x + _knockback.x
	velocity.z = desired.z + _knockback.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GameConfig.GRAVITY * delta
	move_and_slide()

	if state != State.DOWNED:
		var target_basis := Basis.looking_at(_facing)
		basis = basis.slerp(target_basis, minf(GameConfig.PLAYER_TURN_SPEED * delta, 1.0)).orthonormalized()


func _input_dir() -> Vector3:
	var move := InputService.get_move(slot)
	return Vector3(move.x, 0.0, move.y).rotated(Vector3.UP, deg_to_rad(GameConfig.CAMERA_YAW_DEG))


func _update_normal(delta: float, dir: Vector3) -> Vector3:
	if dir.length_squared() > 0.0001:
		_facing = dir.normalized()
	if _try_dodge():
		return _update_dodge(0.0)
	if InputService.just_pressed(slot, InputService.Action.MELEE):
		_start_attack(0, dir)
		return Vector3.ZERO
	if InputService.is_pressed(slot, InputService.Action.RANGED) and _arrow_cooldown == 0.0:
		_shoot_arrow()
	if InputService.just_pressed(slot, InputService.Action.POTION):
		_drink_potion()

	var target := dir * GameConfig.PLAYER_SPEED
	_move = _move.move_toward(target, GameConfig.PLAYER_ACCEL * delta)
	if _anim_lock == 0.0:
		_play("Run" if _move.length() > 0.5 else "Idle")
	return _move


func _try_dodge() -> bool:
	if not InputService.just_pressed(slot, InputService.Action.DODGE) or _dodge_cooldown > 0.0:
		return false
	state = State.DODGING
	_dodge_dir = _facing
	_state_timer = GameConfig.DODGE_TIME
	_dodge_cooldown = GameConfig.DODGE_COOLDOWN
	_play("Roll", GameConfig.DODGE_TIME, true)
	return true


func _update_dodge(delta: float) -> Vector3:
	_state_timer -= delta
	if _state_timer <= 0.0:
		state = State.NORMAL
		_move = _dodge_dir * GameConfig.PLAYER_SPEED
	return _dodge_dir * GameConfig.DODGE_SPEED


## Corpo a corpo

func _start_attack(step: int, dir: Vector3) -> void:
	state = State.ATTACKING
	_combo_step = step
	_combo_queued = false
	_hit_done = false
	_state_timer = 0.0
	_move = Vector3.ZERO
	var enemies := get_tree().get_nodes_in_group("enemies")
	var aim := Combat.nearest_in_cone(global_position, _facing, enemies, GameConfig.SOFT_AIM_RADIUS, 360.0)
	if aim:
		_facing = Combat.flat(aim.global_position - global_position).normalized()
	elif dir.length_squared() > 0.0001:
		_facing = dir.normalized()
	var hit: Dictionary = COMBO[step]
	_play("Sword_Slash", hit.windup + hit.recovery, true)


func _update_attack(delta: float, dir: Vector3) -> Vector3:
	if _try_dodge():
		return _update_dodge(0.0)
	var hit: Dictionary = COMBO[_combo_step]
	_state_timer += delta
	if InputService.just_pressed(slot, InputService.Action.MELEE):
		_combo_queued = true

	var desired := Vector3.ZERO
	if _state_timer < hit.windup:
		desired = _facing * hit.lunge
	elif not _hit_done:
		_hit_done = true
		_melee_hit(hit)

	if _state_timer >= hit.windup + hit.recovery:
		if _combo_queued and _combo_step < COMBO.size() - 1:
			_start_attack(_combo_step + 1, dir)
		else:
			state = State.NORMAL
	return desired


func _melee_hit(hit: Dictionary) -> void:
	var finisher := _combo_step == COMBO.size() - 1
	var targets := Combat.query_arc(self, _facing, GameConfig.MELEE_RADIUS, GameConfig.MELEE_ARC_DEG, GameConfig.LAYER_ENEMIES)
	for target in targets:
		target.take_hit(hit.damage, _facing * hit.knockback)
	_spawn_slash_fx(finisher)
	if not targets.is_empty():
		_hitstop = GameConfig.HITSTOP_TIME
		Combat.shake_camera(self, 0.35 if finisher else 0.12)


func _spawn_slash_fx(finisher: bool) -> void:
	var material := Combat.overlay_material(Color(1.0, 1.0, 1.0, 0.7 if finisher else 0.45))
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var fx := MeshInstance3D.new()
	fx.mesh = _get_arc_mesh()
	fx.material_override = material
	get_parent().add_child(fx)
	fx.global_transform = Transform3D(Basis.looking_at(_facing), global_position + Vector3.UP * 0.9)
	if finisher:
		fx.scale = Vector3.ONE * 1.25
	var tween := fx.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.15)
	tween.tween_callback(fx.queue_free)


static func _get_arc_mesh() -> ArrayMesh:
	if _arc_mesh:
		return _arc_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 12
	var half := deg_to_rad(GameConfig.MELEE_ARC_DEG / 2.0)
	var inner := GameConfig.MELEE_RADIUS * 0.55
	var outer := GameConfig.MELEE_RADIUS
	for i in segments:
		var a0 := lerpf(-half, half, float(i) / segments)
		var a1 := lerpf(-half, half, float(i + 1) / segments)
		var d0 := Vector3(sin(a0), 0.0, -cos(a0))
		var d1 := Vector3(sin(a1), 0.0, -cos(a1))
		for v in [d0 * inner, d0 * outer, d1 * outer, d0 * inner, d1 * outer, d1 * inner]:
			st.add_vertex(v)
	_arc_mesh = st.commit()
	return _arc_mesh


## À distância, poção, cair

func _shoot_arrow() -> void:
	_arrow_cooldown = GameConfig.ARROW_COOLDOWN
	var enemies := get_tree().get_nodes_in_group("enemies")
	var aim := Combat.nearest_in_cone(global_position, _facing, enemies, GameConfig.ARROW_RANGE, GameConfig.ARROW_AIM_CONE_DEG)
	if aim:
		_facing = Combat.flat(aim.global_position - global_position).normalized()
	var from := global_position + Vector3.UP * 1.1 + _facing * 0.6
	Projectile.spawn(get_parent(), from, _facing, GameConfig.ARROW_SPEED, GameConfig.ARROW_DAMAGE,
			GameConfig.LAYER_ENEMIES, Color(1.0, 0.95, 0.7))
	_play("Gun_Shoot", 0.3, true)
	_anim_lock = 0.3


func _drink_potion() -> void:
	if potion_cooldown > 0.0 or health.hp >= health.max_hp:
		return
	health.heal(health.max_hp * GameConfig.POTION_HEAL)
	potion_cooldown = GameConfig.POTION_COOLDOWN
	Combat.flash(_model, Color(0.3, 1.0, 0.4, 0.5), null, 0.25)


func _on_died() -> void:
	state = State.DOWNED
	revive_progress = 0.0
	_move = Vector3.ZERO
	_play("Death")
	downed.emit()


## Caído: um companheiro de pé por perto vai enchendo a barra de reviver.
func _update_downed(delta: float) -> void:
	for other: Player in get_tree().get_nodes_in_group("players"):
		if other != self and other.is_targetable() \
				and other.global_position.distance_to(global_position) <= GameConfig.REVIVE_RADIUS:
			revive_progress += delta / GameConfig.REVIVE_TIME
			break
	if revive_progress >= 1.0:
		revive(GameConfig.REVIVE_HP)


## Toca uma animação do modelo. Com `duration`, ajusta a velocidade para durar esse tempo.
func _play(anim_name: String, duration := 0.0, restart := false) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if _anim.current_animation == anim_name and not restart:
		return
	var speed := 1.0
	if duration > 0.0:
		speed = _anim.get_animation(anim_name).length / duration
	_anim.play(anim_name, ANIM_BLEND, speed)
	if restart:
		_anim.seek(0.0, true)
