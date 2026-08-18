extends Node
# Работает с multiplayer напрямую
const PORT: int = 7777
const MAX_PLAYERS: int = 4
const PLAYER := preload("../actors/player/player.tscn")
const ITEMS := preload("res://items/hummer.tscn")
const BREAK_ITEMS := preload("res://items/break_item.tscn")
var peer: SteamMultiplayerPeer

var players: Dictionary = {}	# id ПИРА -> узел игрока
var spawned_ids: Array[int] = []	# кого сервер уже создал

#func _ready() -> void:
	## Коннектим пиры
	#multiplayer.peer_connected.connect(_on_peer_connected)
	#multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
################################# СТИМОВСКОЕ ПОДКЛЮЧЕНИЕ

# Откатить для локальных тестов:
# SteamMultiplayerPeer -> EnetMultiplayerPeer, (NetworkSteam.VIRTUAL_PORT, MAX_PLAYERS) -> (PORT, MAX_PLAYERS)
# (host_steam_id, NetworkSteam.VIRTUAL_PORT) -> (id, PORT)

func host_game() -> Error:	# создать апи, создать сервер, проверить, подключить мультиплеер пир, заспавнить, вернуть ошибку/подтверждение
	peer = SteamMultiplayerPeer.new()
	var serv = peer.create_host(NetworkSteam.VIRTUAL_PORT)
	if serv != OK:
		push_error("Сервер не поднялся: ", error_string(serv))
		return serv
	multiplayer.multiplayer_peer = peer
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

#func _on_peer_connected(id: int) -> void:
	#if multiplayer.is_server():
		#_spawn_players(id)
	#player_connect.emit(id)
	#
#func _on_peer_disconnected(id: int) -> void:
	#if players.has(id) and is_instance_valid(players[id]):	# проверяем существование key в словаре и памяти
		#players[id].queue_free()
	#players.erase(id)
	#player_disconnect.emit(id)

####### СПАВН ИГРОКА

# Зовет сервак из ack_ready когда пир подтвердил, что в сцене
func server_spawn_player(id: int) -> void:
	if not multiplayer.is_server(): return
	if id in spawned_ids: return
	
	create_player.rpc(id) # спавним и сразу реплицируем
	for existing in spawned_ids:
		create_player.rpc_id(id, existing)	# на всякий прогоняю, чтобы у нового пира игроки были
	spawned_ids.append(id)

# Алгоритм похожий, но теперь следим, чтобы пир был на сценах, защита от Node not found
@rpc("authority", "call_local", "reliable")
func create_player(id: int) -> void:
	var cont := get_tree().current_scene.get_node_or_null("PlayersCont")  # _or_null: get_node кидает ошибку, если пир ещё не в сцене
	if cont == null: return
	
	if cont.has_node(str(id)): return
	var p := PLAYER.instantiate()
	p.name = str(id)
	p.set_multiplayer_authority(id)
	cont.add_child(p)

func server_dispawn_player(id: int) -> void:
	if not multiplayer.is_server(): return
	spawned_ids.erase(id)
	_remove_player.rpc(id)

@rpc("authority", "call_local", "reliable")
func _remove_player(id: int) -> void:
	var cont := get_tree().current_scene.get_node_or_null("PlayersCont")
	if cont and cont.has_node(str(id)):
		cont.get_node(str(id)).queue_free()
	
func clear_spawned() -> void:
	spawned_ids.clear()	# Чистим реестр игроков
	spawned_items.clear()	# и реестр предметов (сами узлы умрут вместе со сценой)

#######

####### СПАВН ПРЕДМЕТОВ как у игроков

enum ItemType { HUMMER, BREAK }

var spawned_items: Dictionary = {}
var _item_counter: int = 0

# Зовёт сервер из ack_ready
func spawn_content() -> void:
	if not multiplayer.is_server(): return
	for n in 4:
		_server_spawn_item(ItemType.HUMMER, Vector3(randf_range(-6.0, 6.0), 3.0, randf_range(-6.0, 6.0)))
	for n in 5:
		_server_spawn_item(ItemType.BREAK, Vector3(randf_range(-10.0, 6.0), 1.5, randf_range(-10.0, 6.0)))

# сервак создаёт предмет локально + регистрирует + рассылает готовым клиентам
func _server_spawn_item(type: int, pos: Vector3) -> void:
	if not multiplayer.is_server(): return
	_item_counter += 1
	var item_name := "item_%d" % _item_counter			# сетевое имя, по нему удалять
	var node := _instantiate_item(type, item_name, pos)	# создаём локально у сервера
	if node == null: return
	spawned_items[item_name] = {"type": type, "node": node}
	_create_item.rpc(type, item_name, pos)

# Выполняется у КЛИЕНТОВ
@rpc("authority", "reliable")
func _create_item(type: int, item_name: String, pos: Vector3) -> void:
	_instantiate_item(type, item_name, pos)

# Локальное создание узла (одинаково на сервере и клиенте)
func _instantiate_item(type: int, item_name: String, pos: Vector3) -> Node:
	var cont := get_tree().current_scene.get_node_or_null("Items")
	if cont == null: return null
	if cont.has_node(item_name): return cont.get_node(item_name)
	var scene: PackedScene = ITEMS if type == ItemType.HUMMER else BREAK_ITEMS
	var i := scene.instantiate()
	i.name = item_name
	i.set_multiplayer_authority(1)		# предметы всегда серверо-авторитетны (freeze считается по этому)
	i.position = pos
	cont.add_child(i)
	return i

# Догоняем новый пир, предохранитель от херни со спавном игрока
func send_items_to(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	for item_name in spawned_items:
		var d = spawned_items[item_name]
		if is_instance_valid(d.node):
			_create_item.rpc_id(peer_id, d.type, item_name, d.node.global_position)

# зовётся из break_component при разрушении (сервер)
func despawn_item(item_name: String) -> void:
	if not multiplayer.is_server(): return
	spawned_items.erase(item_name)
	_remove_item.rpc(item_name)

@rpc("authority", "call_local", "reliable")
func _remove_item(item_name: String) -> void:
	var cont := get_tree().current_scene.get_node_or_null("Items")
	if cont and cont.has_node(item_name):
		cont.get_node(item_name).queue_free()
