extends SceneTree
## Fichas de peças (PropDef/PropBuilder): cada tipo vira a peça certa, e a física cai e para.
## Rodar: godot --headless --fixed-fps 60 --path coop-dungeon -s tests/props_test.gd
## Sem tipos do jogo aqui: o script de teste compila antes dos serviços globais existirem.

const SECOND := 60

var _frames := 0
var _failed := false
var _world: Node3D
var _cone: RigidBody3D


func _initialize() -> void:
	var builder: Script = load("res://props/prop_builder.gd")
	_check(builder.id_from("Caixa d'água 2") == "caixa_dagua_2", "id da peça a partir do nome (%s)" % builder.id_from("Caixa d'água 2"))
	var catalog: Array = builder.catalog()
	var cone_entry: Array = catalog.filter(func(e: Dictionary) -> bool: return e.path.ends_with("/cone.tscn"))
	_check(cone_entry.size() == 1 and cone_entry[0].kind == "fisico", "cone está na lista como físico")
	_check(catalog.any(func(e: Dictionary) -> bool: return e.path.ends_with("/casa_pequena.tscn") and e.def == null), "peças montadas à mão continuam na lista (sem ficha)")

	var def: Resource = load("res://props/prop_def.gd").new()
	def.id = "teste_barril"
	def.display_name = "Barril de teste"
	def.model = load("res://assets/props/Barrel.glb")
	for kind in ["fixo", "conteiner", "fisico", "atravessavel"]:
		def.kind = kind
		var node: Node3D = builder.build(def)
		match kind:
			"fixo":
				_check(node is StaticBody3D and node.get_node_or_null("Collision") != null, "fixo: corpo sólido com colisão")
			"conteiner":
				_check(node.get_script() == load("res://world/loot_container.gd") and node.random_items == def.random_items, "contêiner: vira baú (LootContainer)")
			"fisico":
				_check(node is RigidBody3D and node.mass == def.mass and node.get_node_or_null("Collision") != null, "físico: corpo rígido com peso e colisão")
			"atravessavel":
				_check(not (node is CollisionObject3D) and node.find_children("*", "CollisionShape3D", true, false).is_empty(), "atravessável: sem colisão nenhuma")
		var model := node.get_node_or_null("Modelo") as Node3D
		if model:
			var box: AABB = builder._bounds(model)
			_check(absf(box.position.y + model.position.y) < 0.02, "%s: base do modelo no chão" % kind)
		node.free()


func _process(_delta: float) -> bool:
	_frames += 1
	match _frames:
		1:
			_world = Node3D.new()
			root.add_child(_world)
			var ground := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(40, 1, 40)
			shape.shape = box
			ground.add_child(shape)
			ground.position.y = -0.5
			_world.add_child(ground)
			# Cone solto a 2 m de altura e já tombando: cai, rola e para.
			_cone = (load("res://world/prefabs/cone.tscn") as PackedScene).instantiate()
			_world.add_child(_cone)
			_cone.global_position = Vector3(0, 2.0, 0)
			_cone.rotation.z = 0.6
			_cone.angular_velocity = Vector3(0, 0, 3)
		6 * SECOND:
			_check(_cone.global_position.y < 0.6, "cone solto do alto caiu até o chão (y %.2f)" % _cone.global_position.y)
			_check(_cone.sleeping or _cone.linear_velocity.length() < 0.05, "e parou (%.3f m/s)" % _cone.linear_velocity.length())
			print("PEÇAS: " + ("FALHOU" if _failed else "OK"))
			quit(1 if _failed else 0)
	return false


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	_failed = _failed or not ok
