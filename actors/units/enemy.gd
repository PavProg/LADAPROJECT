extends CharacterBody3D
class_name Enemy

# Основной класс врага под все нужды и состояния

@export var data: UnitData
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var priority: PriorityComponent = $PriorityComponent
@onready var anim: AnimationPlayer = $"Root Scene/AnimationPlayer"
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

## Базовые имена анимаций. Реальные в AnimationPlayer могут иметь префикс
## арматуры ("RatArmature|Rat_Idle") - его снимает _resolve_anim.
const ANIM_IDLE := &"Rat_Idle"
const ANIM_WALK := &"Rat_Walk"
const ANIM_RUN := &"Rat_Run"

## Бежать или идти. Ставится тем, кто задаёт цель (см. set_move_target)
var is_sprinting: bool = false
var _current_anim: StringName = &""

############ Navigation

func _ready() -> void:
	if not multiplayer.is_server():
		$BTPlayer.active = false
		set_physics_process(false)
		return
	call_deferred("_setup_nav")

func _setup_nav() -> void:
	await get_tree().physics_frame
	agent.path_desired_distance = 0.5
	agent.target_desired_distance = 1.0

## sprint задаёт тот, кто ставит цель: Chase - true, патруль/поиск - false.
## Так скорость всегда соответствует намерению и сбрасывается сама.
func set_move_target(pos: Vector3, sprint: bool = false) -> void:
	agent.target_position = pos
	is_sprinting = sprint

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if agent.is_navigation_finished():
		velocity.z = 0.0
		velocity.x = 0.0
		move_and_slide()
		_update_anim()
		return
	var next := agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0.0
	if dir.length() > 0.05:
		dir = dir.normalized()
		var speed: float = data.speed_sprint if is_sprinting else data.speed_walk
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		look_at(global_position + dir, Vector3.UP, true)
	move_and_slide()
	_update_anim()

func stop_moving() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	is_sprinting = false
	agent.target_position = global_position

############ Animations

## Выбор анимации по текущей скорости. Крутится ТОЛЬКО на сервере
## (у клиента _physics_process выключен), поэтому клиентам состояние
## доезжает через RPC внутри play_anim.
func _update_anim() -> void:
	var horizontal := Vector2(velocity.x, velocity.z).length()
	var want: StringName = ANIM_IDLE
	if horizontal > 0.1:
		want = ANIM_RUN if is_sprinting else ANIM_WALK
	play_anim(want)

func play_anim(name: StringName, loop: bool = true) -> void:
	if not multiplayer.is_server():
		return
	if name == _current_anim:
		return					# анимация не сменилась - в сеть ничего не шлём
	_current_anim = name
	_play_anim.rpc(name, loop)

@rpc("authority", "call_local", "reliable")
func _play_anim(name: StringName, loop: bool) -> void:
	if anim == null:
		return
	var resolved := _resolve_anim(name)
	if resolved == &"":
		return
	var a := anim.get_animation(resolved)
	if a:
		a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	if anim.current_animation != resolved:
		anim.play(resolved)

## В GLTF анимации приходят с префиксом арматуры ("RatArmature|Rat_Idle").
## Ищем сначала точное имя, потом любое, оканчивающееся на нужное.
func _resolve_anim(base_name: StringName) -> StringName:
	if anim.has_animation(base_name):
		return base_name
	for a in anim.get_animation_list():
		if String(a).ends_with(String(base_name)):
			return a
	return &""
