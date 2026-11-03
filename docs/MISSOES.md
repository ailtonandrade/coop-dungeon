# Missões (questLog)

Missões secundárias dadas pelos NPCs. A história principal (o D3M1URGO) continua nas
entrelinhas, pelo sistema de Conhecimento (`docs/LORE.md`); as missões são o que faz o jogo
escalar: trabalho, recompensa e motivo para ir longe.

## Como criar uma missão (no Godot)

1. Em `world/quests/`, duplique uma ficha (`.tres`) ou crie um recurso novo do tipo **QuestDef**.
2. Preencha no Inspector:
   - **Id** (único, sem espaço), **Title** (aparece no questLog) e **Giver** (nome do NPC no mapa,
     igual ao do NPC: "Brando", "Seu Gouveia"...);
   - **Offer Text** (fala ao oferecer), **Progress Text** (se voltar antes), **Done Text** (ao
     entregar) e **Summary** (uma linha embaixo do título no questLog);
   - **Objectives**: cada um é um **QuestObjective** com **Target** (classe da criatura: `punk`,
     `atirador`, `corrompido`, `androide`), **Amount** e, se quiser, **Label** (nome no questLog);
   - **Requires** (fatos que o grupo precisa saber para a missão aparecer) e **Teaches** (fatos
     que o grupo aprende ao entregar), ligando com a história quando fizer sentido;
   - **Recompensa**: parafusos e experiência para cada um do grupo, e um item para quem entrega;
     **Repeatable** deixa pegar de novo.
3. Pronto: o NPC passa a oferecer na conversa ("» Trabalho: ..."), com Aceito / Agora não.

## No jogo

- **questLog** no canto superior esquerdo: até 3 missões, com título, objetivos (caixinha e
  contador) e, terminada, "Volte para <NPC>". Pisca quando muda.
- Só conta a classe certa de criatura, de qualquer um do grupo (co-op).
- Na conversa com o NPC: "» Entregar: ..." quando estiver pronta; "» ... (em andamento)" antes.
- O progresso é do grupo, fica no save do mundo e vai para os convidados online.

## As que já existem

| Missão | NPC | Objetivo | Recompensa |
|---|---|---|---|
| Ferro de gangue (repetível) | Brando | 6 bandidos de cano | 150 parafusos, 120 XP |
| Guardas de lata (depois de entrar no Lab 4) | Seu Gouveia | 4 androides de segurança | 300 parafusos, 250 XP, amuleto |

Teste: `tests/quest_test.gd`.
