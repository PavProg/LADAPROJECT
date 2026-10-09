class_name RoomData extends Resource

## сцена с комнатой
@export var scene: PackedScene
## размер комнаты X на Z
@export var size: Vector2i
## битовые флаги для отслеживания направления дверей в комнате
@export_flags("East", "North", "West", "South") var doors: int = 0
