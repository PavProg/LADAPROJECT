@tool
extends BTAction

## Радиус блуждания вокруг текущей позиции врага.
## 0 = точка берётся где угодно на навмеше - но на многоэтажной карте это
## регулярно даёт НЕДОСТИЖИМУЮ точку (крыша, отрезанный кусок), и враг
## бесконечно топчется у границы. Поэтому по умолчанию ищем рядом с собой.
@export var wander_radius: float = 12.0
## Пауза на достигнутой точке
@export var idle_time: float = 1.5
## Максимум времени на одну точку. Не дошли - берём другую.
## Страховка от недостижимых точек: без неё is_navigation_finished()
## никогда не станет true и враг зависнет на месте навсегда.
@export var max_travel_time: float = 8.0

var _idle_left: float = 0.0
var _has_point: bool = false
var _travel_left: float = 0.0

func _generate_name() -> String:
	return "Action patrol"

func _enter() -> void:
	_idle_left = idle_time	# первая пауза тоже полноценная
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
		_travel_left = max_travel_time
		return RUNNING

	# Дошли
	if e.agent.is_navigation_finished():
		_idle_left -= delta
		if _idle_left <= 0.0:
			_idle_left = idle_time
			_has_point = false
		return RUNNING

	# Не дошли за отведённое время - точка недостижима, берём другую
	_travel_left -= delta
	if _travel_left <= 0.0:
		_has_point = false
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
