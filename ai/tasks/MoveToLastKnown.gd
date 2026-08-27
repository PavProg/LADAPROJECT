@tool
extends BTAction

@export var _repath_time: float = 0.2
var _t = 0.0

func _generate_name() -> String:
	return "Action move to last known"

func _enter() -> void:
	_t = 0.0

func _tick(delta: float) -> Status:
	var e := agent as Enemy
	
	if e == null:
		return FAILURE
	if not e.priority.has_last_known:
		return FAILURE
	
	if e.agent.is_navigation_finished():
		return SUCCESS
	
	_t -= delta
	if _t <= 0.0:
		_t = _repath_time
		
		var map := e.get_world_3d().navigation_map
		# map_get_closet_point позволяет при случае точки цели на ящике/кафедре и тп взять ближайшую к нему
		var goal := NavigationServer3D.map_get_closest_point(map, e.priority.last_known_position)
		
		e.set_move_target(goal)
		if not e.agent.is_target_reachable():
			return FAILURE	# Добраться нельзя - переходим в Patrol

	return RUNNING
