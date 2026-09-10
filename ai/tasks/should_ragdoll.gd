@tool
extends BTCondition

func _generate_name() -> String:
	return "Should Ragdoll?"

func _tick(delta: float) -> Status:
	var e := agent as Enemy
	if e == null:
		return FAILURE
	return SUCCESS if e.is_ragdoll else FAILURE
