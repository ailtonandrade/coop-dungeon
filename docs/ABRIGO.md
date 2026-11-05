# Abrigo (base do jogador) e mapa

## Entrar no modo de construção

- **Teclado:** digite `/construir` no chat (de novo para sair).
- **Controle:** segure **LB + RB** por 1,5 s (de novo para sair). Com LB segurado, RB não joga granada.

O editor de mapa do dono do jogo (antigo `/construir`) agora é **`/editar`** e continua só no projeto.

| | Teclado/mouse | Controle |
|---|---|---|
| Construir | clique esquerdo | X |
| Desmontar (devolve metade) | clique direito | RT |
| Trocar peça | Q / E | ◀ ▶ |
| Trocar material | T | ▲ |
| Girar | R | Y |
| Sair | `/construir` | B (ou LB+RB) |

O fantasma da peça aparece à frente do herói, encaixado na grade de 3 m da base: verde pode,
vermelho não (o painel diz o motivo). O host confere tudo de novo.

## Receitas (liberam com o nível)

| Nível | Receita | Custo |
|---|---|---|
| 3 | Terminal de base | 10 metal, 4 fibra |
| 3 | Piso / Parede | 4 do material escolhido |
| 3 | Parede com porta | 3 do material |
| 3 | Cama | 6 madeira, 2 fibra |
| 5 | Teto | 4 do material |
| 5 | Luminária | 2 metal, 2 fibra |
| 7 | Baú | 6 madeira, 2 metal |

Materiais: **metal**, **madeira** e **fibra de vidro**. São contadores do herói (não ocupam a
mochila), caem das criaturas (`Loot.MATERIAL_CHANCE`) e sempre vêm um pouco nos baús e
contêineres do mapa. Tudo fica em `world/base/base_catalog.gd`.

## Terminal e área segura

- Um terminal por personagem. Só num pátio aberto: longe de NPCs/cidade (40 m), fora de região
  segura, longe de ninho de criaturas e de outro abrigo, sem muita coisa de pé em volta.
- Em volta dele fica a área do abrigo (raio de 15 m), contornada no chão. Lá dentro é **zona
  segura**: criaturas não entram nem miram quem está dentro, e nada fere.
- Só o dono constrói no abrigo dele. O terminal aparece no minimapa e no mapa como uma casinha.
- **Cama:** quando o grupo todo cai, o dono acorda nela.
- **Baú:** abre o cofre (o mesmo do banco), então dá para guardar coisas no abrigo.
- **Luminária:** luz quente acesa.

Os abrigos ficam no save do mundo (`world["bases"]`) e vão para os convidados ao entrar e a cada
mudança (`NetService.set_base`).

## Mapa completo

**M** no teclado, **direcional ◀** no controle. Mostra os blocos com o nome da região, o terreno
carregado, heróis, NPCs, para onde ir nas missões e os abrigos. Rodinha / RT·LB dão zoom; WASD,
arrastar ou o analógico movem a vista; M, Esc ou B fecham.
