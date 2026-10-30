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

Na lista **Peças prontas** (casas, árvore, rochas, boca de caverna, poço, gerador de criaturas,
NPCs de serviço), escolha uma e clique em **Inserir na cena aberta**: ela entra no centro da vista 3D.
Depois mova e gire como qualquer nó (Ctrl+Z desfaz).
- As peças são cenas em `world/prefabs`: mudar uma muda todos os lugares que a usam.
- **Gerador de criaturas:** no Inspector, escolha tipos, quantidade, alcance de perseguição,
  limite da casa, poder do loot e tempo de reaparecimento. Nunca em área segura.
- **NPC:** escolha o serviço (comerciante, ferreiro, encantador, banco) e o nome.

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
