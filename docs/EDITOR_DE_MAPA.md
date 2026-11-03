# Editor de mapa (guia de uso)

O mapa é um só, fixo e feito à mão; ele cresce com as atualizações. Tudo acontece dentro do
editor do Godot, com o painel **Mapa do Mundo** (lado direito, embaixo do Inspector).

## O painel Mapa do Mundo

- **Grade do mapa:** cada quadrado é um bloco de 64 x 64 m, na cor da região. O ponto amarelo é
  onde o grupo começa. A volta de quadrados vazios é onde dá para criar blocos novos.
  Clique seleciona; clique duplo abre o bloco.
- **Região do bloco:** escolha na lista para trocar a região do bloco selecionado.
- **Criar bloco aqui:** num quadrado vazio, cria o bloco (chão da região + grade de pintura) e abre.
- **Jogar a partir deste bloco:** roda o jogo começando no meio do bloco selecionado.
- **Regiões e ponto de partida (Inspetor):** abre o mapa no Inspector para criar/editar regiões
  (nome, perigo, área segura, cor do nome, cores do chão) e mudar o ponto de partida.

## Pintar o bloco (como no Remere's)

1. Abra o bloco e selecione o nó **Navigation > Tiles** (a grade de pintura).
2. A paleta de peças aparece embaixo: chão (pedra, grama, terra, madeira, areia, caverna),
   paredes, mureta, coluna, cerca, blocos empilháveis e rampa.
3. Clique para pintar, clique direito para apagar. Teclas da grade do Godot: **S** gira a peça
   (paredes: gire 90° para correr no outro sentido; **A**/**D** giram nos outros eixos),
   **Q/E** descem e sobem o andar (muros altos, cavernas, torres), **Shift + arrastar** seleciona
   uma área. A lista completa de atalhos fica no menu da grade, no topo da vista 3D.
4. Paredes pintadas abrem sozinhas um buraco em volta do herói quando ficam na frente dele.

## Peças prontas

A lista **Peças prontas** mostra as peças em grade (com miniatura):
- **Construções:** casas, poço, boca de caverna.
- **Natureza e relevo:** árvore, rochas, arbusto, arbusto seco (dá para atravessar o mato),
  morro baixo, morro alto e barranco (com rampa suave: dá para subir andando).
- **Sucata de rua:** poste de luz (acende), carro quebrado, contêiner, pilha de pneus, barril,
  cone, saco de lixo, pallet, bloco de concreto, barreira.
- **Com saque:** baú de saque e contêiner de saque.
- **Jogo:** gerador de criaturas, NPCs de serviço.

Dois jeitos de colocar:
- **Colocar clicando na vista (carimbo):** escolha a peça, ligue o botão e clique na vista 3D:
  cada clique põe uma peça ali (no chão ou em cima do que tiver colisão). Com **Variar giro e
  tamanho** ligado, cada uma sai girada e com tamanho um pouco diferente (bom para mato, pedras e
  lixo; NPC, baú e gerador só giram). Clique direito, Esc ou o botão de novo param o carimbo.
- **Inserir no centro da vista:** uma peça onde o centro da vista 3D bate no chão (com relevo),
  virada para a câmera. Se esse ponto estiver longe (mais de 15 m) ou a vista apontar para o céu,
  a peça cai no chão um pouco à frente da câmera, ainda na tela. (A câmera do editor gira em volta
  de um ponto fixo: girar e dar zoom não mudam o centro; andar com botão direito + WASD muda.)

Depois mova e gire como qualquer nó (Ctrl+Z desfaz). Ao terminar o bloco: Ctrl+S. A navegação
das criaturas o jogo calcula sozinho ao carregar cada bloco (não fica salva na cena, então não
aparece mais a "película" azul por cima do cenário; cenas antigas: botão **Tirar a película azul**).
- Escolhendo uma peça na lista, a **prévia 3D** embaixo dela mostra o modelo girando.
- As peças são cenas em `world/prefabs`: mudar uma muda todos os lugares que a usam.

### Categorias (pastas)

As peças ficam em `world/prefabs`; cada **subpasta** é uma categoria (`world/prefabs/cidade/` →
"Cidade"), e as soltas na raiz ficam em "Geral". Para organizar, crie pastas e mova as peças no
painel **FileSystem** do Godot (arrastando lá dentro o Godot atualiza os blocos que usam a peça;
fora do Godot, não). A lista do editor de mapa tem o filtro de categoria em cima, e no modo
construtor o **V** passa de uma categoria para a outra.

### Packs de modelos (para o modo construtor)

Jogue packs inteiros em **`assets/props/packs/`** (ou `props/packs/`), uma pasta por pack:
`packs/DownTown`, `packs/Survival`, `packs/Zombie`... Cada pasta vira uma **categoria** no
`/construir` (V passa de uma para a outra), com **todos os modelos dela**, até nas
sub-subpastas. Pack que vem com o mesmo modelo em vários formatos aparece uma vez só (glb >
gltf > fbx > obj). Para trazer mais, é só criar outra pasta ali e abrir o projeto no Godot (ele
importa sozinho).

Na **primeira vez que você carimba** um modelo do pack, ele vira peça pronta **fixa** (com
caixa de colisão e tamanho ajustado se vier em centímetros) em `world/prefabs/<pack>/`. Daí em
diante é uma peça como as outras: para deixar física, contêiner ou enfeite, abra a ficha dela no
editor de mapa. Os modelos que ainda não viraram peça só aparecem no `/construir`.

Os packs ficam no projeto: para o jogo exportado ter as peças que você colocou, faça commit das
pastas dos packs junto (ou pelo menos dos modelos usados).

### Objetos 3D próprios (.obj, .glb, .gltf, .fbx)

**Importar objeto 3D…** abre o seletor de arquivos (pode ser fora do projeto: o modelo é copiado
para `assets/props/importados/<nome>/` junto com o que ele usa, como .mtl e texturas do .obj ou
.bin do .gltf). O Godot importa e abre a **ficha da peça**:
- **Nome**, **Tamanho** e **Giro** do modelo (modelo exportado em centímetros já vem com
  tamanho 0,01 sugerido). A base fica sempre no chão.
- **Tipo:**
  - **Fixo:** sólido, ninguém mexe (postes, muros, carcaças pesadas).
  - **Contêiner:** abre e solta itens (nome ao abrir, parafusos, itens sorteados; itens fixos e
    reabastecer no Inspector depois de colocar).
  - **Físico:** cai, rola e os heróis empurram (peso em kg). No online o host simula e os
    convidados acompanham.
  - **Atravessável:** só enfeite, sem colisão (mato, papel no chão).

**Importar pasta inteira…** traz todos os modelos de uma pasta e das subpastas de uma vez,
como peças **fixas**, e cada pasta vira uma categoria (um pack com `cidade/` e `natureza/` vira
as categorias Cidade e Natureza). Depois é só abrir a ficha das que forem físicas, contêineres
ou enfeites. Importando um modelo só, ele também cai na categoria da pasta de onde veio.

**Salvar peça** grava a ficha em `world/props/<id>.tres` e gera a peça pronta em
`world/prefabs/<categoria>/<id>.tscn`. **Ficha da peça…** abre a ficha da peça escolhida para mudar (a peça é
gerada de novo e todos os lugares do mapa que a usam mudam junto). Cone, barril, saco de lixo,
pilha de pneus, pallet e bloco de concreto já vêm como **físicos**. Peças montadas por partes
(casas, árvores, NPCs) não têm ficha.
- **Gerador de criaturas:** no Inspector, escolha tipos, quantidade, alcance de perseguição,
  limite da casa, poder do loot e tempo de reaparecimento. Nunca em área segura.
- **NPC:** escolha o serviço (comerciante, ferreiro, encantador, banco) e o nome. Comerciante:
  o campo **Shop Id** é o nome da loja nas fichas de item (vazio = o nome do NPC).

### Baú e contêiner de saque

Coloque um **baú de saque** (ou contêiner de saque) e, no Inspector:
- **Title:** o nome que aparece em cima ("Baú do Ferro-Velho").
- **Contents:** os itens fixos. Clique em *Add Element*, depois em *Novo ContainerItem*, e
  escolha o item (lista com todos os itens do jogo), a quantidade, o poder (0 = o perigo da
  região), a raridade (sorteada ou fixa) e a chance (%).
- **Gold:** parafusos. **Random Items:** quantos itens extras sortear do loot geral da região.
- **Refill Minutes:** 0 = abre uma vez por mundo; senão, enche de novo depois desse tempo.
- **Open Range:** de que distância abre (contêiner grande precisa de mais).
- **Model / Model Scale:** troque o modelo (qualquer .glb) e o tamanho.

No jogo, perto dele aparece "[LB / F] abrir": os itens saltam para o chão em volta e o time
todo vê e pega, como o loot das criaturas. Aberto, ele fica escuro. Quem abriu fica salvo no
mundo do host (vale para todos os jogadores da sala e continua depois de fechar o jogo).
- **Container ID:** identificador único (é o que fica salvo). O editor preenche sozinho, e uma
  cópia com Ctrl+D ganha id novo. **Validar mapa** avisa id repetido e baú vazio.

### Relevo (morros, declives)

Por enquanto o relevo é feito com peças: **morros** e **barranco** (peças prontas) e, na grade
de pintura, **blocos empilháveis** e **rampa** (Q/E sobem o andar). Pincel de esculpir terreno
(subir/descer o chão com tamanho e força) não faz parte do editor: se um dia precisar de terreno
ondulado de verdade, o caminho é o plugin gratuito **Terrain3D** dentro de cada bloco.

## Masmorras e entradas

1. Em **Masmorras e interiores**, dê um id (ex.: `mina_abandonada`), escolha a região na lista de
   regiões acima e clique **Nova masmorra**. Ela nasce longe do mapa de fora, com chão, paredes
   em volta e duas luzes; pinte e decore como um bloco.
2. Selecione o bloco de fora na grade e a masmorra na lista, dê um id para a ligação e clique
   **Ligar bloco ↔ masmorra**: uma entrada nasce em cada lado.
3. Mova cada entrada para o lugar certo. O **eixo azul** da entrada aponta para onde o grupo sai
   quando chega por ela.
4. Clique **Sincronizar entradas** sempre que mover uma entrada.

## Antes de subir uma atualização do mapa

- **Validar mapa:** mostra blocos sem cena ou sem região, navegação não calculada, criaturas fora
  do bloco ou em área segura, entradas sem par ou desatualizadas, falta de comerciante.
- **Assar navegação de tudo:** recalcula por onde as criaturas andam em todos os blocos
  (necessário depois de pintar ou mover coisas sólidas).
- Rode os testes (`docs/ARCHITECTURE.md`).

## Regras do mapa

- Conteúdo do bloco de 0 a 64 m (coordenadas locais); tudo que é sólido dentro de `Navigation`.
- Não ponha borda no mapa: o jogo põe parede invisível em lado de bloco sem vizinho. Criou bloco
  ao lado, a passagem abre sozinha.
- O que deve ficar transparente quando tapa o herói (árvore, parede de casa) vai dentro de um
  `FadeOccluder` (as peças prontas já vêm assim); paredes pintadas fazem isso sozinhas.


## Modo construtor (dentro do jogo) — só o dono do jogo

Ferramenta sua para montar o mapa andando por ele, como num editor de pista. **Jogadores não
têm acesso:** o código do modo construtor (`world/god_mode.gd`) e o que grava nas cenas do mapa
(`world/map_writer.gd`) **nem vão no jogo exportado** (estão no filtro de exclusão dos presets de
exportação), e o mundo só carrega o modo construtor se o arquivo existir e se estiver rodando
pelo **editor do Godot**. Não aparece em menu nenhum e não funciona entrando no mundo de outra
pessoa. (O que vai no jogo exportado é só `world/world_edits.gd`, que mostra as peças que você
já colocou, inclusive para amigos conectados no seu mundo.)

**Entrar e sair:** abra o chat (Enter) e digite **/construir**. Digite de novo para sair. O
comando não vai para o chat da sala; o aviso "Modo construtor ligado" só aparece na sua tela.

**Hora do mundo:** `/hora 20` (ou `/hora 6:30`) no chat muda o relógio do mundo na hora, para
ver como fica o dia, o pôr do sol e a noite (postes acendem sozinhos de 18h40 a 5h40). Também
só para o dono do jogo, rodando pelo editor; os amigos conectados veem a mesma hora.

O herói continua andando (e correndo), não luta e as criaturas o ignoram. Embaixo aparece o
seletor de peças e, no mundo, o **fantasma** translúcido da peça onde ela vai cair.

| | Teclado e mouse | Controle |
|---|---|---|
| Colocar | clique esquerdo (no cursor) | X (à frente do herói) |
| Trocar peça (dentro da categoria) | Q / E ou rodinha | direcional ◀ ▶ |
| Próxima categoria (pasta) | V (Shift+V volta) | direcional ▼ |
| Girar 45° | R (Shift+R volta) | Y |
| Desfazer a última | Z | B |
| Apagar a peça no cursor (do construtor **ou do mapa**) | Delete | LB |
| Pegar a peça no cursor e mudar de lugar | G (larga com clique; G/Delete desiste) | ▲ (larga com X; ▲/B desiste) |
| Conteúdo do contêiner no cursor | F | RB |

- **Apagar e mudar de lugar valem para qualquer peça pronta do mapa** (postes, letreiros de neon,
  barris, contêineres, cones...), não só as do construtor. Casas, chão e NPCs não. Ao pegar, a
  peça some e vira o fantasma; ela guarda a altura (letreiro na parede continua na parede), o
  tamanho e o que foi ajustado nela (texto e cor do letreiro). R gira antes de largar. Peça do
  mapa muda de lugar dentro do mesmo bloco; as do construtor vão para qualquer bloco.
  Apagou sem querer? A cena do bloco está no Git: dá para voltar.
- Peça **física** (cone, barril, pneus...) nasce 1,5 m acima, cai, rola e, quando para, fica
  gravada exatamente onde parou. As outras gravam na hora.
- **Contêiner** colocado pelo construtor: F/RB abre a lista de itens (clique duplo / A põe; na
  lista "Dentro", clique duplo tira um) e os botões de parafusos.
- **Grava direto na cena do bloco** (`world/chunks/...`), como se a peça fosse colocada no
  editor de mapa: entra no mapa oficial e aparece no editor (peças com nome `god_...`).
- Se tiver amigos conectados no seu mundo enquanto constrói, eles veem cada peça na hora. Quem
  tiver o mapa antigo precisa da versão nova do jogo depois (o mapa muda e o jogo confere).
- Peças novas importadas no editor de mapa (Importar objeto 3D) aparecem no seletor.

## Letreiro de neon

Peça `world/prefabs/letreiro_neon.tscn` (no catálogo de peças e no `/construir`). Selecione no
mapa e mude no Inspector: **Text**, **Color**, **Letter Height** (altura das letras), **Board**
(placa escura atrás), **Flicker** (pisca de vez em quando, neon velho), **Stand** (pé de ferro até
o chão, para barraca na rua) e o alcance/força da luz. A prévia atualiza no editor.

De noite o neon brilha forte e pinta a parede e o chão na cor dele; de dia fica mais fraco. Os da
vila (COFRE, BAR, LANCHES, OFICINA, MERCADO, MODS) foram postos por `tools/letreiros_vila.gd`.
