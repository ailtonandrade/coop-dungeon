# Missões (questLog)

Missões dos NPCs e do mapa. A história principal (o D3M1URGO) segue nas entrelinhas pelo
sistema de Conhecimento (`docs/LORE.md`); uma missão pode ser **principal** ou **secundária**
(as principais ficam primeiro no questLog, com ★ no editor).

## Criar dentro do jogo: `/missoes` (só você, rodando pelo Godot)

Digite **/missoes** no chat (não vai para a sala). Abre o editor: à esquerda as missões de
`world/quests/`, à direita a ficha. **Salvar** grava o `.tres` e a missão já vale na hora.
**Nova**, **Duplicar** e **Apagar** na lista. Os botões **perto** preenchem com o que está do
lado do herói (NPC, área, gatilho, porta, contêiner, peça do mapa). Este editor fica **de fora do
jogo exportado** (como o /editar): ninguém que baixar o jogo tem acesso.

Peças de missão (coloque pelo **/editar**, categoria **Missoes**, ou no editor de mapa):
- **Gatilho de missão**: ponto de LB / F. Visual: invisível, alavanca, terminal, caixa ou placa;
  aviso de perto, mensagem ao usar, uso único. O id é o nome do nó (ou o campo Trigger Id).
- **Área de missão**: círculo (raio ajustável) que dispara quando alguém do grupo entra. Invisível
  no jogo; aparece no editor do Godot e com /editar ou /missoes ligados.

### A ficha se ajeita ao que você escolhe

- **Começa por** muda o resto: NPC não pede área; área/gatilho/item pedem o alvo (com **lista**);
  sem NPC que recebe, somem as falas de andamento/entrega.
- Cada **objetivo** mostra só o que o tipo usa: matar → criatura e quantidade; falar → NPC,
  palavras e respostas; interagir → gatilho; chegar → área; ler/usar/pegar → item.
- Botões **lista**: NPCs, áreas e gatilhos do mapa inteiro **separados por região**; itens e
  documentos numa lista só. **perto** pega o que está do lado do herói.
- **Nome da área/gatilho**: no `/editar`, colocar uma área ou gatilho de missão já abre a caixa
  do nome (vira o id que a missão usa, ex.: `patio_conteineres`); **F** em cima renomeia. Com o
  `/missoes` ou o `/editar` abertos, o nome aparece escrito em cima de cada uma.
- Com o `/missoes` ou o `/editar` abertos, ninguém te ataca.

## A ficha (QuestDef)

- **Categoria**: principal ou secundária.
- **Começa por**:
  - **npc**: o NPC (`giver`) oferece na conversa (Aceito / Agora não);
  - **area**: começa sozinha ao entrar na área de id `start_target`;
  - **gatilho**: começa ao usar o gatilho de id `start_target`;
  - **item**: começa quando alguém do grupo **tem** o item de id `start_target` (pegou do chão, de
    um *Item de missão* do mapa, ganhou, comprou ou já começou com ele, como o diário da mochila).
- **Item ao começar** (ex.: o NPC te entrega algo), falas (oferecer, andamento, entregar), resumo.
- **Volta para entregar**: com NPC, termina voltando nele; sem, conclui sozinha na hora.
- **Requer fatos** (só aparece depois) e **Ensina fatos** (ao concluir), para ligar com a história.
- **Recompensa**: parafusos e experiência para cada um do grupo, item para quem entrega; repetível,
  com **espera para repetir** em minutos (o NPC diz "volte em X min" enquanto isso).

### O que são "fatos"

Um fato é uma etiqueta de "o grupo já descobriu isso", com um nome (`diario_helena`,
`lab4_portao`, `sabe_nome_demiurgo`...). É o mesmo sistema da história escondida: ler um
documento, ouvir certa fala de NPC, abrir um portão por código ou concluir uma missão grava um
fato no save do mundo, para o grupo todo. Na missão:
- **Só aparece se o grupo já sabe**: a missão fica escondida até o grupo ter aqueles fatos
  (ex.: "Guardas de lata" exige `lab4_portao`, então só aparece depois de abrirem o Lab 4);
- **Ao concluir / ao cumprir, o grupo passa a saber**: grava fatos novos, que podem liberar outra
  missão, uma fala nova de NPC, um portão ou um contêiner.
Assim dá para encadear missões (uma libera a outra) e ligar com a história sem programar nada.

De onde vêm os fatos:
- **Documento** lido (campo Teaches da ficha do documento; vazio = o id dele);
- **Fala de NPC**: assunto da conversa com Teaches (e cumprimentos/puxar assunto);
- **Portão com código ou invasão**: o fato de destravar (Unlock Fact);
- **Missão** concluída ou objetivo cumprido (Ensina / passa a saber);
- **Área de missão** ao entrar e **gatilho de missão** ao usar (campo Teaches da peça);
- **Região**: sozinho, `visitou_<id da região>` na primeira vez que o grupo entra
  (`visitou_vila`, `visitou_planicie`, `visitou_bosque`, `visitou_colinas`, `visitou_caverna`).

## Objetivos (QuestObjective)

| Tipo | O que é |
|---|---|
| **matar** | derrotar N criaturas da classe (`punk`, `atirador`, `corrompido`, `androide`) |
| **falar** | dizer ao NPC as **palavras em ordem**: cada uma só vale depois da anterior, e ele responde a cada uma (vai revelando). Opção de a próxima palavra virar botão (controle) |
| **interagir** | usar o gatilho de missão de id X |
| **chegar** | entrar na área de missão de id X |
| **ler** | ler pelo inventário (Y / E) o item de id X (diário, carta), ou o documento da história de id X (vale também o do mapa) |
| **usar** | usar pelo inventário (Y / E) o item de id X (ficha do item: *Uso → usable*; *consume_on_use* faz sumir) |
| **pegar** | ter o item de id X |

Ler, usar e pegar acontecem no inventário: **sem ponto no mapa** (o questLog diz "no inventário").
No `/missoes`, o botão "perto" desses tipos (e do início "item") abre a lista de itens (e de
documentos, no "ler"); um Item de missão perto do herói vem no topo.

Ao cumprir um objetivo: **dar um item**, **ensinar fatos** e uma **reação num objeto do mapa**
pelo nome do nó: **sumir** (some e deixa passar), **aparecer** (começa escondido e surge) ou
**abrir** (portão da história abre de vez; contêiner trancado destrava). As reações ficam no save
do mundo e valem para os amigos online.

## Item de ler / usar e Item de missão no mapa

- **Ficha do item** (painel Itens / Inspector), grupo *Uso*: `document` (id do documento em
  `world/lore/lore.tres` que abre ao usar), `usable`, `consume_on_use`. Casa `missao` = fica na
  mochila e não se vende. No texto do documento, `{nome}` vira o nome do herói e `{companhia}`
  diz se veio só ou com o grupo.
- **Item de missão** (`/editar`, categoria Missoes, `item_de_missao`): o próprio item no chão;
  **F** em cima escolhe qual item ele dá (o mesmo painel do conteúdo do contêiner). LB / F pega e
  vai direto para a mochila; some depois (uma vez por mundo). Junto com início **item** ou
  objetivo **pegar**, é o "achei o diário nos escombros e a missão começou".

## No jogo

- **questLog** no canto superior esquerdo: até 3 missões, título, objetivos (caixinha e contador)
  e, terminada, "Volte para <NPC>". Pisca quando muda.
- **Para onde ir**: losango amarelo no minimapa no próximo passo da missão (acampamento mais perto
  da classe a matar, o NPC para falar, o gatilho ou a área; pronta, o NPC que recebe). Longe, o
  losango fica na borda do minimapa apontando a direção, e o questLog mostra a distância em metros.
  As posições são lidas dos arquivos de todos os blocos, mesmo os que ainda não carregaram.
- Progresso do grupo, no save do mundo, sincronizado online.
- **Tela de missões** na roda do inventário (I / Shift, depois RB / Q até "missões"): as em
  andamento com os objetivos e as concluídas, separadas em principais e secundárias.

## As que já existem

| Missão | NPC | Objetivo | Recompensa |
|---|---|---|---|
| ★ Quem sou eu (a primeira; começa com o diário da mochila) | — | ler o diário | 25 XP |
| Ferro de gangue (repetível) | Brando | 6 bandidos de cano | 150 parafusos, 120 XP |
| Guardas de lata (depois de entrar no Lab 4) | Seu Gouveia | 4 androides de segurança | 300 parafusos, 250 XP, amuleto |

Testes: `tests/quest_test.gd`, `tests/quest_editor_test.gd` e `tests/diary_test.gd`.
