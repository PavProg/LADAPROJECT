extends Resource
class_name PlayerData

@export var max_health: float = 0
@export var health: float = 0
@export var max_endurance: float = 0
@export var endurance: float = 0
@export var speed: float = 0
@export var run_speed: float = 0
@export var jump_velocity: float = 0
## кол-во времени до начала восстановления выносливости
@export var endurance_recovery_time: float = 0 
## кол-во выносливости добавляемое за кадр
@export var endurance_recovery_speed: float = 0
## для действия interact (по стандарту 'e')
@export var interaction_range : float = 0
## значение силы с которой нужно ударить для рэгдола
@export var velocity_threshold: float
