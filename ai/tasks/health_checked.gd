@tool
extends BTAction

@export var target_var: StringName = &"target"

@export var data: UnitData

func _generate_name() -> String:
	return "Health_is_ZERO" + LimboUtility.decorate_var(target_var)
	
func _tick(_delta: float) -> Status:
	# Если после атаки здоровье меньше нуля -> рэгдолл (в отдельной ноде)
	if data.health > 0:
		return FAILURE
	else:
		return SUCCESS
