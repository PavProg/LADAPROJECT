extends Node3D
# Только камера/взгляд. Захват предметов вынесен в GrabComponent.

@onready var player: CharacterBody3D = get_parent() as CharacterBody3D
@onready var camera: Camera3D = $Camera3D

@export var mouse_sensitivity: float = 0.003

func _ready() -> void:
	if not is_multiplayer_authority():
		return                       # чужой камерой не управляем
	camera.make_current()            # активной делаем ТОЛЬКО свою камеру
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return                       # мышь обрабатываем только у своего игрока
	if event is InputEventMouseMotion:
		player.rotate_y(-event.relative.x * mouse_sensitivity)   # yaw (вращение по вертикали) — на теле игрока (реплицируется через Player.rotation)
		rotate_x(-event.relative.y * mouse_sensitivity)          # pitch (вращение о горизонтали) — на камере (реплицируется через CameraController.rotation)
		rotation.x = clamp(rotation.x, deg_to_rad(-89), deg_to_rad(89))
	if event.is_action_pressed("mouse_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
