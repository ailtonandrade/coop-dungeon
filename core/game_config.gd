class_name GameConfig
extends RefCounted
## Escala e proporções de referência do jogo.
## Regra de ouro: 1 unidade = 1 metro = 1 tile. Todo asset é modelado nessa escala.

const MAX_PLAYERS := 4

# Personagem (altura ~1.8 tile, como herói de dungeon crawler isométrico)
const PLAYER_HEIGHT := 1.8
const PLAYER_RADIUS := 0.35
const PLAYER_SPEED := 4.5
const PLAYER_ACCEL := 40.0
const PLAYER_TURN_SPEED := 18.0
const GRAVITY := 30.0

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
## Quem passar dessa distância do companheiro mais próximo é teleportado pra perto dele.
const TETHER_DISTANCE := 16.0
const KILL_Y := -10.0
const STICK_DEADZONE := 0.2

const PLAYER_COLORS: Array[Color] = [
	Color(0.25, 0.55, 1.0),
	Color(1.0, 0.35, 0.3),
	Color(0.35, 0.85, 0.4),
	Color(1.0, 0.8, 0.25),
]
