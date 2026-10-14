class_name RoomData extends Resource


## Сколько раз комната обязана плявться на уровне
@export var min_count: int = 0
## Маскимум на уровень
@export var max_count: int = -1
## Минимальная глубина. Будку не ставим у входа
@export var min_depth: int = 0
## сцена с комнатой
@export var scene: PackedScene
## размер комнаты X на Z
@export var size: Vector2i
## битовые флаги для отслеживания направления дверей в комнате
@export_flags("East", "North", "West", "South") var doors: int = 0
