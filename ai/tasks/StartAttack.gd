@tool
extends BTAction

func _generate_name() -> String:
	return "Action start attack"

func _tick(delta: float) -> Status:
	return RUNNING
