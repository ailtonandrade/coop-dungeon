# Tradução (português / inglês)

- **Idioma no jogo:** Configurações > **Idioma** (Português / English). Na primeira vez o jogo
  usa o idioma do sistema (português se o Windows estiver em português, senão inglês). Trocar no
  menu principal remonta a tela já traduzida.
- **Onde ficam as traduções:** `locale/textos.csv`, uma planilha: a coluna `keys` é o texto em
  português (a própria chave) e a coluna `en` é o inglês. Abra no Excel/LibreOffice/Google
  Sheets, edite a coluna e salve como CSV (UTF-8, vírgula). O Godot reimporta sozinho.
- Texto sem tradução aparece em português. Nomes próprios (Dona Alda, Zé Gato, Ferro-Velho,
  Sinapse...) ficam iguais de propósito.
- **Texto novo:** depois de escrever textos novos (código, itens, conversas dos NPCs,
  documentos), rode `godot --headless --path . -s tools/extrair_textos.gd`: ele junta tudo no
  CSV, mantém as traduções que já existem e diz quantos estão sem tradução.
- **No código:** botões e rótulos com texto fixo o Godot traduz sozinho. Texto montado com
  valores precisa passar pela tradução antes: `Txt.t("Versão %s") % versao` (não
  `"Versão %s" % versao`, que não acha a chave).
- **Conversas dos NPCs:** as respostas e botões são traduzidos pela planilha; as **palavras que o
  jogador digita** também (a linha "agua" -> "water" faz quem joga em inglês achar o assunto
  digitando "water").
- **Outro idioma (espanhol...):** acrescente a coluna (ex.: `es`) no CSV, a língua em
  `Txt.LANGUAGES` (`core/txt.gd`) e o arquivo `res://locale/textos.es.translation` em
  Configurações do Projeto > Localização.
- Nos testes automáticos (sem tela) o jogo fica sempre em português.
