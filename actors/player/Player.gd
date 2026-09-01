extends CharacterBody3D

@onready var physical_bone_controller: PhysicalBoneSimulator3D = $PlayerBody/Rig_Medium/Skeleton3D/PhysicalBoneSimulator3D
@onready var physical_bone_hips: PhysicalBone3D = $"PlayerBody/Rig_Medium/Skeleton3D/PhysicalBoneSimulator3D/Physical Bone hips"
@onready var mannequin_head: MeshInstance3D = $PlayerBody/Rig_Medium/Skeleton3D/Mannequin_Head
@onready var endurance_timer: Timer = $EnduranceTimer # таймер, по истечении которого начинает восстанавливаться выносливость
@onready var anim_player: AnimationPlayer = $PlayerBody/AnimationPlayer
@onready var collision: CollisionShape3D = $Collision
@onready var camera_controller: Node3D = $CameraController
@onready var bone_attachment_3d: BoneAttachment3D = $PlayerBody/Rig_Medium/Skeleton3D/BoneAttachment3D
@onready var third_person_camera_pos: Node3D = $ThirdPersonCameraPos

#@onready var reload_button: Button = get_parent().get_parent().get_node("button2/SubViewport/Control/Button")

@onready var meshes_to_unsee: Array[MeshInstance3D] = [
	$PlayerBody/Rig_Medium/Skeleton3D/Mannequin_Head,
	$PlayerBody/Rig_Medium/Skeleton3D/Mannequin_LegLeft,
	$PlayerBody/Rig_Medium/Skeleton3D/Mannequin_LegRight,
	$PlayerBody/Rig_Medium/Skeleton3D/Mannequin_Body
]

@export var export_data: Resource
var data: Resource

@export var sync_rate: float = 0.05 # Как часто отправляем
var _sync_t: float  = 0.0

var air_speed_reduction = 0.05   # насколько каждый кадр снижается скорость в воздухе после прыжка
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var gravity_scale: float = 1.5

var _intent = {"move": Vector2.ZERO, "jump": false }
var ragdoll_root_offset: Vector3 = Vector3(0, 0.5, 0)
var input_movement_vector = Vector3.ZERO
var camera_main_global_transform: Transform3D
var need_jump: bool = false
var running: bool = false
var endurance_recovering: bool = false
var is_ragdoll: bool = false
var is_ragdoll_on_floor: bool = false

func _ready() -> void:
	data = export_data
	if is_multiplayer_authority():
		Events.local_player_spawned.emit(self)
	set_unseen_meshes_visibiliy(false)
	print("[PLAYER/GRAB] authority=, my_id=, is_auth=, ", get_multiplayer_authority(), multiplayer.get_unique_id(), is_multiplayer_authority())

func set_unseen_meshes_visibiliy(is_active: bool) -> void:
	# убираем видимость только для себя(тоесть код на клиенте)
	if is_multiplayer_authority():
		for mesh in meshes_to_unsee:
			mesh.visible = is_active
	pass

#region Ретрансляция трансформа
#
#@rpc("any_peer", "call_local", "unreliable_ordered")
#func _push_transform(pos: Vector3, yaw: float, pitch: float) -> void:
	#if not multiplayer.is_server(): return
#
	#if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		#return
	#
	#_apply_transform(pos, yaw, pitch)
	#_broadcast_transform.rpc(pos, yaw, pitch)
#
#@rpc("any_peer", "call_local", "unreliable_ordered")
#func _broadcast_transform(pos: Vector3, yaw: float, pitch: float) -> void:
	#if multiplayer.get_remote_sender_id() != 1:
		#return
	#
	#if is_multiplayer_authority():
		#return
	#
	#_apply_transform(pos, yaw, pitch)
#
#func _apply_transform(pos: Vector3, yaw: float, pitch: float) -> void:
	#global_position = pos
	#rotation.y = yaw
	#camera_controller.rotation.x = pitch

#endregion

#region INPUTS
func apply_intent(intent: Dictionary):
	_intent = intent

func input():
	input_movement_vector = Vector2.ZERO
	need_jump = true
	running = false
	input_movement_vector = Input.get_vector("move_left", "move_right", "move_forward","move_backward")
	need_jump = Input.is_action_just_pressed("jump")
	running = Input.is_action_pressed("run")
	if Input.is_action_just_pressed("ragdoll") and is_multiplayer_authority():
		if !is_ragdoll:
			start_ragdoll()
		else:
			stop_ragdoll()

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
		synchronize_player_and_ragdoll()
	
	## Ретрансляция трансформа
	#_sync_t -= delta
	#if _sync_t <= 0.0:
		#_sync_t = sync_rate
		#_push_transform.rpc_id(1, global_position, rotation.y, camera_controller.rotation.x)
#endregion

#region RAGDOLL
func synchronize_player_and_ragdoll() -> void:
	if is_ragdoll:
		global_position = physical_bone_hips.position
	pass

func start_ragdoll() -> void:
	is_ragdoll = true
	camera_main_global_transform = camera_controller.transform
	physical_bone_controller.physical_bones_start_simulation()
	set_unseen_meshes_visibiliy(true)
	# отключить обычную коллизию CharacterBody
	collision.set_deferred("disabled", true)
	anim_player.stop()

func stop_ragdoll() -> void:
	is_ragdoll = false
	if is_on_floor() or is_on_wall():
		print("floor")
		global_position += Vector3(0.0, 0.3, 0.0)
	camera_controller.transform = camera_main_global_transform
	physical_bone_controller.physical_bones_stop_simulation()
	set_unseen_meshes_visibiliy(false)
	# вернуть коллизию
	collision.set_deferred("disabled", false)
	anim_player.play("Idle_A")

func ragdoll_process(delta: float) -> void:
	camera_controller.global_position = third_person_camera_pos.global_position
	var target_transform = camera_controller.global_transform.looking_at(bone_attachment_3d.global_position, Vector3.UP)
	camera_controller.global_transform = camera_controller.global_transform.interpolate_with(target_transform, 5 * delta)
	pass
	

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
				anim_player.play("Walking_A")
			# бег
			else:
				velocity = input_movement_vector * data.run_speed
				data.endurance = clamp(data.endurance - 0.2, 0.0, data.max_endurance)
				endurance_recovering = false
				# перезапуска таймера
				endurance_timer.stop()
				endurance_timer.wait_time = data.endurance_recovery_time
				endurance_timer.start()
				anim_player.play("Running_A")
		else:
			velocity.x = 0
			velocity.z = 0
			anim_player.play("Idle_A")
			
		# прыжок
		if need_jump:
			velocity.y = data.jump_velocity
			anim_player.play("Jump_Idle")
		
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
		
	move_and_slide()
	
	
	# столкновения
	for i in get_slide_collision_count():
		var item_collision = get_slide_collision(i)
		var item_body = item_collision.get_collider() as RigidBody3D
		if item_body is RigidBody3D:
			var push_dir = item_collision.get_position() - global_position
			# сила толчка
			item_body.apply_force(push_dir * 5, item_collision.get_position())
			
			#var push_force = data.speed * 5 if !running else data.run_speed * 5
			#item_body.apply_impulse(push_dir * push_force * velocity.length() * delta, item_collision.get_position() - item_body.global_position)


func _on_endurance_timer_timeout() -> void:
	endurance_recovering = true
	pass

#endregion
#region TAKEDAMAGE
func take_damage() -> void:
	pass
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
