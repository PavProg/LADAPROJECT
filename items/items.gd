extends RigidBody3D

@export var filename: String
var item_data: Resource
@export var export_item_data: Resource
@export var follow_speed: float = 20.0
@export var rotate_speed: float = 5.0

var _hold_by: int = 0	# 0 - никто не удерживает, иначе id игрока

# Физика притягивания живёт в предмете и считается только на авторитете (хосте). 
# Предмет знает, кто его держит (held_by), и сам тянется к точке удержания этого игрока.

func _ready() -> void:
	add_to_group("item")
	item_data = export_item_data
	can_sleep = false	# встроенная функция сна
	_update_freeze()

func grab_by(peer_id: int) -> void:
	_hold_by = peer_id # та самая функция :0

func release() -> void:
	_hold_by = 0

func _update_freeze() -> void:
	# У авторитета физика аткивна, у остальных заморожена + прием позиции!!!
	freeze = not is_multiplayer_authority()

func is_free() -> bool:
	return _hold_by == 0

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if _hold_by == 0:
		return
	var hold := _hold_point_of(_hold_by)
	
	if hold == null:
		return
	
	# «пружина»: скорость пропорциональна расстоянию до точки удержания
	linear_velocity = (hold.global_position - global_position) * follow_speed
	# плавный поворот к ориентации точки удержания (твой slerp — он корректен)
	var cur := global_transform.basis.get_rotation_quaternion()
	var tgt := hold.global_transform.basis.get_rotation_quaternion()
	angular_velocity = Vector3.ZERO
	global_transform.basis = Basis(cur.slerp(tgt, rotate_speed * delta))
	
func _hold_point_of(peer_id: int) -> Node3D:
	var players := get_tree().current_scene.get_node_or_null("Players")
	if players == null: return null
	var p := players.get_node_or_null(str(peer_id))	# игроки названы своим id
	if p == null: return null
	return p.get_node_or_null("CameraController/HoldPoint")
