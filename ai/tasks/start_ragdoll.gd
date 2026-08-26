@tool
extends BTAction

# ЛОГИКА РЭГДОЛА ВРАГА
# ИМПЛЕМЕНТАЦИЯ КЛАССА РЭГДОЛА ИЗ КОМПОНЕНТОВ

# ВАЖНО для активации ноды
func _generate_name() -> String:
	return "Action start ragdoll"

func _tick(delta: float) -> Status:
	# Запуск рэгдолла
	_ragdolled()
	return RUNNING
	
func _ragdolled() -> void:
	pass
