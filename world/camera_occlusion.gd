class_name CameraOcclusion
extends Node
## Decide a cada quadro o que deve sumir para os jogadores desta tela não ficarem escondidos:
## com alguém dentro da casa, o telhado some e as paredes da frente ficam translúcidas; o que
## estiver entre a câmera e um jogador fica transparente. Fica como filho da câmera.

## Quantas coisas o raio atravessa procurando o que tapa (paredes em sequência, árvore + telhado).
const MAX_HITS := 4

@onready var _camera: Camera3D = get_parent()


func _process(_delta: float) -> void:
	var local_players: Array[Player] = []
	for player: Player in get_tree().get_nodes_in_group("players"):
		if player.is_local():
			local_players.append(player)

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
