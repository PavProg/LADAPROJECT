extends TutorialStep


const STEP : float = 25.0

@export var dialougue : TutorialDialogue

var time : float = 0.0

func update(delta : float) -> void:
	if (Input.is_action_pressed("move_forward") || 	\
		Input.is_action_pressed("move_left") ||		\
		Input.is_action_pressed("move_backward") ||	\
		Input.is_action_pressed("move_right")) &&	\
		Input.is_action_pressed("run"):
		time += delta
		dialougue.add_progress(delta*STEP)
	
	if time >= 1:
		time -= 1
	
	if dialougue.get_progress() >= 100:
		dialougue.reset_progress()
		complete()
