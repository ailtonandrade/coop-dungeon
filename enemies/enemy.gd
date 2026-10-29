class_name Enemy
extends CharacterBody3D
## Inimigo básico com navegação. MELEE corre até o herói e bate; RANGED mantém
## distância e atira. Todo ataque tem um tempo de preparo visível (fica vermelho)
## para dar chance de rolar.
## A IA roda só no host; nos clientes o inimigo mostra o estado replicado.

signal died(enemy: Enemy)

enum Kind { MELEE, RANGED }
enum State { CHASE, WINDUP, RECOVER, STAGGER, DEAD }

const STATS := {
	Kind.MELEE: {
		"model": "res://assets/characters/Punk.glb", "tint": Color(0.3, 0.9, 0.2, 0.3), "scale": 1.1,
		"hp": 30.0, "speed": 3.4, "attack_range": 1.6, "windup": 0.5, "recover": 0.8,
		"damage": 12.0, "knockback": 6.0, "anim": "Punch_Right",
	},
	Kind.RANGED: {
		"model": "res://assets/characters/Casual_Hoodie.glb", "tint": Color(0.7, 0.3, 1.0, 0.3), "scale": 1.0,
		"hp": 20.0, "speed": 3.0, "attack_range": 10.0, "windup": 0.7, "recover": 1.6,
		"damage": 10.0, "knockback": 3.0, "anim": "Gun_Shoot",
	},
}
const RANGED_MIN_DIST := 5.0
const PROJECTILE_SPEED := 9.0
const STAGGER_TIME := 0.25
const TURN_SPEED := 12.0
const ANIM_BLEND := 0.12
const WINDUP_TINT := Color(1.0, 0.15, 0.1, 0.55)
const NET_SMOOTHING := 18.0
const NET_SNAP_DISTANCE := 3.0

var kind := Kind.MELEE
var state := State.CHASE
var health := Health.new()

var _stats: Dictionary
var _target: Player
var _retarget := 0.0
var _timer := 0.0
var _facing := Vector3.FORWARD
var _knockback := Vector3.ZERO
var _model: Node3D
var _anim: AnimationPlayer
var _tint: StandardMaterial3D
var _agent: NavigationAgent3D
var _anim_name := ""
var _anim_speed := 1.0
var _anim_serial := 0
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _net_synced := false


static func create(p_kind: Kind) -> Enemy:
	var enemy := Enemy.new()
	enemy.kind = p_kind
	return enemy


func _ready() -> void:
	_stats = STATS[kind]
	add_to_group("enemies")
	collision_layer = GameConfig.LAYER_ENEMIES
	collision_mask = GameConfig.LAYER_WORLD | GameConfig.LAYER_PLAYERS | GameConfig.LAYER_ENEMIES

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)

	_agent = NavigationAgent3D.new()
	_agent.radius = 0.4
	_agent.height = 1.8
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 0.6
	add_child(_agent)

	var pivot := Node3D.new()
	pivot.rotation.y = PI  # modelos olham para +Z; o jogo usa -Z como frente
	pivot.scale = Vector3.ONE * _stats.scale
	add_child(pivot)
	_model = (load(_stats.model) as PackedScene).instantiate()
	pivot.add_child(_model)
	_tint = Combat.overlay_material(_stats.tint)
	Combat.set_overlay(_model, _tint)
	_anim = _model.find_child("AnimationPlayer", true, false)
	if _anim:
		for anim_name in ["Idle", "Run"]:
			if _anim.has_animation(anim_name):
				_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR

	health.max_hp = _stats.hp
	add_child(health)
	health.died.connect(_on_died)


func is_targetable() -> bool:
	return state != State.DEAD


func take_hit(amount: float, knockback := Vector3.ZERO) -> void:
	if state == State.DEAD or not health.take_hit(amount):
		return
	_knockback = Combat.flat(knockback)
	if state == State.DEAD:
		return
	var replicator := NetReplicator.of(self)
	if replicator:
		replicator.broadcast_fx(self, "fx_flash", [])
	else:
		fx_flash()
	# Apanhar interrompe o ataque em preparo.
	state = State.STAGGER
	_timer = STAGGER_TIME
	_play("HitRecieve", STAGGER_TIME, true)


func fx_flash() -> void:
	Combat.flash(_model, Color(1.0, 1.0, 1.0, 0.8), _tint, 0.08)


func _process(delta: float) -> void:
	if multiplayer.is_server() or not _net_synced:
		return
	if global_position.distance_to(_net_pos) > NET_SNAP_DISTANCE:
		global_position = _net_pos
	else:
		global_position = global_position.lerp(_net_pos, 1.0 - exp(-NET_SMOOTHING * delta))
	rotation.y = lerp_angle(rotation.y, _net_yaw, 1.0 - exp(-NET_SMOOTHING * delta))


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_knockback = _knockback.move_toward(Vector3.ZERO, 25.0 * delta)
	var desired := Vector3.ZERO

	if state != State.DEAD:
		_retarget -= delta
		if _retarget <= 0.0 or _target == null or not is_instance_valid(_target) or not _target.is_targetable():
			_target = _find_target()
			_retarget = 0.5
		_timer -= delta
		match state:
			State.CHASE:
				desired = _chase()
			State.WINDUP:
				if _timer <= 0.0:
					_strike()
			State.RECOVER, State.STAGGER:
				if _timer <= 0.0:
					state = State.CHASE

	velocity.x = desired.x + _knockback.x
	velocity.z = desired.z + _knockback.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GameConfig.GRAVITY * delta
	move_and_slide()

	if state == State.DEAD:
		return
	basis = basis.slerp(Basis.looking_at(_facing), minf(TURN_SPEED * delta, 1.0)).orthonormalized()
	if state == State.CHASE:
		_play("Run" if desired.length() > 0.3 else "Idle")


func _chase() -> Vector3:
	if _target == null:
		return Vector3.ZERO
	var to := Combat.flat(_target.global_position - global_position)
	var dist := to.length()
	if dist > 0.01:
		_facing = to / dist

	if kind == Kind.RANGED:
		if dist < RANGED_MIN_DIST:
			return -_facing * _stats.speed * 0.8
		if dist <= _stats.attack_range and _has_line_of_sight():
			_begin_windup()
			return Vector3.ZERO
	elif dist <= _stats.attack_range:
		_begin_windup()
		return Vector3.ZERO
	return _nav_velocity(_target.global_position)


func _nav_velocity(target: Vector3) -> Vector3:
	if _agent.target_position.distance_to(target) > 0.5:
		_agent.target_position = target
	var next := Combat.flat(_agent.get_next_path_position() - global_position)
	if next.length_squared() < 0.0001:
		return Vector3.ZERO
	return next.normalized() * _stats.speed


func _begin_windup() -> void:
	state = State.WINDUP
	_timer = _stats.windup
	Combat.set_overlay(_model, Combat.overlay_material(WINDUP_TINT))
	_play(_stats.anim, _stats.windup + 0.2, true)


func _strike() -> void:
	state = State.RECOVER
	_timer = _stats.recover
	Combat.set_overlay(_model, _tint)
	if kind == Kind.MELEE:
		for body in Combat.query_arc(self, _facing, _stats.attack_range + 0.4, 100.0, GameConfig.LAYER_PLAYERS):
			body.take_hit(_stats.damage, _facing * _stats.knockback)
	elif _target:
		var from := global_position + Vector3.UP * 1.1 + _facing * 0.5
		var dir := (_target.global_position + Vector3.UP * 1.0 - from).normalized()
		Projectile.fire(self, from, dir, PROJECTILE_SPEED, _stats.damage,
				GameConfig.LAYER_PLAYERS, Color(0.8, 0.3, 1.0), Vector3(0.35, 0.35, 0.35))


func _has_line_of_sight() -> bool:
	var query := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * 1.1, _target.global_position + Vector3.UP * 1.1, GameConfig.LAYER_WORLD)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _find_target() -> Player:
	var best: Player = null
	var best_dist := INF
	for player: Player in get_tree().get_nodes_in_group("players"):
		var dist := player.global_position.distance_squared_to(global_position)
		if player.is_targetable() and dist < best_dist:
			best = player
			best_dist = dist
	return best


func _on_died() -> void:
	_become_dead()
	_play("Death", 0.0, true)
	var spawner := get_tree().get_first_node_in_group("wave_spawner")
	Loot.roll_drops(self, (spawner.wave if spawner else 1) + randi_range(0, 1))
	died.emit(self)
	get_tree().create_timer(1.5).timeout.connect(queue_free)


func _become_dead() -> void:
	state = State.DEAD
	collision_layer = 0
	collision_mask = GameConfig.LAYER_WORLD
	remove_from_group("enemies")
	Combat.set_overlay(_model, _tint)


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
		_anim_serial += 1
	_anim_name = anim_name
	_anim_speed = speed


## Rede

func get_net_state() -> Array:
	return [global_position, rotation.y, _anim_name, _anim_speed, _anim_serial, state, health.hp]


func apply_net_state(s: Array) -> void:
	_net_pos = s[0]
	_net_yaw = s[1]
	if not _net_synced:
		_net_synced = true
		global_position = _net_pos
		rotation.y = _net_yaw
	var serial: int = s[4]
	if _anim and _anim.has_animation(s[2]) and (serial != _anim_serial or s[2] != _anim.current_animation):
		_anim.play(s[2], ANIM_BLEND, s[3])
		if serial != _anim_serial:
			_anim.seek(0.0, true)
	_anim_serial = serial
	health.hp = s[6]
	var new_state: State = s[5]
	if new_state == state:
		return
	state = new_state
	if state == State.DEAD:
		_become_dead()
	elif state == State.WINDUP:
		Combat.set_overlay(_model, Combat.overlay_material(WINDUP_TINT))
	else:
		Combat.set_overlay(_model, _tint)
