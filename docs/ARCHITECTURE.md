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
world/       mundo aberto: WorldMap e RegionDef (dados), WorldStreamer (carrega blocos),
             CreatureSpawner, Entrance, WorldNpc, FadeOccluder + CameraOcclusion (o que tapa o herói),
             world.tscn (cena principal do jogo), chunks/ e interiors/ (cenas dos blocos), textures/
levels/      arena de combate (usada nos testes de combate)
tools/       ferramentas de criação (gerador da região de teste)
ui/          menu principal, HUD, inventário, minimapa
platform/    tudo que muda por plataforma: identidade (PlatformService), save (SaveBackend)
assets/      modelos (provisórios: Quaternius, CC0)
tests/       testes automáticos (sem tela) e o teste de rede com host + cliente
docs/        GDD.md (design) e este arquivo
```

Planejadas: `addons/map_editor/` (editor de mapa dentro do Godot, ver abaixo), `services/`
(telas de comerciante, ferreiro, encantador) e `quests/`.

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

### Uma área nova do mapa (bloco)
1. Crie a cena do bloco em `world/chunks/` (copie um bloco parecido). Conteúdo em coordenadas
   locais de 0 a 64 m; o chão e tudo que é sólido ficam dentro do nó `Navigation`.
2. Coisas que tapam o herói (árvore, parede da frente, telhado) vão dentro de um `FadeOccluder`;
   telhado de casa leva `zone` (o interior) para sumir quando alguém entra.
3. Criaturas: um `CreatureSpawner` (tipos, quantidade, perseguição, limite, poder, reaparecimento).
4. NPCs de serviço: um `WorldNpc` no lugar fixo dele.
5. No `world/test_world.tres` (inspetor): `chunks[Vector2i(x, z)]` = caminho da cena e
   `chunk_regions[Vector2i(x, z)]` = id da região.
6. Asse a navegação do bloco (selecione `Navigation` > Bake NavigationMesh).

### Uma masmorra / interior
1. Cena em `world/interiors/`, com origem própria longe do mapa (ex.: x = 4000).
2. Registre em `interiors` do WorldMap: caminho, origem, tamanho, região.
3. Uma `Entrance` no mapa apontando para dentro e uma `Entrance` de saída apontando para fora.
   Quem joga na mesma tela entra junto; jogadores de outras máquinas ficam onde estão.
4. Estado que precisa lembrar (baú aberto, chefe morto) vai no save do mundo do host.

### Uma região
1. Um `RegionDef` em `regions` do WorldMap: id, nome, perigo (= poder base do loot), segura ou não, cor.
2. Os blocos apontam para ela em `chunk_regions`.

### Um NPC de serviço (M9)
1. `WorldNpc` fixo no mapa, com o tipo de serviço: comerciante, ferreiro, encantador, banco.
2. A tela do serviço usa o mesmo padrão do inventário: painel por jogador local, cursor próprio,
   comandos executados pelo host.

## Mundo: carregamento e rede

- `WorldStreamer` carrega os blocos a até 1 bloco de cada jogador (3x3) e descarrega a mais de 2.
  Host: em volta de todos; cliente: só dos jogadores dele. O bloco onde alguém está é carregado
  na hora; os vizinhos em segundo plano. Sem chão carregado, o herói espera parado.
- Criaturas são do bloco: nascem quando ele carrega e somem quando descarrega.
- O NetReplicator manda a cada máquina só o que está a 48 m dos jogadores dela, só o que
  mudou, em lotes que cabem num pacote (retrato completo a cada 1 s).

## Testes

```bash
godot --headless --fixed-fps 60 --path coop-dungeon -s tests/smoke_test.gd    # jogo local
godot --headless --path coop-dungeon -s tests/inventory_test.gd                # regras do inventário
godot --headless --fixed-fps 60 --path coop-dungeon -s tests/world_test.gd     # mundo aberto
GODOT=godot coop-dungeon/tests/run_net_test.sh                                 # online: host + cliente
```

Os scripts de teste não usam os tipos do jogo (Player, ItemDB...) direto, porque compilam
antes dos serviços globais existirem: carregam com `load(...)` na hora.
