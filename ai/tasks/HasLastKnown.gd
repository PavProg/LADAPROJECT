@tool
extends BTCondition

func _generate_name() -> String:
	return "Has Last Known?"


func _tick(delta: float) -> Status:
	var e := agent as Enemy
	
	if e == null:
		return FAILURE
	
	return SUCCESS if e.priority.has_last_known else FAILURE
