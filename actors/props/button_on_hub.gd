extends StaticBody3D

func on_interact() -> void:
	request_start.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func request_start() -> void:
	if not multiplayer.is_server():
		return
	LevelManager.start_first_run()
