@tool
extends BTCondition

func _generate_name() -> String:
	return "Check Range attack"

func _tick(delta: float) -> Status:
	return FAILURE
