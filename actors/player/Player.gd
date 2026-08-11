extends CharacterBody3D

@onready var data: Resource = preload("res://core/data/treska/player_data.tres")
@onready var endurance_timer: Timer = $EnduranceTimer # таймер, по истечении которого начинает восстанавливаться выносливость

var air_speed_reduction = 0.1   # насколько каждый кадр снижается скорость в воздухе после прыжка
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var _intent = {"move": Vector2.ZERO, "jump": false }
var input_movement_vector = Vector3.ZERO
var need_jump: bool = false
var running: bool = false
var endurance_recovering: bool = false

func _ready() -> void:
	pass


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func apply_intent(intent: Dictionary):
	_intent = intent

func input():
	input_movement_vector = Vector2.ZERO
	need_jump = true
	running = false
	input_movement_vector = Input.get_vector("move_left", "move_right", "move_forward","move_backward")
	need_jump = Input.is_action_just_pressed("jump")
	running = Input.is_action_pressed("run")
	

func _physics_process(delta: float) -> void:
	input()
	if is_multiplayer_authority():
		apply_intent({
			"move": input_movement_vector,
			"jump": need_jump
		})
		movement(delta)


func _process(delta: float) -> void:
	if endurance_recovering:
		data.endurance = clamp(data.endurance + data.endurance_recovery_speed, 0, data.max_endurance)
		if data.endurance == data.max_endurance: endurance_recovering = false
	pass


func movement(delta: float) -> void:
	if is_on_floor():
		# хождение на земле
		if input_movement_vector != Vector2.ZERO:
			input_movement_vector = Vector3(input_movement_vector.x, 0, input_movement_vector.y)
			input_movement_vector = (global_transform.basis * input_movement_vector).normalized()
			if !running or data.endurance <= 0:
				velocity = input_movement_vector * data.speed
			# бег
			else:
				velocity = input_movement_vector * data.run_speed
				data.endurance = clamp(data.endurance - 0.2, 0, data.max_endurance)
				# перезапуска таймера
				endurance_timer.stop()
				endurance_timer.wait_time = data.endurance_recovery_time
				endurance_timer.start()

		else:
			velocity.x = 0
			velocity.z = 0
			
		# прыжок
		if need_jump:
			velocity.y = data.jump_velocity
		
	# перемещение в воздухе 
	else:
		# в воздухе игрок не управляет персонажем, просто летит туда куда прыгнул
		velocity.x = move_toward(velocity.x, 0, air_speed_reduction)
		velocity.z = move_toward(velocity.z, 0, air_speed_reduction)
		# падение
		velocity.y -= gravity * delta
		
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
