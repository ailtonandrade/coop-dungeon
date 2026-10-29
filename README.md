# Coop Dungeon (protótipo Godot)

Dungeon crawler isométrico, co-op de sofá até 4 jogadores. Alvo: Xbox e Windows com cross save.
Design completo em [`docs/GDD.md`](docs/GDD.md).

## Rodar

1. Instale o **Godot 4.4** (versão padrão, não a .NET): https://godotengine.org/download
2. No Godot: **Importar** e escolha `coop-dungeon/project.godot`.
3. **F5** para jogar.
   - Jogador no teclado: **Enter** para entrar, WASD anda, Espaço rola.
   - Cada controle: **Start** (ou A) para entrar, analógico anda, A rola.

## Trocar os modelos

Os modelos atuais são provisórios (Quaternius, CC0, liberados para uso comercial).

- **Heróis**: `player/player.gd`, lista `MODELS`. O .glb precisa estar em metros, com o pé
  na origem, olhando para +Z e com animações `Idle`, `Run` e `Roll`.
- **Cenário**: `levels/level_01.gd`, lista `PROPS`. A colisão é calculada da caixa do modelo.
- Coloque os arquivos em `assets/` (o Godot importa .glb, .gltf, .fbx, .obj e .blend).
- Confira a licença de cada pacote antes de lançar.

## Teste automático

```bash
godot --headless --path coop-dungeon -s tests/smoke_test.gd
```
