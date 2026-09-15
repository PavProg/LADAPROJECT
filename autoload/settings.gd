extends Node

const SETTINGS := {
	  "master_volume": { "section": "audio", "default": 1.0 },
	  "sfx_volume":    { "section": "audio", "default": 1.0 },
}
const SAVE_PATH := "user://settings.cfg"

var master_volume : float = SETTINGS.master_volume.default
var sfx_volume : float = SETTINGS.sfx_volume.default

func _ready() -> void:
	load_from_file()
	apply()

func apply():
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"),linear_to_db(master_volume))
	
func save_to_file() -> void:
	var config = ConfigFile.new()
	for key in SETTINGS:
		config.set_value(SETTINGS[key].section, key, get(key))
	
	var err = config.save(SAVE_PATH)
	if err != OK:
		push_error("Не удалось сохранить конфиг файл")

func load_from_file() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err != OK:
		return
	for key in SETTINGS:
		set(key, config.get_value(SETTINGS[key].section, key, SETTINGS[key].default))

	
