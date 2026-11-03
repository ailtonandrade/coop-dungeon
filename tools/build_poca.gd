extends SceneTree
## Gera o material compartilhado das poças e a peça world/prefabs/poca_dagua.tscn.
## godot --headless --path . -s tools/build_poca.gd

func _initialize() -> void:
	var shape := NoiseTexture2D.new()
	shape.width = 256
	shape.height = 256
	shape.seamless = true
	shape.generate_mipmaps = true
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	shape.noise = noise
	var ripple := NoiseTexture2D.new()
	ripple.width = 256
	ripple.height = 256
	ripple.seamless = true
	ripple.as_normal_map = true
	ripple.bump_strength = 6.0
	var ripple_noise := FastNoiseLite.new()
	ripple_noise.frequency = 0.06
	ripple.noise = ripple_noise
	var material := ShaderMaterial.new()
	material.shader = load("res://world/water/poca.gdshader")
	material.set_shader_parameter("shape_noise", shape)
	material.set_shader_parameter("ripple_noise", ripple)
	ResourceSaver.save(material, "res://world/water/poca_material.tres")

	var root := Node3D.new()
	root.name = "PocaDagua"
	root.set_script(load("res://world/water/poca.gd"))
	var water := MeshInstance3D.new()
	water.name = "Agua"
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.6, 1.8)
	water.mesh = plane
	water.material_override = load("res://world/water/poca_material.tres")
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Um dedo acima do chão (sem piscar com ele).
	water.position.y = 0.015
	root.add_child(water)
	water.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://world/prefabs/poca_dagua.tscn")
	print("poça pronta")
	quit()
