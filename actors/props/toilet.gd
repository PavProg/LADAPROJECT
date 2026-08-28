extends Node3D
class_name EscapeToilet

@export var escape_area : Area3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func on_interact() -> void:
	if GameManager.current_quote > GameManager.required_quote:
		LevelManager.return_to_hub()
