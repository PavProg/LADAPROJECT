extends Node
class_name TutorialStep

signal completed
@export var step_dialogue : Label

func enter() -> void:
	print(self.name + " step entered")
	
	if step_dialogue:
		step_dialogue.visible = true
	
func exit() -> void:
	print(self.name + " step completed")
	
	if step_dialogue:
		step_dialogue.visible = false
	
func update(delta : float) -> void:
	pass
	
func complete() -> void:
	completed.emit()
