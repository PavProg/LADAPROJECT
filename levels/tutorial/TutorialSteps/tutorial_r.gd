extends TutorialStep

const STEP : float = 100.0

@export var dialougue : TutorialDialogue

func update(delta : float) -> void:
	if Input.is_action_just_pressed("ragdoll"):
		dialougue.add_progress(STEP)
	
	if dialougue.get_progress() >= 100:
		dialougue.reset_progress()
		complete()
