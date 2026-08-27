@tool
extends BTAction

func _generate_name() -> String:
	return "Action clear target"

func _tick(delta: float) -> Status:
	var e := agent as Enemy
	if e == null:
		return FAILURE
	
	e.priority.clear_target()
	return SUCCESS
