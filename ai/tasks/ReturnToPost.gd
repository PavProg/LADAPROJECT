@tool
extends BTAction

@export var face_speed: float = 6.0

var _target_set: bool = false

func _generate_name() -> String:
	return "Action return to post"

func _enter() -> void:
	_target_set = false

## Вызывается и при завершении, когда DynamicSelector прерывает задачу
## - охранник встает с поста
func _exit() -> void:
	var g := agent as EnemyGuard
	if g:
		g.at_post = false

func _tick(delta: float) -> Status:
	var g := agent as EnemyGuard
	if g == null:
		return FAILURE
	
	if not _target_set:
		g.set_move_target(g.post_position)
		_target_set = true
		if not g.agent.is_target_reachable():
			push_warning("[GUARD] пост недостижим по навмешу: %s" % g.post_position)
		return RUNNING
	
	if not g.agent.is_navigation_finished():
		return RUNNING
	
	g.stop_moving()
	g.face_yaw(g.post_yaw, face_speed * delta)
	g.at_post = true
	return RUNNING
			
