# Corrumpted (protótipo Godot)

RPG de ação isométrico em cyberpunk de ferro-velho: robôs sucateados, gangues e os Corrompidos
(humanos com chip queimado). Identidade e história em [`docs/IDENTIDADE.md`](docs/IDENTIDADE.md).

Dungeon crawler isométrico, co-op de sofá até 4 jogadores. Alvo: Xbox e Windows com cross save.
Design completo em [`docs/GDD.md`](docs/GDD.md); estrutura e como estender em [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Rodar

1. Instale o **Godot 4.7** (versão padrão, não a .NET): https://godotengine.org/download
2. No Godot: **Importar** e escolha `coop-dungeon/project.godot`.
3. **F5** para jogar.
   - Teclado + mouse: **Enter** entra, WASD anda, mouse mira, botão esquerdo (ou J) ataca,
     botão direito (ou K) atira, Espaço pula, Shift rola, E poção, F pega item / fala com NPC, I inventário.
   - Cada controle: **Start** (ou A) entra, analógico esquerdo anda, **analógico direito mira**,
     X ataca, RT atira, A pula, B rola, Y poção, LB pega item / fala com NPC, Back inventário.
   - Na Vila de Pedra: comerciante, ferreiro (refino), encantador e banco. Criaturas soltam moedas.
   - Mirando, o herói anda de costas e de lado olhando para a mira, e dá pra atirar andando.
   - Pule contra uma borda (até ~2,7 m: pilares, plataformas, carro, contêiner) e o herói escala sozinho.
   - Ondas de inimigos chegam sozinhas. Quem cai é revivido quando um companheiro fica perto.

## Mundos e online

O jogo abre no menu:
- **Novo mundo**: nome, semente e quem pode entrar:
  - **Aberto**: aparece em "Buscar mundos" para quem está na mesma rede.
  - **Privado**: só entra quem tiver o seu IP.
  - **Offline**: só o pessoal do sofá.
- **Meus mundos**: continuar ou apagar mundos salvos.
- **Buscar mundos**: lista os mundos abertos na rede local, ou entra direto pelo IP do host.

Sofá e online somam até 4 jogadores por sala. Quem entra pela rede também aperta Start
(ou Enter) para cada controle do sofá dele.
- O IP do host aparece no canto da tela e no menu de pausa (Esc / Start).
- **Pela internet:** o host libera a porta **7777 UDP** no roteador e passa o IP público.
  Na versão de lançamento isso vira convite pelo Xbox/Steam, sem mexer em roteador.
- **Firewall do Windows:** na primeira vez que abrir um mundo, permita o Godot / o jogo.

## Trocar os modelos

Os modelos atuais são provisórios (Quaternius, CC0, liberados para uso comercial).

- **Heróis**: `player/player.gd`, lista `MODELS`. O .glb precisa estar em metros, com o pé
  na origem, olhando para +Z e com animações `Idle`, `Run` e `Roll`.
- **Cenário**: `levels/level_01.gd`, lista `PROPS`. A colisão é calculada da caixa do modelo.
- Coloque os arquivos em `assets/` (o Godot importa .glb, .gltf, .fbx, .obj e .blend).
- Confira a licença de cada pacote antes de lançar.

## Inventário

Estilo Tibia: 9 casas de equipamento e a mochila equipada, que pode ter bolsas dentro.
Cada jogador do sofá abre o seu (Back / I) e navega com o próprio controle ao mesmo tempo.
- Controle: direcional move · **A** pega e solta · **Y** equipa (ou abre a bolsa) · **X** larga no chão · **B** volta.
- Teclado: WASD/setas · Espaço · E · J · Shift.
- O loot é do time todo (estilo MU): quem pegar primeiro (LB / F perto do item) leva.

## Mundo aberto

O jogo abre no mundo aberto (`world/world.tscn`): região de teste com a Vila de Pedra no centro,
planície, bosque, colinas e a Caverna Velha (fique na entrada para o grupo entrar junto).
Os blocos do mapa ficam em `world/chunks/` e se editam no Godot com o painel **Mapa do Mundo**
(pintar chão e paredes, peças prontas, masmorras, entradas, validar): ver `docs/EDITOR_DE_MAPA.md`.

## Exportar

`export_presets.cfg` já tem a exportação para Windows; ela deixa de fora o editor de mapa
(`addons/`), as ferramentas, os testes e a documentação. Precisa dos modelos de exportação do
Godot 4.7 instalados (Editor > Gerenciar modelos de exportação).

## Testes automáticos

Jogo offline (fase, combate, escalada, inimigos, save):

```bash
godot --headless --fixed-fps 60 --path coop-dungeon -s tests/smoke_test.gd
```

Lógica do inventário (equipar, bolsas dentro de bolsas, mochila cheia, save):

```bash
godot --headless --path coop-dungeon -s tests/inventory_test.gd
```

Mundo aberto (carregamento, criaturas, telhado, masmorra, pausa):

```bash
godot --headless --fixed-fps 60 --path coop-dungeon -s tests/world_test.gd
```

Editor de mapa (criar bloco, pintar, masmorra, entradas, validar):

```bash
godot --headless --path coop-dungeon -s tests/map_tools_test.gd
```

Serviços da cidade (comerciante pela tela, refino, encantamento, banco, moedas):

```bash
godot --headless --fixed-fps 60 --path coop-dungeon -s tests/services_test.gd
```

Online de ponta a ponta (sobe um host e um cliente na mesma máquina; depois um cliente com mapa
adulterado, que tem que ser recusado):

```bash
GODOT=godot coop-dungeon/tests/run_net_test.sh
```
