@tool
extends BTCondition

func _generate_name() -> String:
	return "Has Last Known?"
	
func _tick(delta: float) -> Status:
	return SUCCESS
