# Lançar versão nova (e como o jogo atualiza sozinho)

## Lançar

Dois cliques em **`tools/lancar_release.bat`** (Windows, precisa do Git instalado):

1. Ele pega o que tem de novo no GitHub e mostra as mudanças que ainda não foram enviadas
   (elas vão junto, inclusive as peças do modo construtor nas cenas dos blocos).
2. Pergunta o número da versão nova (Enter aceita a sugestão: a atual + 1 no último número) e
   uma linha do que mudou.
3. Grava a versão no projeto (`application/config/version` no `project.godot`), faz o commit,
   cria a tag `v<versão>` e manda tudo. O navegador abre na página de Actions.
4. Em uns 5 minutos o GitHub exporta Windows, Linux e Web e publica em **Releases**
   (`.github/workflows/release.yml`).

Sem o bat: mude a versão no `project.godot`, faça commit e push, e mande a tag
(`git tag v0.2.0` e `git push origin v0.2.0`). A exportação usa sempre o número da tag.

## Como o jogo dos jogadores atualiza

`core/updater.gd` (serviço `Updater`):
- Ao abrir o jogo e a cada 30 minutos, consulta o release mais recente no GitHub.
- Tendo versão maior que a do jogo, o menu principal mostra o cartão **NOVA VERSÃO
  DISPONÍVEL** com as novidades, **Atualizar agora** e **Depois**. "Depois" deixa um selo no
  canto do menu ("⬆ Versão X disponível") que abre o cartão de novo.
- **Atualizar agora** baixa o .zip da plataforma (com barra de progresso), confere o SHA-256
  que o próprio GitHub calcula para o arquivo, extrai e deixa um script trocar os arquivos
  depois que o jogo fecha; o jogo abre de novo já atualizado. O save não é tocado (fica na
  pasta do usuário, não na do jogo).
- Se a pasta do jogo não deixa gravar (instalado em Arquivos de Programas, por exemplo), o
  botão vira **Baixar no site** e abre a página da versão.
- Rodando pelo editor do Godot (sua cópia de desenvolvimento) só avisa: atualize pelo Git.
- Online, host e convidados precisam estar na mesma versão (o jogo recusa versão diferente com
  a mensagem dizendo qual é a de cada um).
