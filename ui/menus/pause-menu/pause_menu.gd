extends Control

@onready var resume_button: Button = $Dim/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ResumeButton
@onready var settings_button: Button = $Dim/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $Dim/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/QuitButton

func _on_resume_button_pressed() -> void:
	UiManager.pause_close()


func _on_settings_button_pressed() -> void:
	UiManager.settings_open()
