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
- **Inserir no centro da vista:** uma peça no meio da vista 3D.

Depois mova e gire como qualquer nó (Ctrl+Z desfaz). Ao terminar o bloco: Ctrl+S e
**Assar navegação de tudo**, para as criaturas desviarem das peças novas.
- As peças são cenas em `world/prefabs`: mudar uma muda todos os lugares que a usam.
  Peça nova: salve uma cena lá dentro e ela aparece na lista.
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
