# СИНГЛТОН стим инит подключение и переход в хаб. (Возможно перехожы между уровнями)
extends Node
# Чисто стимовские приколы с соединением и подключением P2P (синглтон)
# Часть скриптов оберентся около host_game и joined_game
# Запускаем host и join. Создаем UUID группы и lobby_id

# Callbacks, metadata, UI

const APP_ID: int = 480
const VIRTUAL_PORT: int = 0
const LOBBY_MAX: int = 4
const GROUP_KEY: String = "My_group_id"

var lobby_id: int = 0
var steam_id: int = 0	# host_game и join_game происходит ЗДЕСЬ! ТК STEAM_ID назначается ЗДЕСЬ!!!
var steam_username: String = ""

signal status(msg: String)

func _init() -> void:
	OS.set_environment("SteamAppId", str(APP_ID))
	OS.set_environment("SteamGameId", str(APP_ID))

func _ready() -> void:
	if not Steam.steamInit():
		push_error("Ошибка инициализации стима")
	steam_id = Steam.getSteamID()
	
	# Callbacks
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_match_list.connect(_on_steam_lobby_match_list)
	Steam.join_requested.connect(_on_join_request)

func _process(_delta: float):
	Steam.run_callbacks()

# Для кнопки ХОСТА в main_menu_controller.gd
func create_group() -> void:
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, LOBBY_MAX)

func _on_lobby_created(result: int, new_lobby_id: int):
	if result != Steam.RESULT_OK:
		return

	lobby_id = new_lobby_id
	var uuid := LobbyUuid.generate_uuid()
	## Добавляем uuid в метаданные
	Steam.setLobbyData(lobby_id, GROUP_KEY, uuid)
	DisplayServer.clipboard_set(str(uuid))
	Net.host_game()
	LevelManager.go_to_hub()

func _on_group_joined_by_uuid(uuid: String) -> void:
	uuid = uuid.strip_edges()
	if uuid.is_empty():
		status.emit("Введите ID группы"); return
	status.emit("Поиск группы...")
	Steam.addRequestLobbyListStringFilter(GROUP_KEY, uuid, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()

func _on_lobby_joined(this_lobby_id: int, _permission: int, _locked: bool, responce: int) -> void:
	if responce != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		status.emit("Не удалось создать лобби")
		return
	lobby_id = this_lobby_id
	var host_id := Steam.getLobbyOwner(lobby_id)	# Steam id хоста!
	if host_id == steam_id: return
	Net.join_game(host_id)

func _on_join_request(lobby_steam_id: int):
	Steam.joinLobby(lobby_steam_id)

func _on_steam_lobby_match_list(lobbies: Array):
	if lobbies.is_empty():
		status.emit("Комната не найдена"); return
	Steam.joinLobby(lobbies[0])
