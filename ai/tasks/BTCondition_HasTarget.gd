@tool
extends BTCondition

func _generate_name() -> String:
	return "Has Target?"

func _tick(_delta: float) -> Status:
	var e := agent as Enemy
	if e == null:
		return FAILURE
	var t := e.priority.current_target
	if t == null or not is_instance_valid(t):
		return FAILURE
	return SUCCESS
