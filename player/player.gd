class_name Player
extends CharacterBody3D
## Herói. Movimento relativo à câmera isométrica, com mira separada do movimento (twin-stick):
## analógico direito ou mouse miram, e o herói anda de costas e de lado olhando para a mira.
## No host (ou offline) ele simula tudo a partir do PlayerInput, seja o controle local
## ou os comandos que chegam pela rede. Nos clientes ele só mostra o estado replicado.

signal downed
signal revived
## O inventário mudou (no dono, para a tela de inventário se atualizar).
signal inventory_updated

## Modelo provisório por jogador da sala (P1 a P4) (Quaternius, CC0). Para trocar, basta outro .glb na mesma
## escala (1 unidade = 1 m, pé na origem) com animações Idle, Run, Roll, Sword_Slash e Death.
## As animações são pedidas por ação (AnimSets.HUMANOID); pulo, queda e escalada vêm do
## modelo se ele tiver, senão de ProceduralAnims.
const MODELS: Array[PackedScene] = [
	preload("res://assets/characters/Adventurer.glb"),
	preload("res://assets/characters/Swat.glb"),
	preload("res://assets/characters/Farmer.glb"),
	preload("res://assets/characters/Worker.glb"),
]
## Suavização da posição replicada nos clientes (maior = segue mais rápido).
const NET_SMOOTHING := 18.0
const NET_SNAP_DISTANCE := 3.0
## Dano sem arma corpo a corpo.
const UNARMED_DAMAGE := 5.0
## Golpes do combo corpo a corpo, em ordem. Apertar ataque durante um golpe encadeia o próximo.
## "damage" é o multiplicador sobre o dano da arma (x10). "windup" é o tempo até o golpe acertar.
const COMBO: Array[Dictionary] = [
	{"damage": 10.0, "knockback": 3.0, "windup": 0.18, "recovery": 0.3, "lunge": 2.5},
	{"damage": 10.0, "knockback": 3.0, "windup": 0.18, "recovery": 0.3, "lunge": 2.5},
	{"damage": 22.0, "knockback": 8.0, "windup": 0.26, "recovery": 0.42, "lunge": 4.0},
]
## Em que fração da animação de golpe ("slash") a lâmina passa pela frente (para casar com o acerto).
const SLASH_IMPACT := 0.4
## Depois de atirar, por quanto tempo as pernas correm com a animação de "correr atirando".
const SHOOT_POSE_TIME := 0.35

enum State { NORMAL, DODGING, ATTACKING, CLIMBING, DOWNED }

static var _arc_mesh: ArrayMesh

## Máquina dona do jogador (id de rede) e o slot do controle nela.
var owner_peer := 1
var slot := 0
## Posição na sala (P1 a P4): define cor e modelo.
var index := 0
var display_name := ""
## Inventário: no host é o de verdade; no dono é a cópia que ele recebe; nos outros fica vazio.
var inventory := Inventory.new()
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
var _melee_cooldown := 0.0
var _combo_step := 0
var _combo_queued := false
var _hit_done := false
var _hitstop := 0.0
var _anim_lock := 0.0
var _shoot_pose := 0.0
var _aim_dir := Vector3.ZERO
var _coyote := 0.0
var _jump_buffer := 0.0
var _climb_from := Vector3.ZERO
var _climb_to := Vector3.ZERO
var _animator: CharacterAnimator
var _model: Node3D
var _input: PlayerInput
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _net_synced := false
var _visual := []

@onready var _ring: MeshInstance3D = $Ring
@onready var _tag: Label3D = $Tag


func setup(data: Dictionary) -> void:
	owner_peer = data.peer
	slot = data.slot
	index = data.index
	display_name = data.get("name", "")
	inventory = Inventory.from_dict(data.get("inventory", {}))
	if inventory.is_empty():
		inventory = Inventory.starter()
	_visual = data.get("visual", inventory.visual())


func _ready() -> void:
	add_to_group("players")
	if multiplayer.is_server():
		if owner_peer == multiplayer.get_unique_id():
			_input = PlayerInput.local(slot)
		else:
			_input = NetService.remote_input(owner_peer, slot)
	collision_layer = GameConfig.LAYER_PLAYERS
	collision_mask = GameConfig.LAYER_WORLD | GameConfig.LAYER_ENEMIES
	health.max_hp = GameConfig.PLAYER_MAX_HP
	add_child(health)
	health.died.connect(_on_died)

	var color := GameConfig.PLAYER_COLORS[index]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = material
	_tag.modulate = color

	_model = MODELS[index % MODELS.size()].instantiate()
	$Model.add_child(_model)
	_animator = CharacterAnimator.new(_model, AnimSets.HUMANOID)
	ItemVisuals.dress(_model, _visual)
	if multiplayer.is_server():
		inventory.changed.connect(_on_inventory_changed)
		_apply_stats()
		# Depois de nascer em todo mundo, o dono recebe o inventário (e salva o kit inicial).
		_send_inventory.call_deferred()


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
	# Armadura reduz o dano: 25 de armadura deixa passar 2/3.
	amount *= 100.0 / (100.0 + armor() * 2.0)
	if health.take_hit(amount):
		_knockback = Combat.flat(knockback)
		_fx("fx_flash", [Color(1.0, 0.2, 0.2, 0.6), 0.1])
		_fx("fx_shake", [0.25])


func revive(fraction: float) -> void:
	health.reset(fraction)
	revive_progress = 0.0
	state = State.NORMAL
	_animator.play("idle")
	revived.emit()


## Jogador desta máquina (a câmera e a HUD daqui cuidam dele).
## Segundos até poder rolar de novo (o host simula; no cliente fica 0).
func dodge_cooldown_left() -> float:
	return _dodge_cooldown


func is_local() -> bool:
	return owner_peer == multiplayer.get_unique_id()


func _process(delta: float) -> void:
	if is_local():
		InputService.set_aim_anchor(slot, global_position)
	_tag.text = "P%d" % (index + 1)
	if state == State.DOWNED:
		_tag.text += "  ✚ %d%%" % int(revive_progress * 100.0)
	if not multiplayer.is_server() and _net_synced:
		if global_position.distance_to(_net_pos) > NET_SNAP_DISTANCE:
			global_position = _net_pos
		else:
			global_position = global_position.lerp(_net_pos, 1.0 - exp(-NET_SMOOTHING * delta))
		rotation.y = lerp_angle(rotation.y, _net_yaw, 1.0 - exp(-NET_SMOOTHING * delta))


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	# Sem chão carregado embaixo (bloco ainda chegando): espera parado em vez de cair.
	var streamer := WorldStreamer.of(self)
	if streamer and not streamer.is_ready_at(global_position):
		return
	_input.begin_tick()
	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	_arrow_cooldown = maxf(_arrow_cooldown - delta, 0.0)
	_melee_cooldown = maxf(_melee_cooldown - delta, 0.0)
	potion_cooldown = maxf(potion_cooldown - delta, 0.0)
	_anim_lock = maxf(_anim_lock - delta, 0.0)
	_shoot_pose = maxf(_shoot_pose - delta, 0.0)
	_coyote = GameConfig.COYOTE_TIME if is_on_floor() else maxf(_coyote - delta, 0.0)
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if _input.just_pressed(InputService.Action.JUMP):
		_jump_buffer = GameConfig.JUMP_BUFFER

	# Hit-stop: congela o atacante um instante quando o golpe conecta, pra dar peso.
	if _hitstop > 0.0:
		_hitstop -= delta
		_input.defer()
		_animator.set_frozen(true)
		return
	_animator.set_frozen(false)

	var dir := _input_dir()
	_aim_dir = Vector3(_input.aim.x, 0.0, _input.aim.y).normalized() if _input.aim.length_squared() > 0.01 else Vector3.ZERO
	var desired := Vector3.ZERO
	match state:
		State.NORMAL:
			desired = _update_normal(delta, dir)
		State.ATTACKING:
			desired = _update_attack(delta, dir)
		State.DODGING:
			desired = _update_dodge(delta)
		State.CLIMBING:
			_update_climb(delta)
			return
		State.DOWNED:
			_update_downed(delta)

	desired = _apply_leash(desired)
	_knockback = _knockback.move_toward(Vector3.ZERO, 30.0 * delta)
	velocity.x = desired.x + _knockback.x
	velocity.z = desired.z + _knockback.z
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = 0.0
	else:
		velocity.y -= GameConfig.GRAVITY * delta
	move_and_slide()

	if state != State.DOWNED:
		var target_basis := Basis.looking_at(_facing)
		basis = basis.slerp(target_basis, minf(GameConfig.PLAYER_TURN_SPEED * delta, 1.0)).orthonormalized()


func _input_dir() -> Vector3:
	var move := _input.move
	return Vector3(move.x, 0.0, move.y).rotated(Vector3.UP, deg_to_rad(GameConfig.CAMERA_YAW_DEG))


func _update_normal(delta: float, dir: Vector3) -> Vector3:
	var moving := dir.length_squared() > 0.0001
	var aiming := _aim_dir != Vector3.ZERO
	# Mirando, o herói olha para a mira; senão, para onde anda.
	if aiming:
		_facing = _aim_dir
	elif moving:
		_facing = dir.normalized()
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = GameConfig.JUMP_VELOCITY
		_jump_buffer = 0.0
		_coyote = 0.0
		_animator.play("jump", 0.0, true, 0.08)
	# No quadro do pulo o herói ainda conta como "no chão"; a subida já vale como ar.
	var grounded := is_on_floor() and velocity.y <= 0.0
	# No ar, empurrando contra uma borda alcançável: escala.
	if not grounded and moving and _try_mantle():
		return Vector3.ZERO
	if grounded and _try_dodge():
		return _update_dodge(0.0)
	# Apertar ataca; segurar continua atacando (depois da pausa curta entre combos).
	var melee := _input.just_pressed(InputService.Action.MELEE) \
			or (_input.is_pressed(InputService.Action.MELEE) and _melee_cooldown == 0.0)
	if grounded and melee:
		_start_attack(0, dir)
		return Vector3.ZERO
	if _input.is_pressed(InputService.Action.RANGED) and _arrow_cooldown == 0.0:
		_shoot_arrow()
	if _input.just_pressed(InputService.Action.POTION):
		_drink_potion()
	if _input.just_pressed(InputService.Action.PICKUP):
		_pick_up()

	var target := dir * move_speed() * _strafe_factor(dir)
	_move = _move.move_toward(target, GameConfig.PLAYER_ACCEL * delta)
	if not grounded:
		if not _animator.is_playing("jump"):
			_animator.play("fall", 0.0, false, 0.12)
	elif _anim_lock == 0.0:
		_animator.play(_locomotion_anim(aiming))
	return _move


## Andando de costas ou de lado (mirando) é mais devagar que de frente.
func _strafe_factor(dir: Vector3) -> float:
	if _aim_dir == Vector3.ZERO or dir.length_squared() < 0.0001:
		return 1.0
	var forward := dir.normalized().dot(_facing)
	return lerpf(GameConfig.BACKPEDAL_SPEED_FACTOR, 1.0, (forward + 1.0) / 2.0)


## Ação das pernas: parado, correndo, ou (mirando/atirando) de costas e de lado.
func _locomotion_anim(aiming: bool) -> String:
	var action := CharacterAnimator.locomotion_action(_move, _facing)
	if action == "idle":
		return "idle_aim" if aiming else "idle"
	if action == "move" and _shoot_pose > 0.0:
		return "move_shoot"
	return action


## Sofá: quem divide a tela não se afasta mais que COUCH_LEASH dos outros da mesma tela
## (como uma parede invisível). Assim a região em volta do grupo cabe na tela e fica carregada.
## Jogadores online, em outras máquinas, não têm esse limite.
func _apply_leash(desired: Vector3) -> Vector3:
	for other: Player in get_tree().get_nodes_in_group("players"):
		if other == self or other.owner_peer != owner_peer or not other.is_targetable():
			continue
		var offset := Combat.flat(global_position - other.global_position)
		var distance := offset.length()
		if distance > GameConfig.COUCH_LEASH:
			var away := offset / distance
			var outward := desired.dot(away)
			if outward > 0.0:
				desired -= away * outward
	return desired


func _try_dodge() -> bool:
	if not _input.just_pressed(InputService.Action.DODGE) or _dodge_cooldown > 0.0:
		return false
	state = State.DODGING
	_dodge_dir = _facing
	_state_timer = GameConfig.DODGE_TIME
	_dodge_cooldown = GameConfig.DODGE_COOLDOWN
	_animator.play("roll", GameConfig.DODGE_TIME, true)
	return true


func _update_dodge(delta: float) -> Vector3:
	_state_timer -= delta
	if _state_timer <= 0.0:
		state = State.NORMAL
		_move = _dodge_dir * move_speed()
	return _dodge_dir * GameConfig.DODGE_SPEED


## Escalada: procura uma parede à frente, acha o topo dela com um raio de cima para
## baixo e confere se cabe o herói lá em cima. Paredes altas demais não têm topo ao alcance.
func _try_mantle() -> bool:
	var space := get_world_3d().direct_space_state
	var wall := {}
	for height: float in [1.2, 0.5]:
		var from := global_position + Vector3.UP * height
		var ray := PhysicsRayQueryParameters3D.create(from, from + _facing * 0.8, GameConfig.LAYER_WORLD)
		wall = space.intersect_ray(ray)
		if not wall.is_empty():
			break
	if wall.is_empty() or absf(wall.normal.y) > 0.3:
		return false

	var probe: Vector3 = wall.position + _facing * 0.25
	var top_ray := PhysicsRayQueryParameters3D.create(
			Vector3(probe.x, global_position.y + GameConfig.MANTLE_REACH + 0.3, probe.z),
			Vector3(probe.x, global_position.y + 0.3, probe.z), GameConfig.LAYER_WORLD)
	var top := space.intersect_ray(top_ray)
	if top.is_empty() or top.normal.y < 0.7:
		return false
	var ledge: Vector3 = top.position
	if ledge.y - global_position.y > GameConfig.MANTLE_REACH:
		return false

	var capsule := CapsuleShape3D.new()
	capsule.radius = GameConfig.PLAYER_RADIUS
	capsule.height = GameConfig.PLAYER_HEIGHT
	var room := PhysicsShapeQueryParameters3D.new()
	room.shape = capsule
	room.transform = Transform3D(Basis.IDENTITY, ledge + Vector3.UP * (GameConfig.PLAYER_HEIGHT / 2.0 + 0.05))
	room.collision_mask = GameConfig.LAYER_WORLD | GameConfig.LAYER_ENEMIES
	if not space.intersect_shape(room, 1).is_empty():
		return false

	state = State.CLIMBING
	_state_timer = 0.0
	_climb_from = global_position
	_climb_to = ledge + Vector3.UP * 0.02
	velocity = Vector3.ZERO
	_move = Vector3.ZERO
	_animator.play("climb", GameConfig.MANTLE_TIME, true, 0.06)
	return true


## Sobe reto até a altura da borda e depois avança para cima dela.
func _update_climb(delta: float) -> void:
	_state_timer += delta
	var t := clampf(_state_timer / GameConfig.MANTLE_TIME, 0.0, 1.0)
	var rise := clampf(t / 0.6, 0.0, 1.0)
	var forward := clampf((t - 0.6) / 0.4, 0.0, 1.0)
	var pos := _climb_from
	pos.y = lerpf(_climb_from.y, _climb_to.y, ease(rise, 0.5))
	pos.x = lerpf(_climb_from.x, _climb_to.x, forward)
	pos.z = lerpf(_climb_from.z, _climb_to.z, forward)
	global_position = pos
	if t >= 1.0:
		state = State.NORMAL
		velocity = Vector3.ZERO


## Corpo a corpo

func _start_attack(step: int, dir: Vector3) -> void:
	state = State.ATTACKING
	_combo_step = step
	_combo_queued = false
	_hit_done = false
	_state_timer = 0.0
	_move = Vector3.ZERO
	var enemies := get_tree().get_nodes_in_group("enemies")
	if _aim_dir != Vector3.ZERO:
		_facing = _aim_dir
	else:
		var aim := Combat.nearest_in_cone(global_position, _facing, enemies, GameConfig.SOFT_AIM_RADIUS, 360.0)
		if aim:
			_facing = Combat.flat(aim.global_position - global_position).normalized()
		elif dir.length_squared() > 0.0001:
			_facing = dir.normalized()
	var hit: Dictionary = COMBO[step]
	# Duração escolhida para a lâmina passar na frente bem na hora do acerto (fim do windup).
	_animator.play("slash", hit.windup / SLASH_IMPACT, true, 0.04)


func _update_attack(delta: float, dir: Vector3) -> Vector3:
	if _try_dodge():
		return _update_dodge(0.0)
	var hit: Dictionary = COMBO[_combo_step]
	_state_timer += delta
	# Apertar de novo ou continuar segurando encadeia o próximo golpe.
	if _input.just_pressed(InputService.Action.MELEE) or _input.is_pressed(InputService.Action.MELEE):
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
			_melee_cooldown = GameConfig.MELEE_REPEAT_COOLDOWN
	return desired


func _melee_hit(hit: Dictionary) -> void:
	var finisher := _combo_step == COMBO.size() - 1
	var targets := Combat.query_arc(self, _facing, GameConfig.MELEE_RADIUS, GameConfig.MELEE_ARC_DEG, GameConfig.LAYER_ENEMIES)
	var dealt := 0.0
	for target in targets:
		var amount: float = hit.damage / 10.0 * melee_damage()
		target.take_hit(amount, _facing * hit.knockback)
		dealt += amount
	# Roubo de vida (encantamento Vampírico).
	if dealt > 0.0:
		health.heal(dealt * inventory.total("lifesteal_pct") / 100.0)
	_fx("fx_slash", [finisher, _facing])
	if not targets.is_empty():
		_hitstop = GameConfig.HITSTOP_TIME
		_fx("fx_shake", [0.35 if finisher else 0.12])


## Efeitos visuais: rodam aqui e nas outras máquinas da sala.

func _fx(method: String, args: Array) -> void:
	var replicator := NetReplicator.of(self)
	if replicator:
		replicator.broadcast_fx(self, method, args)
	else:
		callv(method, args)


func fx_flash(color: Color, time: float) -> void:
	Combat.flash(_model, color, null, time)


func fx_shake(strength: float) -> void:
	Combat.shake_camera(self, strength)


func fx_slash(finisher: bool, facing: Vector3) -> void:
	var material := Combat.overlay_material(Color(1.0, 0.97, 0.85, 0.85 if finisher else 0.6))
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var fx := MeshInstance3D.new()
	fx.mesh = _get_arc_mesh()
	fx.material_override = material
	get_parent().add_child(fx)
	fx.global_transform = Transform3D(Basis.looking_at(facing), global_position + Vector3.UP * 0.9)
	fx.scale = Vector3.ONE * (1.3 if finisher else 1.0)
	var tween := fx.create_tween()
	tween.tween_property(fx, "rotation:y", fx.rotation.y + 0.35, 0.22)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.22)
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
	if ranged_damage() <= 0.0:
		return
	_arrow_cooldown = GameConfig.ARROW_COOLDOWN
	# Mirando de verdade (analógico/mouse) a correção é pequena; atirando "para a frente", maior.
	var aimed := _aim_dir != Vector3.ZERO
	var cone := GameConfig.ARROW_AIM_ASSIST_DEG if aimed else GameConfig.ARROW_AIM_CONE_DEG
	var enemies := get_tree().get_nodes_in_group("enemies")
	var aim := Combat.nearest_in_cone(global_position, _facing, enemies, GameConfig.ARROW_RANGE, cone)
	if aim and not aimed:
		_facing = Combat.flat(aim.global_position - global_position).normalized()
	var from := global_position + Vector3.UP * 1.1 + _facing * 0.6
	var dir := _facing
	if aim:
		dir = (aim.global_position + Vector3.UP * 1.0 - from).normalized()
	Projectile.fire(self, from, dir, GameConfig.ARROW_SPEED, ranged_damage(),
			GameConfig.LAYER_ENEMIES, Color(1.0, 0.95, 0.7))
	# Parado, o corpo todo atira; andando, as pernas continuam correndo (Run_Shoot e direções).
	_shoot_pose = SHOOT_POSE_TIME
	if Combat.flat(_move).length() < 0.5 and is_on_floor():
		_animator.play("shoot", 0.3, true, 0.05)
		_anim_lock = 0.3


func _drink_potion() -> void:
	if potion_cooldown > 0.0 or health.hp >= health.max_hp:
		return
	health.heal(health.max_hp * GameConfig.POTION_HEAL)
	potion_cooldown = GameConfig.POTION_COOLDOWN
	_fx("fx_flash", [Color(0.3, 1.0, 0.4, 0.5), 0.25])


func _on_died() -> void:
	state = State.DOWNED
	revive_progress = 0.0
	_move = Vector3.ZERO
	_animator.play("death")
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


## Rede

func get_net_state() -> Array:
	return [global_position, rotation.y, _animator.net_state(),
			health.hp, state, revive_progress, potion_cooldown, health.max_hp]


func apply_net_state(s: Array) -> void:
	_net_pos = s[0]
	_net_yaw = s[1]
	if not _net_synced:
		_net_synced = true
		global_position = _net_pos
		rotation.y = _net_yaw
	_animator.apply_net_state(s[2])
	health.hp = s[3]
	state = s[4]
	revive_progress = s[5]
	potion_cooldown = s[6]
	health.max_hp = s[7]


## Inventário e atributos

func melee_damage() -> float:
	var weapon: Variant = inventory.equipment.get("melee")
	var base := ItemDB.stat(weapon, "damage") if weapon else UNARMED_DAMAGE
	return base * (1.0 + inventory.total("damage_pct") / 100.0)


func ranged_damage() -> float:
	var weapon: Variant = inventory.equipment.get("ranged")
	return ItemDB.stat(weapon, "damage") * (1.0 + inventory.total("damage_pct") / 100.0) if weapon else 0.0


func armor() -> float:
	return inventory.total("armor")


func move_speed() -> float:
	return GameConfig.PLAYER_SPEED * (1.0 + inventory.total("move_speed_pct") / 100.0)


## Pedido vindo da tela de inventário do dono. Comandos: "move" [de, para],
## "equip" [casa], "drop" [casa]. Quem executa é sempre o host.
func request_inventory(command: String, args: Array) -> void:
	if multiplayer.is_server():
		apply_inventory_command(command, args)
	else:
		NetService.send_inventory_command(self, command, args)


func apply_inventory_command(command: String, args: Array) -> void:
	if command in Services.COMMANDS:
		var result := Services.run(self, command, args)
		_fx("fx_toast", [result[1], result[2]])
		return
	match command:
		"move":
			# O depósito do banco só se mexe perto do banco.
			if (args[0][0] == "depot" or args[1][0] == "depot") \
					and WorldNpc.nearest(get_tree(), global_position, Services.BANK, WorldNpc.TALK_RANGE + 0.6) == null:
				return
			inventory.move(args[0], args[1])
		"equip":
			inventory.equip(args[0])
		"drop":
			var item: Variant = inventory.remove(args[0])
			if item != null:
				Loot.drop(self, item, Combat.flat(global_position) + _facing * 1.2)


## Pega do chão o item mais perto (qualquer um do time pode pegar; quem pegar primeiro leva).
func _pick_up() -> void:
	var loot := Loot.nearest(get_tree(), global_position)
	if loot and give_item(loot.item):
		loot.queue_free()


## Host: guarda o item na mochila. Retorna false se não couber.
func give_item(item: Dictionary) -> bool:
	if item.get("id") == "gold":
		inventory.add_gold(int(item.get("amount", 0)))
		_fx("fx_toast", ["+" + ItemDB.money(int(item.get("amount", 0))), ItemDB.DEFS.gold.color])
		return true
	if inventory.add_item(item).is_empty():
		_fx("fx_toast", ["Mochila cheia", Color(1.0, 0.5, 0.4)])
		return false
	_fx("fx_toast", [ItemDB.display_name(item), ItemDB.rarity_color(item)])
	return true


func _on_inventory_changed() -> void:
	_apply_stats()
	var visual := inventory.visual()
	if visual != _visual:
		_visual = visual
		var data: Dictionary = get_meta("net_data", {})
		data["visual"] = visual
		_fx("fx_dress", [visual])
	_send_inventory()


func _send_inventory() -> void:
	var replicator := NetReplicator.of(self)
	if replicator:
		replicator.send_to_peer(owner_peer, self, "net_inventory", [inventory.to_dict()])
	else:
		net_inventory(inventory.to_dict())


func _apply_stats() -> void:
	var old_max := health.max_hp
	health.max_hp = GameConfig.PLAYER_MAX_HP + inventory.total("hp")
	if not health.is_dead():
		health.hp = clampf(health.hp + maxf(health.max_hp - old_max, 0.0), 0.0, health.max_hp)


## No dono: chegou a versão nova do inventário (no host o objeto já é o mesmo).
func net_inventory(data: Dictionary) -> void:
	if not multiplayer.is_server():
		inventory = Inventory.from_dict(data)
	if is_local():
		SaveService.save_player(slot, {"inventory": data})
	inventory_updated.emit()


func fx_dress(visual: Array) -> void:
	_visual = visual
	ItemVisuals.dress(_model, visual)


## Texto que sobe da cabeça (item pego, mochila cheia).
func fx_toast(text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 40
	label.outline_size = 10
	label.layers = 2
	add_child(label)
	label.position = Vector3.UP * 2.9
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", 3.6, 1.2)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.2).set_delay(0.5)
	tween.tween_callback(label.queue_free)
