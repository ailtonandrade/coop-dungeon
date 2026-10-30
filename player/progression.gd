class_name Progression
extends RefCounted
## Nível, experiência e chips piratas de um herói. Vai no save do personagem junto com o
## inventário (cross save) e quem decide é o host, como no resto.
##
## XP vem das criaturas (todo o time por perto ganha o mesmo, estilo co-op). Cada nível dá um
## pouco de vida e dano e um ponto de chip pirata, que o jogador instala onde quiser no painel
## "Chip pirata" (RB / Q dentro do inventário).

signal changed

const MAX_LEVEL := 60
const MAX_CHIP := 10
## Chips: id -> nome, texto do efeito (com o total) e quanto cada ponto dá.
## Os ids ficam no save: não mude depois de lançar.
const CHIPS := {
	"carcaca": {"name": "Carcaça reforçada", "text": "+%s%% de vida", "per": 6.0, "stat": "hp_pct"},
	"braco": {"name": "Braço hidráulico", "text": "+%s%% de dano", "per": 5.0, "stat": "damage_pct"},
	"reflexo": {"name": "Reflexo turbinado", "text": "-%s%% nas recargas (rolar, tiro, poção)", "per": 4.0, "stat": "cooldown_pct"},
	"motor": {"name": "Motor nas pernas", "text": "+%s%% de velocidade", "per": 2.5, "stat": "speed_pct"},
}
## Ganho de cada nível, sem precisar gastar nada.
const HP_PER_LEVEL := 3.0
const DAMAGE_PCT_PER_LEVEL := 1.5

var level := 1
var xp := 0
var chips := {}


## XP para passar do nível `at` para o próximo.
static func xp_to_next(at: int) -> int:
	return roundi(60.0 * pow(at, 1.45))


## Soma XP e sobe de nível quantas vezes der. Devolve quantos níveis subiu.
func add_xp(amount: int) -> int:
	if level >= MAX_LEVEL or amount <= 0:
		return 0
	xp += amount
	var gained := 0
	while level < MAX_LEVEL and xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		gained += 1
	if level >= MAX_LEVEL:
		xp = 0
	changed.emit()
	return gained


func xp_ratio() -> float:
	return 1.0 if level >= MAX_LEVEL else clampf(float(xp) / xp_to_next(level), 0.0, 1.0)


func points_total() -> int:
	return level - 1


func points_spent() -> int:
	var total := 0
	for id: String in chips:
		total += int(chips[id])
	return total


func points_free() -> int:
	return points_total() - points_spent()


func chip_level(id: String) -> int:
	return int(chips.get(id, 0))


func can_install(id: String) -> bool:
	return CHIPS.has(id) and points_free() > 0 and chip_level(id) < MAX_CHIP


func install(id: String) -> bool:
	if not can_install(id):
		return false
	chips[id] = chip_level(id) + 1
	changed.emit()
	return true


## Bônus somado de chips e níveis: "hp_pct", "hp_flat", "damage_pct", "cooldown_pct", "speed_pct".
func bonus(stat: String) -> float:
	var total := 0.0
	match stat:
		"hp_flat":
			total = (level - 1) * HP_PER_LEVEL
		"damage_pct":
			total = (level - 1) * DAMAGE_PCT_PER_LEVEL
	for id: String in CHIPS:
		if CHIPS[id].stat == stat:
			total += chip_level(id) * float(CHIPS[id].per)
	return total


## Texto do efeito de um chip com `points` pontos (0 = sem efeito ainda).
static func chip_text(id: String, points: int) -> String:
	var info: Dictionary = CHIPS[id]
	return String(info.text) % str(snappedf(points * float(info.per), 0.1))


func to_dict() -> Dictionary:
	return {"level": level, "xp": xp, "chips": chips.duplicate()}


## Lê do save, sem confiar nele: nível no limite, chips conhecidos, no máximo e sem gastar
## mais pontos do que o nível dá.
static func from_dict(data: Variant) -> Progression:
	var progress := Progression.new()
	if not data is Dictionary:
		return progress
	progress.level = clampi(int(data.get("level", 1)), 1, MAX_LEVEL)
	progress.xp = clampi(int(data.get("xp", 0)), 0, xp_to_next(progress.level) - 1)
	var source: Variant = data.get("chips", {})
	if source is Dictionary:
		for id: String in CHIPS:
			var points := clampi(int(source.get(id, 0)), 0, MAX_CHIP)
			points = mini(points, progress.points_free())
			if points > 0:
				progress.chips[id] = points
	return progress
