extends Control

@export var host_scene: PackedScene  # Сцена для хоста (перетащите в инспектор)

@onready var menu_buttons_container: VBoxContainer = $MenuButtonsContainer
@onready var host_button = $MenuButtonsContainer/HostButton
@onready var join_button = $MenuButtonsContainer/JoinButton
@onready var exit_button = $MenuButtonsContainer/ExitButton
@onready var join_popup = get_node("JoinGamePopup")
@onready var uid_enter_box = join_popup.get_node("VBoxContainer/MarginContainer/UIDEnterBox")
@onready var confirm_join_button = join_popup.get_node("VBoxContainer/HBoxContainer/ConfirmJoinButton")
@onready var cancel_join_button = join_popup.get_node("VBoxContainer/HBoxContainer/CancelJoinButton")

func _ready():
	# Изначально скрываем попап
	join_popup.visible = false
	
	# Подключаем сигналы
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	confirm_join_button.pressed.connect(_on_confirm_join_pressed)
	cancel_join_button.pressed.connect(_on_cancel_join_pressed)
	
	# Закрытие попапа по нажатию Escape
	join_popup.focus_entered.connect(_on_popup_focus_entered)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_host_pressed():
	if host_scene:
		get_tree().change_scene_to_packed(host_scene)
	else:
		print("Ошибка: хост-сцена не назначена в инспекторе!")

func _on_join_pressed():
	# Показываем попап
	join_popup.visible = true
	uid_enter_box.text = ""
	uid_enter_box.grab_focus()

func _on_exit_pressed():
	get_tree().quit()

func _on_confirm_join_pressed():
	var uid = uid_enter_box.text.strip_edges()
	if uid.is_empty():
		# Можно добавить визуальную обратную связь
		print("Введите UID игры")
		return
	
	print("Подключение к игре с UID: ", uid)
	# Здесь будет логика подключения к игре
	# Например: NetworkManager.join_game(uid)
	
	# Закрываем попап после подтверждения
	join_popup.visible = false

func _on_cancel_join_pressed():
	join_popup.visible = false
	# Возвращаем фокус на кнопку Join
	join_button.grab_focus()

func _on_popup_focus_entered():
	# Обработка нажатия Escape для закрытия попапа
	pass

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if join_popup.visible:
			join_popup.visible = false
			join_button.grab_focus()
