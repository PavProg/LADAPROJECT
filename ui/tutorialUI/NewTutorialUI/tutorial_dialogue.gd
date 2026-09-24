extends Control
class_name TutorialDialogue

@export var dialogues: Array[Label] = []
@export var task_progress_bar : ProgressBar

var current_dialogue : Label
var task_progress : float
var time:float

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	reset_progress()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _show() -> void:
	self.visible = true

func _hide() -> void:
	self.visible = false

func hide_dialogue() -> void:
	current_dialogue.visible = false
	
func show_new_dialogue(new_dialogue : Label) -> void:
	if (new_dialogue == null):
		return
	
	if current_dialogue:
		current_dialogue.visible = false
		
	current_dialogue = new_dialogue
	current_dialogue.visible = true
	
func show_next_dialogue() -> void:
	var current_dialogue_index = dialogues.find(current_dialogue)
	
	if (current_dialogue_index + 1) < dialogues.size():
		print(dialogues.size())
		show_new_dialogue(dialogues[current_dialogue_index + 1])
	
func add_progress(progress: float) -> void:
	task_progress += progress
	task_progress_bar.value = task_progress

func get_progress() -> float:
	return task_progress

func reset_progress() -> void:
	task_progress = 0
	task_progress_bar.value = task_progress
