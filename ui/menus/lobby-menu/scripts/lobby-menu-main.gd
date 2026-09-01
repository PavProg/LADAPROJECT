extends Control

#region Подключение нод
@onready var entry_panel: Control = $EntryPanel
@onready var host_button: Button = $EntryPanel/MenuButtonsContainer/HostButton
@onready var join_button: Button = $EntryPanel/MenuButtonsContainer/JoinButton
@onready var exit_button: Button = $EntryPanel/MenuButtonsContainer/ExitButton
#@onready var single_button: Button = $EntryPanel/MenuButtonsContainer/SingleButton

@onready var join_popup: Panel = $JoinGamePopup
@onready var uid_box: LineEdit = $JoinGamePopup/VBoxContainer/MarginContainer/UIDEnterBox
@onready var confirm_join: Button = $JoinGamePopup/VBoxContainer/HBoxContainer/ConfirmJoinButton
@onready var cancel_join: Button = $JoinGamePopup/VBoxContainer/HBoxContainer/CancelJoinButton

@onready var room_panel: Panel = $RoomPanel
@onready var code_value: Label = $RoomPanel/MarginContainer/RoomContainer/CodeRow/CodeValue
@onready var copy_code: Button = $RoomPanel/MarginContainer/RoomContainer/CodeRow/CopyCodeButton
@onready var players_list: VBoxContainer = $RoomPanel/MarginContainer/RoomContainer/PlayersScroll/PlayersList
@onready var row_template: Label = $RoomPanel/MarginContainer/RoomContainer/PlayersScroll/PlayersList/PlayerRowTemplate
@onready var invite_button: Button = $RoomPanel/MarginContainer/RoomContainer/ButtonsRow/InviteFriendButton
@onready var start_button: Button = $RoomPanel/MarginContainer/RoomContainer/ButtonsRow/StartGameButton
@onready var leave_button: Button = $RoomPanel/MarginContainer/RoomContainer/ButtonsRow/LeaveButton

@onready var status_label: Label = $StatusLabel
#endregion

#region Подключение сигналов
func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	#single_button.pressed.connect(_on_single_pressed)
	
	confirm_join.pressed.connect(_on_confirm_join_pressed)
	cancel_join.pressed.connect(_on_cancel_join_pressed)
	
	copy_code.pressed.connect(_on_copy_code_pressed)
	invite_button.pressed.connect(_on_invite_button_pressed)
	start_button.pressed.connect(_on_start_button_pressed)
	leave_button.pressed.connect(_on_leave_button_pressed)
	
	# Steam
	NetworkSteam.status.connect(_on_status)
	NetworkSteam.group_created.connect(_on_group_created)
	NetworkSteam.group_joined.connect(_on_group_joined)
	multiplayer.peer_connected.connect(_on_peer_changed)
	multiplayer.peer_disconnected.connect(_on_peer_changed)
	
	_show_entry()
#endregion

#region КЛЮЧЕВОЕ: 3 состояния экрана
func _show_entry() -> void:
	entry_panel.visible = true
	room_panel.visible = false
	join_popup.visible = false

func _show_room(is_host: bool) -> void:
	entry_panel.visible = false
	room_panel.visible = true
	join_popup.visible = false
	
	# Запускать может только ХОСТ
	start_button.disabled = not is_host
	invite_button.visible = is_host
	_refresh_player()
#endregion

#region Взаимодействие с меню
func _refresh_player() -> void:
	# чистим все кроме шаблона
	for child in players_list.get_children():
		if child != row_template:
			child.queue_free()
	
	if multiplayer.multiplayer_peer == null:
		return
	
	var ids: Array[int] = [1]
	for pid in multiplayer.get_peers():
		if pid != 1:
			ids.append(pid)
	
	for pid in ids:
		var row: Label = row_template.duplicate()
		row.visible = true
		var me := " (вы)" if pid == multiplayer.get_unique_id() else ""
		var host := " - хост" if pid == 1 else ""
		row.text = "%d%s%s" % [pid, host, me]
		players_list.add_child(row)

func _on_peer_changed(_id: int) -> void:
	_refresh_player()

func _on_status(msg: String) -> void:
	status_label.text = msg
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if join_popup.visible:
			join_popup.visible = false
			join_button.grab_focus()

func _on_group_created(code: String) -> void:
	code_value.text = code
	_show_room(true)

func _on_group_joined(code: String) -> void:
	code_value.text = code
	_show_room(false)
#endregion

#region хелперы для кнопок
## Кнопка покинуть лобби
func _on_leave_button_pressed() -> void:
	if NetworkSteam.lobby_id != 0:
		Steam.leaveLobby(NetworkSteam.lobby_id)
		NetworkSteam.lobby_id = 0
	multiplayer.multiplayer_peer = null
	host_button.disabled = false
	code_value.text = ""
	Net.peer = null
	_show_entry()

## Кнопка начала игры
func _on_start_button_pressed() -> void:
	if not multiplayer.is_server():
		return
	LevelManager.go_to_hub()

## Кнопка приглашения стим
func _on_invite_button_pressed() -> void:
	Steam.activateGameOverlayInviteDialog(NetworkSteam.lobby_id)

## Кнопка копирования кода группы
func _on_copy_code_pressed() -> void:
	DisplayServer.clipboard_set(code_value.text)
	status_label.text = "Код скопирован"

## Кнопка отмены присоединения
func _on_cancel_join_pressed() -> void:
	join_popup.visible = false
	join_button.grab_focus()

## Кнопка подтверждения join
func _on_confirm_join_pressed() -> void:
	var code := uid_box.text.strip_edges().to_upper()
	if code.is_empty():
		status_label.text = "Введите код группы"
		return
	join_popup.visible = false
	status_label.text = "Ищем комнату..."
	NetworkSteam._on_group_joined_by_uuid(code)

## Кнопка для перехода в сингл
func _on_single_pressed() -> void:
	pass

## Кнопка хоста
func _on_host_pressed() -> void:
	status_label.text = "Создаем комнату..."
	host_button.disabled = true
	NetworkSteam.create_group()

## Кнопка присоединиться
func _on_join_pressed() -> void:
	join_popup.visible = true
	uid_box.text = ""
	uid_box.grab_focus()

## Кнопка выхода
func _on_exit_pressed() -> void:
	get_tree().quit()
#endregion
