class_name MapIntegrity
extends RefCounted
## Impressão digital do mapa: um resumo (hash) do conteúdo de verdade do WorldMap e de todas
## as cenas de blocos e interiores, como o jogo as carregou. Qualquer mudança (peça movida,
## parede pintada, criatura trocada, bloco a mais) muda a impressão digital.
##
## Uso: ao entrar num mundo online, o convidado manda a dele e o host recusa se for diferente.
## Assim ninguém joga online com mapa alterado (de propósito ou por versões diferentes).
## O mapa só muda pelas mãos do dono do jogo, no editor, e chega a todos numa atualização.

## Profundidade máxima ao descer em sub-recursos (formas de colisão, materiais, navegação).
const MAX_DEPTH := 4


static func fingerprint(map: WorldMap) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	_feed(ctx, "mapa:%s|%s|%s|%s" % [map.chunk_size, _text(map.chunk_regions, 0), _text(map.interiors, 0), map.spawn_point])
	for region in map.regions:
		_feed(ctx, _text(region, 0))
	var scenes := {}
	for coords: Vector2i in map.chunks:
		scenes["%s=%s" % [coords, map.chunks[coords]]] = map.chunks[coords]
	for id: String in map.interiors:
		scenes["i:%s=%s" % [id, map.interiors[id].path]] = map.interiors[id].path
	var keys := scenes.keys()
	keys.sort()
	for key: String in keys:
		_feed(ctx, key)
		var scene := load(scenes[key]) as PackedScene
		_feed(ctx, _scene_text(scene) if scene else "faltando")
	return ctx.finish().hex_encode()


static func _scene_text(scene: PackedScene) -> String:
	var state := scene.get_state()
	var parts := PackedStringArray()
	for i in state.get_node_count():
		parts.append("%s|%s|%s" % [state.get_node_path(i), state.get_node_type(i), _text(state.get_node_instance(i), 0)])
		for p in state.get_node_property_count(i):
			parts.append("%s=%s" % [state.get_node_property_name(i, p), _text(state.get_node_property_value(i, p), 0)])
	return "\n".join(parts)


## Texto estável de um valor (sem endereços de memória, que mudam a cada execução).
static func _text(value: Variant, depth: int) -> String:
	if value is Resource:
		var resource: Resource = value
		if resource.resource_path and not resource.resource_path.contains("::"):
			# Recurso externo: conta pelo caminho. Peças prontas do mapa (world/) entram pelo
			# conteúdo, porque mexer nelas muda o mapa; modelos de assets/ só pelo caminho.
			if resource is PackedScene and resource.resource_path.begins_with("res://world/") and depth < MAX_DEPTH:
				return "cena(%s){%s}" % [resource.resource_path, _scene_text(resource).sha256_text()]
			return "ext(%s)" % resource.resource_path
		if depth >= MAX_DEPTH:
			return resource.get_class()
		var fields := PackedStringArray([resource.get_class()])
		for property in resource.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE and property.name != "resource_name":
				fields.append("%s=%s" % [property.name, _text(resource.get(property.name), depth + 1)])
		return "{%s}" % ",".join(fields)
	if value is Array:
		var items := PackedStringArray()
		for item in value:
			items.append(_text(item, depth + 1))
		return "[%s]" % ",".join(items)
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		var items := PackedStringArray()
		for key in keys:
			items.append("%s:%s" % [str(key), _text(value[key], depth + 1)])
		return "{%s}" % ",".join(items)
	if value is Object:
		return value.get_class()
	return var_to_str(value)


static func _feed(ctx: HashingContext, text: String) -> void:
	ctx.update(text.to_utf8_buffer())
