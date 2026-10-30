class_name CameraOcclusion
extends Node
## Decide a cada quadro o que deve sumir para os jogadores desta tela não ficarem escondidos:
## com alguém dentro da casa, o telhado some e as paredes da frente ficam translúcidas; o que
## estiver entre a câmera e um jogador fica transparente. Fica como filho da câmera.
## Paredes pintadas na grade (peças da biblioteca) usam outro jeito: o material delas abre um
## buraco em volta de cada jogador; aqui só passamos onde os jogadores estão na tela.

## Quantas coisas o raio atravessa procurando o que tapa (paredes em sequência, árvore + telhado).
const MAX_HITS := 4
const TILES_DIR := "res://world/tiles"

var _wall_materials: Array[ShaderMaterial] = []

@onready var _camera: Camera3D = get_parent()


func _ready() -> void:
	for file in ResourceLoader.list_directory(TILES_DIR):
		if file.begins_with("wall_") and file.ends_with(".tres"):
			var material := load(TILES_DIR.path_join(file)) as ShaderMaterial
			if material:
				_wall_materials.append(material)


func _process(_delta: float) -> void:
	var local_players: Array[Player] = []
	for player: Player in get_tree().get_nodes_in_group("players"):
		if player.is_local():
			local_players.append(player)

	_update_wall_cutout(local_players)
	var blocking := {}
	for player in local_players:
		for occluder in _occluders_between(_camera.global_position, player.global_position + Vector3.UP * 1.0):
			blocking[occluder] = true

	for occluder: FadeOccluder in get_tree().get_nodes_in_group("fade_occluders"):
		var inside := false
		if occluder.has_zone():
			for player in local_players:
				if occluder.zone_contains(player.global_position):
					inside = true
					break
		occluder.target = occluder.inside_fade if inside else (occluder.see_through if blocking.has(occluder) else 0.0)


## Passa para as paredes pintadas onde está cada jogador desta tela (tela 0..1 e distância).
func _update_wall_cutout(local_players: Array[Player]) -> void:
	if _wall_materials.is_empty():
		return
	var view := _camera.get_viewport().get_visible_rect().size
	var to_camera := _camera.global_transform.affine_inverse()
	var players: Array[Vector4] = []
	for i in 4:
		var data := Vector4.ZERO
		if i < local_players.size():
			var chest := local_players[i].global_position + Vector3.UP * 1.0
			var screen := _camera.unproject_position(chest) / view
			data = Vector4(screen.x, screen.y, -(to_camera * chest).z, 1.0)
		players.append(data)
	for material in _wall_materials:
		material.set_shader_parameter("occlusion_players", players)
		material.set_shader_parameter("aspect", view.x / view.y)


func _occluders_between(from: Vector3, to: Vector3) -> Array[FadeOccluder]:
	var found: Array[FadeOccluder] = []
	var space := _camera.get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	for i in MAX_HITS:
		var query := PhysicsRayQueryParameters3D.create(from, to, GameConfig.LAYER_WORLD | GameConfig.LAYER_OCCLUDER, exclude)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		exclude.append(hit.rid)
		var node: Node = hit.collider
		while node and not node is FadeOccluder:
			node = node.get_parent()
		if node:
			found.append(node)
	return found
