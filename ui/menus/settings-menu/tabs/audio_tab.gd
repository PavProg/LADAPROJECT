extends VBoxContainer

signal settings_changed

@onready var master_volume_slider: HSlider = $MarginContainer/VBoxContainer/MasterVolumeRow/Slider
@onready var master_volume_value: Label = $MarginContainer/VBoxContainer/MasterVolumeRow/Value

@onready var sfx_volume_slider: HSlider = $MarginContainer/VBoxContainer/SFXVolumeRow/Slider
@onready var sfx_volume_value: Label = $MarginContainer/VBoxContainer/SFXVolumeRow/Value

var rows := []

func _ready() -> void:
	rows = [
		{ "slider": master_volume_slider, "label": master_volume_value, "key": "master_volume" },
		{ "slider": sfx_volume_slider, "label": sfx_volume_value, "key": "sfx_volume"},
	]

func load_settings():
	for row in rows:
		var value = Settings.get(row.key)
		row.slider.set_value_no_signal(value)
		show_percent(row.label, value)
func save_settings():
	for row in rows:
		Settings.set(row.key,row.slider.value)

func has_changes() -> bool:
	for row in rows:
		if not is_equal_approx(row.slider.value, Settings.get(row.key)):
			return true
	return false


func _on_sfx_volume_slider_value_changed(value: float) -> void:
	show_percent(sfx_volume_value,value)
	settings_changed.emit()


func _on_master_volume_slider_value_changed(value: float) -> void:
	show_percent(master_volume_value,value)
	settings_changed.emit()

func show_percent(label : Label,value : float):
	label.text = str(roundi(value*100))
