class_name Entrance
extends Marker3D
## Entrada (porta de masmorra, escada, buraco) que leva para outro ponto do mundo.
## Como a tela é uma só, quem joga na mesma tela entra junto: basta um deles ficar na
## entrada por ENTER_TIME. Jogadores online de outras máquinas não são levados.
## Roda no host; o destino é carregado na hora antes do teleporte.

const ENTER_TIME := 1.2

@export var title := "Entrada"
## Para onde leva (posição no mundo; interiores ficam longe do mapa de fora).
@export var target_point := Vector3.ZERO
@export var radius := 1.8

var _progress := {}  # máquina (peer) -> segundos na entrada
var _label: Label3D


func _ready() -> void:
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 34
	_label.outline_size = 10
	_label.modulate = Color(1.0, 0.85, 0.5)
	_label.layers = 2
	_label.position.y = 3.0
	add_child(_label)
	_label.text = title

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.12
	torus.outer_radius = radius
	ring.mesh = torus
	ring.scale = Vector3(1, 0.15, 1)
	ring.position.y = 0.04
	ring.material_override = Combat.overlay_material(Color(1.0, 0.85, 0.4, 0.6))
	add_child(ring)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var standing := {}
	for player: Player in get_tree().get_nodes_in_group("players"):
		if player.is_targetable() and Combat.flat(player.global_position - global_position).length() <= radius:
			standing[player.owner_peer] = true
	for peer: int in _progress.keys():
		if not standing.has(peer):
			_progress.erase(peer)
	for peer: int in standing:
		_progress[peer] = _progress.get(peer, 0.0) + delta
		if _progress[peer] >= ENTER_TIME:
			_progress.erase(peer)
			_send_through(peer)


func _send_through(peer: int) -> void:
	var streamer := WorldStreamer.of(self)
	if streamer:
		streamer.load_now(target_point)
	var index := 0
	for player: Player in get_tree().get_nodes_in_group("players"):
		if player.owner_peer == peer:
			player.teleport_to(target_point + Vector3.RIGHT.rotated(Vector3.UP, TAU * index / 4.0) * 1.2)
			index += 1
