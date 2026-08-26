@tool
extends BTAction

# Проверяем ренджу для атаки, нужная - атакуем (после проигрывания анимации)
func _generate_name() -> String:
	return "Face target action"

func _tick(delta: float) -> Status:
	return RUNNING
