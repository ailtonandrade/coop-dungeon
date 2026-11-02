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
			_check(_god.active and _player().building, "comando /construir no chat liga o modo construtor")
			var chat: Array = root.get_node("Chat").history.map(func(m: Dictionary) -> String: return m.text)
			_check(not chat.has("/construir") and not chat.any(func(t: String) -> bool: return t.contains("construir") and not t.begins_with("Modo construtor")),
					"o comando não aparece no chat da sala")
			_check(get_first_node_in_group("hud").find_children("*", "Button", true, false).all(func(b: Button) -> bool: return not b.text.to_lower().contains("construtor")),
					"nenhum botão de modo construtor nos menus")
			_check(not _player().is_targetable(), "construindo: criaturas ignoram o herói")
			_check(_god._ghost != null and _god._ghost.get_child_count() > 0, "fantasma da peça aparece")
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
			_check(not _god.active and _player().is_targetable(), "/construir de novo desliga: herói volta a lutar")
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
	chat_box._submit("/construir")


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
