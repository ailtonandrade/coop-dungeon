class_name QuestBanner
extends VBoxContainer
## Aviso grande no alto da tela quando uma missão começa ("NOVA MISSÃO") ou termina ("MISSÃO
## CONCLUÍDA", com a recompensa) e, depois de concluir, qual é o próximo passo da história
## ("Fale com Dona Alda"). Some sozinho.

const SHOW_TIME := 3.6
const AMBER := Color(1.0, 0.8, 0.28)

var _queue: Array = []  # [título pequeno, título grande, linha de baixo, cor]
var _left := 0.0
var _kicker: Label
var _title: Label
var _detail: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 2)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	offset_top = 120
	_kicker = UiSkin.label("", 18, AMBER, "Bold", 4)
	_title = UiSkin.label("", 34, UiSkin.TEXT, "Bold", 6)
	_detail = UiSkin.label("", 16, Color(1, 1, 1, 0.8), "Regular", 3)
	for label: Label in [_kicker, _title, _detail]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)
	modulate.a = 0.0
	Quests.quest_event.connect(_on_quest_event)


func _on_quest_event(id: String, state: String) -> void:
	var quest := Quests.def(id)
	if quest == null:
		return
	var star := "★ " if quest.category == "principal" else ""
	match state:
		"ativa":
			_queue.append([Txt.t("NOVA MISSÃO"), star + Txt.t(quest.title), Txt.t(quest.summary), AMBER])
		"entregue":
			var rewards := PackedStringArray()
			if quest.reward_gold > 0:
				rewards.append(ItemDB.money(quest.reward_gold))
			if quest.reward_xp > 0:
				rewards.append("%d XP" % quest.reward_xp)
			_queue.append([Txt.t("MISSÃO CONCLUÍDA"), star + Txt.t(quest.title), " · ".join(rewards), UiSkin.SAFE])
			Sound.play("quest_done")
			# Depois de concluir: para onde a história segue.
			(func() -> void:
				var next := Quests.next_steps()
				if next.size() == 1:
					_queue.append([Txt.t("PRÓXIMO PASSO"), "★ " + Txt.t(next[0].title), Quests.start_hint(next[0]), AMBER])
				elif next.size() > 1:
					var titles := PackedStringArray()
					for step in next:
						titles.append("★ " + Txt.t(step.title))
					_queue.append([Txt.t("PRÓXIMOS PASSOS"), " · ".join(titles), Txt.t("Escolha qual rastrear na tela de missões (inventário, RB/Q)"), AMBER])
			).call_deferred()


func _process(delta: float) -> void:
	if _left > 0.0:
		_left -= delta
		modulate.a = clampf(minf(_left, SHOW_TIME - _left) * 3.0, 0.0, 1.0)
		return
	modulate.a = 0.0
	if _queue.is_empty():
		return
	var next: Array = _queue.pop_front()
	_kicker.text = next[0]
	_kicker.add_theme_color_override("font_color", next[3])
	_title.text = next[1]
	_detail.text = next[2]
	_detail.visible = not String(next[2]).is_empty()
	_left = SHOW_TIME
