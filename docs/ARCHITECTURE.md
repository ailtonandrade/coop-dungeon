# Arquitetura

Como o projeto está organizado, as regras que mantêm ele escalável e o passo a passo para
acrescentar coisas novas (item, criatura, região, NPC) sem mexer no resto.

## Pastas

```
core/        serviços do jogo inteiro e regras de grupo; Characters (personagens da máquina:
             até 5, visual, chip; o save fica no SaveService)
             InputService (controle -> slot, mira), PlayerInput (comandos de um jogador),
             SaveService (fachada de save), Settings (preferências da máquina),
             PlayerManager (vagas P1-P4, corda do sofá), GameConfig (números do jogo)
net/         sessão online e replicação
             NetService (offline/host/cliente), NetReplicator (entidades e estado),
             LanDiscovery (busca de mundos na rede local), InternetAccess (UPnP abre a porta
             sozinho, código do mundo, aviso de CGNAT). Ver [`JOGAR_ONLINE.md`](JOGAR_ONLINE.md)
characters/  o que todo personagem usa
             CharacterAnimator (toca AÇÕES), AnimSets (ação -> clipe por tipo de corpo),
             ProceduralAnims (pulo/queda/escalada montados por código para o esqueleto humano)
player/      o herói (movimento, mira, combate, inventário) e a cena dele; Progression (nível,
             XP e chips piratas, salvos no personagem)
audio/       Sound (autoload: eventos, som 3D, música/ambiente, barramentos), SoundBank (evento ->
             arquivos, volume, afinação), Voice (autoload: voz pela rede, rádio, mudo do host),
             sfx/ e music/. Ver [`SOM.md`](SOM.md)
enemies/     criaturas (IA, ataques) e o gerador de ondas da arena de teste
combat/      Health, Combat (golpes em leque, mira assistida, efeitos), Projectile, HitFx (número
             de dano, faíscas, explosão de morte, coluna de subir de nível)
items/       ItemDB (lê as fichas), ItemDef/ItemDrop (ficha do item e regra de loot), Inventory
             (regras estilo Tibia), ItemVisuals (peças no boneco), Loot
items/defs/  uma ficha por item (.tres), editadas no painel "Itens"
camera/      câmera compartilhada: de cima (enquadra os jogadores da máquina, projeta a mira do
             mouse) ou atrás do herói, estilo GTA, quando a tela tem um jogador só (opção na pausa)
world/       mundo aberto: WorldMap e RegionDef (dados), WorldStreamer (carrega blocos),
             CreatureSpawner, Entrance, WorldNpc, LootContainer + ContainerItem (baús com
             saque), Services (regras dos serviços da cidade),
             FadeOccluder + CameraOcclusion (o que tapa o herói),
             world.tscn (cena principal do jogo), chunks/ e interiors/ (cenas dos blocos), textures/
levels/      arena de combate (usada nos testes de combate)
tools/       scripts de uma vez só: build_ui_skin (texturas e tema da interface), build_tiles (peças de pintura), build_prefabs (peças prontas),
             migrate_map, paint_demo_ruin e build_test_world (gerou a região de teste inicial;
             não é o fluxo de criação: o mapa se edita à mão no editor)
addons/item_editor/ painel "Itens": fichas, modelos 3D, encaixe com prévia, ícone, lojas e loot
             (lógica testável em item_tools.gd). Ver [`EDITOR_DE_ITENS.md`](EDITOR_DE_ITENS.md)
addons/map_editor/  editor de mapa: painel "Mapa do Mundo" (world_map_dock, map_grid_view)
             e MapTools (a lógica: criar bloco/masmorra, ligar e sincronizar entradas, validar,
             assar navegação), usado pelo painel e pelos testes
ui/          menu principal (com a vila 3D ao fundo: MenuBackdrop), HUD (PlayerCard, RegionBanner),
             inventário, Chip pirata (ChipPanel), escolha de personagem (CharacterSelect, com
             CharacterPreview), configurações (SettingsPanel, no menu e na pausa), tela de serviço
             (ServicePanel), minimapa
ui/skin/     visual da interface: texturas das molduras, corrumpted_theme.tres (tema do projeto
             inteiro) e UiSkin (paleta, fontes, peças desenhadas por código)
ui/fonts/    Chakra Petch (texto) e Black Ops One (títulos), licença OFL (vai junto na exportação)
platform/    tudo que muda por plataforma: identidade (PlatformService), save (SaveBackend)
assets/      modelos (provisórios: Quaternius, CC0)
tests/       testes automáticos (sem tela) e o teste de rede com host + cliente
docs/        GDD.md (design) e este arquivo
```

Planejadas: `services/` (telas de comerciante, ferreiro, encantador) e `quests/`.
Como usar o editor de mapa: [`EDITOR_DE_MAPA.md`](EDITOR_DE_MAPA.md).

## Regras

1. **Entrada só pelo InputService.** Nada lê `Input` direto. O herói lê um `PlayerInput`, que é
   igual vindo do controle local ou da rede. Andar e mirar já vêm no chão do mundo (a câmera de
   cada tela é contada na máquina de quem joga; o host não precisa saber dela). Menu aberto bloqueia só os comandos daquele slot.
2. **Save só pelo SaveService.** Nada grava arquivo direto. O backend muda por plataforma
   (`platform/`); testes usam uma pasta separada (`use_test_storage`).
3. **O host é a verdade.** Simulação (movimento, IA, dano, loot, inventário) roda só onde
   `multiplayer.is_server()` é verdade (offline também é "host"). Clientes mandam comandos e
   mostram o que chega. Todo sistema novo já nasce assim.
4. **Tudo que nasce e morre na fase passa pelo NetReplicator** (`spawn`), com dados simples
   (números, textos, vetores, Dictionary/Array). Entidades replicadas implementam
   `get_net_state()` / `apply_net_state()`. Efeitos visuais vão por `broadcast_fx`;
   coisa só do dono (inventário) por `send_to_peer`.
5. **Som por evento, nunca por arquivo.** O código pede `Sound.play("hit", posição)`; o
   SoundBank diz quais arquivos, volume e variação. Som que todos ouvem sai de um `fx_*`.
6. **Animação por ação, nunca por nome de clipe.** O código pede `"move"`, `"slash"`, `"hit"`;
   o mapa do tipo de corpo (AnimSets) escolhe o clipe do modelo. Assim cada criatura tem as
   próprias animações.
7. **Dados separados de código.** Itens, criaturas e (depois) regiões e NPCs são tabelas/arquivos
   de dados; o código é genérico.
8. **Números do jogo em GameConfig** (ou na tabela do dado), não espalhados.
9. **Plataforma só em `platform/`.** Xbox/Steam/PlayFab nunca aparecem no resto do código.
10. **Visual da interface pelo tema.** Botões, painéis e campos já saem vestidos pelo tema do
   projeto; cores e fontes vêm do `UiSkin`. Nada de `StyleBoxFlat` solto em tela nova.
   Trocar a arte = pintar por cima das texturas de `ui/skin/` (mesmo tamanho e bordas).
11. **GDScript tipado**, sem C#, pelo port de console.
12. **Toda mudança roda os testes** (abaixo). Teste novo para sistema novo, de preferência
    passando pelos botões de verdade (`Input.parse_input_event`).

## Como acrescentar

### Um item novo
Pelo painel **Itens** do editor (ver [`EDITOR_DE_ITENS.md`](EDITOR_DE_ITENS.md)): Novo, importar o
modelo, ajustar atributos, lojas, loot e encaixe no Inspector, gerar o ícone. Por baixo:
- A ficha é um `ItemDef` em `items/defs/<id>.tres`; o `ItemDB` lê todas e entrega o Dictionary de
  sempre (`ItemDB.def`). O item no save e na rede continua só com o id.
- Desenho provisório novo (sem modelo): um caso em `ItemVisuals.build`, `ItemVisuals.MOUNTS`,
  `ItemIcon.draw_glyph` e o nome em `ItemDef.LOOKS`.

### Uma criatura nova (cachorro, rato, dragão...)
1. Modelo em `assets/creatures/<nome>/` (1 unidade = 1 m, pé na origem, olhando para +Z).
2. Mapa de animações em `AnimSets` (ex.: `QUADRUPED`): para cada ação, os clipes do modelo
   em ordem de preferência. Ações que a IA usa: `idle`, `move`, o ataque dela, `hit`, `death`.
3. Ficha da criatura (hoje `Enemy.STATS`; vai virar um arquivo de dados por criatura):
   id, modelo, mapa de animações, vida, velocidade, alcance, ataque, dano. O id vai também em
   `GameConfig.CREATURES` para aparecer nas regras de loot das fichas de item.
4. Comportamento diferente (voar, cuspir fogo, fugir) entra como um tipo de IA novo,
   reaproveitando navegação, aviso de ataque (fica vermelho) e replicação.

### Uma área nova do mapa, masmorra ou entrada
Pelo painel **Mapa do Mundo** (ver [`EDITOR_DE_MAPA.md`](EDITOR_DE_MAPA.md)): criar bloco, pintar
na grade, inserir peças prontas, criar masmorra, ligar e sincronizar entradas, validar e assar.
Por baixo:
- Bloco: cena com conteúdo de 0 a 64 m; o chão, a grade de pintura (`Tiles`, um GridMap) e tudo
  que é sólido ficam dentro de `Navigation`. Registrado em `chunks`/`chunk_regions` do WorldMap.
- Navegação lê malhas + colisões (o Godot não lê as colisões do GridMap na navegação).
- Interior: cena com origem própria longe do mapa, registrada em `interiors`.
- Entrada: par com o mesmo `link_id`; o destino de cada uma é a frente (+Z) da outra.
- Estado que precisa lembrar (baú aberto, chefe morto) vai no save do mundo do host
  (`NetService.world`; os baús em `world.containers`, avisados aos convidados por RPC).
- Peça de pintura nova: acrescente em `tools/build_tiles.gd` e rode (ids existentes não mudam).
- Peça pronta nova: cena em `world/prefabs/` (aparece sozinha no painel).

### Uma região
1. Um `RegionDef` em `regions` do WorldMap: id, nome, perigo (= poder base do loot), segura ou não, cor.
2. Os blocos apontam para ela em `chunk_regions`.

### Um NPC de serviço
1. `WorldNpc` fixo no mapa (peça pronta no editor), com o serviço; comerciante tem `shop_items`
   e `shop_power` no Inspector.
2. Serviço novo: um comando em `world/services.gd` (confere NPC perto e moedas, muda o inventário,
   devolve a mensagem) e uma aba em `ServicePanel.TABS` com as linhas dela.
3. Encantamento novo: uma linha em `ItemDB.ENCHANTS` (atributo, por nível, em que peças). Se o
   atributo for novo, ele precisa ser lido no herói (como `lifesteal_pct` e `move_speed_pct`).

## O mapa é do dono do jogo

O mapa é único e só o dono do jogo edita, no editor do Godot. Os jogadores não têm como mexer:
- **O editor não vai no jogo:** a exportação (`export_presets.cfg`) exclui `addons/`, `tools/`,
  `tests/` e `docs/`. O painel do editor só existe dentro do Godot; o jogo não tem nenhum comando
  ou mensagem de rede que altere o mapa. Conferido abrindo o pacote exportado.
- **Impressão digital do mapa** (`MapIntegrity`): hash do conteúdo de verdade do WorldMap e de
  todas as cenas de blocos, interiores e peças prontas, como o jogo carregou. Ao entrar num mundo
  online, o convidado manda a dele e o host recusa se for diferente (arquivos mexidos ou
  atualização diferente). Hoje leva ~0,6 s para 17 blocos; com o mapa grande, calcular em
  segundo plano ao abrir o jogo.
- **Host com autoridade:** colisão, criaturas, loot e inventário são do host. Um convidado com
  arquivos mexidos só veria coisas diferentes na própria tela (e nem entra, pela impressão digital).
- **Xbox:** o pacote é assinado; não dá para alterar arquivos. **PC:** dá para dificultar mais com
  PCK criptografado (exige compilar os modelos de exportação com chave própria); nenhum jogo de PC
  é 100% à prova de modificação, mas o que importa (online) está protegido acima.
- O save do mundo guarda progresso, não o mapa: editar o save não muda o mapa.

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
godot --headless --path coop-dungeon -s tests/map_tools_test.gd                # editor de mapa
godot --headless --fixed-fps 60 --path coop-dungeon -s tests/services_test.gd  # serviços da cidade
godot --headless --path coop-dungeon -s tests/item_tools_test.gd               # fichas de item e painel Itens
godot --headless --fixed-fps 60 --path coop-dungeon -s tests/container_test.gd # baús com saque
godot --headless --fixed-fps 60 --path coop-dungeon -s tests/camera_test.gd    # câmera atrás do herói
godot --headless --fixed-fps 60 --path coop-dungeon -s tests/progress_test.gd  # nível, XP, chip pirata, sons e números
godot --headless --path coop-dungeon -s tests/internet_test.gd                 # código do mundo, UPnP sem roteador
godot --headless --fixed-fps 60 --path coop-dungeon -s tests/character_test.gd # personagens: migrar, escolher, personalizar
godot --headless --path coop-dungeon -s tests/voice_test.gd                    # voz: codificação, rádio, volumes, distância
GODOT=godot coop-dungeon/tests/run_net_test.sh                                 # online: host + cliente (com voz), mapa adulterado e senha
```

Os testes que entram no mundo ligam `Engine.set_meta("auto_pick_character", true)`: sem tela
de escolha, cada vaga entra com o último personagem dela (ou um novo).

Os scripts de teste não usam os tipos do jogo (Player, ItemDB...) direto, porque compilam
antes dos serviços globais existirem: carregam com `load(...)` na hora.
