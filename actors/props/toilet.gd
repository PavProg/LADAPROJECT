extends StaticBody3D
class_name EscapeToilet

## Площадь выхода, кто вне зоны - смерть
@export var escape_area : Area3D

func on_interact() -> void:
	if LevelManager._run_index != -1:
		#print("Запрос перехода")
		LevelManager.start_first_run()
	if GameManager.current_quote >= GameManager.required_quote:
		request_exit.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func request_exit() -> void:
	if not multiplayer.is_server():
		return
	if GameManager.current_state != GameManager.quote_states.FINISHED:
		return 
	LevelManager.next_level()
