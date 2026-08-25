extends Resource
class_name ItemData

@export var id: StringName
@export var display_name: String
@export var throw_force: float = 12.0
@export var distructed_scene: PackedScene
@export var value: int = 10
@export var mass: float = 2.0
@export var damage: int = 5
@export var max_durability: int = 100
@export var durability: int = 100
## Это то значение velocity между объектами, которое нужно преодолеть, чтобы в целом нанести урон. 
## Другими словами, это значение определеяет насколько сильно нужно ударить по тому ии иному объекту, чтобы вообще нанести ему урон(актуально для Breakable объектов)
@export var velocity_length_threshold: float = 1.0

# Поля тестовые сделаны для примера .tres и могут меняться
