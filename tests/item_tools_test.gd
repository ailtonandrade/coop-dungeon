extends SceneTree
## Teste das fichas de item e do painel "Itens" (ItemTools), numa pasta própria em tests/tmp:
## as fichas migradas batem com a tabela antiga, criar item com modelo próprio e encaixe,
## vender numa loja do mapa, cair de uma criatura, validar, ícone e apagar.
## Rodar: godot --headless --path coop-dungeon -s tests/item_tools_test.gd

const TMP := "res://tests/tmp/items"

var _failed := false
var _done := false
var _finished := false


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	_run()
	# Um erro de script no meio para o _run antes do fim: conta como falha.
	_check(_finished, "teste rodou até o fim")
	print("ITENS: ", "FALHOU" if _failed else "OK")
	quit(1 if _failed else 0)
	return false


func _run() -> void:
	var tools: Script = load("res://addons/item_editor/item_tools.gd")
	var item_def: Script = load("res://items/item_def.gd")
	var item_drop: Script = load("res://items/item_drop.gd")
	var loot: Script = load("res://items/loot.gd")
	var visuals: Script = load("res://items/item_visuals.gd")
	var config: Script = load("res://core/game_config.gd")
	_clean()
	DirAccess.make_dir_recursive_absolute(TMP)

	# Fichas migradas: os itens antigos continuam iguais.
	_db().reload()
	_check(_db().ids().size() == 21, "21 fichas lidas de items/defs (%d)" % _db().ids().size())
	_check(_db().def({"id": "axe"}).get("damage") == 13.0 and _db().def({"id": "axe"}).get("price") == 50, "machado: dano 13, preço 50")
	_check(_db().def({"id": "big_backpack"}).get("capacity") == 20, "mochilão: 20 espaços")
	_check(_db().def({"id": "gold"}).get("look") == "coins", "parafusos continuam existindo")
	_check(_db().drop_pool().size() == 21, "todos no sorteio geral, como antes")
	_check(_db().make("backpack").contents.size() == 12, "mochila nasce com 12 casas")

	# Criaturas: os ids das fichas batem com as criaturas do jogo.
	var enemy: Script = load("res://enemies/enemy.gd")
	var ids := []
	for kind in enemy.STATS:
		ids.append(enemy.STATS[kind].id)
	_check(ids.all(func(id: String) -> bool: return config.CREATURES.has(id)), "toda criatura tem id conhecido no editor")

	# Item novo com o painel (na pasta de teste).
	tools.defs_dir = TMP + "/defs"
	tools.models_dir = TMP + "/models"
	tools.icons_dir = TMP + "/icons"
	_db().use_dirs(PackedStringArray([_db().DEFS_DIR, tools.defs_dir]))
	_check(tools.slugify("Facão de Serra!") == "facao_de_serra", "id a partir do nome")
	var item: Resource = tools.create_item("chave_inglesa", "Chave inglesa", "melee")
	_check(item != null and FileAccess.file_exists(TMP + "/defs/chave_inglesa.tres"), "ficha nova criada")
	_check(tools.create_item("chave_inglesa", "De novo", "melee") == null, "não cria id repetido")
	_check(tools.create_item("axe", "Outro machado", "melee") == null, "não cria por cima de item que já existe")
	_check(not tools.validate(item).is_empty(), "arma sem dano é apontada na validação")

	# Modelo 3D próprio (uma cena com uma malha, como um .glb importado) e encaixe próprio.
	var model_root := Node3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.1, 0.6, 0.1)
	mesh.mesh = box
	mesh.position.y = 0.3
	model_root.add_child(mesh)
	mesh.owner = model_root
	var packed := PackedScene.new()
	packed.pack(model_root)
	model_root.free()
	ResourceSaver.save(packed, TMP + "/chave.tscn")

	item.damage = 11.0
	item.price = 42
	item.model = load(TMP + "/chave.tscn")
	item.model_scale = 1.5
	item.custom_mount = true
	item.mount_bone = "Wrist.L"
	item.mount_position = Vector3(0, -0.05, 0.03)
	item.random_loot = false
	item.sold_by.append("Dona Alda")
	var rule: Resource = item_drop.new()
	rule.creature = "corrompido"
	rule.chance = 100.0
	rule.min_count = 2
	rule.max_count = 2
	rule.rarity = "rare"
	item.drops.append(rule)
	_check(tools.save_item(item) == OK, "ficha salva")
	_check(tools.validate(item).is_empty(), "ficha completa passa na validação: %s" % ", ".join(tools.validate(item)))
	_check(_db().def({"id": "chave_inglesa"}).get("damage") == 11.0, "o jogo lê a ficha nova")

	# Onde conseguir: loja do mapa e loot da criatura.
	var shops: Array = tools.list_shops(load("res://world/test_world.tres"))
	_check(shops.any(func(s: Dictionary) -> bool: return s.key == "Dona Alda"), "acha a loja da Dona Alda no mapa")
	_check(not shops.any(func(s: Dictionary) -> bool: return s.key == "Brando"), "mecânico não aparece como loja")
	var npc: Node = load("res://world/world_npc.gd").new()
	npc.npc_name = "Dona Alda"
	_check(npc.stock().has("chave_inglesa"), "a Dona Alda passa a vender a chave inglesa")
	_check(npc.stock().has("sword"), "e continua vendendo o que já vendia")
	npc.npc_name = "Outra"
	_check(not npc.stock().has("chave_inglesa"), "outra loja não vende")
	npc.free()
	var dropped: Array = loot.roll_items(3, "corrompido").filter(func(i: Dictionary) -> bool: return i.id == "chave_inglesa")
	_check(dropped.size() == 2 and dropped.all(func(i: Dictionary) -> bool: return i.rarity == "rare" and i.power == 3),
			"Corrompido deixa cair 2 chaves Remendadas (%d)" % dropped.size())
	var from_punk := 0
	for i in 30:
		from_punk += loot.roll_items(3, "punk").filter(func(i: Dictionary) -> bool: return i.id == "chave_inglesa").size()
	_check(from_punk == 0, "Bandido não deixa cair (fora do sorteio geral)")

	# Visual: modelo próprio, no tamanho da ficha, preso no osso escolhido.
	var piece: Node3D = visuals.build({"id": "chave_inglesa", "rarity": "rare"})
	var meshes := piece.find_children("*", "MeshInstance3D", true, false)
	_check(meshes.size() == 1 and piece.get_child(0).scale.is_equal_approx(Vector3.ONE * 1.5), "usa o modelo 3D da ficha, na escala certa")
	piece.free()
	var hero: Node3D = load("res://assets/characters/Adventurer.glb").instantiate()
	root.add_child(hero)
	visuals.dress(hero, [{"id": "chave_inglesa", "rarity": "common"}])
	var attached := hero.find_children("*", "BoneAttachment3D", true, false)
	_check(attached.size() == 1 and attached[0].bone_name == "Wrist.L", "presa no osso da ficha (mão esquerda)")
	hero.free()

	# Modelo gigante e deitado (30 m no eixo X): o ajuste automático põe em pé, no tamanho de uma
	# espada, com o cabo na origem.
	var huge_root := Node3D.new()
	var huge_mesh := MeshInstance3D.new()
	var huge_box := BoxMesh.new()
	huge_box.size = Vector3(30, 1, 2)
	huge_mesh.mesh = huge_box
	huge_mesh.position = Vector3(40, 5, 0)
	huge_root.add_child(huge_mesh)
	huge_mesh.owner = huge_root
	var huge_packed := PackedScene.new()
	huge_packed.pack(huge_root)
	huge_root.free()
	ResourceSaver.save(huge_packed, TMP + "/gigante.tscn")
	var sword: Resource = tools.create_item("espada_gigante", "Espada gigante", "melee")
	sword.damage = 10.0
	sword.look = "sword"
	sword.model = load(TMP + "/gigante.tscn")
	_check(tools.auto_fit(sword), "ajuste automático roda")
	_check(sword.model_rotation == Vector3(0, 0, 90), "deitada no X: gira para ficar em pé (%s)" % sword.model_rotation)
	tools.save_item(sword)
	var fitted: Node3D = visuals.build({"id": "espada_gigante", "rarity": "common"})
	root.add_child(fitted)
	var fit_box: AABB = tools.bounds(fitted)
	fitted.free()
	_check(absf(fit_box.size.y - 0.9) < 0.02 and fit_box.size.x < 0.1, "fica com 0,9 m de altura, em pé (%s)" % fit_box.size)
	_check(absf(fit_box.position.y) < 0.01 and absf(fit_box.get_center().x) < 0.01, "cabo na origem, centralizada (%s)" % fit_box.position)

	# Vestir no corpo: a roupa de outro personagem (mesmo esqueleto) dobra junto com o herói.
	var vest: Resource = tools.create_item("roupa_teste", "Roupa de teste", "chest")
	vest.armor = 3.0
	vest.model = load("res://assets/characters/Casual_Hoodie.glb")
	vest.wear_on_body = true
	vest.hide_body = 1 | 2
	tools.save_item(vest)
	var wearer: Node3D = load("res://assets/characters/Adventurer.glb").instantiate()
	root.add_child(wearer)
	visuals.dress(wearer, [{"id": "roupa_teste", "rarity": "common"}])
	var skeleton: Skeleton3D = wearer.find_children("*", "Skeleton3D", true, false)[0]
	var worn := skeleton.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D and n.has_meta("equipment_piece"))
	_check(not worn.is_empty() and worn.all(func(m: MeshInstance3D) -> bool: return m.skin != null and m.get_node_or_null(m.skeleton) == skeleton),
			"roupa com ossos vestida no esqueleto do herói (%d malhas)" % worn.size())
	_check(skeleton.find_children("*", "BoneAttachment3D", true, false).is_empty(), "vestida não vai presa num osso")
	var own := skeleton.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D and not n.has_meta("equipment_piece"))
	var body_hidden := own.filter(func(m: MeshInstance3D) -> bool: return m.name.to_lower().ends_with("body") or m.name.to_lower().ends_with("legs"))
	_check(not body_hidden.is_empty() and body_hidden.all(func(m: MeshInstance3D) -> bool: return not m.visible), "tronco e pernas do herói escondidos por baixo")
	_check(own.filter(func(m: MeshInstance3D) -> bool: return m.name.to_lower().ends_with("feet")).all(func(m: MeshInstance3D) -> bool: return m.visible), "pés continuam aparecendo")
	wearer.free()
	tools.delete_item("espada_gigante")
	tools.delete_item("roupa_teste")

	# Ícone pronto (sem importar) e a ficha usando ele.
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	var icon: Texture2D = tools.save_icon(image, "chave_inglesa")
	_check(icon != null and icon.get_width() == 16, "ícone salvo e carregável")

	# Impressão digital do online muda quando uma ficha muda.
	var before: String = _db().fingerprint()
	item.damage = 12.0
	tools.save_item(item)
	_check(_db().fingerprint() != before, "mudar uma ficha muda a impressão digital do online")

	# Duplicar e apagar.
	var copy: Resource = tools.create_item("chave_inglesa_2", "Chave inglesa (cópia)", "melee", item)
	_check(copy != null and copy.damage == 12.0 and copy.drops.size() == 1, "duplicar copia atributos e loot")
	_check(tools.delete_item("chave_inglesa_2") == OK and not _db().has("chave_inglesa_2"), "apagar tira do jogo")

	# Importar modelo de fora do projeto copia para a pasta do item.
	var outside := OS.get_user_data_dir().path_join("modelo_teste.obj")
	var file := FileAccess.open(outside, FileAccess.WRITE)
	file.store_string("v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n")
	file.close()
	var copied: String = tools.import_model(outside, "chave_inglesa")
	_check(copied == TMP + "/models/chave_inglesa/modelo_teste.obj" and FileAccess.file_exists(copied), "modelo de fora copiado para a pasta do item")
	_check(tools.import_model(outside.get_basename() + ".txt", "x").is_empty(), "arquivo que não é modelo é recusado")
	DirAccess.remove_absolute(outside)

	# As fichas de verdade passam na validação.
	_db().use_dirs(PackedStringArray([_db().DEFS_DIR]))
	item_def.set_known_shops(PackedStringArray(shops.map(func(s: Dictionary) -> String: return s.key)))
	var problems := PackedStringArray()
	for id: String in _db().ids():
		for issue in tools.validate(_db().source(id)):
			problems.append("%s: %s" % [id, issue])
	_check(problems.is_empty(), "fichas do jogo sem problemas %s" % ", ".join(problems))
	_clean()
	_finished = true


## O catálogo sempre pela versão atual do script (salvar uma ficha pode recompilar as classes
## ligadas a ela, e uma referência antiga ficaria com os dados velhos).
func _db() -> Script:
	return load("res://items/item_db.gd")


func _clean() -> void:
	if DirAccess.dir_exists_absolute(TMP):
		_remove_tree(ProjectSettings.globalize_path(TMP))


func _remove_tree(path: String) -> void:
	for dir in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(dir))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


func _check(ok: bool, text: String) -> void:
	print("  ", "ok  " if ok else "FALHOU", " ", text)
	if not ok:
		_failed = true
