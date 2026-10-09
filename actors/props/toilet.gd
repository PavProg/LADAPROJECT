extends StaticBody3D
class_name EscapeToilet

## Площадь выхода, кто вне зоны - смерть
@export var escape_area : Area3D

func on_interact() -> void:

	#print("Запрос перехода")
	# хаб или обычный уровень — сервер сам решит, пускать или нет
	request_next_level.rpc_id(1)
		
@rpc("any_peer", "call_local", "reliable")
func request_exit() -> void:
	if not multiplayer.is_server():
		return
	if GameManager.current_state != GameManager.quote_states.FINISHED:
		return 
	LevelManager.next_level()

@rpc("any_peer", "call_local", "reliable")
func request_next_level() -> void:
	if not multiplayer.is_server():
		return

	# Хаб — выходим всегда, квоты тут нет.
	if LevelManager.is_hub():
		LevelManager.next_level()
		return

	# Обычный уровень — только при набранной квоте.
	if GameManager.current_state != GameManager.quote_states.FINISHED:
		return
	LevelManager.next_level()
