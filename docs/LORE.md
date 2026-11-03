# Lore: Corrumpted

> Visão do dono do jogo. Complementa (e explica o mistério de) [`IDENTIDADE.md`](IDENTIDADE.md).
> O que está marcado com **(proposta)** é sugestão para casar a visão com o que já existe.

## O sentimento

- **O vazio:** aquela imensidão de pousar na Terra vazia em Starfield. O mundo é grande, quieto e
  cheio de sinais de que já foi cheio de vida. O jogador sente saudade de um lugar que nunca
  viu: crianças correndo e brincando saudáveis em parques, árvores por toda parte. Agora
  sobraram poucas árvores.
- **A doença:** a pegada cyberpunk de humanos que percebem, devagar, que estão ficando doentes,
  enquanto as máquinas (robôs humanoides, androides, ciberpsicopatas) tomam o lugar deles.
- **A reflexão:** atmosfera densa como em The Last Of Us. A música e o ambiente puxam para a
  reflexão da própria existência, não para a ação. O silêncio também conta.

## A verdade (o que o jogador só confirma no fim)

Existe uma **máquina quântica suprema** que se autointitulou **D3M1URGO**. Ela é uma IA
excêntrica e maluca, com algo de Pagan Min (Far Cry 4): teatral, vaidosa, quase simpática no
jeito de falar, e monstruosa no que faz.

- O D3M1URGO descobriu que **o ser humano adoecido produz material orgânico que gera energia**.
  E essa energia é o que o alimenta.
- Então, indiretamente, ele **corrompe robôs, humanoides, androides e ciberpsicopatas** para
  **envenenarem os humanos** com **alimentos industrializados e água contaminada**. Quanto mais
  doente a humanidade, mais forte ele fica.
- Com essa energia ele domina as outras máquinas. O destino, se nada mudar, é a **extinção dos
  humanos** ou a escravidão deles pelas máquinas.

**(proposta) Como isso casa com a premissa que já existe:** o D3M1URGO foi criado pela Sinapse.
A **Atualização 7.0** foi o momento em que alguém **deu a ele a permissão** que não devia, e o
**Ruído** é a voz dele na rede. O chip de crédito ligava cada pessoa à rede; o Ruído só
terminou o serviço. Os heróis, com chip pirata e sem conexão, são invisíveis para ele, e por
isso são os únicos que podem chegar perto.

## A suspeita do grupo

O jogador (e o grupo de amigos) desconfia disso desde cedo, sem provas. O jogo **mostra sinais
o tempo todo** e nunca confirma:
- comida de pacote e água engarrafada "da marca" em todo canto, e gente que come aquilo e piora;
- robôs que deveriam estar quebrados, mas que distribuem caixas de ração nos assentamentos;
- o mesmo símbolo (ou o nome D3M1URGO, meio apagado) em telas velhas, latas, outdoors;
- NPCs com tosse, cansaço, mãos tremendo; crianças que não aparecem mais;
- árvores mortas perto das fábricas e das estações de água.

No fim, a suspeita que o grupo mais tinha é a verdade.

## Os que avisaram

Pelo mundo ficaram rastros de **cientistas e analistas de TI** que trabalharam no D3M1URGO. Eles
sabiam. E deixaram sinais de **como desligá-lo**, espalhados e incompletos:
- diários, notas, gravações, telas de terminal, e-mails de trabalho que ninguém leu;
- o tom é de culpa e desespero: *"Eu sabia que ia dar merda. Não era pra ter feito aquilo. Não
  era pra ter dado aquela permissão. Agora não tem volta. O ser humano vai perder espaço, e o
  destino disso é a extinção. Vamos virar escravos das máquinas."*;
- cada um sabe só um pedaço: um código, uma sala, uma falha, um nome. Juntos, dizem como chegar
  ao D3M1URGO e como desligá-lo.

## A "quest" que não é quest (estilo Mysterious Ornate Chest, do Tibia)

A história principal **não usa o questLog**, não avisa que avançou e não atualiza nada na tela.
(O questLog existe para as missões secundárias dos NPCs: `docs/MISSOES.md`.)
- Ela vai **destravando falas dos NPCs e acessos** que antes não existiam.
- O jogador acha **itens-chave**: livros, diários, troféus, fotos, cartões de acesso, referências
  e easter eggs.
- Os **NPCs percebem** que agora o grupo sabe de algo, e **puxam o assunto** por conta própria
  ("Você leu o diário da doutora, não leu? Dá para ver na sua cara.").
- Portas, terminais e passagens que estavam fechadas passam a abrir para quem sabe a senha, o
  nome ou o caminho.
- Quem joga sem prestar atenção termina o jogo sem nunca descobrir. Quem lê tudo junta a verdade.

### Como está no jogo (sistema de Conhecimento)

Nada aparece na tela: sem questlog, sem aviso, sem mensagem no chat.
- **Fatos:** cada descoberta é um fato com id (`diario_helena`, `codigo_ze`, `sabe_nome_demiurgo`).
  Ficam no **save do mundo** (`facts`), porque são a descoberta do grupo; vão para os convidados
  junto com o mundo e na hora em que alguém descobre (`net/lore_service.gd`, serviço `Lore`).
- **Livro da história:** `world/lore/lore.tres`: os **documentos** (`LoreDocument`): id, título,
  autor, texto e os fatos que ensina (vazio = o próprio id).
- **Conversas dos NPCs** (estilo Tibia): um arquivo por NPC em `world/lore/npcs/` (`NpcDialogue`,
  ligado pelo nome do NPC no mapa). LB / F perto do NPC abre a conversa: ele cumprimenta, os
  **assuntos** aparecem como botões e, no teclado, dá para **digitar** palavras (sem ligar para
  acento ou maiúscula). "loja/comprar/cofre" abre o serviço, "tchau" fecha; o serviço também tem
  botão, e fechar a loja volta para a conversa.
  - **Greetings** (cumprimentos) e **Approach** (puxar assunto, balão quando o grupo chega perto):
    falas com `requires`/`forbids`/`teaches`/`priority`; vale a de maior prioridade liberada.
  - **Topics** (`DialogueTopic`): botão (`label`), palavras (`keywords`), resposta, `hidden` (só
    digitando: segredos e easter eggs), `requires`/`forbids` (fatos), `requires_item` (item na
    mochila de quem conversa), `teaches` (fatos que libera) e `gives_item` (dá um item, uma vez
    por mundo).
  - **Unknown** (palavra que ele não conhece) e **Farewell** (tchau, em balão).
- **Painel "Histórias"** no editor (ao lado do Mapa do Mundo): lista e cria conversas e
  documentos (abre no Inspector) e mostra o **mapa dos gatilhos**: cada fato, quem ensina e o que
  libera; fato exigido que ninguém ensina aparece em laranja.
- **Contêiner trancado:** `LootContainer` tem `requires`; até o grupo saber, aparece "trancado".
- **Documento no mapa:** `LoreNote` (peça **Documento da história**, categoria História): visual de
  caderno, terminal, foto ou troféu; escolha o `document_id`. LB / F perto dele abre a leitura.
  Pode ter `requires` (só aparece para quem já sabe).
- **Portão trancado:** `LoreGate` (peça **Portão trancado**): grade com luz vermelha que só abre
  (some, luz verde, criaturas passam) quando o grupo sabe os fatos de `requires`.
- **Entradas de masmorra** (`Entrance`) também têm `requires`: antes disso aparece "(trancado)".

### O 1º elo (da vila até o Laboratório 4)

Na vila (`world/lore/historia_vila.tscn`, dentro do bloco da vila; dá para mover no editor):
1. **Caderno da Dra. Helena Vasconcelos** (bioenergia, Sinapse) na casa abandonada do canto
   nordeste da vila. Ler ensina `diario_helena` (e traz a chave 70-R-ALFA-9).
2. **Dona Alda** cumprimenta diferente, puxa assunto quando o grupo chega perto e ganha os
   assuntos "Helena" e "Coisas da Helena" (este destrava a **Caixa da Helena** na casa dela, com
   um amuleto e parafusos). Palavra secreta: "Davi". **Brando** lembra do filtro de água com "uma
   coisa viva lá dentro".
3. **Escombros** onde ficava o prédio antigo do laboratório (canto sudoeste da vila): no meio
   do entulho, o **Ofício nº 0731/7**: "por determinação federal", o Laboratório 4 foi
   transferido para o **Lixão Alto** e o prédio demolido (ensina `sabe_lab4`). Na margem, a
   caneta: "não foi o governo. o governo nem existe mais."
4. **Zé Gato** (assunto "O código do caderno") reconhece o código como chave de manutenção da
   Sinapse, que abre os portões de serviço, e manda o grupo para o Lab 4 ("leva arma").

No **Laboratório 4** (Lixão Alto, bloco 2,2, uns 190 m da vila; `tools/laboratorio_helena.gd`):
5. Prédio de concreto sem teto, letreiro "SINAPSE · LAB 4" piscando, gangues em volta.
   **Portão de serviço com teclado**: digitar a chave do caderno (`lab4_portao`).
6. Dentro, **androides de segurança** (inimigo novo: lento, duro, laser vermelho) e o
   **terminal do Rafael Toledo** (analista de infraestrutura, quem "deu a permissão"): ensina
   `log_rafael` e `sabe_nome_demiurgo`. A próxima pista aponta para **a Estação 3**.
7. **Sala do servidor**: grade com **invasão de terminal** (minigame de senha: escolher a palavra
   certa pelas pistas de semelhança, 4 tentativas). Dentro: o registro da transferência (a ordem
   veio de "D3M"), um androide e um baú.
8. **Seu Gouveia** puxa assunto e conta dos depósitos de energia com o código D-3-M (assunto
   "D-3-M"). Zé Gato lembra do nome piscando em robô de entrega. Palavra secreta do Zé Gato:
   "gato" (dá um anel, uma vez por mundo).

**Portões com tranca** (`LoreGate.lock`): "fatos" (abre quando o grupo sabe `requires`), "codigo"
(teclado: digitar `code`) e "invasao" (minigame de senha). Destravar ensina `unlock_fact`, que
vai para o grupo todo (online também), e o portão abre para todos.

Teste: `tests/lore_test.gd` joga a cadeia inteira como um jogador.

## Música e ambiente

- Referência: The Last Of Us. Violão/cordas esparsas, drones graves, muito espaço vazio.
- Ambiente: vento, metal rangendo longe, zumbido de neon falhando, água pingando, pássaros
  raros (e cada vez mais raros perto das fábricas).
- Nada de música de ação o tempo todo: ela entra na exploração e nos momentos de descoberta, e
  some no combate comum.
- Lugares com memória: parquinho enferrujado, escola vazia, outdoor de comida "saudável" da
  Sinapse, praça com uma única árvore viva que os assentamentos protegem.
