@tool
extends BTAction

## Длительность search
@export var duration: float = 2.5
## Скорость вращения рад/сек
@export var turn_speed: float = 1.5

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
	
	# Увидел игрока - обрываем ВСЮ ветку SEARCH через FAILURE.
	# Если вернуть SUCCESS, Sequence пойдёт дальше в ClearTarget
	# и сотрёт только что найденную цель.
	if e.priority.current_target != null:
		return FAILURE

	_left -= delta
	e.rotate_y(turn_speed * delta)	# крутимся на месте, осматриваясь

	if _left > 0.0:
		return RUNNING	# Еще осматриваемся

	return SUCCESS		# время вышло, никого - дальше ClearTarget
