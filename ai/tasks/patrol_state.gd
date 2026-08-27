@tool
extends BTAction

## РПадиус блуждания вокруг текущей позиции врага. 0 - всяф карта, точка ставится рандомно на навмеше.
## Если нужно поставить врагов в комнат, меняется wander_radius > 0
@export var wander_radius: float = 0.0
## Пауза на достигнутой точке
@export var idle_time: float = 1.5

var _idle_left: float = 0.0
var _has_point: bool = false

func _generate_name() -> String:
	return "Action patrol"

func _enter() -> void:
	_idle_left = 0.0
	_has_point = false

func _tick(delta: float) -> Status:
	var e := agent as Enemy
	if e == null:
		return FAILURE
	
	# Точки нет выбираем новую на навмеше
	if not _has_point:
		var p := _pick_point(e)
		if p == Vector3.INF:
			return FAILURE
		e.set_move_target(p)
		_has_point = true
		return RUNNING
	
	# Дошли
	if e.agent.is_navigation_finished():
		_idle_left -= delta
		if _idle_left <= 0.0:
			_idle_left = idle_time
			_has_point = false
		return RUNNING
	
	return RUNNING

func _pick_point(e : Enemy) -> Vector3:
	var map := e.get_world_3d().navigation_map
	if not map.is_valid():
		return Vector3.INF
	
	# Если радиус нулевой спавним рандомно по ВСЕЙ карте
	if wander_radius <= 0.0:
		return NavigationServer3D.map_get_random_point(map, e.agent.navigation_layers, true)
	
	# Точка в радиусе врага + смещение
	var offset := Vector3(randf_range(-wander_radius, wander_radius), 0.0, randf_range(-wander_radius, wander_radius))
	return NavigationServer3D.map_get_closest_point(map, e.global_position + offset)
