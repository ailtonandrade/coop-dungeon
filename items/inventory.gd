class_name Inventory
extends RefCounted
## Inventário de um herói, estilo Tibia: casas de equipamento e uma mochila equipada
## que pode ter bolsas dentro (que podem ter outras bolsas dentro).
##
## Endereço de uma casa (path), um Array simples que vai pela rede:
##   ["eq", "head"]       casa de equipamento
##   ["bag", 3]           4ª casa da mochila equipada
##   ["bag", 3, 0]        1ª casa da bolsa que está na 4ª casa da mochila
## Quem altera é o host; o dono recebe uma cópia a cada mudança (e salva na conta dele).

signal changed

var equipment := {}  # slot -> item (Dictionary); casa vazia não tem chave


static func from_dict(data: Dictionary) -> Inventory:
	var inventory := Inventory.new()
	var source: Dictionary = data.get("equipment", {})
	for slot: String in ItemDB.EQUIP_SLOTS:
		var item: Variant = source.get(slot)
		if ItemDB.is_valid(item) and ItemDB.slot_of(item) == slot:
			inventory.equipment[slot] = _sanitize(item)
	return inventory


static func starter() -> Inventory:
	return from_dict({"equipment": ItemDB.starter_kit()})


func to_dict() -> Dictionary:
	return {"equipment": equipment.duplicate(true)}


func is_empty() -> bool:
	return equipment.is_empty()


## Leitura

func get_item(path: Array) -> Variant:
	if path.size() == 2 and path[0] == "eq":
		return equipment.get(path[1])
	var holder := _holder(path)
	if holder.is_empty():
		return null
	var index: int = path[-1]
	return holder.contents[index] if index >= 0 and index < holder.contents.size() else null


## Recipiente (bolsa) que contém a casa `path`, ou {} se o caminho não existe.
func _holder(path: Array) -> Dictionary:
	if path.size() < 2 or path[0] != "bag":
		return {}
	var container: Variant = equipment.get("bag")
	for i in range(1, path.size() - 1):
		if not ItemDB.is_container(container):
			return {}
		var index: int = path[i]
		if index < 0 or index >= container.contents.size():
			return {}
		container = container.contents[index]
	return container if ItemDB.is_container(container) else {}


## Conteúdo da bolsa aberta em `container_path` (["bag"] = mochila equipada).
func container_at(container_path: Array) -> Variant:
	var item: Variant = equipment.get("bag") if container_path.size() == 1 else get_item(container_path)
	return item if ItemDB.is_container(item) else null


## Soma de um atributo em tudo que está equipado.
func total(key: String) -> float:
	var sum := 0.0
	for slot: String in equipment:
		if slot != "bag":
			sum += ItemDB.stat(equipment[slot], key)
	return sum


## Escrita (host)

func _set_item(path: Array, item: Variant) -> void:
	if path[0] == "eq":
		if item == null:
			equipment.erase(path[1])
		else:
			equipment[path[1]] = item
	else:
		_holder(path).contents[path[-1]] = item


## Pode `item` ficar na casa `path`? (casa certa do equipamento, casa existe,
## e uma bolsa não pode ir para dentro dela mesma.)
func can_place(item: Variant, path: Array) -> bool:
	if path.size() < 2:
		return false
	if path[0] == "eq":
		return item == null or ItemDB.slot_of(item) == path[1]
	var holder := _holder(path)
	var index: int = path[-1]
	if holder.is_empty() or index < 0 or index >= holder.contents.size():
		return false
	return item == null or not _path_goes_through(path, item)


func _path_goes_through(path: Array, item: Dictionary) -> bool:
	var container: Variant = equipment.get("bag")
	for i in range(1, path.size()):
		if not ItemDB.is_container(container):
			return false
		if container.uid == item.uid:
			return true
		if i < path.size() - 1:
			container = container.contents[path[i]]
	return false


## Move de `src` para `dst`. Casa ocupada troca os dois; soltar em cima de uma bolsa
## guarda dentro dela. Retorna false se não pode.
func move(src: Array, dst: Array) -> bool:
	if src == dst:
		return false
	var item: Variant = get_item(src)
	if item == null:
		return false
	var target: Variant = get_item(dst)
	var onto_bag_slot := dst == ["eq", "bag"]
	# Soltar em cima de uma bolsa: guarda dentro (bolsa sobre a casa da mochila troca).
	if ItemDB.is_container(target) and target.uid != item.uid and not (onto_bag_slot and ItemDB.is_container(item)):
		var free: int = target.contents.find(null)
		var inner := (["bag"] if onto_bag_slot else dst) + [free]
		if free == -1 or not can_place(item, inner):
			return false
		_set_item(src, null)
		target.contents[free] = item
		changed.emit()
		return true
	# Equipar uma mochila que está dentro da atual: a atual vai para dentro da nova.
	if onto_bag_slot and target != null and src[0] == "bag" and _path_goes_through(src, target):
		var free: int = item.contents.find(null)
		if free == -1:
			return false
		_set_item(src, null)
		item.contents[free] = target
		equipment["bag"] = item
		changed.emit()
		return true
	if not can_place(item, dst) or not can_place(target, src):
		return false
	_set_item(src, null)
	_set_item(dst, item)
	if target != null:
		_set_item(src, target)
	changed.emit()
	return true


## Equipa direto na casa do item (trocando com o que estiver lá).
func equip(path: Array) -> bool:
	var item: Variant = get_item(path)
	if item == null or path[0] == "eq":
		return false
	return move(path, ["eq", ItemDB.slot_of(item)])


## Guarda na primeira casa livre: mochila primeiro, depois bolsas dentro dela.
## Retorna o path onde ficou, ou [] se não coube.
func add_item(item: Dictionary) -> Array:
	var queue := [["bag"]]
	while not queue.is_empty():
		var container_path: Array = queue.pop_front()
		var container: Variant = container_at(container_path)
		if container == null:
			continue
		for i in container.contents.size():
			var path := container_path + [i]
			if container.contents[i] == null and can_place(item, path):
				container.contents[i] = item
				changed.emit()
				return path
			if ItemDB.is_container(container.contents[i]):
				queue.append(path)
	return []


func remove(path: Array) -> Variant:
	var item: Variant = get_item(path)
	if item != null:
		_set_item(path, null)
		changed.emit()
	return item


## Visual do que está equipado, para desenhar no boneco: [{id, rarity}, ...]
func visual() -> Array:
	var result := []
	for slot: String in ItemDB.EQUIP_SLOTS:
		if equipment.has(slot):
			result.append({"id": equipment[slot].id, "rarity": equipment[slot].rarity})
	return result


static func _sanitize(item: Dictionary) -> Dictionary:
	var clean := {
		"id": str(item.id), "uid": int(item.get("uid", randi())),
		"power": clampi(int(item.get("power", 1)), 1, 999),
		"rarity": item.get("rarity", "common") if ItemDB.RARITIES.has(item.get("rarity")) else "common",
	}
	var capacity: int = ItemDB.DEFS[clean.id].get("capacity", 0)
	if capacity > 0:
		var contents := []
		contents.resize(capacity)
		var source: Array = item.get("contents", [])
		for i in mini(capacity, source.size()):
			if ItemDB.is_valid(source[i]):
				contents[i] = _sanitize(source[i])
		clean["contents"] = contents
	return clean
