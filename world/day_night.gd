class_name DayNight
extends Node
## Relógio do mundo e ciclo de dia e noite. O host (ou o sofá offline) manda no relógio: ele
## anda sozinho, fica no save do mundo (chave "clock", em horas 0..24) e vai junto quando alguém
## entra. Os convidados andam o relógio por conta própria e o host corrige de tempos em tempos.
##
## A luz segue a hora: madrugada azul-escura, amanhecer rosado, dia de poluição, fim de tarde
## dourado, anoitecer roxo e noite (com o neon brilhando mais). O sol cruza o céu de dia e a lua
## faz a luz fria de noite.

signal hour_changed(hour: int)

## Minutos de verdade para um dia inteiro do jogo (24 = uma hora do jogo por minuto).
const DAY_MINUTES := 24.0
## Mundo novo começa no fim da tarde: dá para ver o pôr do sol e a noite logo no começo.
const START_HOUR := 17.0
## De quantos em quantos segundos o host manda a hora para os convidados.
const SYNC_EVERY := 15.0
## Sol entre estas horas; fora delas é a lua.
const SUNRISE := 5.5
const SUNSET := 19.5

## Pontos da luz ao longo do dia (hora, cor do céu, luz ambiente, força do ambiente,
## cor do sol/lua, força do sol/lua, brilho do neon). Entre dois pontos a luz vai misturando.
const KEYS := [
	[0.0, Color(0.015, 0.02, 0.04), Color(0.34, 0.38, 0.6), 0.22, Color(0.55, 0.65, 1.0), 0.2, 1.3],
	[4.5, Color(0.02, 0.025, 0.05), Color(0.34, 0.38, 0.58), 0.23, Color(0.55, 0.65, 1.0), 0.18, 1.3],
	[5.5, Color(0.08, 0.06, 0.1), Color(0.45, 0.42, 0.55), 0.36, Color(0.85, 0.65, 0.6), 0.12, 1.15],
	[6.5, Color(0.3, 0.22, 0.24), Color(0.66, 0.58, 0.58), 0.45, Color(1.0, 0.75, 0.58), 0.5, 1.0],
	[9.0, Color(0.32, 0.36, 0.42), Color(0.62, 0.64, 0.7), 0.47, Color(1.0, 0.93, 0.84), 0.78, 0.85],
	[16.0, Color(0.34, 0.35, 0.4), Color(0.64, 0.63, 0.66), 0.47, Color(1.0, 0.9, 0.78), 0.76, 0.85],
	[18.0, Color(0.4, 0.26, 0.22), Color(0.7, 0.58, 0.54), 0.48, Color(1.0, 0.72, 0.5), 0.7, 0.95],
	[19.5, Color(0.09, 0.06, 0.12), Color(0.44, 0.4, 0.58), 0.38, Color(0.72, 0.6, 0.85), 0.12, 1.15],
	[21.0, Color(0.02, 0.025, 0.05), Color(0.35, 0.38, 0.6), 0.23, Color(0.55, 0.65, 1.0), 0.2, 1.3],
	[24.0, Color(0.015, 0.02, 0.04), Color(0.34, 0.38, 0.6), 0.22, Color(0.55, 0.65, 1.0), 0.2, 1.3],
]

var hour := START_HOUR
var environment: Environment
var sun: DirectionalLight3D

var _sync_timer := 0.0
var _last_whole := -1
var _base_glow := 0.9
var _lights_on := -1.0

## Postes de luz (prefab "PosteDeLuz"): apagados de dia, acendem no anoitecer.
const STREET_LIGHT_PREFIX := "PosteDeLuz"
const LIGHTS_ON := [18.6, 19.6]   # começa a acender, totalmente aceso
const LIGHTS_OFF := [5.6, 6.6]    # começa a apagar, apagado


static func of(tree: SceneTree) -> DayNight:
	return tree.get_first_node_in_group("day_night") as DayNight


func setup(p_environment: Environment, p_sun: DirectionalLight3D) -> void:
	environment = p_environment
	sun = p_sun
	_base_glow = environment.glow_intensity
	hour = wrapf(float(NetService.world.get("clock", START_HOUR)), 0.0, 24.0)
	_apply()


func _ready() -> void:
	add_to_group("day_night")
	NetService.clock_received.connect(_on_clock_received)
	# Postes que já estão no mundo e os que os blocos do mapa forem trazendo.
	get_tree().node_added.connect(_on_node_added)
	for light: Node in get_tree().root.find_children("*", "OmniLight3D", true, false):
		_on_node_added(light)


func _on_node_added(node: Node) -> void:
	if node is Light3D and node.get_parent() and String(node.get_parent().name).begins_with(STREET_LIGHT_PREFIX):
		var light := node as Light3D
		if not light.has_meta("full_energy"):
			light.set_meta("full_energy", light.light_energy)
		light.add_to_group("street_lights")
		_set_light(light, street_lights_level(hour))


func _exit_tree() -> void:
	# Quem manda no mundo guarda a hora no save.
	if NetService.mode != NetService.Mode.CLIENT and NetService.world.has("id"):
		NetService.world["clock"] = hour
		SaveService.save_world(NetService.world)


func _process(delta: float) -> void:
	hour = wrapf(hour + delta * 24.0 / (DAY_MINUTES * 60.0), 0.0, 24.0)
	if NetService.mode != NetService.Mode.CLIENT:
		NetService.world["clock"] = hour
		_sync_timer -= delta
		if _sync_timer <= 0.0:
			_sync_timer = SYNC_EVERY
			NetService.send_clock(hour)
	_apply()


## Muda a hora (comando /hora do dono do jogo). Só quem manda no mundo.
func set_hour(value: float) -> void:
	if NetService.mode == NetService.Mode.CLIENT:
		return
	hour = wrapf(value, 0.0, 24.0)
	NetService.world["clock"] = hour
	NetService.send_clock(hour)
	_apply()


## "18:42"
func clock_text() -> String:
	var minutes := int(hour * 60.0) % (24 * 60)
	return "%02d:%02d" % [minutes / 60, minutes % 60]


func is_night() -> bool:
	return hour >= SUNSET or hour < SUNRISE


func _on_clock_received(value: float) -> void:
	# Pequena diferença só acerta o passo; grande (entrou agora, /hora) pula direto.
	var diff := wrapf(value - hour, -12.0, 12.0)
	hour = wrapf(hour + diff, 0.0, 24.0)
	_apply()


func _apply() -> void:
	var whole := int(hour)
	if whole != _last_whole:
		_last_whole = whole
		hour_changed.emit(whole)
	if environment == null or sun == null:
		return
	var light := sample(hour)
	# Chuva fecha o céu: menos sol, céu e névoa cinza, neblina mais perto.
	var weather := get_tree().get_first_node_in_group("weather")
	var rain: float = float(weather.get("level")) if weather else 0.0
	var grey: Color = Color(0.16, 0.17, 0.19) * (0.35 + 0.65 * float(light.ambient_energy) / 0.5)
	light.sky = (light.sky as Color).lerp(grey, rain * 0.6)
	environment.background_color = light.sky
	environment.ambient_light_color = light.ambient
	environment.ambient_light_energy = light.ambient_energy * (1.0 - 0.18 * rain)
	environment.fog_light_color = light.sky.lerp(Color(0.1, 0.09, 0.14), 0.5)
	environment.fog_depth_begin = lerpf(45.0, 26.0, rain)
	environment.glow_intensity = _base_glow * light.neon
	sun.light_color = light.sun
	sun.light_energy = light.sun_energy * (1.0 - 0.55 * rain)
	sun.rotation_degrees = sun_angles(hour)
	var level := street_lights_level(hour)
	if absf(level - _lights_on) > 0.01:
		_lights_on = level
		for lamp: Node in get_tree().get_nodes_in_group("street_lights"):
			_set_light(lamp as Light3D, level)


## Quanto os postes estão acesos nesta hora (0 = apagados, 1 = acesos).
static func street_lights_level(at_hour: float) -> float:
	var h := wrapf(at_hour, 0.0, 24.0)
	if h >= LIGHTS_ON[0]:
		return clampf((h - LIGHTS_ON[0]) / (LIGHTS_ON[1] - LIGHTS_ON[0]), 0.0, 1.0)
	if h >= LIGHTS_OFF[0]:
		return 1.0 - clampf((h - LIGHTS_OFF[0]) / (LIGHTS_OFF[1] - LIGHTS_OFF[0]), 0.0, 1.0)
	return 1.0


## Apagado, o poste nem entra na conta da luz (de dia o jogo fica mais leve).
static func _set_light(light: Light3D, level: float) -> void:
	light.light_energy = float(light.get_meta("full_energy", light.light_energy)) * level
	light.visible = level > 0.01


## Luz misturada para uma hora.
static func sample(at_hour: float) -> Dictionary:
	var h := wrapf(at_hour, 0.0, 24.0)
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if h >= a[0] and h <= b[0]:
			var k := smoothstep(0.0, 1.0, (h - a[0]) / maxf(b[0] - a[0], 0.001))
			return {
				"sky": (a[1] as Color).lerp(b[1], k), "ambient": (a[2] as Color).lerp(b[2], k),
				"ambient_energy": lerpf(a[3], b[3], k), "sun": (a[4] as Color).lerp(b[4], k),
				"sun_energy": lerpf(a[5], b[5], k), "neon": lerpf(a[6], b[6], k),
			}
	return sample(0.0)


## Direção da luz: de dia o sol nasce de um lado, sobe e se põe do outro; de noite a lua faz o
## mesmo caminho. Nunca fica rente ao chão (sombra comprida demais atravessa o mapa).
static func sun_angles(at_hour: float) -> Vector3:
	var h := wrapf(at_hour, 0.0, 24.0)
	var day_length := SUNSET - SUNRISE
	var t := 0.0
	if h >= SUNRISE and h < SUNSET:
		t = (h - SUNRISE) / day_length
	else:
		t = wrapf(h - SUNSET, 0.0, 24.0) / (24.0 - day_length)
	var elevation := 18.0 + sin(t * PI) * 50.0
	var azimuth := lerpf(-70.0, 110.0, t)
	return Vector3(-elevation, azimuth, 0.0)
