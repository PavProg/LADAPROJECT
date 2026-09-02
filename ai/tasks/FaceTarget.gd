@tool
extends BTAction

@export var max_time: float = 1.0
## Погрешность угла по которому считаем что враг смотрим на цель
@export var angle_tolerance: float = 0.15

var _left: float = 0.0

# Проверяем ренджу для атаки, нужная - атакуем (после проигрывания анимации)
func _generate_name() -> String:
	return "Face target action"

func _enter() -> void:
	_left = max_time
	var e := agent as Enemy
	if e:
		e.stop_moving()

func _tick(delta: float) -> Status:
	var e := agent as Enemy
	if e == null:
		return FAILURE
	
	var t := e.priority.current_target
	if t == null or not is_instance_valid(t):
		return FAILURE
	
	e.face_target(t.global_position, delta)
	
	var to := t.global_position - e.global_position
	to.y = 0.0
	
	var want := atan2(to.x, to.z)
	if absf(angle_difference(e.rotation.y, want)) <= angle_tolerance:
		return SUCCESS
	
	_left -= delta
	if _left <= 0:
		return SUCCESS
	return RUNNING
