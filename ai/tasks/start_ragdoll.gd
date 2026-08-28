@tool
extends BTAction

var _left: float = 0.0

# ВАЖНО для активации ноды
func _generate_name() -> String:
	return "Action start ragdoll"

func _enter() -> void:
	var e := agent as Enemy
	if e == null:
		return
	
	_left = e.data.ragdoll_time
	e._enter_ragdoll()

func _tick(delta: float) -> Status:
	var e := agent as Enemy
	if e == null:
		return FAILURE
	
	_left -= delta
	if _left > 0:
		return RUNNING
	
	e.recover_from_ragdoll()
	return SUCCESS
	
