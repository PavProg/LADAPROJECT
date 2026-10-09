extends StaticBody3D

## Площадь выхода, кто вне зоны - смерть
@export var escape_area : Area3D
const MAIN_MENU : String = "res://ui/menus/lobby-menu/lobby-menu.tscn"


func on_interact() -> void:
	Net.clear_peer_for_exit()
	LevelManager.change_scene(MAIN_MENU, -1, 0)
