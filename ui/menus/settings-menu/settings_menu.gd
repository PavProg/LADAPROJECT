extends Control

@export var tab_group: ButtonGroup

@onready var tab_container: TabContainer = $Dim/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer
@onready var apply_button: Button = $Dim/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxBot/ApplyButton
@onready var status_label: Label = $Dim/StatusLabel

func _ready() -> void:
	tab_group.pressed.connect(_on_tab_group_pressed)
	for tab in tab_container.get_children():
		if tab.has_signal("settings_changed"):
			tab.settings_changed.connect(refresh_apply_state)

func refresh_apply_state():
	var changed := false
	for tab in tab_container.get_children():
		if tab.has_method("has_changes") and tab.has_changes():
			changed = true
	apply_button.disabled = not changed
	status_label.text = "Settings not saved" if changed else ""

func _on_tab_group_pressed(button):
	tab_container.current_tab = button.get_index()



func _on_back_button_pressed() -> void:
	UiManager.settings_close()


func _on_apply_button_pressed() -> void:
	for child in tab_container.get_children():
		if child.has_method("save_settings"):
			child.save_settings()
	Settings.apply()
	Settings.save_to_file()
	refresh_apply_state()
	status_label.text = "Settings saved"
	


func _on_visibility_changed() -> void:
	if self.visible:
		for child in tab_container.get_children():
			if child.has_method("load_settings"):
				child.load_settings()
		refresh_apply_state()
