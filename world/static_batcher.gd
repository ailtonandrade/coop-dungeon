class_name StaticBatcher
extends RefCounted
## Junta a decoração parada de um bloco em poucas malhas, para desenhar em poucas chamadas.
##
## O mapa tem centenas de pecinhas (caixotes, mesas de bar, letreiros, paredes e enfeites feitos
## de caixas), cada uma com o próprio material: cada uma é uma chamada de desenho, e é isso que
## mais pesa nos gráficos integrados (Intel HD). Ao carregar o bloco, as malhas paradas que usam
## o mesmo material (mesmo visual, mesmo se forem cópias) viram UMA malha por pedaço de
## CELL metros; as originais ficam invisíveis (a colisão delas continua valendo).
##
## Fica de fora o que muda ou se mexe: peças com comportamento próprio (portas, baús, NPCs,
## criaturas, loot, peças físicas), o que some com a câmera (FadeOccluder: telhado, paredes
## da frente), personagens com esqueleto, transparências e o que as missões fazem sumir/aparecer.
## No editor de mapa do dono (/editar) tudo volta ao normal (unbatch) para mexer nas peças.

const CELL := 32.0
const META := "static_batch"
## Scripts cujas partes paradas podem ser juntadas: só as que não brilham (o letreiro muda o
## brilho dos tubos com a hora e pisca; a moldura e a placa ficam iguais).
const STATIC_SCRIPTS := ["neon_sign.gd"]


## Junta o bloco `chunk` (já na árvore). Retorna quantas malhas viraram quantas.
static func batch(chunk: Node3D, skip_names := {}) -> Vector2i:
	if chunk.has_meta(META):
		return Vector2i.ZERO
	var groups := {}  # chave -> {material, tool, cast}
	var hidden: Array[MeshInstance3D] = []
	var to_chunk := chunk.global_transform.affine_inverse()
	for mesh: MeshInstance3D in chunk.find_children("*", "MeshInstance3D", true, false):
		if not _can_batch(mesh, chunk, skip_names) or _glows(mesh):
			continue
		var xform := to_chunk * mesh.global_transform
		var center := xform * mesh.get_aabb().get_center()
		var cell := Vector2i(floori(center.x / CELL), floori(center.z / CELL))
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			if material == null or not _opaque(material):
				continue
			var key := "%s|%s|%d|%d" % [cell, _material_key(material), mesh.cast_shadow, mesh.layers]
			if not groups.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"material": material, "tool": tool, "cast": mesh.cast_shadow, "layers": mesh.layers, "count": 0}
			var group: Dictionary = groups[key]
			(group.tool as SurfaceTool).append_from(mesh.mesh, surface, xform)
			group.count = int(group.count) + 1
		hidden.append(mesh)
	if hidden.is_empty():
		chunk.set_meta(META, [])
		return Vector2i.ZERO
	var made: Array[MeshInstance3D] = []
	for key: String in groups:
		var group: Dictionary = groups[key]
		var merged := MeshInstance3D.new()
		merged.name = "Lote_%d" % made.size()
		merged.mesh = (group.tool as SurfaceTool).commit()
		merged.material_override = group.material
		merged.cast_shadow = group.cast
		merged.layers = group.layers
		chunk.add_child(merged)
		made.append(merged)
	for mesh in hidden:
		mesh.visible = false
	chunk.set_meta(META, [hidden, made])
	return Vector2i(hidden.size(), made.size())


## Desfaz (editor de mapa): mostra as originais e apaga as juntadas.
static func unbatch(chunk: Node) -> void:
	if not chunk.has_meta(META):
		return
	var data: Array = chunk.get_meta(META)
	chunk.remove_meta(META)
	if data.size() < 2:
		return
	for mesh: Variant in data[0]:
		if is_instance_valid(mesh):
			(mesh as MeshInstance3D).visible = true
	for merged: Variant in data[1]:
		if is_instance_valid(merged):
			(merged as Node).queue_free()


static func _can_batch(mesh: MeshInstance3D, chunk: Node, skip_names: Dictionary) -> bool:
	if mesh.mesh == null or not mesh.is_visible_in_tree() or mesh.skin != null or mesh.get_parent() is Skeleton3D:
		return false
	var node: Node = mesh
	while node and node != chunk:
		if skip_names.has(String(node.name)):
			return false
		if node is FadeOccluder or node is RigidBody3D or node is CharacterBody3D or node is Area3D \
				or node is AnimationPlayer or node is BoneAttachment3D or node is GPUParticles3D:
			return false
		# Modelo importado com animação (ventilador, placa balançando): fica de fora.
		if not node.scene_file_path.is_empty() and node != chunk and _animated(node):
			return false
		var script := node.get_script() as Script
		if script and node != mesh:
			var file := script.resource_path.get_file()
			if not STATIC_SCRIPTS.has(file):
				return false
		elif script and node == mesh:
			return false
		node = node.get_parent()
	return true


static func _animated(instance: Node) -> bool:
	if instance.has_meta("batch_animated"):
		return instance.get_meta("batch_animated")
	var animated := not instance.find_children("*", "AnimationPlayer", true, false).is_empty()
	instance.set_meta("batch_animated", animated)
	return animated


## Peça que brilha (emissão): o brilho pode mudar (letreiro), fica de fora.
static func _glows(mesh: MeshInstance3D) -> bool:
	for surface in mesh.mesh.get_surface_count():
		var material := mesh.get_active_material(surface)
		if material is BaseMaterial3D and (material as BaseMaterial3D).emission_enabled:
			return true
	return false


static func _opaque(material: Material) -> bool:
	if material is BaseMaterial3D:
		var base := material as BaseMaterial3D
		return base.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and base.next_pass == null
	return material is ShaderMaterial and (material as ShaderMaterial).next_pass == null


## Materiais iguais por dentro (cópias feitas por código) contam como o mesmo.
static func _material_key(material: Material) -> String:
	if material is StandardMaterial3D:
		var m := material as StandardMaterial3D
		return "std:%s:%s:%s:%s:%s:%.2f:%.2f:%s:%s:%s:%s:%s:%s" % [
			m.albedo_color.to_html(), m.albedo_texture.get_rid() if m.albedo_texture else "",
			m.emission_enabled, m.emission.to_html() if m.emission_enabled else "", m.emission_energy_multiplier if m.emission_enabled else 0.0,
			m.metallic, m.roughness, m.shading_mode, m.uv1_triplanar, m.uv1_world_triplanar, m.uv1_scale, m.cull_mode,
			m.vertex_color_use_as_albedo]
	return "rid:%s" % material.get_rid()
