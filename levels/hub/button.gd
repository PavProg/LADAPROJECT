extends Button




func _on_pressed() -> void:
	if not multiplayer.is_server():
		return
	LevelManager.start_first_run()
