@tool
class_name DialogueTopic
extends Resource
## Um assunto da conversa com o NPC (como as palavras do Tibia). Aparece como botão (`label`)
## e também responde se o jogador digitar uma das `keywords`. `hidden`: só por digitação (não
## vira botão), bom para segredos e easter eggs.
##
## Gatilhos: só aparece/responde se o grupo sabe `requires` e não sabe `forbids`, e se quem
## conversa tem `requires_item` na mochila. Responder ensina `teaches` (que liberam portões,
## contêineres, entradas e outras falas) e pode dar `gives_item` (uma vez por mundo).

## Texto do botão. Vazio = a primeira palavra de `keywords`.
@export var label := ""
## Palavras que o jogador pode digitar (sem acento ou maiúscula, tanto faz).
@export var keywords: PackedStringArray = []
## Resposta do NPC.
@export_multiline var text := ""
@export var hidden := false
@export var requires: Array[String] = []
@export var forbids: Array[String] = []
## Id de um item que quem conversa precisa ter (mochila ou equipado).
@export var requires_item := ""
@export var teaches: Array[String] = []
## Id de um item que o NPC entrega (uma vez por mundo).
@export var gives_item := ""
@export var priority := 0


func button_text() -> String:
	if not label.is_empty():
		return label
	return keywords[0] if not keywords.is_empty() else "?"
