extends RigidBody3D
class_name HoldableBody


@export var follow_speed: float = 20.0
@export var rotate_speed: float = 5.0
var air_speed_reduction: float = 0.8
var is_on_floor: bool = false
var _hold_by: int = 0

func _ready() -> void:
	contact_monitor = true
	# подвязка сигналов для объекта/осколка
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	
	can_sleep = false
	_update_freeze()

func grab_by(peer_id: int) -> void:
	_hold_by = peer_id

func release() -> void:
	_hold_by = 0

func is_free() -> bool:
	return _hold_by == 0

func _update_freeze() -> void:
	freeze = not is_multiplayer_authority()

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	
	if not is_on_floor and _hold_by == 0:
		var damp_factor := exp(-air_speed_reduction * delta)
		linear_velocity.x *= damp_factor
		linear_velocity.z *= damp_factor
	if _hold_by != 0:
		var hold := _hold_point_of(_hold_by)
		if hold == null:
			return
		linear_velocity = (hold.global_position - global_position) * follow_speed
		var cur := global_transform.basis.get_rotation_quaternion()
		var tgt := hold.global_transform.basis.get_rotation_quaternion()
		angular_velocity = Vector3.ZERO
		global_transform.basis = Basis(cur.slerp(tgt, rotate_speed * delta))

func _on_body_entered(body: Node) -> void:
	is_on_floor = true

func _on_body_exited(body: Node) -> void:
	is_on_floor = false

func _hold_point_of(peer_id: int) -> Node3D:
	var players := get_tree().current_scene.get_node_or_null("PlayersCont")
	if players == null: return null
	var p := players.get_node_or_null(str(peer_id))
	if p == null: return null
	return p.get_node_or_null("CameraController/HoldPoint")
