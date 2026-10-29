class_name FadeOccluder
extends Node3D
## Algo que pode tapar o herói na visão isométrica (telhado, paredes da frente, copa de árvore).
## - Com `zone` (casas): enquanto um jogador desta tela está dentro da zona, some de vez
##   (dá pra ver o herói dentro da casa).
## - Sempre: se fica entre a câmera e um jogador desta tela, fica transparente.
## Quem decide é o CameraOcclusion (da câmera); aqui só fica a transição suave.
## Para a câmera "ver" o que tapa, as peças precisam de colisão (ou na camada LAYER_OCCLUDER).
##
## A transparência vai pelo material (cópia própria de cada peça), o que funciona em todos
## os modos de renderização, inclusive o Compatibility de PCs mais fracos.

## Zona interna (coordenadas locais). Tamanho zero = sem zona.
@export var zone := AABB()
## Transparência quando está entre a câmera e o herói (0 = normal, 1 = invisível).
@export_range(0.0, 1.0) var see_through := 0.7

## Quanto deve sumir agora (o CameraOcclusion ajusta a cada quadro).
var target := 0.0

var _current := 0.0
var _meshes: Array[GeometryInstance3D] = []
var _materials: Array[BaseMaterial3D] = []


func _ready() -> void:
	add_to_group("fade_occluders")
	for node in find_children("*", "GeometryInstance3D", true, false):
		var mesh := node as GeometryInstance3D
		_meshes.append(mesh)
		if mesh.material_override is BaseMaterial3D:
			var material := (mesh.material_override as BaseMaterial3D).duplicate() as BaseMaterial3D
			mesh.material_override = material
			_materials.append(material)


func has_zone() -> bool:
	return zone.size != Vector3.ZERO


func zone_contains(world_position: Vector3) -> bool:
	return has_zone() and zone.has_point(global_transform.affine_inverse() * world_position)


func _process(delta: float) -> void:
	if is_equal_approx(_current, target):
		return
	_current = move_toward(_current, target, delta * 4.0)
	var faded := _current > 0.001
	for material in _materials:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if faded else BaseMaterial3D.TRANSPARENCY_DISABLED
		material.albedo_color.a = 1.0 - _current
	for mesh in _meshes:
		mesh.visible = _current < 0.99
		if mesh.material_override not in _materials:
			mesh.transparency = _current
