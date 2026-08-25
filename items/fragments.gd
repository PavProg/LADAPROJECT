extends Node3D
@onready var disappear_timer: Timer = $DisappearTimer

@export var time_to_disappear_fragments: float # в секундах

func _ready() -> void:
	if not multiplayer.is_server(): return
	disappear_timer.start(time_to_disappear_fragments)
	pass

func _on_disappear_timer_timeout() -> void:
	print("_on_disappear_timer_timeout")
	if not multiplayer.is_server(): return
	delete_fragments.rpc()
	pass

func _process(delta: float):
	#print("TIME LEFT: ", disappear_timer.time_left)
	pass
	

# функция вызывается любым пользователем у себя на компе локально (хост вызывает у всех короче ее) + типо "TCP" протокол чтоб наверняка
@rpc("any_peer", "call_local", "reliable")
func delete_fragments() -> void:
	queue_free()
	pass
