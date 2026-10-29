class_name CharacterAnimator
extends RefCounted
## Animação de um personagem (herói ou criatura) sobre o AnimationPlayer do modelo.
## O jogo pede AÇÕES ("move", "slash", "hit"...) e o mapa do tipo de corpo (AnimSets)
## escolhe o clipe. Junta num lugar só: tocar com duração certa, recomeçar, congelar
## (hit-stop), animações montadas por código e o estado que vai pela rede.

const DEFAULT_BLEND := 0.15

## Ação e clipe tocando agora.
var current := ""
var clip := ""
var speed := 1.0
## Sobe a cada recomeço, para os clientes saberem que é um golpe novo e não o mesmo.
var serial := 0

var _anim: AnimationPlayer
var _actions: Dictionary


func _init(model: Node, anim_set: Dictionary) -> void:
	_actions = anim_set.get("actions", {})
	_anim = model.find_child("AnimationPlayer", true, false)
	if _anim == null:
		return
	if anim_set.get("rig") == "quaternius_humanoid":
		var skeletons := model.find_children("*", "Skeleton3D", true, false)
		if not skeletons.is_empty():
			ProceduralAnims.install(_anim, skeletons[0], model.get_path_to(skeletons[0]))
	for action: String in anim_set.get("loop", []):
		var looped := _clip_for(action)
		if looped:
			_anim.get_animation(looped).loop_mode = Animation.LOOP_LINEAR


## O modelo sabe fazer essa ação?
func has(action: String) -> bool:
	return not _clip_for(action).is_empty()


func length(action: String) -> float:
	var found := _clip_for(action)
	return _anim.get_animation(found).length if found else 0.0


## Toca a ação. Com `duration`, ajusta a velocidade para durar esse tempo.
## `restart` recomeça mesmo se já estiver tocando. Retorna false se o modelo não sabe.
func play(action: String, duration := 0.0, restart := false, blend := DEFAULT_BLEND) -> bool:
	var found := _clip_for(action)
	if found.is_empty():
		return false
	if current == action and _anim.is_playing() and not restart:
		return true
	speed = _anim.get_animation(found).length / duration if duration > 0.0 else 1.0
	_anim.play(found, blend, speed)
	if restart:
		_anim.seek(0.0, true)
		serial += 1
	current = action
	clip = found
	return true


func is_playing(action: String) -> bool:
	return current == action and _anim != null and _anim.is_playing()


## Congela (hit-stop) ou solta.
func set_frozen(frozen: bool) -> void:
	if _anim:
		_anim.speed_scale = 0.0 if frozen else 1.0


func net_state() -> Array:
	return [current, clip, speed, serial]


## Cliente: repete o que o host tocou (recomeça quando o número do golpe muda).
func apply_net_state(s: Array) -> void:
	var net_clip: String = s[1]
	if _anim and _anim.has_animation(net_clip) and (s[3] != serial or net_clip != _anim.current_animation):
		_anim.play(net_clip, DEFAULT_BLEND, s[2])
		if s[3] != serial:
			_anim.seek(0.0, true)
	current = s[0]
	clip = net_clip
	speed = s[2]
	serial = s[3]


## Ação das pernas pela direção do movimento em relação a para onde o corpo olha:
## parado, para a frente, de costas ou de lado. Serve para quem anda olhando para outro
## lugar (herói mirando, atirador recuando de frente para o alvo).
static func locomotion_action(velocity: Vector3, facing: Vector3, min_speed := 0.5) -> String:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal.length() < min_speed:
		return "idle"
	var dir := horizontal.normalized()
	var forward := dir.dot(facing)
	if forward > 0.5:
		return "move"
	if forward < -0.5:
		return "move_back"
	return "move_right" if dir.dot(facing.cross(Vector3.UP)) > 0.0 else "move_left"


func _clip_for(action: String) -> String:
	if _anim == null:
		return ""
	for candidate: String in _actions.get(action, []):
		if _anim.has_animation(candidate):
			return candidate
	return ""
