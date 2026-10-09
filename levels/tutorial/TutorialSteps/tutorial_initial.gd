extends TutorialStep

const AWAIT_TIME : float = 4.0

func enter() -> void:
	#print(self.name + " step entered")
	
	if step_dialogue:
		step_dialogue.visible = true

func update(delta : float) -> void:
	if Input.is_anything_pressed():
		complete()
