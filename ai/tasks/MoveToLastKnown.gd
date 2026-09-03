@tool
extends BTAction

@export var _repath_time: float = 0.2
## Максимум времени на дорогу до последней известной точки.
## Без него, если точка недостижима, is_navigation_finished() никогда
## не станет true и враг навсегда зависнет в состоянии поиска.
@export var max_travel_time: float = 6.0

var _t = 0.0
## Цель уже выставлена хотя бы раз в этом заходе
var _target_set: bool = false
var _travel_left: float = 0.0

func _generate_name() -> String:
	return "Action move to last known"

func _enter() -> void:
	_t = 0.0
	_target_set = false
	_travel_left = max_travel_time

func _tick(delta: float) -> Status:
	var e := agent as Enemy

	if e == null:
		return FAILURE
	if not e.priority.has_last_known:
		return FAILURE

	# Время вышло - считаем, что дошли: пусть отработает LookAround,
	# а затем ClearTarget вернёт врага в патруль. Иначе поиск залипает.
	_travel_left -= delta
	if _travel_left <= 0.0:
		return SUCCESS

	_t -= delta
	# Цель ставим ДО проверки is_navigation_finished.
	# Иначе в первом тике проверялась бы СТАРАЯ цель (после stop_moving она
	# равна позиции самого врага), навигация считалась бы завершённой,
	# и задача возвращала SUCCESS, никуда не сходив.
	if not _target_set or _t <= 0.0:
		_t = _repath_time

		var map := e.get_world_3d().navigation_map
		# map_get_closet_point позволяет при случае точки цели на ящике/кафедре и тп взять ближайшую к нему
		var goal := NavigationServer3D.map_get_closest_point(map, e.priority.last_known_position)

		e.set_move_target(goal)
		_target_set = true
		if not e.agent.is_target_reachable():
			return FAILURE	# Добраться нельзя - переходим в Patrol
		return RUNNING		# даём агенту кадр на пересчёт пути

	if e.agent.is_navigation_finished():
		return SUCCESS

	return RUNNING
