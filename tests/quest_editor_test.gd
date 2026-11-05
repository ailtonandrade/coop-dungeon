extends SceneTree
## Editor de missões dentro do jogo (/missoes): só o dono, monta a ficha nos campos, "perto"
## pega o NPC, salvar grava em world/quests e a missão já vale; apagar tira o arquivo.
## Rodar: godot --headless --fixed-fps 60 --path coop-dungeon -s tests/quest_editor_test.gd

const SECOND := 60
const TEMP_ID := "teste_editor_tmp"

var _frames := 0
var _failed := false
var _editor: Node


func _process(_delta: float) -> bool:
	_frames += 1
	match _frames:
		1:
			root.get_node("SaveService").use_test_storage("test_saves_quest_editor")
			Engine.set_meta("auto_pick_character", true)
			root.get_node("NetService").world = {"id": "teste_quest_editor", "name": "Teste"}
			change_scene_to_file("res://world/world.tscn")
		10:
			root.get_node("InputService")._try_join(-1)
		SECOND:
			_editor = get_first_node_in_group("quest_editor")
			_check(_editor != null and _editor.allowed(), "o mundo tem o editor de missões (rodando pelo Godot)")
			var chat: Node = get_first_node_in_group("hud")._chat
			chat.open_typing(0)
			chat._submit("/missoes")
			_check(_editor.active and _editor.visible, "/missoes no chat abre o editor")
			var said_command: bool = root.get_node("Chat").history.any(func(m: Dictionary) -> bool: return String(m.text).strip_edges() == "/missoes")
			_check(not said_command, "o comando não vai para o chat da sala")
			_check(root.get_node("InputService").is_blocked(0), "herói parado enquanto edita")
			var hero: Node = get_nodes_in_group("players")[0]
			var hp: float = hero.health.hp
			hero.take_hit(25.0)
			_check(not hero.is_targetable() and hero.health.hp == hp, "editando missões ninguém te ataca nem te fere")
			var groups: Dictionary = _editor.npcs_by_region()
			var everyone: Array = []
			for region_name: String in groups:
				everyone.append_array(groups[region_name])
			_check(groups.size() >= 1 and everyone.has("Dona Alda") and everyone.has("Zé Gato"), "lista de NPCs por região (%s)" % [groups.keys()])
			_editor._choose_npc(_editor._fields.giver)
			for npc in get_nodes_in_group("npcs"):
				if npc.npc_name == "Zé Gato":
					get_nodes_in_group("players")[0].teleport_to(npc.global_position + Vector3(0, 0, 1.5))
		SECOND + 10:
			_editor._new_quest()
			_editor._fields.id.text = TEMP_ID
			_editor._fields.title.text = "Recado do Zé"
			_editor._select(_editor._fields.category, "principal")
			_editor._pick_npc("giver")
			_check(_editor._fields.giver.text == "Zé Gato", "\"perto\" pega o NPC do lado (%s)" % _editor._fields.giver.text)
			# A ficha se ajeita ao jeito de começar e ao tipo do objetivo.
			_editor._select(_editor._fields.start, "npc")
			_editor._refresh_start_form()
			_check(not _editor._fields.start_target.get_parent().visible, "começa por NPC: sem campo de área/gatilho/item")
			_editor._select(_editor._fields.start, "area")
			_editor._refresh_start_form()
			_check(_editor._fields.start_target.get_parent().visible and _editor._fields.start_target.get_parent().get_child(0).text.begins_with("Área"), "começa por área: pede a área")
			_editor._select(_editor._fields.start, "npc")
			_editor._refresh_start_form()
			# Dicas dos campos de fatos: id de missão no lugar de fato e prefixo escondido.
			_editor._fields.requires.text = "quem_sou_eu"
			_editor._fields.requires.text_changed.emit("quem_sou_eu")
			var requires_hint: Label = _editor._fields.requires.get_parent().get_parent().get_child(_editor._fields.requires.get_parent().get_index() + 1)
			_check(requires_hint.text.contains("Vem depois de"), "dica avisa: id de missão em \"Só aparece se\" → use Vem depois de")
			_editor._fields.teaches.text = "visitou_patio"
			_editor._fields.teaches.text_changed.emit("visitou_patio")
			var teaches_hint: Label = _editor._fields.teaches.get_parent().get_parent().get_child(_editor._fields.teaches.get_parent().get_index() + 1)
			_check(teaches_hint.text.contains("NÃO aparece"), "dica avisa: visitou_ fica escondido do Conhecimento")
			_editor._fields.requires.text = ""
			_editor._fields.teaches.text = ""
			_editor._add_objective(null)
			var row: Dictionary = _editor._objective_rows[0]
			_editor._select(row.kind, "matar")
			_editor._refresh_objective(row)
			_check(row.amount.get_parent().visible and not row.npc.get_parent().visible and not row.keywords.get_parent().visible, "matar: criatura e quantidade, sem NPC nem palavras")
			_editor._select(row.kind, "chegar")
			_editor._refresh_objective(row)
			_check(row.target.get_parent().get_child(0).text == "Área" and not row.amount.get_parent().visible, "chegar: pede a área")
			_check(_editor.quest_pieces_by_region("area") is Dictionary, "lista de áreas por região")
			_editor._select(row.kind, "falar")
			_editor._refresh_objective(row)
			_check(row.npc.get_parent().visible and not row.target.get_parent().visible, "falar: NPC e palavras, sem alvo")
			_editor._pick_npc_into(row, "npc")
			row.keywords.text = "radio, frequencia"
			row.replies.text = "Rádio? Qual?\nA frequência 7.0. Desliga isso."
			_editor._fields.reward_gold.value = 77
			var path: String = _editor.save()
			_check(path.ends_with(TEMP_ID + ".tres") and FileAccess.file_exists(path), "salvar grava a ficha em world/quests")
			var quest: Resource = root.get_node("Quests").def(TEMP_ID)
			_check(quest != null and quest.category == "principal" and quest.objectives.size() == 1 \
					and quest.objectives[0].keywords == PackedStringArray(["radio", "frequencia"]) and quest.reward_gold == 77,
					"e já vale no jogo, com o que foi preenchido")
			_check(root.get_node("Quests").offers("Zé Gato").has(quest), "o Zé Gato já oferece a missão nova")
			_editor._load(path)
			_check(_editor._fields.title.text == "Recado do Zé" and _editor._objective_rows.size() == 1, "abrir de novo mostra a ficha salva")
			_editor._delete()
			_check(not FileAccess.file_exists(path) and root.get_node("Quests").def(TEMP_ID) == null, "apagar tira o arquivo e a missão")
			_editor.toggle(0)
			_check(not _editor.active and not root.get_node("InputService").is_blocked(0), "/missoes de novo fecha e solta o herói")
			_check(get_nodes_in_group("players")[0].is_targetable(), "fechou: volta a poder ser atacado")
			root.get_node("NetService").mode = root.get_node("NetService").Mode.CLIENT
			_check(not _editor.allowed(), "convidado não tem acesso")
			root.get_node("NetService").mode = root.get_node("NetService").Mode.OFFLINE
			print("EDITOR DE MISSÕES: " + ("FALHOU" if _failed else "OK"))
			quit(1 if _failed else 0)
	return false


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FALHOU ") + what)
	if not ok:
		_failed = true
