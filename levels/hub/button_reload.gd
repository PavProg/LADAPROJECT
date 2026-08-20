extends Button




func _on_pressed() -> void:
	if not multiplayer.is_server():
		return
	LevelManager.reload_hub()
