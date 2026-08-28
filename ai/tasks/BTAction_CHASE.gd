@tool
extends BTAction

## Как часто пересчитываем путь? Каждый кадр - слишком дорого
@export var repath_time: float = 0.1

var _t: float = 0.0

func _enter() -> void:
	_t = 0.0	# Входим в ветку - мгновенно пересчитать путь

func _generate_name() -> String:
	return "Action CHASE"
	
func _tick(delta: float) -> Status:
	var e := agent as Enemy
	if e == null:
		return FAILURE
	
	## Таргет которого преследуем
	var t := e.priority.current_target
	if t == null or not is_instance_valid(t):
		return FAILURE
	
	## Ренжа атаки
	var r := e.data.range_attack
	if e.global_position.distance_squared_to(t.global_position) <= r * r:
		return SUCCESS
		
	_t -= delta
	if _t <= 0.0:
		_t = repath_time
		e.set_move_target(t.global_position, true)	# true - преследуем бегом (speed_sprint)
		if not e.agent.is_target_reachable():
			return FAILURE # Пути нет - обходим, не ударяемся в стену
	return RUNNING
