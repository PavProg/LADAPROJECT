extends RigidBody3D
class_name HoldableBody


@export var follow_speed: float = 20.0
@export var rotate_speed: float = 5.0
var air_speed_reduction: float = 0.8
var is_on_floor: bool = false
var _hold_by: int = 0

func _ready() -> void:
	can_sleep = false
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	# подвязка сигналов для объекта/осколка
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	
	enable_gravity(false)
	_update_freeze()

func enable_gravity(enable: bool) -> void:
	gravity_scale = 1.0 if enable else 0.0
	pass

func _update_freeze() -> void:
	freeze = not is_multiplayer_authority()

func _on_body_entered(body: Node) -> void:
	enable_gravity(true)
	is_on_floor = true

func _on_body_exited(body: Node) -> void:
	is_on_floor = false
