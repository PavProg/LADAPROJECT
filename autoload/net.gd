extends Node
# Работает с multiplayer напрямую
const PORT: int = 7777
const MAX_PLAYERS: int = 4
const PLAYER := preload("../actors/player/player.tscn")
const ITEMS := preload("res://items/hummer.tscn")
const BREAK_ITEMS := preload("res://items/break_item.tscn")
var peer: SteamMultiplayerPeer

var players: Dictionary = {}	# id ПИРА -> узел игрока

signal player_connect(id: int)
signal player_disconnect(id: int)

func _ready() -> void:
	# Коннектим пиры
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
################################# СТИМОВСКОЕ ПОДКЛЮЧЕНИЕ

# Откатить для локальных тестов:
# SteamMultiplayerPeer -> EnetMultiplayerPeer, (NetworkSteam.VIRTUAL_PORT, MAX_PLAYERS) -> (PORT, MAX_PLAYERS)
# (host_steam_id, NetworkSteam.VIRTUAL_PORT) -> (id, PORT)

func host_game() -> Error:	# создать апи, создать сервер, проверить, подключить мультиплеер пир, заспавнить, вернуть ошибку/подтверждение
	peer = SteamMultiplayerPeer.new()
	var serv = peer.create_server(NetworkSteam.VIRTUAL_PORT, MAX_PLAYERS)
	if serv != OK:
		push_error("Сервер не поднялся: ", error_string(serv))
		return serv
	multiplayer.multiplayer_peer = peer
	_spawn_hummers()
	_spawn_items()
	_spawn_players(1)	# Спавним, тк подключения к пиру не было, а хост тоже игрок
	return OK

func join_game(host_steam_id: int) -> Error:	 # Стимовский айдишник берется в network_steam
	peer = SteamMultiplayerPeer.new()
	var cli = peer.create_client(host_steam_id, NetworkSteam.VIRTUAL_PORT)
	if cli != OK:
		push_error("Клиент не появился: ", error_string(cli))
		return cli
	multiplayer.multiplayer_peer = peer
	return OK

#################################

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_spawn_players(id)
	player_connect.emit(id)
	
func _on_peer_disconnected(id: int) -> void:
	if players.has(id) and is_instance_valid(players[id]):	# проверяем существование key в словаре и памяти
		players[id].queue_free()
	players.erase(id)
	player_disconnect.emit(id)

# На будующее сделать отдельную функцию под спавн всех объектов нужных

func _spawn_players(id: int) -> void:
	var container := get_tree().current_scene.get_node("Players")
	var p := PLAYER.instantiate()
	p.name = str(id)	# Для authority, под имя отдельное поле
	container.add_child(p, true)
	players[id] = p

func _spawn_hummers(count: int = 4) -> void:
	# спавнит ТОЛЬКО сервер; MItemsSpawner2 реплицирует предметы всем
	var container := get_tree().current_scene.get_node("Items")
	for n in count:
		var i := ITEMS.instantiate()
		i.position = Vector3(randf_range(-6.0, 6.0), 3.0, randf_range(-6.0, 6.0))  # позицию ставим ДО add_child
		container.add_child(i, true)

func _spawn_items(count: int = 5) -> void:
	var container := get_tree().current_scene.get_node("Items")
	for n in count:
		var i := BREAK_ITEMS.instantiate()
		i.position = Vector3(randf_range(-10.0, 6.0), 1.5, randf_range(-10.0, 6.0))
		container.add_child(i, true)
