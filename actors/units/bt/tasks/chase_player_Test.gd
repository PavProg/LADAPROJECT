@tool
extends BTAction
# Проверяет можно ли преследовать игрока, через NavigationRegion и RayCast


@export var target_var: StringName = &"target"

func _generate_name() -> String:
	return "ChaseTarget" + LimboUtility.decorate_var(target_var)
	
func _tick(delta: float) -> Status:
	# Логика проверки через Navigation
	return SUCCESS
