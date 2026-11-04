class_name WorldNpc
extends Node3D
## Personagem fixo do mapa que presta um serviço (comerciante, ferreiro, encantador, banco).
## Fica sempre no mesmo lugar, para o jogador aprender onde encontrar cada serviço.
## Perto dele, o botão de pegar (LB / F) abre a tela do serviço (ServicePanel). O host
## confere que o jogador está mesmo perto do NPC certo antes de comprar, refinar etc.

enum Service { MERCHANT, BLACKSMITH, ENCHANTER, BANK }

const SERVICE_NAMES := {
	Service.MERCHANT: "Sucateiro", Service.BLACKSMITH: "Mecânico (upgrade)",
	Service.ENCHANTER: "Hacker de chips (mods)", Service.BANK: "Cofre",
}

## Distância para conversar.
const TALK_RANGE := 2.6

@export var service := Service.MERCHANT
@export var npc_name := ""
@export var model: PackedScene
## Comerciante: o que ele vende (ids do ItemDB) e com que poder.
@export var shop_items := PackedStringArray([
	"sword", "axe", "bow", "longbow", "leather_hood", "iron_helmet", "leather_vest", "chainmail",
	"leather_pants", "leather_boots", "pouch", "backpack",
])
@export var shop_power := 2
## Nome da loja nas fichas de item ("vendido por"); vazio = usa o nome do NPC.
@export var shop_id := ""

var _label: Label3D
var _title := ""

## Vida: cabeça acompanha quem chega perto, corpo vira se a pessoa está muito de lado, acena ao
## chegar, gestos de vez em quando e Idle fora de sincronia com os outros NPCs. Só visual, em
## cada máquina (cada tela vê o NPC olhar para o próprio jogador).
const LOOK_RANGE := 6.0
const GREET_RANGE := 4.0
const TURN_SPEED := 3.0
## Ângulo entre a frente do corpo e a pessoa a partir do qual o corpo vira (o resto é a cabeça).
const TURN_START := deg_to_rad(55.0)
var _pivot: Node3D
var _animator: CharacterAnimator
var _anim_player: AnimationPlayer
var _look: LookAtModifier3D
var _look_target: Marker3D
var _home_yaw := PI
var _yaw_goal := PI
var _away_time := 0.0
var _greet_cooldown := 0.0
var _fidget_timer := 0.0
var _gesture := false
var _was_near := false


## NPC mais perto de `position` dentro do alcance de conversa (de um serviço, ou qualquer um com -1).
static func nearest(tree: SceneTree, position: Vector3, wanted_service := -1, reach := TALK_RANGE) -> WorldNpc:
	var best: WorldNpc = null
	var best_distance := reach
	for npc: WorldNpc in tree.get_nodes_in_group("npcs"):
		if wanted_service != -1 and npc.service != wanted_service:
			continue
		var offset := npc.global_position - position
		var distance := Vector2(offset.x, offset.z).length()
		if distance <= best_distance:
			best = npc
			best_distance = distance
	return best


func shop_key() -> String:
	return shop_id if shop_id else npc_name


## Estoque do comerciante: o que está no NPC (Inspector) mais o que as fichas de item dizem
## que esta loja vende.
func stock() -> PackedStringArray:
	var result := PackedStringArray()
	for id in shop_items:
		if ItemDB.has(id) and not result.has(id):
			result.append(id)
	if not shop_key().is_empty():
		for id in ItemDB.sold_by(shop_key()):
			if not result.has(id):
				result.append(id)
	return result


## Item `index` do estoque do comerciante (novo a cada compra).
func shop_item(index: int) -> Dictionary:
	var items := stock()
	if index < 0 or index >= items.size():
		return {}
	return ItemDB.make(items[index], shop_power)


func _ready() -> void:
	add_to_group("npcs")
	if model:
		var body := model.instantiate()
		_pivot = Node3D.new()
		_pivot.rotation.y = PI  # modelos olham para +Z; a frente do jogo é -Z
		add_child(_pivot)
		_pivot.add_child(body)
		ItemVisuals.hide_model_weapons(body)
		_animator = CharacterAnimator.new(body, AnimSets.HUMANOID)
		_anim_player = body.find_child("AnimationPlayer", true, false)
		_idle(true)
		_setup_look(body)
		_fidget_timer = randf_range(5.0, 14.0)
	_title = "%s\n%s" % [npc_name, Txt.t(SERVICE_NAMES[service])] if npc_name else Txt.t(SERVICE_NAMES[service])
	_label = WorldText.make(_title, 20, Color(0.75, 1.0, 0.75))
	_label.position.y = 2.5
	add_child(_label)


## Mostra o aviso de conversa quando um jogador desta tela está perto.
func _process(delta: float) -> void:
	var near := false
	var closest: Node3D = null
	var closest_distance := LOOK_RANGE
	for player: Node3D in get_tree().get_nodes_in_group("players"):
		if player.is_local():
			var offset := player.global_position - global_position
			var distance := Vector2(offset.x, offset.z).length()
			if distance <= TALK_RANGE:
				near = true
			if distance < closest_distance:
				closest = player
				closest_distance = distance
	_live(delta, closest, closest_distance)
	_label.text = _title + (InputService.pickup_text(Txt.t("\n[LB / F] falar")) if near else "")
	# Puxa assunto sozinho quando o grupo chega perto depois de descobrir algo (uma vez).
	if near:
		var line: DialogueLine = Lore.approach_line(npc_name)
		if line:
			Lore.mark_said(line)
			say(line.text)


## Balão de fala acima da cabeça por uns segundos (só nesta tela).
func say(text: String) -> void:
	var bubble := WorldText.make("“%s”" % Txt.t(text), 17, Color(1.0, 0.95, 0.8), true)
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.width = 900.0
	bubble.position.y = 3.2
	add_child(bubble)
	var tween := bubble.create_tween()
	tween.tween_interval(6.0)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.8)
	tween.tween_callback(bubble.queue_free)


## Idle com ponto de partida e ritmo sorteados (os NPCs não respiram todos juntos).
func _idle(random_start := false) -> void:
	if _animator == null or not _animator.play("idle", 0.0, false, 0.35):
		return
	_gesture = false
	if random_start and _anim_player and _anim_player.current_animation_length > 0.0:
		_anim_player.seek(randf() * _anim_player.current_animation_length, true)
	if _anim_player:
		_anim_player.speed_scale = randf_range(0.85, 1.1)


## Cabeça olhando para um alvo (LookAtModifier3D no osso da cabeça), com limite e transição suave.
func _setup_look(body: Node) -> void:
	var skeletons := body.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton: Skeleton3D = skeletons[0]
	var head := skeleton.find_bone("Head")
	if head == -1:
		return
	_look_target = Marker3D.new()
	add_child(_look_target)
	_look_target.position = Vector3(0, 1.6, -3.0)
	_look = LookAtModifier3D.new()
	_look.bone = head
	# Eixos do osso: o que aponta para a frente do modelo (+Z) e o que aponta para cima (gira o "não").
	var basis := skeleton.get_bone_global_rest(head).basis.orthonormalized()
	_look.forward_axis = _closest_bone_axis(basis, Vector3.BACK)
	_look.primary_rotation_axis = _closest_axis(basis, Vector3.UP)
	_look.use_angle_limitation = true
	_look.symmetry_limitation = true
	_look.primary_limit_angle = deg_to_rad(70.0)
	_look.primary_damp_threshold = 0.8
	_look.secondary_limit_angle = deg_to_rad(25.0)
	_look.secondary_damp_threshold = 0.8
	_look.duration = 0.45
	_look.transition_type = Tween.TRANS_SINE
	_look.ease_type = Tween.EASE_IN_OUT
	skeleton.add_child(_look)
	_look.target_node = _look.get_path_to(_look_target)


static func _closest_bone_axis(basis: Basis, wanted: Vector3) -> SkeletonModifier3D.BoneAxis:
	var best := SkeletonModifier3D.BONE_AXIS_PLUS_Z
	var best_dot := -2.0
	var axes := [[basis.x, SkeletonModifier3D.BONE_AXIS_PLUS_X], [-basis.x, SkeletonModifier3D.BONE_AXIS_MINUS_X],
			[basis.y, SkeletonModifier3D.BONE_AXIS_PLUS_Y], [-basis.y, SkeletonModifier3D.BONE_AXIS_MINUS_Y],
			[basis.z, SkeletonModifier3D.BONE_AXIS_PLUS_Z], [-basis.z, SkeletonModifier3D.BONE_AXIS_MINUS_Z]]
	for axis: Array in axes:
		var dot := (axis[0] as Vector3).dot(wanted)
		if dot > best_dot:
			best_dot = dot
			best = axis[1]
	return best


static func _closest_axis(basis: Basis, wanted: Vector3) -> Vector3.Axis:
	var dots := [absf(basis.x.dot(wanted)), absf(basis.y.dot(wanted)), absf(basis.z.dot(wanted))]
	return Vector3.AXIS_X if dots[0] >= dots[1] and dots[0] >= dots[2] else (Vector3.AXIS_Y if dots[1] >= dots[2] else Vector3.AXIS_Z)


## Olhar, virar, acenar e gestos.
func _live(delta: float, player: Node3D, distance: float) -> void:
	if _pivot == null:
		return
	_greet_cooldown = maxf(_greet_cooldown - delta, 0.0)
	if player:
		_away_time = 0.0
		var local := to_local(player.global_position)
		# Cabeça: na altura dos olhos de quem chegou.
		if _look_target:
			_look_target.position = local + Vector3.UP * 1.55
		var wanted := atan2(local.x, local.z)
		if absf(wrapf(wanted - _pivot.rotation.y, -PI, PI)) > TURN_START or distance <= TALK_RANGE:
			_yaw_goal = wanted
		if not _was_near and distance <= GREET_RANGE and _greet_cooldown == 0.0 and not _gesture:
			_greet_cooldown = 25.0
			_play_gesture("wave", 1.6)
	else:
		_away_time += delta
		if _away_time > 3.0:
			_yaw_goal = _home_yaw
			if _look_target:
				_look_target.position = _look_target.position.lerp(Vector3(sin(_home_yaw), 1.6, cos(_home_yaw)) * Vector3(3, 1, 3), minf(delta * 2.0, 1.0))
		_fidget_timer -= delta
		if _fidget_timer <= 0.0 and not _gesture:
			_fidget_timer = randf_range(8.0, 18.0)
			_play_gesture("fidget" if randf() < 0.6 else "idle_alt", 2.4)
	_was_near = player != null and distance <= GREET_RANGE
	_pivot.rotation.y = rotate_toward(_pivot.rotation.y, _yaw_goal, TURN_SPEED * delta)
	if _gesture and _animator and not _animator.is_playing(_animator.current):
		_idle()


func _play_gesture(action: String, duration: float) -> void:
	if _animator and _animator.has(action) and _animator.play(action, duration, true, 0.3):
		_gesture = true
		if _anim_player:
			_anim_player.speed_scale = 1.0
