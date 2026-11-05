extends SceneTree
## Modo construtor: liga só para o dono, peça física cai e é gravada onde parou, peça fixa
## grava na hora, desfazer, bloco recarregado traz as peças de volta, e a gravação nas cenas
## dos blocos (numa cópia).
## Rodar: godot --headless --fixed-fps 60 --path coop-dungeon -s tests/god_test.gd
## Sem tipos do jogo aqui: o script de teste compila antes dos serviços globais existirem.

const SECOND := 60

var _frames := 0
var _failed := false
var _god: Node
var _cone: Node3D
var _fixed_id := ""
var _start := Vector3.ZERO


func _process(_delta: float) -> bool:
	_frames += 1
	match _frames:
		1:
			root.get_node("SaveService").use_test_storage("test_saves_god")
			Engine.set_meta("auto_pick_character", true)
			Engine.set_meta("world_edits_to_save", true)
			root.get_node("NetService").world = {"id": "teste_god", "name": "Teste"}
			change_scene_to_file("res://world/world.tscn")
		10:
			root.get_node("InputService")._try_join(-1)
		SECOND:
			_god = get_first_node_in_group("god_mode")
			_check(_god != null, "mundo tem o modo construtor")
			_command()
			_start = _player().global_position
			_check(_god.active and _player().building, "comando /editar no chat liga o modo construtor")
			var chat: Array = root.get_node("Chat").history.map(func(m: Dictionary) -> String: return m.text)
			_check(not chat.has("/editar") and not chat.any(func(t: String) -> bool: return t.contains("editar") and not t.begins_with("Modo construtor")),
					"o comando não aparece no chat da sala")
			_check(get_first_node_in_group("hud").find_children("*", "Button", true, false).all(func(b: Button) -> bool: return not b.text.to_lower().contains("construtor")),
					"nenhum botão de modo construtor nos menus")
			_check(not _player().is_targetable(), "construindo: criaturas ignoram o herói")
			_check(_god._ghost != null and _god._ghost.get_child_count() > 0, "fantasma da peça aparece")
			# Categorias: com uma pasta de teste, V troca de pasta e Q/E fica dentro dela.
			var cat_def: Resource = load("res://props/prop_def.gd").new()
			cat_def.id = "teste_god_categoria"
			cat_def.display_name = "Caixa de teste"
			cat_def.model = load("res://assets/props/Barrel.glb")
			load("res://props/prop_builder.gd").save(cat_def, "zz teste")
			_god._catalog = load("res://props/prop_builder.gd").catalog()
			_select("cone.tscn")
			_check(_god.current_category() == "Geral", "cone está na categoria Geral")
			var categories: PackedStringArray = load("res://props/prop_builder.gd").categories(_god._catalog)
			_god.next_category(1)
			_check(_god.current_category() == categories[1], "V vai para a próxima pasta (%s)" % _god.current_category())
			# Shift+V volta; da primeira, dá a volta para a última (a pasta de teste, "Zz...").
			_god.next_category(-1)
			_god.next_category(-1)
			_check(_god.current_category() == "Zz Teste" and String(_god.current().path).ends_with("teste_god_categoria.tscn"), "Shift+V volta e dá a volta nas pastas (%s)" % _god.current_category())
			_god.select_next(1)
			_check(_god.current_category() == "Zz Teste", "Q/E dá a volta dentro da pasta, sem sair dela")
			_check(_god._title.text.contains("ZZ TESTE"), "a tela mostra a categoria")
			_check(_god.allowed() and root.get_node("InputService").builder_slot == 0, "V do construtor não abre o microfone (vaga marcada)")
			_god.next_category(1)
			_check(_god.current_category() == "Geral", "V dá a volta nas categorias")
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://world/prefabs/zz_teste/teste_god_categoria.tscn"))
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://world/prefabs/zz_teste"))
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://world/props/teste_god_categoria.tres"))
			# Packs: cada subpasta de packs/ vira categoria com os modelos dela; carimbar um modelo
			# solto cria a peça pronta (fixa) na hora. Aqui "assets" faz o papel da pasta packs/.
			var builder: Script = load("res://props/prop_builder.gd")
			builder.pack_dirs = ["res://assets"]
			_god._catalog = builder.catalog(true)
			var raw: Array = _god._catalog.filter(func(e: Dictionary) -> bool: return e.get("raw", false) and e.pack == "props")
			_check(not raw.is_empty() and raw.all(func(e: Dictionary) -> bool: return e.category == "Props"), "subpasta do pack vira categoria com os modelos soltos (%d)" % raw.size())
			_check(not _god._catalog.any(func(e: Dictionary) -> bool: return e.get("raw", false) and String(e.path).ends_with("TrafficCone_1.glb")), "modelo que já virou peça (o cone) não aparece repetido")
			_god._index = _god._catalog.find(raw[0])
			_god._rebuild_ghost()
			_check(_god._ghost.get_child_count() > 0, "fantasma do modelo do pack aparece")
			var made: Node3D = _god.place_at(_player().global_position + Vector3(4, 0, -3))
			_check(made != null and made.scene_file_path.begins_with("res://world/prefabs/props/") and made is StaticBody3D, "carimbar o modelo do pack cria a peça fixa na pasta do pack (%s)" % (made.scene_file_path if made else "-"))
			_check(not _god.current().get("raw", true), "e a lista passa a usar a peça nova")
			var made_path: String = made.scene_file_path
			_god.remove_piece(String(made.name))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(made_path))
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://world/props/" + made_path.get_file().get_basename() + ".tres"))
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://world/prefabs/props"))
			builder.pack_dirs = ["res://assets/props/packs", "res://props/packs"]
			_god._catalog = builder.catalog()
			_select("cone.tscn")
			_cone = _god.place_at(_player().global_position + Vector3(3, 0, 0))
			_check(_cone != null and _cone.global_position.y > 1.0, "cone físico nasce no alto (y %.2f)" % (_cone.global_position.y if _cone else -1.0))
		SECOND + 4:
			_check(_placed().is_empty(), "enquanto cai, ainda não gravou")
		8 * SECOND:
			_check(_player().global_position.distance_to(_start) < 1.0 and not _player().is_downed(),
					"construindo por vários segundos não conta como time caído (não volta ao início)")
			var placed := _placed()
			_check(placed.size() == 1 and placed[0].id == String(_cone.name), "cone parou e foi gravado no save do mundo")
			var y: float = placed[0].xform[10] if placed.size() == 1 else 99.0
			_check(y < 0.6, "gravado no chão, onde parou (y %.2f)" % y)
			_select("barreira.tscn")
			var fixed: Node3D = _god.place_at(_player().global_position + Vector3(-3, 0, 2))
			_fixed_id = String(fixed.name) if fixed else ""
			_check(_placed().size() == 2, "peça fixa grava na hora")
			# Pegar (G/▲) e largar em outro lugar: a mesma peça muda de lugar e o registro também.
			var from: Vector3 = fixed.global_position
			_check(_god.grab_near(from) and not fixed.visible, "G pega a peça (some do lugar e vira fantasma)")
			_god._yaw = PI / 2.0
			_god.place_at(from + Vector3(2, 0, 0))
			var moved: Array = _placed().filter(func(e: Dictionary) -> bool: return e.id == _fixed_id)
			_check(is_instance_valid(fixed) and fixed.visible and fixed.global_position.distance_to(from + Vector3(2, 0, 0)) < 0.05 \
					and moved.size() == 1 and absf(float(moved[0].xform[9]) - (fixed.position.x)) < 0.05,
					"largou no lugar novo, girada, e o registro foi junto")
			_check(_placed().size() == 2, "mudar de lugar não duplica a peça")
			# Estrutura (parede de tijolo do pack): fica onde larga e encaixa na vizinha.
			_select("brick_plain_1.tscn")
			_check(_god._current_kind() == "estrutura", "parede do pack é estrutura")
			var base_point: Vector3 = _player().global_position + Vector3(4, 0, -4)
			_god._yaw = 0.0
			var wall_a: Node3D = _god.place_at(base_point)
			var width: float = _god.box_of(wall_a).size.x
			# Mira meio torta perto da ponta direita: encaixa certinho do lado.
			var wall_b: Node3D = _god.place_at(base_point + Vector3(width + 0.35, 0.0, 0.3))
			var side: Vector3 = wall_b.global_position - wall_a.global_position
			_check(absf(side.x - width) < 0.01 and absf(side.z) < 0.01 and absf(side.y) < 0.01,
					"segunda parede encaixa ao lado, sem fresta (%s)" % side)
			# Em cima: outro andar de tijolo.
			var height: float = _god.box_of(wall_a).size.y
			var wall_c: Node3D = _god.place_at(wall_a.global_position + Vector3(0.2, height, 0.1))
			var up: Vector3 = wall_c.global_position - wall_a.global_position
			_check(absf(up.y - height) < 0.01 and absf(up.x) < 0.01 and absf(up.z) < 0.01, "e empilha em cima (%s)" % up)
			_god.rotate_piece(45.0)
			_check(is_equal_approx(_god._yaw, PI / 2.0), "estrutura gira de 90 em 90")
			_god._yaw = 0.0
			# Peça fixa comum largada no ar desce até o chão.
			_select("barreira.tscn")
			var dropped: Transform3D = _god.placement(_player().global_position + Vector3(-2, 2.5, 3))
			# Desce até o que tiver embaixo (chão ou alguma peça posta ali no mapa).
			_check(dropped.origin.y < _player().global_position.y + 1.5, "objeto solto no ar desce até o chão (y %.2f)" % dropped.origin.y)
			_god.change_lift(0.05)
			_god.change_lift(0.05)
			var lifted: Transform3D = _god.placement(_player().global_position + Vector3(-2, 2.5, 3))
			_check(absf(lifted.origin.y - dropped.origin.y - 0.1) < 0.005, "PgUp sobe a peça (+%.2f m)" % (lifted.origin.y - dropped.origin.y))
			_god.change_lift(-_god._lift)
			for wall: Node3D in [wall_a, wall_b, wall_c]:
				_god.remove_piece(String(wall.name))
			# Peça do mapa (poste do editor): nos testes nunca mexe nos arquivos do mapa.
			var lamp: Array = root.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.scene_file_path.ends_with("poste_de_luz.tscn"))
			if not lamp.is_empty():
				var lamp_node: Node3D = lamp[0]
				_check(_god.piece_near(Vector3(lamp_node.global_position.x, 0, lamp_node.global_position.z)) == lamp_node, "acha peça do mapa (poste) para apagar ou mover")
			_god.undo()
		8 * SECOND + 5:
			_check(_placed().size() == 1 and not _placed().any(func(e: Dictionary) -> bool: return e.id == _fixed_id), "desfazer tira a última peça")
			# Contêiner do construtor: escolhe o que tem dentro.
			_select("bau_de_saque.tscn")
			var chest: Node = _god.place_at(_player().global_position + Vector3(0, 0, 4))
			var gold_before: int = chest.gold
			_god.open_loot_editor(chest)
			_check(_god._loot_panel.visible, "F/RB abre o conteúdo do contêiner")
			_god.loot_add("sword")
			_god.loot_add("sword")
			_god.loot_add("iron_helmet")
			_god.loot_remove(1)
			_god.loot_gold(500)
			_god.close_loot_editor()
			var entry: Dictionary = root.get_node("NetService").world_edit(String(chest.name))
			_check(entry.get("loot", []) == [["sword", 2]] and entry.get("gold", 0) == gold_before + 500, "conteúdo escolhido foi gravado (%s, %s)" % [entry.get("loot"), entry.get("gold")])
			_check(chest.contents.size() == 1 and chest.contents[0].count == 2 and chest.gold == gold_before + 500, "o baú no mundo já tem o conteúdo novo")
			_god.remove_piece(String(chest.name))
			# Área de missão: colocar já pede o nome; o nome vira o id e fica gravado.
			_select("area_de_missao.tscn")
			var area: Node = _god.place_at(_player().global_position + Vector3(0, 0, -4))
			_check(_god._name_panel.visible, "colocar área de missão abre a caixa do nome")
			_god.confirm_name("Pátio dos Contêineres")
			var area_entry: Dictionary = root.get_node("NetService").world_edit(String(area.name))
			_check(area.id() == "patio_dos_conteineres" and not _god._name_panel.visible, "o nome vira o id da área (%s)" % area.id())
			_check(area_entry.get("props", {}).get("area_id") == "patio_dos_conteineres", "e fica gravado com a peça")
			_god.remove_piece(String(area.name))
			# Depois de dar nome (caixa de texto), /editar no chat ainda fecha e abre de novo.
			_command()
			_check(not _god.active, "/editar fecha depois de dar nome à área")
			_command()
			_check(_god.active, "e abre de novo")
			_command()
			_check(not _god.active, "fecha de novo")
			var chat_box: Node = get_first_node_in_group("hud")._chat
			chat_box.open_typing(0)
			chat_box._submit("\\editar")
			_check(_god.active, "\\editar (barra invertida) também abre")
			# Bloco descarregado e carregado de novo: o cone volta pelo save do mundo.
			var streamer := get_first_node_in_group("world_streamer")
			var key: String = _placed()[0].key
			streamer._unload(key)
		8 * SECOND + 10:
			var streamer := get_first_node_in_group("world_streamer")
			var key: String = _placed()[0].key
			streamer._load_sync(key)
			var chunk: Node = streamer.chunk_at(streamer._path_and_origin(key)[1] + Vector3(1, 0, 1))[0]
			var again: Node = chunk.get_node("Navigation").get_node_or_null(NodePath(_placed()[0].id)) if chunk else null
			_check(again != null, "bloco recarregado traz o cone de volta")
			_command()
			_check(not _god.active and _player().is_targetable(), "/editar de novo desliga: herói volta a lutar")
			# Convidado (cliente) nunca tem: nem pelo comando.
			var net := root.get_node("NetService")
			net.mode = 2  # Mode.CLIENT
			_check(not _god.allowed(), "convidado não tem acesso ao modo construtor")
			net.mode = 0
			_test_scene_files()
			print("CONSTRUTOR: " + ("FALHOU" if _failed else "OK"))
			quit(1 if _failed else 0)
	return false


## Gravação direto na cena do bloco (rodando pelo editor), numa cópia da cena.
func _test_scene_files() -> void:
	var edits: Script = load("res://world/world_edits.gd")
	var writer: Script = load("res://world/map_writer.gd")
	var copy := "user://test_god_chunk.tscn"
	var packed: PackedScene = load("res://world/chunks/chunk_0_0.tscn")
	ResourceSaver.save(packed, copy)
	var entry := {"id": "god_teste_1", "key": "0,0", "prefab": "res://world/prefabs/barril.tscn",
			"xform": edits.pack_xform(Transform3D(Basis.IDENTITY, Vector3(5, 0, 7)))}
	_check(writer.save_to_scene(copy, entry), "grava a peça na cena do bloco")
	var root: Node = (ResourceLoader.load(copy, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	var node: Node3D = root.get_node("Navigation").get_node_or_null("god_teste_1")
	_check(node != null and node.scene_file_path.ends_with("barril.tscn") and node.position.is_equal_approx(Vector3(5, 0, 7)), "a cena do bloco tem a peça no lugar")
	_check(root.get_node("Navigation").navigation_mesh.get_polygon_count() == 0, "sem malha de navegação salva junto")
	root.free()
	_check(writer.remove_from_scene(copy, "god_teste_1"), "tira a peça da cena do bloco")
	root = (ResourceLoader.load(copy, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	_check(root.get_node("Navigation").get_node_or_null("god_teste_1") == null, "a cena do bloco ficou sem a peça")
	root.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(copy))


## Digita o comando no chat como o jogador do teclado.
func _command() -> void:
	var chat_box: Node = get_first_node_in_group("hud")._chat
	chat_box.open_typing(0)
	chat_box._submit("/editar")


func _select(file: String) -> void:
	for i in _god._catalog.size():
		if String(_god._catalog[i].path).ends_with("/" + file):
			_god._index = i
			_god._rebuild_ghost()
			return
	_check(false, "peça %s na lista" % file)


func _placed() -> Array:
	return root.get_node("NetService").world.get("placed", [])


func _player() -> Node:
	for p in get_nodes_in_group("players"):
		if p.slot == 0:
			return p
	return null


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	_failed = _failed or not ok
