extends CharacterBody3D
class_name Enemy

# Основной класс врага под все нужды и состояния

@export var data: UnitData
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var priority: PriorityComponent = $Priority
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

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

func set_move_target(pos: Vector3) -> void:
	agent.target_position = pos
	
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if agent.is_navigation_finished():
		velocity.z = 0.0
		velocity.x = 0.0
		move_and_slide()
		return
	var next := agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0.0
	if dir.length() > 0.05:
		dir = dir.normalized()
		velocity.x = dir.x * data.speed_walk
		velocity.z = dir.z * data.speed_walk
		look_at(global_position + dir, Vector3.UP)
	move_and_slide()

############ States
