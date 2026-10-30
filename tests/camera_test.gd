extends SceneTree
## Teste da câmera atrás do herói (estilo GTA): liga com 1 jogador na tela, andar vai para a
## frente da câmera (e muda quando ela gira), atacar mira para a frente dela, e com o 2º
## jogador no sofá volta sozinha para a câmera de cima.
## Rodar: godot --headless --fixed-fps 60 --path coop-dungeon -s tests/camera_test.gd
## Atenção: cada passo é um quadro; dois passos no mesmo quadro fazem só o primeiro rodar.

const SECOND := 60

var _frames := 0
var _failed := false
var _start := Vector3.ZERO


func _process(_delta: float) -> bool:
	_frames += 1
	match _frames:
		1:
			root.get_node("SaveService").use_test_storage("test_saves_camera")
			root.get_node("Settings").camera_mode = "behind"
			change_scene_to_file("res://world/world.tscn")
		SECOND:
			_p1().teleport_to(Vector3(33, 0, 47))
		SECOND + 5:
			_check(_camera().is_behind(), "1 jogador na tela: câmera atrás do herói")
			_check(_camera().fov > 50.0, "campo de visão aberto (%.0f°)" % _camera().fov)
			_start = _p1().global_position
			_key(KEY_W, true)
		SECOND + 45:
			_key(KEY_W, false)
			var moved := (_p1().global_position - _start) * Vector3(1, 0, 1)
			var forward: Vector3 = root.get_node("InputService").view_forward
			_check(moved.length() > 2.0 and moved.normalized().dot(forward) > 0.95, "W anda para a frente da câmera (%.2f)" % moved.normalized().dot(forward))
			# Gira a câmera 90° para a esquerda: W passa a andar para a esquerda do que era.
			_camera()._turn(PI / 2.0, 0.0)
		SECOND + 50:
			_start = _p1().global_position
			_key(KEY_W, true)
		SECOND + 90:
			_key(KEY_W, false)
			var moved := ((_p1().global_position - _start) * Vector3(1, 0, 1)).normalized()
			var forward: Vector3 = root.get_node("InputService").view_forward
			_check(moved.dot(forward) > 0.95 and absf(moved.dot(Vector3(0, 0, -1))) < 0.2, "câmera girada: W segue a nova frente (%s)" % moved)
			# Atacar: mira para a frente da câmera.
			_key(KEY_J, true)
		SECOND + 92:
			var aim: Vector2 = root.get_node("InputService").get_aim(_p1().slot)
			var forward: Vector3 = root.get_node("InputService").view_forward
			_check(aim.dot(Vector2(forward.x, forward.z)) > 0.99, "atacando, a mira é a frente da câmera")
			_key(KEY_J, false)
		SECOND + 100:
			_check(root.get_node("InputService").get_aim(_p1().slot) == Vector2.ZERO, "sem atacar, o herói olha para onde anda")
			root.get_node("InputService")._try_join(0)
		SECOND + 130:
			_check(get_nodes_in_group("players").size() == 2, "entrou o 2º jogador no sofá")
			_check(not _camera().is_behind(), "com 2 na tela volta para a câmera de cima")
			_check(is_equal_approx(root.get_node("InputService").view_yaw_deg, 45.0), "andar volta a ser pela câmera de cima")
			root.get_node("Settings").camera_mode = "iso"
			print("CÂMERA: ", "FALHOU" if _failed else "OK")
			quit(1 if _failed else 0)
	return false


func _camera() -> Node:
	return get_first_node_in_group("shared_camera")


func _p1() -> Node3D:
	for p in get_nodes_in_group("players"):
		if p.index == 0:
			return p
	return null


func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)


func _check(ok: bool, text: String) -> void:
	print("  ", "ok  " if ok else "FALHOU", " ", text)
	if not ok:
		_failed = true
