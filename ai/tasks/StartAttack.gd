@tool
extends BTAction

func _generate_name() -> String:
	return "Action start attack"

func _tick(delta: float) -> Status:
	var e := agent as Enemy
	if e == null:
		return FAILURE
	
	if not e.attack._can_attack():
		return FAILURE
	
	e.attack._start_attack()
	return SUCCESS
