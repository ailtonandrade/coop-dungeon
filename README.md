# Coop Dungeon (protótipo Godot)

Dungeon crawler isométrico, co-op de sofá até 4 jogadores. Alvo: Xbox e Windows com cross save.
Design completo em [`docs/GDD.md`](docs/GDD.md).

## Rodar

1. Instale o **Godot 4.7** (versão padrão, não a .NET): https://godotengine.org/download
2. No Godot: **Importar** e escolha `coop-dungeon/project.godot`.
3. **F5** para jogar.
   - Teclado: **Enter** entra, WASD anda, Espaço pula, J ataca, K atira flecha, Shift rola, E bebe poção.
   - Cada controle: **Start** (ou A) entra, analógico anda, A pula, X ataca, RT atira, B rola, Y poção.
   - Pule contra uma borda (até ~2,7 m: pilares, plataformas, carro, contêiner) e o herói escala sozinho.
   - Ondas de inimigos chegam sozinhas. Quem cai é revivido quando um companheiro fica perto.

## Trocar os modelos

Os modelos atuais são provisórios (Quaternius, CC0, liberados para uso comercial).

- **Heróis**: `player/player.gd`, lista `MODELS`. O .glb precisa estar em metros, com o pé
  na origem, olhando para +Z e com animações `Idle`, `Run` e `Roll`.
- **Cenário**: `levels/level_01.gd`, lista `PROPS`. A colisão é calculada da caixa do modelo.
- Coloque os arquivos em `assets/` (o Godot importa .glb, .gltf, .fbx, .obj e .blend).
- Confira a licença de cada pacote antes de lançar.

## Teste automático

```bash
godot --headless --fixed-fps 60 --path coop-dungeon -s tests/smoke_test.gd
```
