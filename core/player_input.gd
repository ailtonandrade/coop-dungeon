class_name PlayerInput
extends RefCounted
## Comandos de um jogador num quadro de física, vindos do controle local ou da rede.
## O Player só lê daqui, então joga igual sendo local ou remoto.
##
## Pela rede, cada ação manda um contador de apertos (e não só "apertou agora"):
## se um pacote se perde, o próximo ainda mostra o contador diferente e o aperto não some.

var move := Vector2.ZERO
## Mira no chão do mundo (x, z), comprimento 1, ou zero se não está mirando.
var aim := Vector2.ZERO

var _local_slot := -1
var _down := 0
var _edges := 0       # apertos recebidos e ainda não usados
var _tick_edges := 0  # apertos que valem neste quadro
var _counts := PackedByteArray()


static func local(slot: int) -> PlayerInput:
	var input := PlayerInput.new()
	input._local_slot = slot
	return input


## Chamado pelo Player no começo de cada quadro de física.
func begin_tick() -> void:
	if _local_slot >= 0:
		move = InputService.get_move(_local_slot)
		aim = InputService.get_aim(_local_slot)
		_down = InputService.get_down_mask(_local_slot)
		_edges |= InputService.get_pressed_mask(_local_slot)
	_tick_edges = _edges
	_edges = 0


## Guarda os apertos deste quadro para o próximo (ex.: durante o hit-stop).
func defer() -> void:
	_edges |= _tick_edges
	_tick_edges = 0


func apply_remote(p_move: Vector2, p_aim: Vector2, down: int, counts: PackedByteArray) -> void:
	move = p_move.limit_length(1.0)
	aim = p_aim.normalized() if p_aim.length_squared() > 0.01 else Vector2.ZERO
	_down = down
	if _counts.size() == counts.size():
		for i in counts.size():
			if counts[i] != _counts[i]:
				_edges |= 1 << i
	_counts = counts


func is_pressed(action: int) -> bool:
	return _down & (1 << action) != 0


func just_pressed(action: int) -> bool:
	return _tick_edges & (1 << action) != 0
