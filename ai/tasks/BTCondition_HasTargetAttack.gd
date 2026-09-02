@tool
extends BTCondition

func _generate_name() -> String:
	return "Check Range attack"

func _tick(delta: float) -> Status:
	var e := agent as Enemy
	if e == null:
		return FAILURE
	
	var t := e.priority.current_target
	if t == null or not is_instance_valid(t):
		return FAILURE
	var r := e.data.range_attack
	return SUCCESS if e.global_position.distance_squared_to(t.global_position) <= r * r else FAILURE
