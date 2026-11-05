@tool
class_name FactDef
extends Resource
## Ficha de um fato do Conhecimento (o que o grupo já sabe da história). Um arquivo por fato em
## res://world/lore/facts/<id>.tres. Aparece na tela de Conhecimento (roda do inventário: RB/Q)
## com o título e de onde veio. Fato sem ficha aparece com o próprio id e a origem gravada na
## hora em que o grupo aprendeu (documento, conversa, missão...).

## O mesmo id usado em teaches/requires/unlock_fact.
@export var id := ""
## Como o jogador vê o fato ("A senha do portão do Lab 4").
@export var title := ""
## Uma ou duas linhas do que se sabe (opcional).
@export_multiline var description := ""
## Onde se obtém ("Caderno de capa vermelha, na casa da Helena"). Vazio = a origem gravada.
@export var source := ""
## Fato interno (marcador de missão, porta aberta...): não aparece na tela.
@export var hidden := false
