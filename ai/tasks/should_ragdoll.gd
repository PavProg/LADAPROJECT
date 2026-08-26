@tool
extends BTCondition

func _generate_name() -> String:
	return "Should Ragdoll?"

func _tick(delta: float) -> Status:
	return FAILURE
