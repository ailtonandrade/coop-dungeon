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

## A ficha (QuestDef)

- **Categoria**: principal ou secundária.
- **Começa por**:
  - **npc**: o NPC (`giver`) oferece na conversa (Aceito / Agora não);
  - **area**: começa sozinha ao entrar na área de id `start_target`;
  - **gatilho**: começa ao usar o gatilho de id `start_target`.
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

Ao cumprir um objetivo: **dar um item**, **ensinar fatos** e uma **reação num objeto do mapa**
pelo nome do nó: **sumir** (some e deixa passar), **aparecer** (começa escondido e surge) ou
**abrir** (portão da história abre de vez; contêiner trancado destrava). As reações ficam no save
do mundo e valem para os amigos online.

## No jogo

- **questLog** no canto superior esquerdo: até 3 missões, título, objetivos (caixinha e contador)
  e, terminada, "Volte para <NPC>". Pisca quando muda.
- **Para onde ir**: losango amarelo no minimapa no próximo passo da missão (acampamento mais perto
  da classe a matar, o NPC para falar, o gatilho ou a área; pronta, o NPC que recebe). Longe, o
  losango fica na borda do minimapa apontando a direção, e o questLog mostra a distância em metros.
  As posições são lidas dos arquivos de todos os blocos, mesmo os que ainda não carregaram.
- Progresso do grupo, no save do mundo, sincronizado online.

## As que já existem

| Missão | NPC | Objetivo | Recompensa |
|---|---|---|---|
| Ferro de gangue (repetível) | Brando | 6 bandidos de cano | 150 parafusos, 120 XP |
| Guardas de lata (depois de entrar no Lab 4) | Seu Gouveia | 4 androides de segurança | 300 parafusos, 250 XP, amuleto |

Testes: `tests/quest_test.gd` e `tests/quest_editor_test.gd`.
