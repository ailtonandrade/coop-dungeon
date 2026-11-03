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
	"shot": {"files": ["nail_shot_1", "nail_shot_2"], "db": -4.0, "pitch": 0.08},
	"enemy_shot": {"files": ["enemy_shot"], "db": -5.0, "pitch": 0.1},
	"projectile_hit": {"files": ["nail_impact"], "db": -8.0, "pitch": 0.15, "gap": 0.04},
	"player_hurt": {"files": ["player_hurt_1", "player_hurt_2"], "db": -2.0, "pitch": 0.08, "gap": 0.08},
	"player_down": {"files": ["player_down"], "db": -1.0},
	"revive": {"files": ["revive"], "db": -3.0},
	"dodge": {"files": ["dodge"], "db": -7.0, "pitch": 0.1},
	"jump": {"files": ["kenney_jump"], "db": -10.0, "pitch": 0.08},
	"land": {"files": ["kenney_land"], "db": -10.0, "pitch": 0.1},
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
	"level_up": {"files": ["level_up"], "db": -1.0},
	"chip_install": {"files": ["chip_install"], "db": -4.0, "bus": "UI", "world": false},
	# Interface
	# Interface: macio e baixinho (passar por cima/focar, apertar, voltar, digitar).
	"ui_move": {"files": ["ui_move"], "db": -20.0, "pitch": 0.05, "bus": "UI", "world": false, "gap": 0.04},
	"ui_confirm": {"files": ["ui_confirm"], "db": -15.0, "pitch": 0.03, "bus": "UI", "world": false, "gap": 0.04},
	"ui_back": {"files": ["ui_back"], "db": -15.0, "pitch": 0.03, "bus": "UI", "world": false, "gap": 0.04},
	"ui_error": {"files": ["ui_error"], "db": -13.0, "bus": "UI", "world": false, "gap": 0.15},
	"ui_type": {"files": ["ui_type_1", "ui_type_2", "ui_type_3", "ui_type_4"], "db": -21.0, "pitch": 0.06, "bus": "UI", "world": false, "gap": 0.02},
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
