class_name Health
extends Node

@export var data: UnitData
@export var rat_health: float = 10.0	# Желательно менять через data
@export var damage_for_ragdoll: float = 5.0

signal ragdolled
signal damaged(amount: float)

var _current_health: float

func _ready():
	_current_health = rat_health

func _on_ragdolled(amount: float) -> void:
	if _current_health <= 0:
		return
		
	_current_health -= amount
	_current_health = max(_current_health, 0.0)
	
	if _current_health <= 0.0:
		print("Enemy ragdolled")
		ragdolled.emit()
	else:
		damaged.emit(amount)
	pass
