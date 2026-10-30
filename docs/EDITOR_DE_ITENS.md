# Editor de itens (painel "Itens")

Cada arma, armadura, bolsa e acessório é uma **ficha** em `items/defs/<id>.tres`. O painel
**Itens** (aba ao lado de Cena, no canto esquerdo do Godot) cria e edita essas fichas, traz os
modelos 3D e mostra o herói segurando o item. O painel só existe no editor: não vai no jogo.

## Criar uma arma nova (passo a passo)

1. Aba **Itens** > **Novo**: digite o nome ("Chave inglesa") e escolha a casa do corpo
   (Corpo a corpo). O id (`chave_inglesa`) sai do nome; ele é o que vai nos saves, então
   não mude depois que o jogo estiver lançado.
2. **Importar modelo**: escolha o `.glb` (ou `.gltf`, `.fbx`, `.obj`, `.blend`) em qualquer
   pasta do PC. Ele é copiado para `assets/items/<id>/` e importado; a prévia já mostra o herói
   segurando o item.
   - Armas: cabo na origem, ponta para cima (+Y), 1 unidade = 1 metro.
   - Sem modelo, o item usa um modelo provisório de blocos pelo tipo (Look).
3. Ajuste no **Inspector** (tudo salva sozinho e a prévia acompanha):
   - **Item:** nome, casa, tipo de desenho (Look: dá o ícone padrão e o encaixe padrão),
     cor, preço.
   - **Atributos:** dano, armadura, vida, % de dano, % de roubo de vida, % de velocidade,
     espaços (bolsas). São os valores no poder 1 e raridade Sucata; o jogo escala com poder,
     raridade e upgrade.
   - **Onde conseguir:**
     - *Sold By*: as lojas do mapa que vendem (a lista mostra os comerciantes do mapa).
     - *Random Loot*: entra no sorteio geral (pode cair de qualquer criatura).
     - *Drops*: regras por criatura. Clique em "Add Element", depois em "Novo ItemDrop", e
       escolha a criatura, a chance (%), a quantidade mínima e máxima, a raridade
       (sorteada ou fixa) e um bônus de poder.
   - **Modelo 3D:** escala do modelo, tamanho a mais no chão (loot) e o **encaixe**. Clique em
     **Encaixe** no painel para começar do encaixe padrão do tipo; aí mude o osso, a posição e a
     rotação no Inspector e veja na prévia.
4. **Gerar ícone**: fotografa o modelo para o ícone do inventário (`items/icons/<id>.res`).
5. **Ver no chão**: mostra como o item fica caído (loot), para acertar o tamanho.
6. O quadro de baixo do painel diz onde o item aparece e aponta problemas (arma sem dano,
   loja que não existe, ninguém vende nem dropa...). Item com problema fica amarelo na lista.

**Duplicar** é o jeito rápido de fazer variações (Facão enferrujado, Facão de titânio...).

## Lojas

Um item vendido aparece em todo comerciante cujo nome de loja está em *Sold By*. O nome da loja
é o campo **Shop Id** do NPC (no Inspector do NPC no mapa) ou, se vazio, o nome dele
("Dona Alda"). O NPC continua com a lista própria (*Shop Items*); as duas se somam.

## Criaturas

As criaturas que aparecem na regra de loot estão em `GameConfig.CREATURES`; o id bate com o
`"id"` de cada criatura em `Enemy.STATS`. Criatura nova: uma linha em cada.

## Online

As fichas entram na impressão digital do online junto com o mapa: quem tiver itens diferentes
do host (arquivos mexidos ou outra versão) não entra no mundo.

## Armaduras que vestem o corpo

Peito, pernas e pés sem modelo próprio pintam a roupa do personagem com a cor da ficha. Com
modelo próprio, a peça vai presa num osso (ombreira, cinto, bota). Uma roupa que dobra junto com
o corpo precisa ser feita sobre o esqueleto dos personagens (Quaternius) com pesos de pele; esse
tipo de peça ainda não tem caminho pronto no painel.
