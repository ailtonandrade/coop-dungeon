# Missões (questLog)

Missões dos NPCs e do mapa. A história principal (o D3M1URGO) segue nas entrelinhas pelo
sistema de Conhecimento (`docs/LORE.md`); uma missão pode ser **principal** ou **secundária**
(as principais ficam primeiro no questLog, com ★ no editor).

## Criar dentro do jogo: `/missoes` (só você, rodando pelo Godot)

Digite **/missoes** no chat (não vai para a sala). Abre o editor: à esquerda as missões de
`world/quests/`, à direita a ficha. **Salvar** grava o `.tres` e a missão já vale na hora.
**Nova**, **Duplicar** e **Apagar** na lista. Os botões **perto** preenchem com o que está do
lado do herói (NPC, área, gatilho, porta, contêiner, peça do mapa). Este editor fica **de fora do
jogo exportado** (como o /construir): ninguém que baixar o jogo tem acesso.

Peças de missão (coloque pelo **/construir**, categoria **Missoes**, ou no editor de mapa):
- **Gatilho de missão**: ponto de LB / F. Visual: invisível, alavanca, terminal, caixa ou placa;
  aviso de perto, mensagem ao usar, uso único. O id é o nome do nó (ou o campo Trigger Id).
- **Área de missão**: círculo (raio ajustável) que dispara quando alguém do grupo entra. Invisível
  no jogo; aparece no editor do Godot e com /construir ou /missoes ligados.

## A ficha (QuestDef)

- **Categoria**: principal ou secundária.
- **Começa por**:
  - **npc**: o NPC (`giver`) oferece na conversa (Aceito / Agora não);
  - **area**: começa sozinha ao entrar na área de id `start_target`;
  - **gatilho**: começa ao usar o gatilho de id `start_target`.
- **Item ao começar** (ex.: o NPC te entrega algo), falas (oferecer, andamento, entregar), resumo.
- **Volta para entregar**: com NPC, termina voltando nele; sem, conclui sozinha na hora.
- **Requer fatos** (só aparece depois) e **Ensina fatos** (ao concluir), para ligar com a história.
- **Recompensa**: parafusos e experiência para cada um do grupo, item para quem entrega; repetível.

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
- Progresso do grupo, no save do mundo, sincronizado online.

## As que já existem

| Missão | NPC | Objetivo | Recompensa |
|---|---|---|---|
| Ferro de gangue (repetível) | Brando | 6 bandidos de cano | 150 parafusos, 120 XP |
| Guardas de lata (depois de entrar no Lab 4) | Seu Gouveia | 4 androides de segurança | 300 parafusos, 250 XP, amuleto |

Testes: `tests/quest_test.gd` e `tests/quest_editor_test.gd`.
