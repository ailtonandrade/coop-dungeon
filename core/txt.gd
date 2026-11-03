class_name Txt
extends RefCounted
## Tradução (português -> inglês...). O texto em português é a própria chave: em português o
## jogo mostra ele mesmo; nos outros idiomas, a tradução de locale/textos.csv (coluna do
## idioma). Botões e rótulos com texto fixo o Godot já traduz sozinho; use Txt.t() quando o texto
## vai ser montado (Txt.t("Versão %s") % v) ou não vai direto para a interface.
## Para gerar/atualizar a lista de textos: python3 tools/extrair_textos.py

const LANGUAGES := {"pt_BR": "Português", "en": "English"}


static func t(text: String) -> String:
	return String(TranslationServer.translate(text))
