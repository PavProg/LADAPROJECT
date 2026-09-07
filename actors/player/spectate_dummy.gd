extends Node3D
class_name SpectateDummy

## ОТЛАДОЧНЫЙ болванчик для проверки камеры наблюдателя без второго игрока.
## В игровой логике не участвует: создаётся только из Player._debug_spawn_dummy().
##
## Ездит по кругу вокруг точки, где был создан, чтобы было видно,
## как камера следует за движущейся целью и как SpringArm3D
## подтягивает её при заходе цели за стену.

## Радиус круга, по которому ездит болванчик (метры)
@export var radius: float = 4.0
## Скорость обхода круга (радиан в секунду)
@export var speed: float = 1.0

var _origin: Vector3
var _t: float = 0.0


func _ready() -> void:
	_origin = global_position


func _process(delta: float) -> void:
	_t += delta * speed
	global_position = _origin + Vector3(cos(_t) * radius, 0.0, sin(_t) * radius)
	# Разворачиваем болванчика по ходу движения - камера при первом входе
	# в наблюдение берёт стартовый угол именно из поворота цели.
	rotation.y = -_t
