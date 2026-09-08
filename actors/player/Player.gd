extends CharacterBody3D

#region Ragdoll vars
@onready var physical_bone_controller: PhysicalBoneSimulator3D = $Character/root/Skeleton3D/PhysicalBoneSimulator3D
@onready var physical_bone_spine: PhysicalBone3D = $"Character/root/Skeleton3D/PhysicalBoneSimulator3D/Physical Bone spine"
@onready var bone_attachment_3d: BoneAttachment3D = $Character/root/Skeleton3D/BoneAttachment3D
@onready var anchor: Node3D = $CameraController/HoldPoint/HoldPoint_Ragdoll
@onready var pin_joint: Generic6DOFJoint3D = $CameraController/HoldPoint/HoldPoint_Ragdoll/PinJoint3D
var is_ragdoll_on_floor: bool = false
var grabbed_object: Node3D = null
@export var is_ragdoll: bool = false
var exceptions: Array[RID] # RID костей который игнорирует игрок(свои кости собственно)

## Как часто сервер шлет корень трупа. 0.05 = 20 раз в секунду
@export var ragdoll_sync_rate: float = 0.08
## Порог ошибки, ниже не вмешиваемся в рэгдолл. Постоянная коррекция вызывает больше рассинхрона
@export var ragdoll_snap_treshhold: float = 0.35

var _rag_sync_t: float = 0.0
var is_held: bool = false
#endregion

#region Movement vars
@onready var endurance_timer: Timer = $EnduranceTimer # таймер, по истечении которого начинает восстанавливаться выносливость
var endurance_recovering: bool = false
var air_speed_reduction = 0.05   # насколько каждый кадр снижается скорость в воздухе после прыжка
var input_movement_vector = Vector3.ZERO
var need_jump: bool = false
var running: bool = false
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var gravity_scale: float = 1.5
#endregion

#region Camera vars
@onready var camera_controller: Node3D = $CameraController
@onready var ragdoll_camera_pos: Node3D = $RagdollSpringArm/RagdollCameraPos
@onready var ragdoll_spring_arm: SpringArm3D = $RagdollSpringArm
var camera_main_global_transform: Transform3D
#endregion
#region Meshes / Collisions vars
@onready var collision: CollisionShape3D = $Collision
@onready var meshes_to_unsee: Array[MeshInstance3D] = [
	$Character/root/Skeleton3D/Body,
	$Character/root/Skeleton3D/eye_l,
	$Character/root/Skeleton3D/eye_r,
	$Character/root/Skeleton3D/eyelash_down,
	$Character/root/Skeleton3D/eyelash_up
]
#endregion

#region Sounds vars
@onready var foot_step_player: AudioStreamPlayer3D = $FootStepPlayer
@onready var jump_sound_player: AudioStreamPlayer3D = $JumpSoundPlayer
@onready var landing_sound_player: AudioStreamPlayer3D = $LandSoundPlayer
var walk_step_interval: float = 0.45
var run_step_interval: float = 0.28
var walk_step_volume: float = -20.0
var run_step_volume: float = -15.0
var foot_step_timer: float = 0.0
var was_on_floor: bool = true
#endregion

#region Data vars
@export var export_data: Resource
var data: Resource
#endregion

#region Net vars
@export var sync_rate: float = 0.05 # Как часто отправляем
var _sync_t: float  = 0.0
var _intent = {"move": Vector2.ZERO, "jump": false }
#endregion

#region Animations vars
@onready var anim_player: AnimationPlayer = $Character/AnimationPlayer
#endregion

#region take damage vars
var _health: float = 100.0

var _spectate_mode: bool = false
var _is_death: bool = false
var _spectate_camera: SpectateMode = null

@onready var death_label: Label3D = $DeathLabel
@export var timer_to_death: float = 5.0

var SPECTATEMODE := preload("res://actors/player/SpectateCamera.tscn")
#endregion

func _ready() -> void:
	data = export_data
	_health = data.max_health

	if is_multiplayer_authority():
		Events.local_player_spawned.emit(self)
	
	set_unseen_meshes_visibiliy(false)
	set_physical_bones_ignore() # отключение для рейкаста хватания своих костей из видимости
	pin_joint.node_a = NodePath("")
	pin_joint.node_b = NodePath("")
	if is_ragdoll: start_ragdoll()
	pass

func set_physical_bones_ignore() -> void:
		# Исключение скелета того кто хватает из своего рейкаста
	var phys_skeleton := $Character/root/Skeleton3D/PhysicalBoneSimulator3D as PhysicalBoneSimulator3D
	if phys_skeleton:
		# Перебираем все дочерние узлы скелета в поиске физических костей
		for child in phys_skeleton.get_children():
			if child is PhysicalBone3D:
				exceptions.append(child.get_rid()) # Добавляем RID каждой кости
	pass

func set_unseen_meshes_visibiliy(is_active: bool) -> void:
	# убираем видимость только для себя(тоесть код на клиенте)
	if is_multiplayer_authority():
		for mesh in meshes_to_unsee:
			mesh.visible = is_active
	pass

#region INPUTS + PhysicProcess
func apply_intent(intent: Dictionary):
	_intent = intent

func input():
	input_movement_vector = Vector2.ZERO
	need_jump = true
	running = false
	input_movement_vector = Input.get_vector("move_left", "move_right", "move_forward","move_backward")
	need_jump = Input.is_action_just_pressed("jump")
	running = Input.is_action_pressed("run")

	if Input.is_action_just_pressed("ragdoll") and is_multiplayer_authority() and _health > 0:
		_request_ragdoll.rpc_id(1, not is_ragdoll)

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event.is_action_pressed("interact"):
		try_interact(4)

func _physics_process(delta: float) -> void:
	input()
	if is_multiplayer_authority():
		apply_intent({
			"move": input_movement_vector,
			"jump": need_jump
		})
		movement(delta)
		handle_footsteps(delta)
		handle_landing()
	
	# Вынес из авторитета, тк узел игрока должен следовать за своим локальным трупом у каждого пира
	# иначе спектейт и подсказки уйдут в пустое место
	synchronize_player_and_ragdoll()

	if is_ragdoll and multiplayer.is_server():
		_rag_sync_t -= delta
		if _rag_sync_t <= 0.0:
			_rag_sync_t = ragdoll_sync_rate
			_push_ragdoll_root.rpc(physical_bone_spine.global_position)
#endregion

#region RAGDOLL
# unrelieable тк переотправлять нет смысла, через 50мс придет новый кадр позиции
@rpc("any_peer", "unreliable_ordered")
func _push_ragdoll_root(pos: Vector3) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	if multiplayer.is_server():
		return
	if not is_ragdoll:
		return
	
	_correct_ragdoll_root(pos)

func _correct_ragdoll_root(pos: Vector3) -> void:
	var err: Vector3 = pos - physical_bone_spine.global_position
	if err.length() < _current_snap_treshold():
		return
	
	# Один сдвиг костей для всех - поза не деформируется
	for bone in physical_bone_controller.get_children():
		if bone is PhysicalBone3D:
			bone.global_position += err

func _current_snap_treshold() -> float:
	return 0.08 if is_held else ragdoll_snap_treshhold



@rpc("any_peer", "call_local", "reliable")
func _request_ragdoll(want: bool) -> void:
	if not multiplayer.is_server(): return

	var sender := multiplayer.get_remote_sender_id()
	# 0 - локальный вызов рэгдолла с хоста. Иначе просит только владелец узла
	if sender != 0 and sender != get_multiplayer_authority():
		return
	if _is_death and not want:
		return
	set_ragdoll_state(want)

## Единая точка входа. ТОЛЬКО сервер
func set_ragdoll_state(want: bool) -> void:
	if not multiplayer.is_server():
		return
	if is_ragdoll == want:
		return
	
	# чтоб рассинхрона не было сразу шлем позицию вместе с состоянием 
	var at := physical_bone_spine.global_position if is_ragdoll else global_position
	apply_ragdoll.rpc(want, at)

# Сервер - все. any_peer + проверка на 1, узел клиент-авторитетный
@rpc("any_peer", "call_local", "reliable")
func apply_ragdoll(want: bool, at: Vector3) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	if want:
		global_position = at
		start_ragdoll()
	else:
		global_position = at
		stop_ragdoll()


func synchronize_player_and_ragdoll() -> void:
	if is_ragdoll:
		global_position = physical_bone_spine.global_position
	pass

func start_ragdoll() -> void:
	is_ragdoll = true
	camera_main_global_transform = camera_controller.transform
	physical_bone_controller.physical_bones_start_simulation()
	set_unseen_meshes_visibiliy(true)
	# отключить обычную коллизию CharacterBody
	collision.set_deferred("disabled", true)
	anim_player.stop()
	_apply_ragdoll_collision_profile()

func _apply_ragdoll_collision_profile() -> void:
	var mask := 4111 if multiplayer.is_server() else 1
	for bone in physical_bone_controller.get_children():
		if bone is  PhysicalBone3D:
			bone.collision_mask = mask

func stop_ragdoll() -> void:
	is_ragdoll = false
	is_held = false
	physical_bone_controller.physical_bones_stop_simulation()
	set_unseen_meshes_visibiliy(false)
	# вернуть коллизию
	collision.set_deferred("disabled", false)
	camera_controller.transform = camera_main_global_transform
	anim_player.play("Idle")
	if is_on_floor() or is_on_wall():
		#print("floor")
		global_position += Vector3(0.0, 0.3, 0.0)
	

func ragdoll_process(delta: float) -> void:
	# RagdollSpringArm следует за spine Bone на игроке
	ragdoll_spring_arm.global_position = bone_attachment_3d.global_position
	# камера берет позицию RagdollCameraPos на RagdollSpringArm
	camera_controller.global_position = camera_controller.global_position.lerp(ragdoll_camera_pos.global_position, 50 * delta)
	# поворот камеры
	var target_transform := camera_controller.global_transform.looking_at(bone_attachment_3d.global_position, Vector3.UP)
	camera_controller.global_transform = camera_controller.global_transform.interpolate_with(target_transform, 50 * delta)


func try_grab(_grabbed_object: Node3D) -> void:
	#print("try_grab")
	grabbed_object = _grabbed_object
	pin_joint.node_a = pin_joint.get_path_to(anchor)
	pin_joint.node_b = pin_joint.get_path_to(grabbed_object)
	
	pass

func release_grab() -> void:
	if grabbed_object:
		pin_joint.node_a = NodePath("")
		pin_joint.node_b = NodePath("")
		grabbed_object = null


func _process(delta: float) -> void:
	if is_ragdoll:
		ragdoll_process(delta)
		
	if endurance_recovering:
		data.endurance = clamp(data.endurance + data.endurance_recovery_speed, 0, data.max_endurance)
		if data.endurance == data.max_endurance: endurance_recovering = false
		
	pass


func movement(delta: float) -> void:
	
	if is_ragdoll: return
	
	#print(data.endurance)
	if is_on_floor():
		# хождение на земле
		if input_movement_vector != Vector2.ZERO:
			input_movement_vector = Vector3(input_movement_vector.x, 0, input_movement_vector.y)
			input_movement_vector = (global_transform.basis * input_movement_vector).normalized()
			if !running or data.endurance <= 0.0:
				velocity = input_movement_vector * data.speed
				anim_player.play("Running_forward")
			# бег
			else:
				velocity = input_movement_vector * data.run_speed
				data.endurance = clamp(data.endurance - 0.2, 0.0, data.max_endurance)
				endurance_recovering = false
				# перезапуска таймера
				endurance_timer.stop()
				endurance_timer.wait_time = data.endurance_recovery_time
				endurance_timer.start()
				anim_player.play("Running_forward_fast")
		else:
			velocity.x = 0
			velocity.z = 0
			anim_player.play("Idle")

		# прыжок
		if need_jump:
			velocity.y = data.jump_velocity
			jump_sound_player.play()
			anim_player.play("Jump")
		
	# перемещение в воздухе 
	else:
		# в воздухе игрок не управляет персонажем, просто летит туда куда прыгнул
		var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
		var speed_h = horizontal_velocity.length()
		if speed_h > 0.0:
			speed_h = move_toward(speed_h, 0, air_speed_reduction)
			horizontal_velocity = horizontal_velocity.normalized() * speed_h
			pass
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z
		# падение
		velocity.y -= gravity * gravity_scale * delta
		
	# Защита от катапультирования игрока в ебеня
	var velocity_before_slide = velocity
		
	move_and_slide()
	
	# Защита от катапультирования игрока в ебеня
	var delta_v = velocity - velocity_before_slide
	var max_delta_v: float = 2.0  # максимально допустимое изменение скорости за кадр
	if delta_v.length() > max_delta_v:
		velocity = velocity_before_slide + delta_v.limit_length(max_delta_v)
	
	# столкновения
	for i in get_slide_collision_count():
		var item_collision = get_slide_collision(i)
		var item_body = item_collision.get_collider() as RigidBody3D
		if item_body:
			#print("Collision pos: ", item_collision.get_position(), " Body pos: ", item_body.global_position, " Diff: ", item_collision.get_position() - item_body.global_position)
			var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
			var push_dir = -item_collision.get_normal()
			push_dir.y = 0.0
			var push_speed = clamp(horizontal_velocity.length(), 0.0, 6.0)
			if push_speed <= 0.01 and push_dir.length_squared() <= 0.001: continue
			var push_strength = push_speed  * item_body.mass * 0.15
			#print("Direction: %s \nStrength: %f " % [push_dir, push_strength])
			var relative_pos = item_collision.get_position() - item_body.global_position
			item_body.apply_impulse(push_strength * push_dir, relative_pos)


func _on_endurance_timer_timeout() -> void:
	endurance_recovering = true
	pass

#endregion

#region TAKEDAMAGE
func take_damage(amount: int, peer_id: int) -> void:
	if not multiplayer.is_server(): return
	if _is_death: return

	_health = maxf(0.0, _health - amount)
	_health_update.rpc(_health)
	if _health > 0.0:
		return
	
	_is_death = true
	if not GameManager.died_players.has(peer_id):
		GameManager.died_players.append(peer_id)
	
	if Net.spawned_ids.size() == 1:
		_death()
		return
	
	var alive_ids: Array[int] = Net.get_alive_peer_ids()
	if alive_ids.is_empty():
		await get_tree().create_timer(timer_to_death).timeout
		GameManager.died_players.clear()
		LevelManager.go_to_hub()
		return
	
	set_ragdoll_state(true)
	_multiplayer_death.rpc_id(peer_id, alive_ids)
	
	for dead_id in GameManager.died_players:
		if dead_id != peer_id:
			Net.spectate_retarget.rpc_id(dead_id, alive_ids)

@rpc("any_peer", "call_local", "reliable")
func _health_update(value: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 1 and sender != 0:
		return
	_health = value

## Смерть в синглплеере
func _death() -> void:
	start_ragdoll()
	death_label.visible = true
	await get_tree().create_timer(timer_to_death).timeout
	LevelManager.go_to_hub()

## Смерть игрока в мультиплеере
@rpc("any_peer", "call_local", "reliable")
func _multiplayer_death(alive_ids: Array) -> void:
	if is_instance_valid(_spectate_camera):
		return
	
	death_label.visible = true
	_spectate_mode = true
	
	$CameraController/Camera3D.current = false
	
	var alive := _resolve_alive(alive_ids)
	if alive.is_empty():
		return
	
	_spectate_camera = SPECTATEMODE.instantiate()
	get_tree().current_scene.add_child(_spectate_camera)
	_spectate_camera.start_spectating(alive)
	
	Events.player_died.emit(str(name).to_int(), true)

func is_dead() -> bool:
	return _is_death

func is_spectating() -> bool:
	return _spectate_mode

func _resolve_alive(alive_ids: Array) -> Array[Node3D]:
	var alive: Array[Node3D] = []
	for id in alive_ids:
		var p: Node3D = Net.get_player_node(id)
		if p != null and p != self:
			alive.append(p)
	return alive

func retarget_spectate(alive_ids: Array) -> void:
	if not is_instance_valid(_spectate_camera):
		return
	var alive := _resolve_alive(alive_ids)
	if alive.is_empty():
		return
	_spectate_camera.start_spectating(alive)
#endregion

#region КНОПКА ИНТЕРАКТА + RAYCAST
func raycast_from_camera(max_distance: float = 100.0) -> Node3D:
	# Рейкаст должен выполняться только у клиента, который управляет игроком
	if not is_multiplayer_authority():
		return null

	# Получаем камеру из CameraController (или любого другого узла, где она хранится)
	var camera: Camera3D = $CameraController/Camera3D
	if camera == null:
		return null

	# Пространство состояний физики текущего мира
	var space_state := get_world_3d().direct_space_state

	# Точка старта луча — позиция камеры
	var from := camera.global_position
	# Точка конца — вперёд от камеры на заданное расстояние (отрицательная ось Z - это вперёд в Godot)
	var to := from + (-camera.global_transform.basis.z * max_distance)

	# Параметры запроса: включаем области (Area3D) и тела (CollisionObject3D)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	
	query.collision_mask = 1 | 256	# Маску здесь ставим тк хардкодим рэйкаст
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]

	# Выполняем рейкаст
	#if not space_state: return
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return null
		
	return result.collider

func try_interact(max_search_depth : int = 5) -> void:
	var target = raycast_from_camera(data.interaction_range)
	
	if(target != null):
		for i in range(max_search_depth):
			if target is Node3D:
				if target.has_method("on_interact"):
					target.on_interact()
					print(target.name)
					return
				else:
					target = target.get_parent()

#endregion

#for sounds
#region sounds
func handle_footsteps(delta: float) -> void:
	# В воздухе шагов нет
	if !is_on_floor():
		foot_step_timer = 0.0
		return

	# Проверяем, действительно ли персонаж движется
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()

	if horizontal_speed < 0.1:
		foot_step_timer = 0.0
		return

	# Выбираем частоту и громкость
	var step_interval: float

	if running and data.endurance > 0:
		step_interval = run_step_interval
		foot_step_player.volume_db = run_step_volume
	else:
		step_interval = walk_step_interval
		foot_step_player.volume_db = walk_step_volume

	# Отсчитываем время до следующего шага
	foot_step_timer -= delta

	if foot_step_timer <= 0.0:
		play_footstep()
		foot_step_timer = step_interval

func play_footstep() -> void:
	foot_step_player.pitch_scale = randf_range(0.96, 1.04)
	foot_step_player.play()


func handle_landing() -> void:
	if !was_on_floor and is_on_floor():
		play_landing_sound()
		
func play_landing_sound() -> void:
	landing_sound_player.pitch_scale = randf_range(0.97, 1.03)
	landing_sound_player.play()
#endregion

#region DEBUG: проверка камеры наблюдателя без второго игрока
# =============================================================================
# КАК ПОЛЬЗОВАТЬСЯ
#
#   F9  - создать болванчика рядом с собой и начать за ним наблюдать.
#         Каждое нажатие добавляет ещё одного болванчика, поэтому
#         жми дважды, если хочешь проверить переключение целей.
#   F10 - переключиться на следующего болванчика (нужно 2+).
#   F8  - прекратить наблюдение и вернуть свою камеру.
#
# ЧТО ЭТИМ ПРОВЕРЯЕТСЯ
#   - камера следует за движущейся целью (болванчик ездит по кругу);
#   - орбита мышью работает (крути мышью во время наблюдения);
#   - SpringArm3D подтягивает камеру, когда между ней и целью стена
#     (встань так, чтобы болванчик уезжал за угол);
#   - switch_target() и автоподхват следующей цели: удали болванчика
#     из дерева в отладчике - камера должна сама перейти на другого.
#
# ЧЕГО ЭТИМ НЕ ПРОВЕРИТЬ
#   Вся сетевая обвязка вокруг камеры: take_damage -> _multiplayer_death,
#   Net.get_alive_peer_ids(), Net.spectate_retarget, переход в хаб
#   после гибели последнего. Для этого нужен реальный второй пир
#   (два экземпляра игры + ENet вместо Steam на время локального теста).
#
# ПЕРЕД РЕЛИЗОМ весь регион можно удалить - на игровую логику он не влияет.
# =============================================================================

const DEBUG_DUMMY := preload("res://actors/player/spectate_dummy.gd")

var _debug_dummies: Array[Node3D] = []


func _input(event: InputEvent) -> void:
	# Отладка только в дебажной сборке и только у своего игрока.
	if not OS.is_debug_build():
		return
	if not is_multiplayer_authority():
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_F9:
			_debug_spawn_dummy()
		KEY_F10:
			if is_instance_valid(_spectate_camera):
				_spectate_camera.switch_target()
		KEY_F8:
			_debug_stop_spectate()


## Создаёт болванчика и (пере)запускает наблюдение по всем созданным.
func _debug_spawn_dummy() -> void:
	var dummy := Node3D.new()
	dummy.set_script(DEBUG_DUMMY)
	dummy.name = "SpectateDummy_%d" % (_debug_dummies.size() + 1)

	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.height = 1.0
	capsule.radius = 0.25
	mesh.mesh = capsule
	mesh.position = Vector3(0.0, 0.5, 0.0)
	dummy.add_child(mesh)

	get_tree().current_scene.add_child(dummy)
	# Разносим болванчиков в стороны, чтобы они не ездили по одному кругу.
	dummy.global_position = global_position + Vector3(3.0 + _debug_dummies.size() * 2.0, 0.0, 0.0)
	_debug_dummies.append(dummy)

	if not is_instance_valid(_spectate_camera):
		_spectate_camera = SPECTATEMODE.instantiate()
		get_tree().current_scene.add_child(_spectate_camera)
		$CameraController/Camera3D.current = false

	_spectate_camera.start_spectating(_debug_dummies)


## Убирает камеру наблюдателя и болванчиков, возвращает управление игроку.
func _debug_stop_spectate() -> void:
	if is_instance_valid(_spectate_camera):
		_spectate_camera.stop_spectating()
		_spectate_camera.queue_free()
	_spectate_camera = null

	for d in _debug_dummies:
		if is_instance_valid(d):
			d.queue_free()
	_debug_dummies.clear()

	$CameraController/Camera3D.current = true
#endregion
