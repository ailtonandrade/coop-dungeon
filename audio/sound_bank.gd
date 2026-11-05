class_name SoundBank
extends RefCounted
## Eventos de som do jogo: nome -> arquivos (variações sorteadas sem repetir), volume, variação
## de afinação e barramento. O código só pede o evento (Sound.play("hit", posição)); trocar ou
## acrescentar arquivos de um evento é só mexer aqui.
##
## Campos: "files" (em audio/sfx, sem .ogg), "db" (volume), "pitch" (variação de afinação, 0.1 =
## ±10%), "bus" ("SFX" ou "UI"), "world" (false = sem posição, toca igual em qualquer lugar),
## "gap" (segundos mínimos entre dois do mesmo evento, contra empilhar dezenas de golpes juntos).

const SFX_DIR := "res://audio/sfx/"
const MUSIC_DIR := "res://audio/music/"

const EVENTS := {
	# Combate
	"swing": {"files": ["swing_1", "swing_2", "swing_3"], "db": -5.0, "pitch": 0.1},
	"swing_heavy": {"files": ["swing_heavy"], "db": -2.0, "pitch": 0.05},
	"hit": {"files": ["hit_1", "hit_2", "hit_3"], "db": -3.0, "pitch": 0.12, "gap": 0.03},
	"hit_heavy": {"files": ["hit_heavy", "metal_1"], "db": -1.0, "pitch": 0.06},
	"enemy_hurt": {"files": ["kenney_enemy_hurt"], "db": -10.0, "pitch": 0.15, "gap": 0.05},
	"shot": {"files": ["nail_shot_1", "nail_shot_2", "nail_shot_3"], "db": 1.0, "pitch": 0.05},
	"enemy_shot": {"files": ["enemy_shot"], "db": -5.0, "pitch": 0.1},
	# Armas de fogo e granada: estalo, estouro grave e eco curto de rua, abafados.
	"shot_9mm": {"files": ["shot_9mm_1", "shot_9mm_2"], "db": 0.0, "pitch": 0.05},
	"shot_rifle": {"files": ["shot_rifle_1", "shot_rifle_2"], "db": 2.0, "pitch": 0.04},
	"shot_shotgun": {"files": ["shot_shotgun_1", "shot_shotgun_2"], "db": 2.0, "pitch": 0.04},
	"explosion": {"files": ["explosion_1", "explosion_2"], "db": 3.0, "pitch": 0.06},
	"grenade_bounce": {"files": ["grenade_bounce_1", "grenade_bounce_2"], "db": -6.0, "pitch": 0.1, "gap": 0.05},
	"dry_fire": {"files": ["dry_fire"], "db": -6.0, "pitch": 0.05, "gap": 0.1},
	"ammo_pickup": {"files": ["ammo_pickup"], "db": -6.0, "pitch": 0.06},
	# Construção da base.
	"build_place": {"files": ["build_place"], "db": -4.0, "pitch": 0.08, "gap": 0.08},
	"build_remove": {"files": ["build_remove"], "db": -5.0, "pitch": 0.06, "gap": 0.1},
	# Prego batendo em parede/chão e entrando em alguém: abafados, sem anel.
	"projectile_hit": {"files": ["nail_impact_1", "nail_impact_2", "nail_impact_3"], "db": -4.0, "pitch": 0.1, "gap": 0.03},
	"nail_hit": {"files": ["nail_body_1", "nail_body_2", "nail_body_3"], "db": -3.0, "pitch": 0.1, "gap": 0.03},
	"player_hurt": {"files": ["player_hurt_1", "player_hurt_2"], "db": -2.0, "pitch": 0.08, "gap": 0.08},
	"player_down": {"files": ["player_down"], "db": -1.0},
	"revive": {"files": ["revive"], "db": -3.0},
	"dodge": {"files": ["dodge"], "db": -7.0, "pitch": 0.1},
	"jump": {"files": ["jump_push"], "db": -6.0, "pitch": 0.06},
	"land": {"files": ["land_feet"], "db": -5.0, "pitch": 0.08},
	"step": {"files": ["step_1", "step_2", "step_3", "step_4", "step_5"], "db": -8.0, "pitch": 0.08, "gap": 0.05},
	"potion": {"files": ["potion"], "db": -4.0},
	"corrupted_alert": {"files": ["corrupted_alert_1", "corrupted_alert_2"], "db": -6.0, "pitch": 0.1, "gap": 0.4},
	"chip_burn": {"files": ["chip_burn_1", "chip_burn_2"], "db": -4.0, "pitch": 0.08},
	"enemy_destroy": {"files": ["kenney_enemy_destroy"], "db": -8.0, "pitch": 0.1},
	# Loot e mundo
	"coin": {"files": ["coin_pickup"], "db": -9.0, "pitch": 0.08, "gap": 0.05},
	"pickup": {"files": ["pickup"], "db": -7.0, "pitch": 0.06},
	"equip": {"files": ["kenney_equip"], "db": -8.0, "bus": "UI", "world": false},
	"loot_drop": {"files": ["loot_drop"], "db": -9.0, "pitch": 0.15, "gap": 0.05},
	"loot_rare": {"files": ["loot_rare"], "db": -5.0},
	"loot_unique": {"files": ["loot_unique"], "db": -2.0},
	"chest_open": {"files": ["chest_open"], "db": -5.0, "pitch": 0.05},
	"container_open": {"files": ["container_open"], "db": -5.0, "pitch": 0.05},
	"refine_ok": {"files": ["refine_ok"], "db": -3.0, "bus": "UI", "world": false},
	"refine_fail": {"files": ["refine_fail"], "db": -3.0, "bus": "UI", "world": false},
	# Progressão
	"level_up": {"files": ["level_up"], "db": -7.0},
	# Gastar ponto de chip: baque curto e abafado (antes era um 'plim' com notas).
	"chip_install": {"files": ["nail_body_1"], "db": -6.0, "pitch": 0.05, "bus": "UI", "world": false},
	# Interface
	# Interface: macio e baixinho (passar por cima/focar, apertar, voltar, digitar).
	"ui_move": {"files": ["ui_move"], "db": -20.0, "pitch": 0.05, "bus": "UI", "world": false, "gap": 0.04},
	"ui_confirm": {"files": ["ui_confirm"], "db": -15.0, "pitch": 0.03, "bus": "UI", "world": false, "gap": 0.04},
	"ui_back": {"files": ["ui_back"], "db": -15.0, "pitch": 0.03, "bus": "UI", "world": false, "gap": 0.04},
	"ui_error": {"files": ["ui_error"], "db": -13.0, "bus": "UI", "world": false, "gap": 0.15},
	"ui_type": {"files": ["ui_type_1", "ui_type_2", "ui_type_3", "ui_type_4"], "db": -21.0, "pitch": 0.06, "bus": "UI", "world": false, "gap": 0.02},
	# Missões: abafado (aceitar, ficou pronta, entregar).
	"quest_accept": {"files": ["quest_accept"], "db": -10.0, "bus": "UI", "world": false, "gap": 0.3},
	"quest_ready": {"files": ["quest_ready"], "db": -10.0, "bus": "UI", "world": false, "gap": 0.3},
	"quest_done": {"files": ["quest_done"], "db": -9.0, "bus": "UI", "world": false, "gap": 0.3},
	# Fala de NPC aparecendo letra por letra.
	"npc_type": {"files": ["npc_type_1", "npc_type_2", "npc_type_3"], "db": -22.0, "pitch": 0.08, "bus": "UI", "world": false, "gap": 0.045},
}

## Músicas e ambientes em loop (audio/music).
const MUSIC := {
	# Piano de feltro grave (tools/gerar_piano.py): tema no menu, quase só silêncio no mundo.
	"menu": "menu_piano",
	"mundo": "mundo_piano",
	"ambiente": "ambiente_ferro_velho",
}
