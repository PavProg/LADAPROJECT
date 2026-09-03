extends CharacterBody3D
class_name Enemy

# Основной класс врага под все нужды и состояния

@export var data: UnitData
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var priority: PriorityComponent = $PriorityComponent
@onready var attack: EnemyAttackComponent = $EnemyAttackComponent
@onready var anim: AnimationPlayer = $"Root Scene/AnimationPlayer"
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var damage_label: Label3D = $"DamageLabel"
@export var take_damage_recovery_time: float = 0.3   # секунд «неуязвимости» между ударами
@export var speed_damage_scale: float = 0.2          # множитель перевода скорости удара в урон (20%)
@export var max_damage_allowed: int = 100            # ограничение максимального урона

## Базовые имена анимаций. Реальные в AnimationPlayer могут иметь префикс
## арматуры ("RatArmature|Rat_Idle") - его снимает _resolve_anim.
const ANIM_IDLE := &"Rat_Idle"
const ANIM_WALK := &"Rat_Walk"
const ANIM_RUN := &"Rat_Run"
const ANIM_ATTACK := &"Rat_Attack"
const ANIM_DEATH := &"Rat_Death"

## Бежать или идти. Ставится тем, кто задаёт цель (см. set_move_target)
var is_sprinting: bool = false
var _current_anim: StringName = &""

var _health: float = 100.0 # Боевое хп
var _is_ragdolled: bool = false

## Пока кулдаун больше 0 анимацию не перебираем
var _anim_lock_left: float = 0.0
var _attack_cd_left: float = 0.0

#region Navigation
func _ready() -> void:
	_health = data.health
	if not multiplayer.is_server():
		$BTPlayer.active = false
		set_physics_process(false)
		return
	call_deferred("_setup_nav")

func _setup_nav() -> void:
	await get_tree().physics_frame
	# Значения в МИРОВЫХ метрах, меряются в 3D (вместе с высотой).
	# Навмеш запечён ВЫШЕ пола (полигоны на y=0.4), поэтому расстояние от
	# врага до точки пути никогда не меньше этого зазора. Если порог сделать
	# меньше зазора, агент не сможет "дойти" до путевой точки и встанет
	# намертво. Держим их заведомо больше зазора, но target - меньше
	# range_attack (1.3), иначе враг останавливается вне зоны удара.
	agent.path_desired_distance = 0.5
	agent.target_desired_distance = 0.7

## Направление взгляда. Модель импортирована с use_model_front,
## значит на цель наводится +Z - здесь единый источник правды для всех,
## кто считает "куда смотрит враг" (FOV, довороты, будущие проверки).
func forward_dir() -> Vector3:
	return global_transform.basis.z.normalized()

## sprint задаёт тот, кто ставит цель: Chase - true, патруль/поиск - false.
## Так скорость всегда соответствует намерению и сбрасывается сама.
func set_move_target(pos: Vector3, sprint: bool = false) -> void:
	agent.target_position = pos
	is_sprinting = sprint

func _physics_process(delta: float) -> void:
	_attack_cd_left = maxf(0.0, _attack_cd_left - delta)
	_anim_lock_left = maxf(0.0, _anim_lock_left - delta)
	
	if _is_ragdolled:
		if not is_on_floor():
			velocity.y -= gravity * delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	
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
#endregion

#region take_damage_component
func take_damage(amount: float) -> void:
	if not multiplayer.is_server():
		return
	if _is_ragdolled:
		return # лежачего не бьют

	_health = maxf(0.0, _health - amount)
	# print("[ENEMY/TAKEDAMAGE] Крыса получила урон! Состояние здоровья: ", _health)
	toggle_damage_label.rpc(amount)

	if _health <= 0.0:
		_is_ragdolled = true	# Оставил как заглушку, TODO гибкая настройка урона от velocity + смерть

# Пока нет костей для рэгдола заглушка в виде отладки и анимации смерти
# TODO Докинуть кости и делать через physical_bones_start_simulation
func _enter_ragdoll() -> void:
	if not multiplayer.is_server():
		return
	if not _is_ragdolled:
		return
	
	stop_moving()
	play_anim(ANIM_DEATH, false)
	_anim_lock_left = INF
	ragdolled_fx.rpc()
 
@rpc("authority", "call_local", "reliable")
func ragdolled_fx() -> void:
	print("------- [ENEMY/REPLICATION] Крыса в рэгдоле! -------")

func recover_from_ragdoll() -> void:
	if not multiplayer.is_server():
		return
	
	_health = data.health
	_anim_lock_left = 0.0
	_is_ragdolled = false
	# play_anim(ANIM_IDLE, true)
	_update_anim()
	recover_fx.rpc()

@rpc("authority", "call_local", "reliable")
func recover_fx() -> void:
	print("[ENEMY/REPLICATION] Крыса встала")

@rpc("any_peer", "call_local", "reliable")
func toggle_damage_label(damage: int) -> void:

	damage_label.text = str(damage)
	damage_label.scale = Vector3.ZERO
	damage_label.modulate = Color.WHITE 
	damage_label.visible = true
	
	# Создаем твин от имени damage_label
	var tween = damage_label.create_tween()
	
	# Устанавливает тип перехода
	tween.set_trans(Tween.TRANS_CUBIC)
	#tween.set_ease(Tween.EASE_OUT)
	
	# Плавный взлет вверх
	#var target_y = damage_label.position.y + 1.5
	#tween.tween_property(damage_label, "position:y", target_y, 1.0)
	
	# Пульсация размера
	tween.parallel().tween_property(damage_label, "scale", Vector3(1.2, 1.2, 1.2), 3.0)
	tween.tween_property(damage_label, "modulate:a", 0.0, 1.0)
	
	tween.tween_callback(func(): damage_label.visible = false)
	pass


func _on_hurtbox_body_entered(body: Node3D) -> void:
	#print("DAMAGE_COMPONENT -- Damage area entered")
	var other_body := body
	if other_body == null: return
	# or, а не and: выйти нужно если тело невалидно ЛИБО это не предмет.
	# И проверка типа обязательна - ниже читаются поля RigidBody3D и ItemData.
	if not is_instance_valid(other_body) or not other_body.is_in_group("item"): return
	if not (other_body is RigidBody3D): return
	if other_body.item_data == null: return

	var other_velocity_length = other_body.linear_velocity.length()
	var other_body_damage = other_body.item_data.damage
	
	var self_velocity_length = 0.9 if self.velocity.length() == 0 else self.velocity.length()
	var overall_velocity_length: float = self_velocity_length * other_velocity_length
	var velocity_threshold = self.data.velocity_length_threshold
	
	# print("actor.velocity            : ", self.velocity)
	# print("other_body.linear_velocity: ", other_body.linear_velocity)
	# print("DAMAGE_COMPONENT -- CHECK VELOCITY")
	# print("overall_velocity: ", self.velocity * other_body.linear_velocity)
	if overall_velocity_length <= velocity_threshold: return
	
	# в данном случае это тот урон который базово получает объект при столкновениях с полом(у хрупких больше, у крепких меньше)
	var base_damage: int = other_body_damage
	# считаем урон с применением velocity (скорости удара)
	var actual_damage: int = clampi(
		int(base_damage * overall_velocity_length * speed_damage_scale),
		base_damage,
		max_damage_allowed
	)
	# print("BREAK_COMPONENT -- Actual damage: %d" % actual_damage)


	take_damage(actual_damage)

#endregion

#region Attack from Rat
## Функция хелпер. Проверяет поле _is_ragdolled.
func is_ragdolled() -> bool:
	return _is_ragdolled

func face_target(target_pos: Vector3, delta: float) -> void:
	var to := target_pos - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return
	
	#atan2() - тангенс угла в радианах - направляет на цель
	var want := atan2(to.x, to.z)
	rotation.y = lerp_angle(rotation.y, want, 8.0 * delta)
	
#endregion

#region Animations

## Выбор анимации по текущей скорости. Крутится ТОЛЬКО на сервере
## (у клиента _physics_process выключен), поэтому клиентам состояние
## доезжает через RPC внутри play_anim.
func _lock_anim(seconds: float) -> void:
	_anim_lock_left = seconds

func _update_anim() -> void:
	if _anim_lock_left > 0 or _is_ragdolled:
		return
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
#endregion
