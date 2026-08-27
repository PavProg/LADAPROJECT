@tool
extends BTAction

## Длительность search
@export var duration: float = 5.0
## Скорость вращения рад/сек
@export var turn_speed: float = 2.0

var _left: float = 0.0

func _generate_name() -> String:
	return "Action look around"
	
func _enter() -> void:
	_left = duration
	var e := agent as Enemy
	if e:
		e.stop_moving()

func _tick(delta: float) -> Status:
	var e := agent as Enemy
	if e == null:
		return FAILURE
	
	# Увидел игрока - сразу в chase
	if e.priority.current_target != null:
		return SUCCESS
	
	_left -= delta
	e.rotate_y(turn_speed * delta)
	
	if _left > 0.0:
		return RUNNING	# Еще осматриваемся 
	return SUCCESS
