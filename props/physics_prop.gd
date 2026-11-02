class_name PhysicsProp
extends RigidBody3D
## Peça física do cenário (ficha "Físico"): cai, rola e os heróis empurram. Quem simula é o
## host; nos convidados ela fica parada (cinemática) e só segue o que o host manda, enquanto
## estiver se mexendo.

## Quanto tempo entre um envio e outro da posição para os convidados.
const SYNC_INTERVAL := 0.1

var _sync_left := 0.0
var _target := Transform3D()
var _has_target := false


func _ready() -> void:
	add_to_group("physics_props")
	collision_layer = GameConfig.LAYER_WORLD
	collision_mask = GameConfig.LAYER_SOLID | GameConfig.LAYER_PLAYERS | GameConfig.LAYER_ENEMIES
	if not multiplayer.is_server():
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		if _has_target:
			global_transform = global_transform.interpolate_with(_target, minf(delta * 12.0, 1.0))
		return
	# Pelo caminho (e não pelo nome NetService): esta classe também é usada pelo editor de mapa,
	# onde os serviços do jogo não existem.
	var net := get_node_or_null("/root/NetService")
	if sleeping or net == null or not net.is_online():
		return
	_sync_left -= delta
	if _sync_left <= 0.0:
		_sync_left = SYNC_INTERVAL
		net.queue_prop_state(self)


## Convidado: posição que veio do host.
func apply_remote(xform: Transform3D) -> void:
	if not _has_target:
		global_transform = xform
	_target = xform
	_has_target = true
