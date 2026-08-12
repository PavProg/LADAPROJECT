@tool
extends BTAction

@export var target_var: StringName = &"target"

@export var data: UnitData

func _generate_name() -> String:
	return "Health_is_ZERO" + LimboUtility.decorate_var(target_var)
	
func _tick(_delta: float) -> Status:
	
	return SUCCESS
