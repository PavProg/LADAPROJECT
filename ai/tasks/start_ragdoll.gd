@tool
extends BTAction

# ЛОГИКА РЭГДОЛА ВРАГА
# ИМПЛЕМЕНТАЦИЯ КЛАССА РЭГДОЛА ИЗ КОМПОНЕНТОВ

# ВАЖНО для активации ноды
@export var target_var: StringName = &"target"

func _tick(delta: float) -> Status:
	# Запуск рэгдолла
	_ragdolled()
	return RUNNING
	
func _ragdolled() -> void:
	pass
