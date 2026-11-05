# Desempenho (PC fraco, gráfico integrado)

Alvo: rodar liso num i5 de 4ª geração com gráfico integrado (Intel HD 4600) em 720p/1080p na
qualidade **Baixa**.

## O que foi medido (mundo aberto, 9 blocos carregados, vila à noite)

| Item | Antes | Agora |
|---|---|---|
| Renderizador | Forward+ (Vulkan/D3D12) | Compatibilidade (OpenGL 3.3) |
| Chamadas de desenho por quadro | ~860 | ~580 |
| Malhas visíveis | ~1140 | ~750 |
| Minimapa | redesenha o mundo todo quadro | 10x/s (5x/s na Baixa) |
| CPU (scripts + física, depois de carregar) | ~10 ms | ~10 ms |

- **Renderizador:** o Forward+ tem custo fixo alto e, no Intel HD de 4ª geração, quase sempre
  cai para um caminho lento. O de compatibilidade é o recomendado para esse tipo de placa, e o
  jogo já usava só recursos que ele tem (névoa, brilho do neon, ajuste de cor, sombra do sol).
- **Decoração juntada (`world/static_batcher.gd`):** ao carregar um bloco, as pecinhas paradas
  com o mesmo visual viram uma malha por pedaço de 32 m. Ficam de fora o que se mexe, o que
  some com a câmera, os letreiros acesos e o que as missões fazem sumir. No `/editar` tudo volta.
- **Qualidade Baixa:** resolução 3D em 60% (com FSR), sem sombra do sol, sem brilho do neon,
  objetos pequenos somem a 45 m. Na **primeira vez** o jogo escolhe Baixa sozinho se a placa for
  integrada (Intel HD/UHD/Iris, Radeon de APU) ou de software (`Graphics.suggested_quality`).

## O que ainda pesa

- **Criaturas:** cada uma tem várias partes (corpo, equipamento). Com dezenas por perto, é o
  maior custo restante, junto com as árvores, os carros e as paredes que somem com a câmera
  (cada uma precisa ser desenhada à parte para sumir sozinha).
- **Entrar no mundo:** os primeiros segundos travam um pouco (blocos montando, navegação das
  criaturas sendo calculada).

## Dicas para quem joga em PC fraco

- Configurações → Gráficos → **Baixa (PC fraco)**.
- Windows: driver de vídeo **mais novo da Intel** (o do Windows Update costuma ser antigo) e o PC
  no plano de energia **Alto desempenho** (no notebook, na tomada).
- Memória em **dual channel** (dois pentes iguais) faz muita diferença no gráfico integrado.
- Jogar em janela 720p se ainda pesar.
