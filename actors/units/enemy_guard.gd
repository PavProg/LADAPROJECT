class_name EnemyGuard
extends Enemy

@export var anim_sit: StringName = &"Sit"

## Пост. Где и куда лицом смотрит охранник. Берется из точки спавна
var post_position: Vector3
var post_yaw: float
## Сидит ли сейчас на посту
var at_post: bool = false

func _ready() -> void:
	add_to_group("security_quard")
	post_position = global_position
	post_yaw = rotation.y
	super._ready()

func _idle_anim() -> StringName:
	return anim_sit if at_post else ANIM_IDLE

## Вызывает камера. Охранник, который уже сам видит игрока, камеру не слушает
func on_camera_sighting(_target: Node3D, pos: Vector3) -> void:
	if not multiplayer.is_server() or is_ragdoll:
		return
	if priority.current_target != null:
		return
	priority.report_sighting(pos)

func face_yaw(yaw: float, weight: float) -> void:
	rotation.y = lerp_angle(rotation.y, yaw, clampf(weight, 0.0, 1.0))
