extends Node3D
class_name SpectateMode

@export var distance_back: float = 3.0
@export var height_offset: float = 1.2
@export var follow_smoothing: float = 10.0
@export var mouse_sensitivity: float = 0.005
@export var pitch_min: float = -1.2
@export var pitch_max: float = 1.2
@export var collide_radius: float = 0.2
@export var arm_margin: float = 0.1

@onready var spring: SpringArm3D = $SpringArm3D
@onready var cam: Camera3D = $SpringArm3D/Camera3D

var _alive_players: Array[Node3D] = []
var _target_player: Node3D = null
var _target_index: int = -1

var orbit_yaw: float = 0.0
var orbit_pitch: float = 0.4

var _active: bool = false


func _ready() -> void:
	cam.current = false
	spring.spring_length = distance_back
	spring.margin = arm_margin
	spring.collision_mask = 1
	var shape := SphereShape3D.new()
	shape.radius = collide_radius
	spring.shape = shape


func start_spectating(alive: Array[Node3D]) -> void:
	_alive_players = alive.filter(func(p): return is_instance_valid(p))
	if _alive_players.is_empty():
		return

	_target_index = 0
	_target_player = _alive_players[0]

	if not _active:
		orbit_yaw = _target_player.global_rotation.y
	_active = true
	cam.current = true
	_snap_to_target()


func stop_spectating() -> void:
	_active = false
	cam.current = false
	_target_player = null


func _process(delta: float) -> void:
	if not _active:
		return
	if _target_player == null or not is_instance_valid(_target_player):
		if not _pick_next_valid():
			return
	_follow_target(delta)


func _pick_next_valid() -> bool:
	_alive_players = _alive_players.filter(func(p): return is_instance_valid(p))
	if _alive_players.is_empty():
		_target_player = null
		return false
	_target_index = clampi(_target_index, 0, _alive_players.size() - 1)
	_target_player = _alive_players[_target_index]
	_snap_to_target()
	return true


func switch_target() -> void:
	_alive_players = _alive_players.filter(func(p): return is_instance_valid(p))
	if _alive_players.size() <= 1:
		return
	_target_index = (_target_index + 1) % _alive_players.size()
	_target_player = _alive_players[_target_index]
	_snap_to_target()


func _follow_target(delta: float) -> void:
	var pivot: Vector3 = _target_player.global_position + Vector3.UP * height_offset
	global_position = global_position.lerp(pivot, clampf(follow_smoothing * delta, 0.0, 1.0))
	rotation = Vector3(orbit_pitch, orbit_yaw, 0.0)


func _snap_to_target() -> void:
	global_position = _target_player.global_position + Vector3.UP * height_offset
	rotation = Vector3(orbit_pitch, orbit_yaw, 0.0)


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseMotion:
		orbit_yaw -= event.relative.x * mouse_sensitivity
		orbit_pitch = clampf(orbit_pitch - event.relative.y * mouse_sensitivity, pitch_min, pitch_max)
