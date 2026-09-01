extends Node
# Работает с multiplayer напрямую
const PLAYER := preload("../actors/player/player.tscn")
const ITEMS := preload("res://items/hummer.tscn")
const BREAK_ITEMS := preload("res://items/bust.tscn")
const ENEMY_RAT := preload("res://actors/units/enemy_rat.tscn")
var peer: SteamMultiplayerPeer

var spawned_ids: Array[int] = []

var spawned_items: Dictionary = {}
var _item_counter: int = 0

var spawned_enemy: Dictionary = {}
var _enemy_counter: int = 0


#region Steam connect
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
#endregion

####### СПАВН ИГРОКА
#region spawn player
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
	p.add_to_group("player") # Добавляем в группу игроков
	p.set_multiplayer_authority(id)
	cont.add_child(p)
	print("[NET/create_player] Создали ноду игрока, добавили в контейнер: ", cont)
	#if id == multiplayer.get_unique_id():                       # ТОЛЬКО свой игрок
		#p.get_node("CameraController/Camera3D").call_deferred("make_current")

func server_dispawn_player(id: int) -> void:
	if not multiplayer.is_server(): return
	spawned_ids.erase(id)
	_remove_player.rpc(id)

# Попытка фикса спавна игроков. Если не работает - ставим камеру вручную в create_player.
# Если и это не сработает - process_frame.
@rpc("authority", "call_local", "reliable")
func _remove_player(id: int) -> void:
	var cont := get_tree().current_scene.get_node_or_null("PlayersCont")
	if cont and cont.has_node(str(id)):
		var node = cont.get_node(str(id))
		node.name = "_dead" + str(id)
		node.queue_free()
		print("[NET/remove_player] Нода игрока была удалена.")
#endregion

#region Spawn Items
# Зовёт сервер из ack_ready. Предметы берутся с марок ItemMarks в сцене уровня.
func spawn_content() -> void:
	if not multiplayer.is_server(): return
	var marks := get_tree().current_scene.get_node_or_null("ItemMarks")
	if marks == null:
		push_warning("ItemMarks не найден в %s" % get_tree().current_scene.scene_file_path)
		return
	for m in marks.get_children():
		if m is ItemMark:
			#print("[NET/spawn_content] Спавним контент по маркам")
			var scene: PackedScene = m.forced_item if m.forced_item else BREAK_ITEMS
			_server_spawn_item(scene.resource_path, m.global_position, m.global_rotation.y)

# сервак создаёт предмет локально + регистрирует + рассылает готовым клиентам
func _server_spawn_item(scene_path: String, pos: Vector3, yaw: float = 0.0) -> Node:
	if not multiplayer.is_server(): return null
	_item_counter += 1
	var item_name := "item_%d" % _item_counter				# сетевое имя, по нему удалять
	var node := _instantiate_item(scene_path, item_name, pos, yaw)	# создаём у сервера
	if node == null: return null
	spawned_items[item_name] = {"scene": scene_path, "node": node}
	_create_item.rpc(scene_path, item_name, pos, yaw)
	return node

# Выдать молоток игроку при спавне на боевом уровне
func give_hammer_to(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	var cont := get_tree().current_scene.get_node_or_null("PlayersCont")
	if cont == null: return
	var p := cont.get_node_or_null(str(peer_id))
	if p == null: return
	_server_spawn_item(ITEMS.resource_path, p.global_position + Vector3.UP * 0.6)

@rpc("authority", "call_local", "reliable")
func _create_item(scene_path: String, item_name: String, pos: Vector3, yaw: float) -> void:
	#print("[NET/createItem] Функция создания rpc предмета была вызвана")
	_instantiate_item(scene_path, item_name, pos, yaw)

# Локальное создание узла (одинаково на сервере и клиенте)
func _instantiate_item(scene_path: String, item_name: String, pos: Vector3, yaw: float) -> Node:
	var cont := get_tree().current_scene.get_node_or_null("Items")
	if cont == null: return null
	if cont.has_node(item_name): return cont.get_node(item_name)
	var scene: PackedScene = load(scene_path)
	if scene == null: return null
	var i := scene.instantiate()
	i.name = item_name
	i.set_multiplayer_authority(1)		# предметы всегда серверо-авторитетны (freeze считается по этому)
	#print("2 -- [CHECK] item full path on server: ", i.get_path())

	i.position = pos
	i.rotation.y = yaw
	cont.add_child(i)
	#print("[NET/inst] Функция инстанцирования предмета была вызвана.")
	return i

# Догоняем новый пир, предохранитель от херни со спавном игрока
func send_items_to(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	for item_name in spawned_items:
		var d = spawned_items[item_name]
		if is_instance_valid(d.node):
			_create_item.rpc_id(peer_id, d.scene, item_name, d.node.global_position, d.node.rotation.y)
			#print("[NET/send_items] Функция досылки предметов клиентам вызвана!")

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
#endregion

#region Spawn enemy
func spawn_enemies() -> void:
	if not multiplayer.is_server(): return
	
	var marks := get_tree().current_scene.get_node_or_null("EnemyMarkCont")
	if marks == null:
		push_warning("[NET/SPAWN-ENEMY] EnemyMarksCont не найден в корневой сцене уровня.")
		return
	
	for m in marks.get_children():
		if m is EnemyMark:
			var scene: PackedScene = m.forced_enemy if m.forced_enemy else ENEMY_RAT
			_server_spawn_enemies(scene.resource_path, m.global_position, m.global_rotation.y)

## сервер спавнит врагов
func _server_spawn_enemies(scene_path: String, pos: Vector3, yaw: float = 0.0) -> Node:
	if not multiplayer.is_server(): return
	
	_enemy_counter += 1
	var enemy_name := "enemy_%d" % _enemy_counter
	
	var node := _instantiate_enemy(scene_path, enemy_name, pos, yaw)
	if node == null: return null
	
	spawned_enemy[enemy_name] = {"scene": scene_path, "node": node}
	_create_enemy.rpc(scene_path, enemy_name, pos, yaw)
	return node

## rpc - создаем сцены врагов
@rpc("authority", "reliable")
func _create_enemy(scene_path: String, enemy_name: String, pos: Vector3, yaw: float) -> void:
	_instantiate_enemy(scene_path, enemy_name, pos, yaw)

## Инстанцируем врагов
func _instantiate_enemy(scene_path: String, enemy_name: String, pos: Vector3, yaw: float) -> Node:
	var cont := get_tree().current_scene.get_node_or_null("EnemiesCont")
	if cont == null: return null
	
	if cont.has_node(enemy_name):
		return cont.get_node(enemy_name)
	
	var scene: PackedScene = load(scene_path)
	if scene == null: return null
	
	var e := scene.instantiate()
	e.name = enemy_name
	e.set_multiplayer_authority(1)
	e.position = pos
	e.rotation.y = yaw
	cont.add_child(e)
	return e

## Предохранитель от гонки
func send_enemies_to(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	
	for enemy_name in spawned_enemy:
		var d = spawned_enemy[enemy_name]
		if is_instance_valid(d.node):
			_create_enemy.rpc_id(peer_id, d.scene, enemy_name, d.node.global_position, d.node.rotation.y)

## функция деспавна врагов
func despawn_enemy(enemy_name: String) -> void:
	if not multiplayer.is_server(): return
	
	spawned_enemy.erase(enemy_name)
	_remove_enemy.rpc(enemy_name)

## Сервер удаляет врагов
@rpc("authority", "call_local", "reliable")
func _remove_enemy(enemy_name: String) -> void:
	var cont := get_tree().current_scene.get_node_or_null("EnemiesCont")
	if cont and cont.has_node(enemy_name):
		cont.get_node(enemy_name).queue_free()

#endregion

#region resapwn + clear
func clear_spawned_players_nodes() -> void:
	if not multiplayer.is_server(): return
	for id in spawned_ids.duplicate():
		_remove_player.rpc(id)
	spawned_ids.clear()

func clear_spawned() -> void:
	spawned_ids.clear()	# Чистим реестр игроков
	spawned_items.clear()	# и реестр предметов (сами узлы умрут вместе со сценой)
	spawned_enemy.clear()
#endregion
