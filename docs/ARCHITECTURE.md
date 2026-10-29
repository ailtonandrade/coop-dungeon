# Arquitetura

Como o projeto está organizado, as regras que mantêm ele escalável e o passo a passo para
acrescentar coisas novas (item, criatura, região, NPC) sem mexer no resto.

## Pastas

```
core/        serviços do jogo inteiro e regras de grupo
             InputService (controle -> slot, mira), PlayerInput (comandos de um jogador),
             SaveService (fachada de save), Settings (preferências da máquina),
             PlayerManager (vagas P1-P4, corda do sofá), GameConfig (números do jogo)
net/         sessão online e replicação
             NetService (offline/host/cliente), NetReplicator (entidades e estado),
             LanDiscovery (busca de mundos na rede local)
characters/  o que todo personagem usa
             CharacterAnimator (toca AÇÕES), AnimSets (ação -> clipe por tipo de corpo),
             ProceduralAnims (pulo/queda/escalada montados por código para o esqueleto humano)
player/      o herói (movimento, mira, combate, inventário) e a cena dele
enemies/     criaturas (IA, ataques) e o gerador de ondas da arena de teste
combat/      Health, Combat (golpes em leque, mira assistida, efeitos), Projectile
items/       ItemDB (catálogo), Inventory (regras estilo Tibia), ItemVisuals (peças no boneco), Loot
camera/      câmera compartilhada (enquadra os jogadores da máquina, projeta a mira do mouse)
levels/      mapas (hoje a arena de teste; depois os blocos do mundo aberto)
ui/          menu principal, HUD, inventário, minimapa
platform/    tudo que muda por plataforma: identidade (PlatformService), save (SaveBackend)
assets/      modelos (provisórios: Quaternius, CC0)
tests/       testes automáticos (sem tela) e o teste de rede com host + cliente
docs/        GDD.md (design) e este arquivo
```

Planejadas para o mundo aberto (M7+): `world/` (WorldStreamer, regiões, blocos, entradas de
masmorra), `npcs/` (comerciante, ferreiro, encantador) e `quests/`.

## Regras

1. **Entrada só pelo InputService.** Nada lê `Input` direto. O herói lê um `PlayerInput`, que é
   igual vindo do controle local ou da rede. Menu aberto bloqueia só os comandos daquele slot.
2. **Save só pelo SaveService.** Nada grava arquivo direto. O backend muda por plataforma
   (`platform/`); testes usam uma pasta separada (`use_test_storage`).
3. **O host é a verdade.** Simulação (movimento, IA, dano, loot, inventário) roda só onde
   `multiplayer.is_server()` é verdade (offline também é "host"). Clientes mandam comandos e
   mostram o que chega. Todo sistema novo já nasce assim.
4. **Tudo que nasce e morre na fase passa pelo NetReplicator** (`spawn`), com dados simples
   (números, textos, vetores, Dictionary/Array). Entidades replicadas implementam
   `get_net_state()` / `apply_net_state()`. Efeitos visuais vão por `broadcast_fx`;
   coisa só do dono (inventário) por `send_to_peer`.
5. **Animação por ação, nunca por nome de clipe.** O código pede `"move"`, `"slash"`, `"hit"`;
   o mapa do tipo de corpo (AnimSets) escolhe o clipe do modelo. Assim cada criatura tem as
   próprias animações.
6. **Dados separados de código.** Itens, criaturas e (depois) regiões e NPCs são tabelas/arquivos
   de dados; o código é genérico.
7. **Números do jogo em GameConfig** (ou na tabela do dado), não espalhados.
8. **Plataforma só em `platform/`.** Xbox/Steam/PlayFab nunca aparecem no resto do código.
9. **GDScript tipado**, sem C#, pelo port de console.
10. **Toda mudança roda os testes** (abaixo). Teste novo para sistema novo, de preferência
    passando pelos botões de verdade (`Input.parse_input_event`).

## Como acrescentar

### Um item novo
1. Uma linha em `ItemDB.DEFS`: nome, casa (`slot`), atributos (`damage`, `armor`, `hp`,
   `damage_pct`, `capacity` para bolsas) e o desenho (`look`).
2. Se quiser que caia de criaturas, ponha o id em `ItemDB.DROP_POOL`.
3. Desenho novo: um caso em `ItemVisuals.build` (peça 3D), `ItemVisuals.MOUNTS` (osso onde vai)
   e `ItemIcon.draw_glyph` (ícone). Peito/pernas/pés pintam o modelo (`ItemVisuals.PAINTS`).
4. Trocar por modelo .glb de verdade: `ItemVisuals.build` passa a instanciar o .glb; o resto não muda.

### Uma criatura nova (cachorro, rato, dragão...)
1. Modelo em `assets/creatures/<nome>/` (1 unidade = 1 m, pé na origem, olhando para +Z).
2. Mapa de animações em `AnimSets` (ex.: `QUADRUPED`): para cada ação, os clipes do modelo
   em ordem de preferência. Ações que a IA usa: `idle`, `move`, o ataque dela, `hit`, `death`.
3. Ficha da criatura (hoje `Enemy.STATS`; vai virar um arquivo de dados por criatura):
   modelo, mapa de animações, vida, velocidade, alcance, ataque, dano.
4. Comportamento diferente (voar, cuspir fogo, fugir) entra como um tipo de IA novo,
   reaproveitando navegação, aviso de ataque (fica vermelho) e replicação.

### Uma região, cidade ou masmorra (M7+)
1. Blocos de 64 x 64 m montados no editor com peças de 1 m (`levels/` -> `world/`).
2. Um arquivo de região: blocos, nível de perigo, criaturas, poder do loot, música.
3. Entradas (porta/escada) ligam o mapa a interiores; o grupo da mesma tela entra junto.
4. Estado que precisa lembrar (baú aberto, chefe morto) vai no save do mundo do host.

### Um NPC de serviço (M9)
1. NPC fixo no mapa (posição desenhada à mão), com o tipo de serviço: comerciante, ferreiro,
   encantador, banco.
2. A tela do serviço usa o mesmo padrão do inventário: painel por jogador local, cursor próprio,
   comandos executados pelo host.

## Testes

```bash
godot --headless --fixed-fps 60 --path coop-dungeon -s tests/smoke_test.gd    # jogo local
godot --headless --path coop-dungeon -s tests/inventory_test.gd                # regras do inventário
GODOT=godot coop-dungeon/tests/run_net_test.sh                                 # online: host + cliente
```

Os scripts de teste não usam os tipos do jogo (Player, ItemDB...) direto, porque compilam
antes dos serviços globais existirem: carregam com `load(...)` na hora.
