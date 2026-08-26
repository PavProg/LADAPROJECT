@tool
extends BTAction

func _generate_name() -> String:
	return "Action clear target"

func _tick(delta: float) -> Status:
	return RUNNING
