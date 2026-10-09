extends TutorialStep

@export var end_area : Area3D

func enter() -> void:
	#print(self.name + " step entered")
	
	if step_dialogue:
		step_dialogue.visible = true
		
	end_area.body_entered.connect(_on_body_entered)
	#print(end_area.name)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("tutorial_vase"):
		end_area.body_entered.disconnect(_on_body_entered)
		complete()
