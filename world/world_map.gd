@tool
class_name WorldMap
extends Resource
## O mapa do mundo: quais blocos existem, a região de cada um, os interiores (masmorras)
## e onde o grupo começa. O mapa é um só e desenhado à mão: cada bloco é uma cena
## (.tscn) que se edita no editor do Godot.
##
## Coordenadas: o bloco (x, z) ocupa de (x, z) * chunk_size até o bloco seguinte.
## Interiores ficam longe do mapa de fora (em `origin`) e carregam do mesmo jeito.

@export var chunk_size := 64.0
## Vector2i(x, z) -> caminho da cena do bloco.
@export var chunks: Dictionary = {}
## Vector2i(x, z) -> id da região.
@export var chunk_regions: Dictionary = {}
@export var regions: Array[RegionDef] = []
## id -> {"path": cena, "origin": Vector3, "size": Vector3, "region": id da região}
@export var interiors: Dictionary = {}
@export var spawn_point := Vector3.ZERO


func chunk_at(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x / chunk_size), floori(position.z / chunk_size))


func chunk_origin(coords: Vector2i) -> Vector3:
	return Vector3(coords.x * chunk_size, 0.0, coords.y * chunk_size)


## Id do interior que contém `position`, ou "" se está no mapa de fora.
func interior_at(position: Vector3) -> String:
	for id: String in interiors:
		var info: Dictionary = interiors[id]
		if AABB(info.origin - Vector3(0, 50, 0), info.size + Vector3(0, 100, 0)).has_point(position):
			return id
	return ""


func region(id: String) -> RegionDef:
	for candidate in regions:
		if candidate.id == id:
			return candidate
	return null


func region_at(position: Vector3) -> RegionDef:
	var interior := interior_at(position)
	if interior:
		return region(interiors[interior].get("region", ""))
	return region(chunk_regions.get(chunk_at(position), ""))
