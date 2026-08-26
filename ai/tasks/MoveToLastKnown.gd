@tool
extends BTAction

func _generate_name() -> String:
	return "Action move to last known"

func _tick(delta: float) -> Status:
	return RUNNING
