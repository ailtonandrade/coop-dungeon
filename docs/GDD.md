# Coop Dungeon: documento de design (protótipo)

## Visão

Dungeon crawler de ação isométrico, **co-op de sofá** (1 a 4 jogadores numa tela só),
com escala, proporções, ritmo e conjunto de funcionalidades **1:1 com a referência
Minecraft Dungeons / Dungeons 2**. Plataformas: **Xbox Series X|S** e **Windows**
(Microsoft Store/Game Pass **e** Steam), com **cross save** entre todas.

### O que "1:1" significa aqui (e o que não significa)

| Pode copiar 1:1 (mecânica, regra, número) | Precisa ser nosso (propriedade intelectual) |
|---|---|
| Escala do personagem, câmera, velocidade, tamanho das salas | Nomes de itens, encantamentos, mobs, fases |
| Estrutura: corpo a corpo + à distância + 3 artefatos, rolada, poção | Arte, estilo visual em blocos, ícones, layout exato de UI |
| Equipamento define o "build" (sem classe fixa) | Músicas, sons, textos |
| Pontos de encantamento por nível, poder de equipamento | Mapas e layouts de fase copiados |

Mecânica não tem direito autoral, mas **visual e conteúdo têm**. Isso pesa mais ainda
porque a referência é da própria Microsoft, que também aprova o jogo na loja do Xbox.

## Escala e câmera (fonte da verdade: `core/game_config.gd`)

- **1 unidade = 1 metro = 1 tile.** Todo asset é modelado nessa escala, com o pé na origem.
- Herói: ~1,8 m de altura, raio de colisão 0,35 m, corre a 4,5 m/s.
- Rolada: 0,4 s, ~3 m de deslocamento, 1 s de recarga.
- Câmera: perspectiva com FOV 30° (quase ortográfica), pitch -50°, yaw 45°,
  distância entre 17 e 28 m, com zoom automático conforme o grupo se espalha.
- Co-op: uma câmera só (sem tela dividida). Quem se afasta mais de 16 m do companheiro
  mais próximo é teleportado para perto dele.

> Esses números foram calibrados a olho a partir do primeiro Dungeons. Vale ajustar
> jogando lado a lado com o Dungeons 2 e só mexer em `game_config.gd`.

## Combate (valores atuais)

- Combo: 10 / 10 / 22 de dano; o 3º golpe empurra longe e treme a câmera.
- Mira assistida: o golpe vira para o inimigo mais próximo num raio de 4 m;
  a flecha corrige para o inimigo dentro de um cone de 30°.
- Inimigos sempre "avisam" o ataque ficando vermelhos (0,5 s no brutamontes, 0,7 s no atirador).
  Apanhar interrompe o ataque deles.
- Herói: 100 de vida. Poção cura 40% (recarga de 15 s). Caído, um companheiro
  perto por 2 s revive com 50%. Todos caídos: em 3 s a arena reinicia na onda 1.

## Controles (padrão)

| Ação | Controle | Teclado |
|---|---|---|
| Mover | Analógico esquerdo | WASD |
| Corpo a corpo | X | J |
| Rolar | A | Espaço |
| À distância | RT | K |
| Poção | Y | E |
| Artefato | RB | Q |
| Entrar no jogo | Start / A | Enter |

## Funcionalidades (escopo completo, em ordem de construção)

1. **Movimento e co-op**: entrar/sair a qualquer momento, câmera compartilhada, corda de teleporte. ✅ protótipo
2. **Combate**: combo de 3 golpes, arma à distância com munição, rolada com invulnerabilidade, hit-stop, knockback.
   ✅ protótipo (flecha ainda sem munição)
3. **Inimigos**: corpo a corpo, à distância, explosivo, elite; spawner por sala; IA com NavigationAgent3D.
   ✅ protótipo: corpo a corpo e à distância, ondas na arena
4. **Sobrevivência**: vida, poção com recarga, cair/reviver pelo parceiro, vidas por fase.
   ✅ protótipo (sem vidas por fase; se todos caem, reinicia a arena)
5. **Loot**: baús e drops **por jogador** (cada um vê o seu); raridade; poder do equipamento.
6. **Progressão**: nível do herói gera pontos de encantamento; 3 encantamentos por item.
7. **Artefatos**: 3 slots com recarga.
8. **Fases**: salas modulares em grid de 1 m, montadas por geração procedural com trechos fixos.
9. **Hub e mapa de missões**, dificuldades e modificadores.
10. **Plataforma**: perfis por controle, save na nuvem, conquistas, certificação.

## Arquitetura

```
core/       InputService (controle -> slot), SaveService (fachada), PlayerManager, GameConfig
player/     Player (CharacterBody3D) + cena
camera/     SharedCamera
levels/     fases
ui/         HUD
platform/   tudo que muda por plataforma: PlatformService, SaveBackend e implementações
assets/     modelos provisórios (Quaternius, CC0)
tests/      teste de fumaça headless
```

Regras:
- O jogo **nunca** lê `Input` direto. Sempre `InputService.get_move(slot)` / `just_pressed(slot, ação)`.
- O jogo **nunca** grava arquivo direto. Sempre `SaveService`.
- Código específico de Xbox/Steam fica só em `platform/`.
- GDScript (não C#), por ser o caminho mais seguro para o port de console.

## Save e cross save

**Dois tipos de save:**
- `world`: progresso da campanha (fases liberadas, história). Pertence ao **host** (P1).
- `player`: personagem (equipamento, nível, encantamentos). Pertence à **conta de cada jogador**.
  Um convidado sem conta joga com personagem temporário.

**Identidade única:** conta Microsoft/Xbox em todas as plataformas.
- Xbox e Microsoft Store: usuário Xbox por controle (GDK `XUser`).
- Steam: login com a conta Microsoft dentro do jogo (dá para usar Xbox services no PC fora da Store).

**Armazenamento:** cache local sempre (o jogo funciona offline) mais uma nuvem única:
- Recomendação: **PlayFab** (da Microsoft) como nuvem comum às três lojas, chaveado pela conta Microsoft.
- No Xbox/Store também existe o `XGameSave` (cloud save nativo), mas ele não chega na Steam.
  Usar só PlayFab evita ter duas nuvens para reconciliar.
- Conflito: cada save tem `version` e `updated_at`. Se o local e o da nuvem divergirem,
  vence o mais novo, e o jogador pode escolher quando os dois mudaram offline.
- Antes de fechar a decisão, confirmar com o ID@Xbox os requisitos de certificação sobre save.

## Caminho para o Xbox

1. Cadastro no **ID@Xbox** para ter dev kit e acesso ao GDK.
2. Port do Godot para Xbox via **W4 Games** (ou estúdio de port). Godot oficial não exporta para console.
3. Implementar `platform/xbox/`: `XUser` por controle, save, conquistas, pausa ao
   desconectar controle e troca de usuário (requisitos de certificação).
4. PC Microsoft Store pelo mesmo GDK; Steam pelo export Windows padrão mais o login Microsoft.

## Marcos do protótipo

| Marco | Entrega | Status |
|---|---|---|
| M0 | Projeto, câmera isométrica, personagem andando | ✅ |
| M1 | Co-op até 4 (entrar com Start), câmera compartilhada, corda | ✅ |
| M2 | Combate corpo a corpo + rolada com invulnerabilidade | ✅ combo, flecha, hit-stop, tremida |
| M3 | 2 inimigos com IA e spawner | ✅ brutamontes e atirador, ondas |
| M4 | Vida, cair/reviver, baú com loot, fim de fase | vida, poção, cair/reviver ✅ |
| M5 | Save local `world` / `player` ligado ao jogo | serviço ✅ |
