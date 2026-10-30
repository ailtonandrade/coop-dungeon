class_name GameConfig
extends RefCounted
## Escala e proporções de referência do jogo.
## Regra de ouro: 1 unidade = 1 metro = 1 tile. Todo asset é modelado nessa escala.

const MAX_PLAYERS := 4

## O mapa do mundo (único para todos; só o dono do jogo edita, no editor).
## A cena world/world.tscn aponta para o mesmo arquivo.
const WORLD_MAP := "res://world/test_world.tres"

# Personagem (altura ~1.8 tile, como herói de dungeon crawler isométrico)
const PLAYER_HEIGHT := 1.8
const PLAYER_RADIUS := 0.35
const PLAYER_SPEED := 4.5
const PLAYER_ACCEL := 40.0
const PLAYER_TURN_SPEED := 18.0
const GRAVITY := 30.0

# Pulo e escalada
## Altura máxima do pulo ~1,2 m. A escalada agarra bordas até MANTLE_REACH acima do pé,
## então pulando dá para subir em coisas de até ~2,7 m (pilares, carro, contêiner).
const JUMP_VELOCITY := 8.5
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12
const MANTLE_REACH := 1.6
const MANTLE_TIME := 0.4

# Rolada (esquiva)
const DODGE_SPEED := 8.0
const DODGE_TIME := 0.4
const DODGE_COOLDOWN := 1.0

# Câmera: perspectiva com FOV baixo (quase ortográfica), pitch e yaw fixos
const CAMERA_YAW_DEG := 45.0
const CAMERA_PITCH_DEG := -50.0
const CAMERA_FOV := 30.0
const CAMERA_DIST_MIN := 17.0
const CAMERA_DIST_MAX := 28.0
const CAMERA_FOLLOW_SPEED := 6.0
const CAMERA_ZOOM_SPEED := 3.0
## Distância entre os jogadores mais afastados que leva ao zoom máximo.
const CAMERA_SPREAD_FOR_MAX := 14.0

# Co-op
## Sofá: distância máxima entre jogadores da mesma tela (parede invisível).
## Mantém o grupo na tela e a região em volta dele carregada.
const COUCH_LEASH := 13.0
## Reserva: quem passar disso do companheiro da mesma tela (queda, empurrão) é teleportado.
const TETHER_DISTANCE := 16.0
const KILL_Y := -10.0
const STICK_DEADZONE := 0.2
## Mouse: o herói olha para o cursor enquanto o mouse foi mexido há menos que isso
## (ou com um botão do mouse apertado). Só no teclado, ele olha para onde anda.
const MOUSE_AIM_TIMEOUT := 3.0
## Analógico direito abaixo disso não mira.
const AIM_DEADZONE := 0.35
## Andando de costas mirando, a velocidade cai para esta fração (de lado fica no meio).
const BACKPEDAL_SPEED_FACTOR := 0.65

# Camadas de física (valor do bit)
const LAYER_WORLD := 1
const LAYER_PLAYERS := 2
const LAYER_ENEMIES := 4
## Só para a câmera achar o que tapa o herói (telhados, copas de árvore). Ninguém colide nela.
const LAYER_OCCLUDER := 8

# Combate do herói
const PLAYER_MAX_HP := 100.0
const MELEE_RADIUS := 2.0
const MELEE_ARC_DEG := 120.0
## Raio em que o golpe vira sozinho para o inimigo mais próximo (mira assistida).
const SOFT_AIM_RADIUS := 4.0
const ARROW_SPEED := 22.0
const ARROW_DAMAGE := 8.0
const ARROW_COOLDOWN := 0.45
const ARROW_RANGE := 20.0
const ARROW_AIM_CONE_DEG := 30.0
## Correção de mira quando o jogador está mirando de verdade (analógico direito / mouse).
const ARROW_AIM_ASSIST_DEG := 12.0
const HITSTOP_TIME := 0.06
## Segurando o ataque, o combo se repete sozinho; entre um combo completo e o próximo há esta pausa.
const MELEE_REPEAT_COOLDOWN := 0.25
const POTION_HEAL := 0.4
const POTION_COOLDOWN := 15.0

# Cair e reviver
const REVIVE_RADIUS := 1.8
const REVIVE_TIME := 2.0
const REVIVE_HP := 0.5
const WIPE_RESTART_TIME := 3.0

const PLAYER_COLORS: Array[Color] = [
	Color(0.25, 0.55, 1.0),
	Color(1.0, 0.35, 0.3),
	Color(0.35, 0.85, 0.4),
	Color(1.0, 0.8, 0.25),
]
