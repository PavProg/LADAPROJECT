extends Node
# Чисто стимовские приколы с соединением и подключением P2P (синглтон)
# Часть скриптов оберентся около host_game и joined_game
# Запускаем host и join. Создаем UUID группы и lobby_id

# p2p туннель инициализируем в net.gd

# ДОкинуть обработку ошибок и подключение к UI!!

const APP_ID: int = 480
const STEAM_APP_ID: String = "SteamAppId"
const STEAM_GAME_ID: String = "SteamGameId"

var steam_id: int = 0	# host_game и join_game происходит ЗДЕСЬ! ТК STEAM_ID назначается ЗДЕСЬ!!!
var steam_username: String = ""

signal lobby_status_changed(message: String)

# ИНИЦИАЛИЗАЦИЯ СТИМА
#########################################

func _init() -> void:
	OS.set_environment(STEAM_APP_ID, str(APP_ID))
	OS.set_environment(STEAM_GAME_ID, str(APP_ID))

func _ready() -> void:
	var intialized: bool = Steam.steamInit()
	
	if not intialized:
		push_error("Ошибка инициализации Steam")
		return
	
	print("Steam инициализирован")
	
	steam_id = Steam.getSteamID()
	steam_username = Steam.getPersonaName()
	Net.host_game()
	Net.join_game(steam_id)

#########################################

func _on_generate_uuid(lobby_id: int) -> void:
	var my_uuid := LobbyUuid.generate_uuid()
	
	steam_id = Steam.getSteamID()
	
	# Записываем uuid комнаты и steam_id в метаданные
	Steam.setLobbyData(lobby_id, "my_group_uuid", my_uuid)
	Steam.setLobbyData(lobby_id, "my_steam_id", str(steam_id))
	
	print("ID лобби и стимовский айди помещены в metadata комнаты")

# Передаем uuid из LineEdit
func join_lobby_by_uuid(message: String):
	if message.is_empty():
		print("Введите корректный UUID")
		return
	
	var target_uuid = message.strip_edges()
	
	Steam.addRequestLobbyListStringFilter("my_group_uuid", target_uuid, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()

func _on_steam_lobby_match_list(lobbies: Array):
	if lobbies.is_empty():
		print("Список лобби пуст")
		return
	
	var found_lobby_id = lobbies[0]
	
	Steam.joinLobby(found_lobby_id)
	pass

func _on_button_pressed() -> void:
	# Активация кнопки нажатися создать лобби
	pass
