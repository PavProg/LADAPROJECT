extends Node
class_name TutorialScript

const TUTORIAL_DIALOGUE = preload("uid://fnamyk5os66v")

@onready var timer: Timer = $Timer

@export var steps: Array[TutorialStep] = []
@export var dialogue : TutorialDialogue
@export var doors: Array[Node3D] = []

@export_subgroup("Areas")
@export var areas: Array[Area3D] = []
@export var area_sens_steps: Array[NextAreaStep] = []
@export var grab_end_area: Area3D
@export_group("")

@export var break_area : Area3D

@onready var grab_item_node: TutorialStep = $Steps/GrabItem
@onready var break_item_node: TutorialStep = $Steps/BreakItem

var current_index: int = -1
var current_step: TutorialStep

var next_door: int = 0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for step in steps:
		step.completed.connect(_on_step_completed)
	
	## Link areas to tutorial steps
	for area in area_sens_steps:
		area.target_area = areas[area_sens_steps.find(area)]
		area.door = doors[area_sens_steps.find(area)]
	
	grab_item_node.end_area = grab_end_area
	# End of linking areas
	
	break_item_node.break_area = break_area
		
	timer.start()
	await timer.timeout
	dialogue.visible = true
	_next_step()
	
func _process(delta:float) -> void:
	if current_step:
		current_step.update(delta)

func _next_step() -> void:
	if current_step:
		current_step.exit()

	current_index += 1

	if current_index >= steps.size():
		return

	current_step = steps[current_index]
	current_step.enter()
	
func _on_step_completed() -> void:
	_next_step()
