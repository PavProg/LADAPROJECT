@tool
extends BTAction

func _generate_name() -> String:
	return "Action patrol"
	
func _tick(delta: float) -> Status:
	return RUNNING
