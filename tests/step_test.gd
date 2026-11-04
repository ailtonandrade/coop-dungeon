extends SceneTree
## Degrau: andando contra um piso baixo (laje, calçada) o herói sobe nele; parede alta continua
## barrando. Rodar: godot --headless --fixed-fps 60 --path coop-dungeon -s tests/step_test.gd

const SECOND := 60

var _frames := 0
var _failed := false
var _start := Vector3.ZERO
var _max_y := 0.0
var _fell_on_step := false
var _left_slab := false
var _air_anims := {}


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > SECOND + 10 and _frames < SECOND + 130 and not get_nodes_in_group("players").is_empty():
		_max_y = maxf(_max_y, _player().global_position.y)
		# Depois de subir, continua andando e desce do piso: isso não é queda.
		var y: float = _player().global_position.y
		if _max_y > 0.18 and y < 0.05:
			_left_slab = true
		if _max_y > 0.18 and _player()._animator.current == "fall":
			_fell_on_step = true
	if _frames > SECOND + 205 and _frames < SECOND + 260:
		_air_anims[_player()._animator.current] = true
	match _frames:
		1:
			root.get_node("SaveService").use_test_storage("test_saves_step")
			Engine.set_meta("auto_pick_character", true)
			root.get_node("Settings").camera_mode = "iso"
			root.get_node("NetService").world = {"id": "teste_step", "name": "Teste"}
			change_scene_to_file("res://world/world.tscn")
		10:
			root.get_node("InputService")._try_join(-1)
		SECOND:
			_player().teleport_to(Vector3(60, 0, 20))
		SECOND + 10:
			var forward: Vector3 = root.get_node("InputService").view_forward
			# Piso de 22 cm (como o Floor 4x4 carimbado) e chegando meio de lado: a quina bate na
			# parte redonda da cápsula.
			_slab(_player().global_position + forward * 2.5, 0.22, forward.rotated(Vector3.UP, deg_to_rad(40)))
			_slab(_player().global_position + forward * 2.5 + Vector3(60, 0, 20) + forward.cross(Vector3.UP) * 8.0, 1.2, forward)
			_key(KEY_W, true)
		SECOND + 130:
			_key(KEY_W, false)
			_check(_max_y > 0.18, "subiu no piso de 22 cm (de lado) andando (y %.2f)" % _max_y)
			_check(_left_slab and not _fell_on_step, "desceu do piso andando, sem pose de queda")
			# Parede alta (1,2 m) ao lado: não sobe sozinho.
			var forward: Vector3 = root.get_node("InputService").view_forward
			_player().teleport_to(Vector3(60, 0, 20) + forward.cross(Vector3.UP) * 8.0)
		SECOND + 140:
			_key(KEY_W, true)
		SECOND + 200:
			_key(KEY_W, false)
			_check(_player().global_position.y < 0.6, "parede alta continua barrando (y %.2f)" % _player().global_position.y)
		SECOND + 204:
			_key(KEY_SPACE, true)
		SECOND + 208:
			_key(KEY_SPACE, false)
		SECOND + 262:
			_check(_air_anims.has("jump") and _air_anims.has("fall"), "pulo mostra pulo e depois queda (%s)" % ", ".join(_air_anims.keys()))
			print("DEGRAU: " + ("FALHOU" if _failed else "OK"))
			quit(1 if _failed else 0)
	return false


func _slab(center: Vector3, height: float, forward: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, height, 4)
	shape.shape = box
	body.add_child(shape)
	current_scene.add_child(body)
	body.global_position = Vector3(center.x, height / 2.0, center.z) + forward * 1.5
	body.global_basis = Basis.looking_at(forward)


func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)


func _player() -> Node:
	return get_nodes_in_group("players")[0]


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FALHOU ") + what)
	if not ok:
		_failed = true
