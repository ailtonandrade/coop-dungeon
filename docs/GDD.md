# Coop Dungeon: documento de design (protótipo)

## Visão

> Identidade, narrativa e estética (cyberpunk de ferro-velho): ver [`IDENTIDADE.md`](IDENTIDADE.md).
> As mecânicas abaixo continuam "1:1 com a referência"; mundo, história e visual são os de lá.

RPG de ação isométrico em **mundo aberto**, com entradas para **interiores** (masmorras,
casas, prédios), com escala, proporções, ritmo e funcionalidades **1:1 com a referência
Minecraft Dungeons 2**. Plataformas: **Xbox Series X|S** e **Windows**
(Microsoft Store/Game Pass **e** Steam), com **cross save** entre todas.

Pilares:
- **Movimento:** andar, pular, escalar e rolar.
- **Combate:** corpo a corpo e à distância.
- **Co-op de sofá:** até 4 jogadores na **mesma tela**, sem tela dividida.
- **Online:** até 4 jogadores na mesma sala, misturável com sofá (ex.: 2 num Xbox + 2 num PC).
- **Cross save:** o personagem e o progresso seguem a conta em qualquer plataforma.

### O que "1:1" significa aqui (e o que não significa)

| Pode copiar 1:1 (mecânica, regra, número) | Precisa ser nosso (propriedade intelectual) |
|---|---|
| Escala do personagem, câmera, velocidade, tamanho das salas | Nomes de itens, encantamentos, mobs, fases |
| Estrutura: corpo a corpo + à distância + 3 artefatos, rolada, poção | Arte, estilo visual em blocos, ícones, layout exato de UI |
| Equipamento define o "build" (sem classe fixa) | Músicas, sons, textos |
| Pontos de encantamento por nível, poder de equipamento | Mapas e layouts de fase copiados |

Mecânica não tem direito autoral, mas **visual e conteúdo têm**. Isso pesa mais ainda
porque a referência é da própria Microsoft, que também aprova o jogo na loja do Xbox.

## Escala e câmera (fonte da verdade: `core/game_config.gd`)

- **1 unidade = 1 metro = 1 tile.** Todo asset é modelado nessa escala, com o pé na origem.
- Herói: ~1,8 m de altura, raio de colisão 0,35 m, corre a 4,5 m/s.
- Rolada: 0,4 s, ~3 m de deslocamento, 1 s de recarga.
- Câmera: perspectiva com FOV 30° (quase ortográfica), pitch -50°, yaw 45°,
  distância entre 17 e 28 m, com zoom automático conforme o grupo se espalha.
- Co-op: uma câmera só (sem tela dividida). Quem se afasta mais de 16 m do companheiro
  mais próximo é teleportado para perto dele.

> Esses números foram calibrados a olho a partir do primeiro Dungeons. Vale ajustar
> jogando lado a lado com o Dungeons 2 e só mexer em `game_config.gd`.

## Combate (valores atuais)

- Combo: 10 / 10 / 22 de dano; o 3º golpe empurra longe e treme a câmera.
- Mira assistida: o golpe vira para o inimigo mais próximo num raio de 4 m;
  a flecha corrige para o inimigo dentro de um cone de 30°.
- Inimigos sempre "avisam" o ataque ficando vermelhos (0,5 s no brutamontes, 0,7 s no atirador).
  Apanhar interrompe o ataque deles.
- Atirador mantém distância: recua de frente para o alvo (andando de costas) e, entre um tiro e
  outro, anda de lado para desviar.
- Herói: 100 de vida. Poção cura 40% (recarga de 15 s). Caído, um companheiro
  perto por 2 s revive com 50%. Todos caídos: em 3 s a arena reinicia na onda 1.

## Pulo e escalada

O herói pula (~1,2 m) e **escala bordas automaticamente**:
no ar, empurrando contra algo cujo topo esteja até 1,6 m acima do pé, ele agarra e sobe.
Na prática, dá pra subir em coisas de até ~2,7 m. Mais alto que isso, ou sem espaço em cima, não sobe.
- Tolerâncias de controle: dá pra pular até 0,1 s depois de sair da borda, e o aperto
  feito até 0,12 s antes de pousar vale.
- As bordas da arena têm colisão invisível alta, pra ninguém escalar pra fora.
- Inimigos não escalam: subir é uma rota de fuga, mas o atirador ainda acerta lá em cima.
  Avaliar se isso deixa o jogo fácil demais.
- O pacote de modelos atual não tem animação de pulo nem de escalada: na escalada
  ele usa "Interact" no lugar. Modelos com "Jump"/"Climb" são usados automaticamente.

## Mundo aberto (estilo Tibia)

**Um mapa só, persistente e desenhado à mão**, não fases. Com o tempo o jogador decora
o mapa: sabe onde fica o comerciante de armas, onde refina equipamento, onde encanta,
qual masmorra dá qual loot, qual região é perigosa para o nível dele.

**Peças do mundo:**
- **Regiões** (floresta, pântano, deserto, montanhas...): cada uma com nível de perigo,
  criaturas típicas, clima/ambiente e o poder do loot que cai lá.
- **Cidades:** lugares seguros (sem combate) com os **serviços**: comerciante (comprar/vender),
  ferreiro (refinar: +1, +2... no poder do item), encantador (encantamentos), banco/baú,
  ponto de retorno (renascer/viagem rápida).
- **Masmorras e interiores** (cavernas, casas, prédios, torres): cenas separadas, ligadas
  ao mapa por **entradas** (porta, escada, buraco). Podem ter andares.
- **Pontos de interesse:** acampamentos de criaturas, chefes, baús, recursos, NPCs de missão.
- **Mapa e minimapa** revelam o que o jogador já explorou (névoa), e marcam serviços já descobertos.

**Como o mapa é feito e carregado:**
- O mapa é montado no editor do Godot em **blocos (chunks) de 64 x 64 m** com peças modulares
  de 1 m (o grid do jogo). Cada bloco é uma cena; um arquivo de região diz quais blocos
  são dela e o que ela tem (perigo, criaturas, música).
- Um `WorldStreamer` carrega em segundo plano os blocos em volta de **cada grupo** e
  descarrega os que ficaram longe (com a navegação dos inimigos de cada bloco).
- **Sofá:** quem divide a tela fica perto (limite de distância), então cada máquina precisa de
  um conjunto pequeno de blocos em volta do grupo dela.
- **Online:** grupos em máquinas diferentes podem estar em regiões diferentes. O host simula
  e mantém carregados os blocos em volta de cada grupo; cada cliente carrega só os blocos
  em volta dos seus jogadores.
- **Entrar numa masmorra/casa:** como a tela é uma só, quem divide a tela entra junto
  (contagem curta na porta). Jogadores online de outras máquinas podem ficar do lado de fora.
- **Telhados e paredes que tapam o herói** somem quando alguém passa por trás (recorte por câmera),
  só na câmera isométrica; na câmera estilo GTA nada some (dá para girar a câmera).
- **Telhados são sólidos:** dá para subir e andar em cima, mas não entrar pelo telhado. Para ter
  entrada por cima, o telhado precisa ter a abertura de verdade (peças separadas com o vão).
  Eles ficam numa camada própria (LAYER_ROOF): heróis, criaturas, tiros e a câmera esbarram,
  mas a navegação das criaturas não usa telhado como caminho.
- **Criaturas por região** (acampamentos, patrulhas, chefes) com reaparecimento por tempo,
  em vez de ondas. As ondas atuais são só a arena de teste do combate.
- **Estado do mundo** (baús abertos, chefes mortos, serviços descobertos) fica no save do mundo do host.

### Região de teste (M7)

4 x 4 blocos de 64 m (256 x 256 m) e uma masmorra:
- **Vila de Pedra** (centro, segura): 4 casas (telhado e paredes da frente somem ao entrar),
  comerciante e encantador na praça, banco e ferreiro dentro de casas.
- **Planície Verde** (perigo 1), **Bosque Norte** (perigo 2, mata fechada), **Colinas do Leste**
  (perigo 3, com a boca da **Caverna Velha**, perigo 4).
- Criaturas por acampamento, com casa, perseguição, limite e reaparecimento.
- Gerada por `tools/build_test_world.gd` só como ponto de partida: os blocos são cenas normais,
  editadas à mão no Godot daqui em diante.

### Ferramentas para criar o mapa (estilo Remere's Map Editor)

O mapa é único, fixo e cresce a cada atualização. A criação é à mão, dentro do editor do Godot,
com estas ferramentas (M7.5, guia em [`EDITOR_DE_MAPA.md`](EDITOR_DE_MAPA.md)):
- **Pintar em grade:** chão, paredes, cercas e peças em células de 1 m com `GridMap` e uma
  biblioteca de peças (MeshLibrary): escolhe a peça na paleta e pinta com o mouse, como no RME.
  Andares (para cavernas, torres) são camadas de altura.
- **Paleta de prontos:** casa, árvore, rocha, boca de caverna, barraca de comerciante, cada um
  uma cena pronta para arrastar para o bloco.
- **Painel "Mapa do mundo"** (plugin do editor): a grade de blocos do mapa inteiro, com a região
  de cada um; clicar abre o bloco; criar bloco novo ao lado; criar interior novo.
- **Ligar entradas:** cria a porta de fora e a de dentro de uma vez, já apontando uma para a outra.
- **Gerador de criaturas e NPCs** com o raio de perseguição e o limite desenhados no editor.
- **Validar o mapa:** entradas sem par, blocos sem navegação assada, criaturas fora da
  navegação, NPC de serviço faltando numa cidade.
- **Assar tudo:** navegação de todos os blocos de uma vez; e uma imagem do mapa inteiro para o
  mapa do jogo.
- **Testar daqui:** abrir o jogo já no bloco que está sendo editado.

## Multiplayer online

**Modelo: host com autoridade.** Uma máquina (o host) roda a simulação de verdade
(inimigos, dano, loot); as outras mandam os comandos dos seus jogadores e recebem o estado.
É o modelo mais simples que funciona bem para co-op de até 4, e evita trapaça entre amigos
sem precisar de servidor dedicado.

- **Sofá + online juntos:** cada máquina tem de 1 a 4 jogadores locais; a sala soma até 4.
  Cada jogador é identificado por (máquina, slot local). O `InputService` já separa por slot;
  falta trocar "ler o controle" por "ler o comando que veio da rede" nos jogadores remotos.
- **Câmera:** cada máquina enquadra só os **seus** jogadores locais. A corda de teleporte
  continua mantendo o grupo inteiro junto.
- **Transporte em camadas** (o jogo não muda, só o "cano"):
  1. Protótipo: ENet do próprio Godot (conectar por IP / rede local).
  2. Lançamento: **PlayFab Party + Lobby** (Microsoft). Funciona entre Xbox, Microsoft Store
     e Steam, e já é o mesmo serviço do cross save. Alternativa: Epic Online Services.
  3. Convites e "entrar no jogo do amigo" pelo Xbox (MPSD) e pela Steam.
- **Requisitos do Xbox para online:** convites, privacidade e bloqueio de usuários,
  e checagem de assinatura quando aplicável. Confirmar a lista com o ID@Xbox.
- **Save no online:** o mundo é o do host; cada convidado leva o próprio personagem
  (equipamento e nível) e salva na própria conta.

### Como está implementado (M6)

- `NetService` (autoload): sessão offline/host/cliente, aperto de mão (versão, sala cheia),
  vagas por (máquina, slot) e envio dos comandos do cliente.
- `NetReplicator` (na fase): o host cria as entidades e manda "nasceu"/"sumiu" e um retrato
  do estado 30 vezes por segundo; os clientes suavizam a posição entre retratos.
  Efeitos visuais (piscar, tremer, rastro do golpe) vão por `broadcast_fx`.
- `PlayerInput`: o herói lê comandos daqui, venham do controle ou da rede. Apertos vão como
  contadores, para não sumirem se um pacote se perder.
- `LanDiscovery`: anúncio e busca de mundos por broadcast UDP (porta 7779). O jogo usa a porta 7777.
- Projéteis: o cliente recebe só o disparo e simula o voo; o dano é sempre do host.
- **Ainda não tem previsão no cliente:** quem joga pela rede vê o próprio herói com o atraso
  da conexão. Em rede local isso não se nota; pela internet vai precisar de previsão (próximo passo do online).
- Teste: `tests/run_net_test.sh` sobe host e cliente e confere busca, entrada, comandos,
  inimigos e saída.

## Mundos

- Cada mundo salvo é uma partida no **mesmo mapa** (o mapa é um só, desenhado à mão), com o
  próprio progresso: o que foi explorado, chefes mortos, baús abertos, serviços descobertos.
- Tem nome, visibilidade (aberto / privado / offline) e fica no perfil do host; no online o
  mundo é sempre o do host. Os personagens (inventário, nível) são de cada jogador.
- A semente fica guardada para o que for aleatório dentro do mapa fixo (ex.: variações de
  masmorra, posição de baús), não para gerar o mapa.

## Inventário e loot

**Inventário estilo Tibia, individual de cada jogador:**
- 9 casas de equipamento num "boneco" 3x3: amuleto, cabeça, mochila / corpo a corpo, peito,
  à distância / anel, pernas, pés.
- A mochila equipada tem casas (Bolsa 6, Mochila 12, Mochila grande 20) e pode ter outras bolsas
  dentro, que também têm casas. Equipar uma mochila que está dentro da atual coloca a atual dentro da nova.
- Soltar um item em cima de uma bolsa guarda dentro dela; uma bolsa não entra nela mesma.
- Cada jogador do sofá abre o próprio painel acima do seu cartão e navega com o próprio controle.
  Enquanto está aberto, aquele herói não anda nem ataca.
- Atributos: dano (arma corpo a corpo e à distância), armadura (reduz dano: 25 deixa passar 2/3),
  vida extra, % de dano. Escalam com raridade (comum 1x, raro 1,25x, único 1,5x) e poder (+8% por ponto).
- **Visível no boneco:** peito, pernas e pés pintam o próprio modelo; elmo, ombreiras, armas,
  amuleto e mochila são peças presas nos ossos. Todas as peças são provisórias, feitas de blocos.

**Loot estilo MU Online:**
- O que cai é o mesmo para todos: todo mundo vê e qualquer um do time pode pegar (quem pegar primeiro leva).
- Uma criatura pode deixar mais de um item (55% o 1º, depois 30%, depois 12%), espalhados no chão.
- Pegar é sempre manual: perto do item, LB / F. Nome no chão na cor da raridade e facho de luz.
- O poder do loot acompanha a onda (vai virar o nível da região no mundo aberto).

**Rede e save:** o host é dono da verdade (pegar, mover, equipar, largar); o dono do herói
manda comandos e recebe a cópia do inventário a cada mudança, e salva na própria conta
(cross save). Cada convidado entra com o inventário salvo dele.

## Economia e serviços da cidade

**Moedas:** criaturas soltam moedas no chão quase sempre (85%), mais quanto maior o perigo da
região; qualquer um do time pega (LB / F). Cada jogador tem as suas, salvas na conta dele.

**Conversar:** perto de um NPC aparece "[LB / F] falar"; o botão abre a tela do serviço daquele
jogador (painel próprio, cursor próprio, como o inventário). O host confere que o jogador está
perto do NPC certo e que tem as moedas antes de executar.

| Serviço | O que faz |
|---|---|
| Comerciante | Comprar do estoque dele (lista e poder definidos no NPC) e vender (paga 30% do valor). |
| Ferreiro | Refino +1 a +9: cada nível dá +10% nos atributos do item. +1 a +3 sempre dá certo; depois 80%, 65%, 50%, 40%, 30%, 20%. Falhar gasta as moedas, não estraga o item. |
| Encantador | Até 3 encantamentos por item, cada um até o nível 3: Afiado (+12% dano por nível, armas), Vampírico (+3% roubo de vida, corpo a corpo), Protetor (+3 armadura, cabeça/peito/pernas/pés), Robusto (+12 vida, peito/pernas/amuleto), Ágil (+5% velocidade, pés/pernas). |
| Banco | Depósito de 40 casas estilo Tibia: guardar e retirar itens, só perto do banco. |

Valor de um item: preço base x raridade² x poder x refino + encantamentos. Tudo em `ItemDB`.

## Minimapa

Canto superior direito. Câmera de cima desenha o terreno; por cima vão os heróis
(seta na cor de cada um, apontando pra onde ele olha) e os inimigos (pontos vermelhos).
Segue o centro dos jogadores da máquina, como a câmera principal.
- **Fixo:** norte sempre pra cima.
- **Rotativo:** gira para a frente do herói (o primeiro jogador local) ficar pra cima.
- Troca no menu de pausa; a escolha fica salva nas preferências desta máquina (`Settings`).

## Controles (padrão)

| Ação | Controle | Teclado |
|---|---|---|
| Mover | Analógico esquerdo | WASD |
| Mirar (anda de costas/lado olhando a mira) | Analógico direito | Mouse (segurando um botão) |
| Corpo a corpo | X | J ou botão esquerdo do mouse |
| À distância (dá pra atirar andando) | RT | K ou botão direito do mouse |
| Pular / escalar | A | Espaço |
| Rolar | B | Shift |
| Poção | Y | E |
| Pegar item do chão / falar com NPC | LB | F |
| Inventário | Back | I |
| Artefato | RB | Q |
| Menu | Start | Esc |
| Entrar no jogo (1º jogador) | — (entra direto com o personagem do menu) | — |
| Entrar no sofá (com alguém jogando) | segurar Y 2 s com o jogo pausado | segurar Espaço 2 s com o jogo pausado |

**Mira (twin-stick):** com o analógico direito (ou mouse), o herói olha para a mira e anda
para qualquer lado: de frente, de lado e de costas (mais devagar de costas). Atirando andando,
as pernas continuam correndo. Sem mirar, o golpe e a flecha corrigem sozinhos para o inimigo mais perto.
No teclado, o herói olha para o cursor enquanto o mouse está em uso (mexido nos últimos 3 s ou
com botão apertado); parado, volta a olhar para onde anda.

**Segurar para atacar:** segurando o ataque corpo a corpo, o combo continua sozinho, com uma
pausa de 0,25 s entre um combo completo e o próximo. Segurando o tiro, atira sem parar
(recarga da arma).

**Teclado ou controle, sozinho:** jogando só uma pessoa nesta máquina, o herói segue o
aparelho que estiver sendo usado: apertou um botão ou inclinou o analógico do controle, passa
para o controle; apertou uma tecla ou clicou, volta para o teclado e mouse. Mexer só o mouse ou
analógico com folga não troca. Com a pausa aberta não troca (aí o aparelho novo segurando
Y/Espaço entra como outro jogador). Com dois ou mais no sofá, cada um fica no seu.

**Entrada no sofá:** o primeiro jogador cai direto no mundo com o personagem marcado no menu
principal (cartão "Jogando como", à direita; câmera estilo GTA se estiver sozinho na tela e
ela estiver ligada, senão a isométrica). Para mais alguém entrar, quem já joga pausa; o novo
jogador segura Y (ou Espaço) por 2 s — o cartão vazio mostra a barra enchendo — e escolhe, em
cards com prévia, um personagem deste PC que ninguém esteja usando, ou cria um novo (visual,
cor do chip e nome) e entra.

**Limite do sofá:** quem divide a tela não se afasta mais que 13 m dos outros da mesma tela
(parede invisível); de reserva, quem passar de 16 m (queda, empurrão) é teleportado.

## Funcionalidades (escopo completo, em ordem de construção)

1. **Movimento e co-op**: entrar/sair a qualquer momento, câmera compartilhada, corda de teleporte. ✅ protótipo
2. **Combate**: combo de 3 golpes, arma à distância com munição, rolada com invulnerabilidade, hit-stop, knockback.
   ✅ protótipo (flecha ainda sem munição)
3. **Inimigos**: corpo a corpo, à distância, explosivo, elite; spawner por sala; IA com NavigationAgent3D.
   ✅ protótipo: corpo a corpo e à distância, ondas na arena
4. **Sobrevivência**: vida, poção com recarga, cair/reviver pelo parceiro, vidas por fase.
   ✅ protótipo (sem vidas por fase; se todos caem, reinicia a arena)
5. **Loot**: baús e drops **por jogador** (cada um vê o seu); raridade; poder do equipamento.
6. **Progressão**: nível do herói gera pontos de encantamento; 3 encantamentos por item.
7. **Artefatos**: 3 slots com recarga.
8. **Online**: host com autoridade, até 4 por sala, sofá + online misturados.
9. **Mundo aberto estilo Tibia**: mapa único desenhado à mão, regiões, blocos carregados em volta de cada grupo.
10. **Cidades e serviços**: comerciante, refino, encantamento, banco, ponto de retorno.
11. **Masmorras e interiores**: entradas no mapa, andares, chefes.
12. **Criaturas variadas**: cada uma com o próprio modelo, esqueleto e mapa de animações (AnimSets).
13. **Plataforma**: perfis por controle, save na nuvem, conquistas, certificação.

## Arquitetura

Estrutura de pastas, regras e como estender cada parte: ver [`ARCHITECTURE.md`](ARCHITECTURE.md).

## Save e cross save

**Dois tipos de save:**
- `world`: progresso da campanha (fases liberadas, história). Pertence ao **host** (P1).
- `player`: personagem (equipamento, nível, encantamentos). Pertence à **conta de cada jogador**.
  Um convidado sem conta joga com personagem temporário.

**Identidade única:** conta Microsoft/Xbox em todas as plataformas.
- Xbox e Microsoft Store: usuário Xbox por controle (GDK `XUser`).
- Steam: login com a conta Microsoft dentro do jogo (dá para usar Xbox services no PC fora da Store).

**Armazenamento:** cache local sempre (o jogo funciona offline) mais uma nuvem única:
- Recomendação: **PlayFab** (da Microsoft) como nuvem comum às três lojas, chaveado pela conta Microsoft.
- No Xbox/Store também existe o `XGameSave` (cloud save nativo), mas ele não chega na Steam.
  Usar só PlayFab evita ter duas nuvens para reconciliar.
- Conflito: cada save tem `version` e `updated_at`. Se o local e o da nuvem divergirem,
  vence o mais novo, e o jogador pode escolher quando os dois mudaram offline.
- Antes de fechar a decisão, confirmar com o ID@Xbox os requisitos de certificação sobre save.

## Caminho para o Xbox

1. Cadastro no **ID@Xbox** para ter dev kit e acesso ao GDK.
2. Port do Godot para Xbox via **W4 Games** (ou estúdio de port). Godot oficial não exporta para console.
3. Implementar `platform/xbox/`: `XUser` por controle, save, conquistas, pausa ao
   desconectar controle e troca de usuário (requisitos de certificação).
4. PC Microsoft Store pelo mesmo GDK; Steam pelo export Windows padrão mais o login Microsoft.

## Marcos do protótipo

| Marco | Entrega | Status |
|---|---|---|
| M0 | Projeto, câmera isométrica, personagem andando | ✅ |
| M1 | Co-op até 4 (entrar com Start), câmera compartilhada, corda | ✅ |
| M2 | Combate corpo a corpo + rolada com invulnerabilidade | ✅ combo, flecha, hit-stop, tremida |
| M3 | 2 inimigos com IA e spawner | ✅ brutamontes e atirador, ondas |
| M4 | Vida, cair/reviver, baú com loot, fim de fase | vida, poção, cair/reviver ✅ |
| M5 | Save local `world` / `player` ligado ao jogo | serviço ✅ |
| M6 | **Base do online**: host/entrar por IP, 2 máquinas + sofá, inimigos e dano pelo host | ✅ + menu de mundos e busca na rede local |
| M7 | **Mundo aberto (base)**: região de teste em blocos com carregamento por grupo, 1 entrada de masmorra, recorte de telhado | ✅ 4x4 blocos, vila, 3 regiões, caverna |
| M7.5 | **Editor de mapa** (estilo Remere's): pintar chão e paredes em grade, paleta de peças, mapa geral, ligar entradas, validar | ✅ painel Mapa do Mundo, ver EDITOR_DE_MAPA.md |
| M8 | Loot e progressão sincronizados no online | ✅ inventário estilo Tibia, loot estilo MU, equipamento no boneco, mira twin-stick |
| M9 | **Cidade e serviços**: comerciante, refino e encantamento | ✅ + banco, moedas, telas por jogador |

O online (M6) vem **antes** do mundo aberto e do loot: todo sistema novo
já nasce sincronizado. Adaptar depois custaria reescrever cada sistema.


## Habilidades (estilo Tibia)

Além do nível (XP das criaturas) e dos chips piratas, cada personagem tem habilidades que sobem
**usando**, começando no 10:
- **Armas:** Lâminas (facão, estilete), Machados, Impacto (martelo), Disparo (bestas, rifle,
  lança-pregos) e Desarmado. Cada acerto com aquele tipo treina; cada nível dá +1,5% de dano
  com ele (Desarmado +2%). A ficha do item pode apontar outra habilidade (campo *Skill*).
- **Vigor:** treina aguentando dano e recuperando vida (poção, roubo de vida); +1,5% de vida
  máxima por nível.
- **Resiliência:** treina a cada golpe recebido (e a cada golpe esquivado rolando); +0,8 de
  armadura por nível.
- Curva exponencial como no Tibia (cada nível pede ~10% mais uso), até 120. Subir avisa no chat
  ("Nina avançou em Lâminas (15)") e sobre o herói. Janela **Habilidades** na roda do
  inventário (RB/Q: Inventário -> Chip pirata -> Habilidades).
