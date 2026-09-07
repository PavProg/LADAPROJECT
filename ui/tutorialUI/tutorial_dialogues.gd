extends Control
class_name TutorialDialogues

@onready var first_dialogue: Label = $MarginContainer/DiaolougeCloud/FirstDialogue
@onready var second_dialogue: Label = $MarginContainer/DiaolougeCloud/SecondDialogue
@onready var third_dialogue: Label = $MarginContainer/DiaolougeCloud/ThirdDialogue

func _ready() -> void:
	self.visible = false
	hide_dialogues()

func hide_dialogues() -> void:
	first_dialogue.visible = false
	second_dialogue.visible = false
	third_dialogue.visible = false

func show_first_dialogue() -> void:
	hide_dialogues()
	self.visible = true
	first_dialogue.visible = true

func show_second_dialogue() -> void:
	hide_dialogues()
	self.visible = true
	second_dialogue.visible = true

func show_third_dialogue() -> void:
	hide_dialogues()
	self.visible = true
	third_dialogue.visible = true
