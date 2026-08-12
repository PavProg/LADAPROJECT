extends CharacterBody3D
class_name Enemy

@export var data: UnitData

@onready var agent: NavigationAgent3D
@onready var bt: BTPlayer


func _ready() -> void:
	pass
	
func _phusic_process() -> void:
	pass
	
func _move() -> void:
	pass
	
# Здесь же функции анимации
