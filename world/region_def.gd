class_name RegionDef
extends Resource
## Uma região do mapa (vila, planície, bosque, masmorra...). Os blocos do mapa apontam
## para a região deles no WorldMap. Editável no inspetor do Godot.

@export var id := ""
@export var display_name := ""
## Perigo (aparece para o jogador). Também é o poder base do loot que cai aqui.
@export_range(0, 99) var danger := 1
## Região segura (cidade): sem criaturas e sem combate.
@export var safe := false
## Cor do nome da região na tela e no mapa.
@export var color := Color.WHITE
