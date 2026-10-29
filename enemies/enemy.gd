class_name Enemy
extends CharacterBody3D
## Inimigo básico com navegação. MELEE corre até o herói e bate; RANGED mantém
## distância e atira. Todo ataque tem um tempo de preparo visível (fica vermelho)
## para dar chance de rolar.
## A IA roda só no host; nos clientes o inimigo mostra o estado replicado.
##
## No mundo aberto a criatura tem "casa" (o ponto do gerador dela): só persegue quem chega
## a `aggro_radius`, e desiste se o alvo a arrastar para mais de `leash_radius` da casa;
## aí volta e se cura. Na arena de teste os dois raios são infinitos.

signal died(enemy: Enemy)

enum Kind { MELEE, RANGED }
enum State { CHASE, WINDUP, RECOVER, STAGGER, DEAD }

const STATS := {
	Kind.MELEE: {
		"model": "res://assets/characters/Punk.glb", "tint": Color(0.3, 0.9, 0.2, 0.3), "scale": 1.1,
		"hp": 30.0, "speed": 3.4, "attack_range": 1.6, "windup": 0.5, "recover": 0.8,
		"damage": 12.0, "knockback": 6.0, "attack": "punch", "anims": AnimSets.HUMANOID,
	},
	Kind.RANGED: {
		"model": "res://assets/characters/Casual_Hoodie.glb", "tint": Color(0.7, 0.3, 1.0, 0.3), "scale": 1.0,
		"hp": 20.0, "speed": 3.0, "attack_range": 10.0, "windup": 0.7, "recover": 1.6,
		"damage": 10.0, "knockback": 3.0, "attack": "shoot", "anims": AnimSets.HUMANOID,
	},
}
const RANGED_MIN_DIST := 5.0
## Atirador: entre um tiro e outro anda de lado (desvia), olhando para o alvo.
const STRAFE_SPEED_FACTOR := 0.6
const PROJECTILE_SPEED := 9.0
const STAGGER_TIME := 0.25
const TURN_SPEED := 12.0
const WINDUP_TINT := Color(1.0, 0.15, 0.1, 0.55)
const NET_SMOOTHING := 18.0
const NET_SNAP_DISTANCE := 3.0

var kind := Kind.MELEE
var state := State.CHASE
var health := Health.new()
var home := Vector3.ZERO
var aggro_radius := INF
var leash_radius := INF
## Poder do loot que essa criatura deixa (vem do perigo da região).
var power := 1

var _stats: Dictionary
var _target: Player
var _retarget := 0.0
var _timer := 0.0
var _facing := Vector3.FORWARD
var _knockback := Vector3.ZERO
var _model: Node3D
var _animator: CharacterAnimator
var _tint: StandardMaterial3D
var _agent: NavigationAgent3D
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _net_synced := false
var _strafe_side := 1.0


## `data` (do NetReplicator): kind, pos e, no mundo aberto, home, aggro, leash, power.
static func create(data: Dictionary) -> Enemy:
	var enemy := Enemy.new()
	enemy.kind = data.kind
	enemy.home = data.get("home", data.get("pos", Vector3.ZERO))
	enemy.aggro_radius = data.get("aggro", INF)
	enemy.leash_radius = data.get("leash", INF)
	enemy.power = data.get("power", 1)
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
	_animator = CharacterAnimator.new(_model, _stats.anims)

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
	_animator.play("hit", STAGGER_TIME, true)


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
			State.RECOVER:
				desired = _recover_move()
				if _timer <= 0.0:
					state = State.CHASE
			State.STAGGER:
				if _timer <= 0.0:
					state = State.CHASE

	velocity.x = desired.x + _knockback.x
	velocity.z = desired.z + _knockback.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GameConfig.GRAVITY * delta
	move_and_slide()

	if state == State.DEAD:
		return
	basis = basis.slerp(Basis.looking_at(_facing), minf(TURN_SPEED * delta, 1.0)).orthonormalized()
	if state == State.CHASE or (state == State.RECOVER and desired != Vector3.ZERO):
		# Recuando ou desviando de frente para o alvo, as pernas andam de costas ou de lado.
		_animator.play(CharacterAnimator.locomotion_action(desired, _facing, 0.3))
	elif state == State.RECOVER:
		_animator.play("idle")


func _chase() -> Vector3:
	if _target == null:
		return _return_home()
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


## Sem alvo: volta para casa e, chegando, recupera a vida.
func _return_home() -> Vector3:
	if Combat.flat(home - global_position).length() < 1.5:
		health.reset()
		return Vector3.ZERO
	_facing = Combat.flat(home - global_position).normalized()
	return _nav_velocity(home)


func _nav_velocity(target: Vector3) -> Vector3:
	if _agent.target_position.distance_to(target) > 0.5:
		_agent.target_position = target
	var next := Combat.flat(_agent.get_next_path_position() - global_position)
	if next.length_squared() < 0.0001:
		return Vector3.ZERO
	return next.normalized() * _stats.speed


## Atirador entre tiros: anda de lado em volta do alvo, sempre olhando para ele.
func _recover_move() -> Vector3:
	if kind != Kind.RANGED or _target == null or _timer < 0.2:
		return Vector3.ZERO
	var to := Combat.flat(_target.global_position - global_position)
	if to.length() < 0.01:
		return Vector3.ZERO
	_facing = to.normalized()
	return _facing.cross(Vector3.UP) * _strafe_side * _stats.speed * STRAFE_SPEED_FACTOR


func _begin_windup() -> void:
	state = State.WINDUP
	_timer = _stats.windup
	Combat.set_overlay(_model, Combat.overlay_material(WINDUP_TINT))
	_animator.play(_stats.attack, _stats.windup + 0.2, true)


func _strike() -> void:
	state = State.RECOVER
	_timer = _stats.recover
	_strafe_side = -1.0 if randf() < 0.5 else 1.0
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


## Jogador de pé mais perto dentro do alcance de perseguição e sem sair do limite da casa.
## O alvo atual tem uma folga, para a criatura não desistir na borda do alcance.
func _find_target() -> Player:
	var best: Player = null
	var best_dist := INF
	for player: Player in get_tree().get_nodes_in_group("players"):
		var dist := player.global_position.distance_squared_to(global_position)
		var reach := aggro_radius * (1.5 if player == _target else 1.0)
		if not player.is_targetable() or dist > reach * reach:
			continue
		if Combat.flat(player.global_position - home).length() > leash_radius:
			continue
		if dist < best_dist:
			best = player
			best_dist = dist
	return best


func _on_died() -> void:
	_become_dead()
	_animator.play("death", 0.0, true)
	Loot.roll_drops(self, power + randi_range(0, 1))
	died.emit(self)
	get_tree().create_timer(1.5).timeout.connect(queue_free)


func _become_dead() -> void:
	state = State.DEAD
	collision_layer = 0
	collision_mask = GameConfig.LAYER_WORLD
	remove_from_group("enemies")
	Combat.set_overlay(_model, _tint)


## Rede

func get_net_state() -> Array:
	return [global_position, rotation.y, _animator.net_state(), state, health.hp]


func apply_net_state(s: Array) -> void:
	_net_pos = s[0]
	_net_yaw = s[1]
	if not _net_synced:
		_net_synced = true
		global_position = _net_pos
		rotation.y = _net_yaw
	_animator.apply_net_state(s[2])
	health.hp = s[4]
	var new_state: State = s[3]
	if new_state == state:
		return
	state = new_state
	if state == State.DEAD:
		_become_dead()
	elif state == State.WINDUP:
		Combat.set_overlay(_model, Combat.overlay_material(WINDUP_TINT))
	else:
		Combat.set_overlay(_model, _tint)
