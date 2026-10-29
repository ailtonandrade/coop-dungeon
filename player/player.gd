class_name Player
extends CharacterBody3D
## Herói. Movimento relativo à câmera isométrica.
## No host (ou offline) ele simula tudo a partir do PlayerInput, seja o controle local
## ou os comandos que chegam pela rede. Nos clientes ele só mostra o estado replicado.

signal downed
signal revived
## O inventário mudou (no dono, para a tela de inventário se atualizar).
signal inventory_updated

## Modelo provisório por jogador da sala (P1 a P4) (Quaternius, CC0). Para trocar, basta outro .glb na mesma
## escala (1 unidade = 1 m, pé na origem) com animações Idle, Run, Roll, Sword_Slash e Death.
## Se o modelo tiver "Jump" e "Climb", elas são usadas no pulo e na escalada.
const MODELS: Array[PackedScene] = [
	preload("res://assets/characters/Adventurer.glb"),
	preload("res://assets/characters/Swat.glb"),
	preload("res://assets/characters/Farmer.glb"),
	preload("res://assets/characters/Worker.glb"),
]
const ANIM_BLEND := 0.15
## Suavização da posição replicada nos clientes (maior = segue mais rápido).
const NET_SMOOTHING := 18.0
const NET_SNAP_DISTANCE := 3.0
## Dano sem arma corpo a corpo.
const UNARMED_DAMAGE := 5.0
## Golpes do combo corpo a corpo, em ordem. Apertar ataque durante um golpe encadeia o próximo.
const COMBO: Array[Dictionary] = [
	{"damage": 10.0, "knockback": 3.0, "windup": 0.12, "recovery": 0.22, "lunge": 2.5},
	{"damage": 10.0, "knockback": 3.0, "windup": 0.12, "recovery": 0.22, "lunge": 2.5},
	{"damage": 22.0, "knockback": 8.0, "windup": 0.2, "recovery": 0.4, "lunge": 4.0},
]

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
var _combo_step := 0
var _combo_queued := false
var _hit_done := false
var _hitstop := 0.0
var _anim_lock := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _climb_from := Vector3.ZERO
var _climb_to := Vector3.ZERO
var _anim: AnimationPlayer
var _model: Node3D
var _input: PlayerInput
var _anim_name := ""
var _anim_speed := 1.0
var _anim_serial := 0
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
	_anim = _model.find_child("AnimationPlayer", true, false)
	if _anim:
		for anim_name in ["Idle", "Run"]:
			if _anim.has_animation(anim_name):
				_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
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
	_play("Idle")
	revived.emit()


## Jogador desta máquina (a câmera e a HUD daqui cuidam dele).
func is_local() -> bool:
	return owner_peer == multiplayer.get_unique_id()


func _process(delta: float) -> void:
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
	_input.begin_tick()
	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	_arrow_cooldown = maxf(_arrow_cooldown - delta, 0.0)
	potion_cooldown = maxf(potion_cooldown - delta, 0.0)
	_anim_lock = maxf(_anim_lock - delta, 0.0)
	_coyote = GameConfig.COYOTE_TIME if is_on_floor() else maxf(_coyote - delta, 0.0)
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if _input.just_pressed(InputService.Action.JUMP):
		_jump_buffer = GameConfig.JUMP_BUFFER

	# Hit-stop: congela o atacante um instante quando o golpe conecta, pra dar peso.
	if _hitstop > 0.0:
		_hitstop -= delta
		_input.defer()
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
		State.CLIMBING:
			_update_climb(delta)
			return
		State.DOWNED:
			_update_downed(delta)

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
	if moving:
		_facing = dir.normalized()
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = GameConfig.JUMP_VELOCITY
		_jump_buffer = 0.0
		_coyote = 0.0
		_play("Jump")
	var grounded := is_on_floor()
	# No ar, empurrando contra uma borda alcançável: escala.
	if not grounded and moving and _try_mantle():
		return Vector3.ZERO
	if grounded and _try_dodge():
		return _update_dodge(0.0)
	if grounded and _input.just_pressed(InputService.Action.MELEE):
		_start_attack(0, dir)
		return Vector3.ZERO
	if _input.is_pressed(InputService.Action.RANGED) and _arrow_cooldown == 0.0:
		_shoot_arrow()
	if _input.just_pressed(InputService.Action.POTION):
		_drink_potion()
	if _input.just_pressed(InputService.Action.PICKUP):
		_pick_up()

	var target := dir * GameConfig.PLAYER_SPEED
	_move = _move.move_toward(target, GameConfig.PLAYER_ACCEL * delta)
	if _anim_lock == 0.0 and grounded:
		_play("Run" if _move.length() > 0.5 else "Idle")
	return _move


func _try_dodge() -> bool:
	if not _input.just_pressed(InputService.Action.DODGE) or _dodge_cooldown > 0.0:
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
	if not _play("Climb", GameConfig.MANTLE_TIME, true):
		_play("Interact", GameConfig.MANTLE_TIME, true)
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
	if _input.just_pressed(InputService.Action.MELEE):
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
		target.take_hit(hit.damage / 10.0 * melee_damage(), _facing * hit.knockback)
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
	var material := Combat.overlay_material(Color(1.0, 1.0, 1.0, 0.7 if finisher else 0.45))
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var fx := MeshInstance3D.new()
	fx.mesh = _get_arc_mesh()
	fx.material_override = material
	get_parent().add_child(fx)
	fx.global_transform = Transform3D(Basis.looking_at(facing), global_position + Vector3.UP * 0.9)
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
	if ranged_damage() <= 0.0:
		return
	_arrow_cooldown = GameConfig.ARROW_COOLDOWN
	var enemies := get_tree().get_nodes_in_group("enemies")
	var aim := Combat.nearest_in_cone(global_position, _facing, enemies, GameConfig.ARROW_RANGE, GameConfig.ARROW_AIM_CONE_DEG)
	if aim:
		_facing = Combat.flat(aim.global_position - global_position).normalized()
	var from := global_position + Vector3.UP * 1.1 + _facing * 0.6
	var dir := _facing
	if aim:
		dir = (aim.global_position + Vector3.UP * 1.0 - from).normalized()
	Projectile.fire(self, from, dir, GameConfig.ARROW_SPEED, ranged_damage(),
			GameConfig.LAYER_ENEMIES, Color(1.0, 0.95, 0.7))
	_play("Gun_Shoot", 0.3, true)
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
## Retorna false se o modelo não tem essa animação.
func _play(anim_name: String, duration := 0.0, restart := false) -> bool:
	if _anim == null or not _anim.has_animation(anim_name):
		return false
	if _anim.current_animation == anim_name and not restart:
		return true
	var speed := 1.0
	if duration > 0.0:
		speed = _anim.get_animation(anim_name).length / duration
	_anim.play(anim_name, ANIM_BLEND, speed)
	if restart:
		_anim.seek(0.0, true)
		_anim_serial += 1
	_anim_name = anim_name
	_anim_speed = speed
	return true


## Rede

func get_net_state() -> Array:
	return [global_position, rotation.y, _anim_name, _anim_speed, _anim_serial,
			health.hp, state, revive_progress, potion_cooldown, health.max_hp]


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
	health.hp = s[5]
	state = s[6]
	revive_progress = s[7]
	potion_cooldown = s[8]
	health.max_hp = s[9]


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


## Pedido vindo da tela de inventário do dono. Comandos: "move" [de, para],
## "equip" [casa], "drop" [casa]. Quem executa é sempre o host.
func request_inventory(command: String, args: Array) -> void:
	if multiplayer.is_server():
		apply_inventory_command(command, args)
	else:
		NetService.send_inventory_command(self, command, args)


func apply_inventory_command(command: String, args: Array) -> void:
	match command:
		"move":
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
