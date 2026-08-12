extends Node3D


func _ready() -> void:
	# управление квотой
	GameManager.on_level_start(GameManager.required_quote_next_level)
	
	#############################################
	var args := OS.get_cmdline_args()
	if "--server" in args:
		Net.host_game()
	elif "--client" in args:
		Net.join_game("127.0.0.1")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("host"):	# F1
		Net.host_game()
	elif event.is_action_pressed("join"):# F2
		Net.join_game("127.0.0.1")
