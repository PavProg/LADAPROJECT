extends CanvasLayer

var hud : Control = null
var pause_menu : Control = null
var settings_menu : Control = null

const MAIN_MENU := "res://ui/menus/lobby-menu/lobby-menu.tscn"

func _ready() -> void:
	Events.local_player_spawned.connect(_local_player_spawned)
	

func _unhandled_input(event: InputEvent) -> void:
	if pause_menu == null:
		return
	if event.is_action_pressed("mouse_cancel"):
		if settings_menu.visible:
			settings_close()
		else:
			pause_switch()
		get_viewport().set_input_as_handled()

func spawn_ui(path: String) -> Control:
	var ui_element_scene = load(path)
	var ui_element = ui_element_scene.instantiate()
	self.add_child(ui_element)
	return ui_element

func _local_player_spawned(player):
	if hud == null:
		hud = spawn_ui("res://ui/hud/hud.tscn")
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if pause_menu == null:
		pause_menu = spawn_ui("res://ui/menus/pause-menu/pause_menu.tscn")
	if settings_menu == null:
		settings_menu = spawn_ui("res://ui/menus/settings-menu/settings_menu.tscn")
		
	var quota : MarginContainer = hud.get_node("./Quota")
	var hint : MarginContainer = hud.get_node("./Hint")
	var damage_feed : Control = hud.get_node("./QuotaDamageFeed")
	var task_container : Control = hud.get_node("./Quota/VBoxContainer/TasksContainer")

	if get_tree().current_scene.name == "Hub":
		quota.visible = false
		hint.visible = true
		damage_feed.visible = false
	elif get_tree().current_scene.name == "TutorialLvl":
		task_container.visible = false
		hint.visible = false
	else:
		quota.visible = true
		hint.visible = false
		damage_feed.visible = true
		task_container.visible = true
		
	hud.set_player(player)
	
func _show_quota() -> void:
	var quota : MarginContainer = hud.get_node("./Quota")
	var damage_feed : Control = hud.get_node("./QuotaDamageFeed")
	quota.visible = true
	damage_feed.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

#region функции для паузы

func pause_open():
	if hud != null:
		hud.crosshair.visible = false
	pause_menu.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func pause_close():
	hud.crosshair.visible = true
	pause_menu.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func pause_switch():
	if pause_menu.visible:
		pause_close()
	else:
		pause_open()
		
func is_game_blocked():
	return (pause_menu != null and pause_menu.visible) or (settings_menu != null and settings_menu.visible)
#endregion

#region функции для настроек

func settings_open():
	settings_menu.visible = true
	pause_menu.visible = false
func settings_close():
	settings_menu.visible = false
	pause_menu.visible = true
	
#endregion

#region функции для выхода (quit)

func quit_pressed():
	Net.clear_peer_for_exit()
	LevelManager.change_scene(MAIN_MENU, -1, 0)
	clear_game_ui()


#endregion

## Функция для очистки с UI (когда например требуется выйти с меню)
func clear_game_ui() -> void:
	for ui in [hud, pause_menu, settings_menu]:
		if ui != null and is_instance_valid(ui):
			ui.queue_free()
	hud = null
	pause_menu = null
	settings_menu = null
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
