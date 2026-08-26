@tool
extends BTAction

func _generate_name() -> String:
	return "Action look around"
	
func _tick(delta: float) -> Status:
	return RUNNING
