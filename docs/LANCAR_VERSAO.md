# Lançar versão nova (e como o jogo atualiza sozinho)

## Onde ficam as versões

- **`ailtonandrade/coop-dungeon`**: o código do projeto (pode ser privado). Aqui ficam o modo
  construtor, o editor de missões, os editores do Godot, testes e docs.
- **`ailtonandrade/corrumpted`**: repositório **público só de downloads**. Cada versão é um
  release com `Corrumpted-vX.Y.Z-Windows.zip`, `-Linux.zip` e `-Web.zip`, e o README de como
  jogar (`tools/release_readme.md`). É aqui que os jogos instalados procuram versão nova.
  O jogo exportado **não leva** o `/construir`, o `/missoes`, o gravador de mapa nem os editores
  (filtro de exportação em `export_presets.cfg`).

## Lançar

Dois cliques em **`tools/lancar_release.bat`** (Windows). Precisa, uma vez:
- **Git** e **GitHub CLI** (`gh`, https://cli.github.com) logado: `gh auth login`;
- **Godot 4.7** com os **modelos de exportação** (no Godot: Editor > Gerenciar modelos de
  exportação > Baixar e instalar). Na primeira vez o bat pergunta onde está o `.exe` do Godot
  (arraste o arquivo para a janela) e guarda.

O que ele faz:
1. Pega o que tem de novo no GitHub e mostra as mudanças que ainda não foram enviadas (elas vão
   junto, inclusive as peças do modo construtor nas cenas dos blocos).
2. Pergunta o número da versão nova (Enter aceita a sugestão: a atual + 1 no último número) e
   uma linha do que mudou.
3. Grava a versão no `project.godot`, exporta Windows, Linux e Web com o seu Godot e compacta.
4. Faz o commit, a tag `v<versão>` e manda o código para o `coop-dungeon`.
5. Cria o `corrumpted` na primeira vez (público, com o README) e publica a versão lá. O navegador
   abre na página da versão.

O workflow do GitHub (`.github/workflows/release.yml`) continua para exportar na nuvem à mão
(Actions > Release > Run workflow), mas não publica mais nada.

## Como o jogo dos jogadores atualiza

`core/updater.gd` (serviço `Updater`):
- Ao abrir o jogo e a cada 30 minutos, consulta o release mais recente em `ailtonandrade/corrumpted`.
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
