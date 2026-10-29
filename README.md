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

## Testes automáticos

Jogo offline (fase, combate, escalada, inimigos, save):

```bash
godot --headless --fixed-fps 60 --path coop-dungeon -s tests/smoke_test.gd
```

Online de ponta a ponta (sobe um host e um cliente na mesma máquina):

```bash
GODOT=godot coop-dungeon/tests/run_net_test.sh
```
