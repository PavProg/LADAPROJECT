extends Node
# Работает с multiplayer напрямую
const PLAYER := preload("../actors/player/player.tscn")
const ITEMS := preload("res://items/hummer.tscn")
const BREAK_ITEMS := preload("res://items/bust.tscn")
const ENEMY_RAT := preload("res://actors/units/enemy_rat.tscn")
var peer: SteamMultiplayerPeer

## Отладочные принты по спавну и сверке состава.
const DEBUG := true

## Состав игроков по последнему ПРИМЕНЁННОМУ снапшоту.
## Одинаков на всех пирах, потому что приходит из одного источника - сервера
var spawned_ids: Array[int] = []

## Текущая эпоха уровня. Ставит LevelManager при смене сцены
var epoch: int = 0

## Снапшот, пришедший ДО того, как сцена успела загрузиться.
## Раньше такой пакет молча терялся
var _pending_state: Dictionary = {}

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

#region гейт видимости серверных узлов (предметы, враги)
# ПРОБЛЕМА, которую это лечит.
# MultiplayerSynchronizer начинает рассылать данные СРАЗУ после add_child -
# всем подключённым пирам, независимо от того, есть ли у них этот узел.
# Сервер создаёт предмет в spawn_content() в тот момент, когда клиенты ещё
# грузят сцену, поэтому у них немедленно сыпалось:
#   Node not found: "Hub/Items/item_1/MultiplayerSynchronizer"
#   process_simplify_path: Parameter "node" is null

## Закрыть синхронизатор только что созданного узла. Только на сервере.
func _gate_sync(node: Node, label: String) -> void:
	if not multiplayer.is_server():
		return
	var sync := node.get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync == null:
		return					# у узла нет синхронизатора - гейтить нечего
	sync.public_visibility = false
	sync.set_visibility_for(1, true)	# себе видно всегда
	_dbg("синхронизатор '%s' закрыт до подтверждения клиентов" % label)

func is_net_active() -> bool:
	var p := multiplayer.multiplayer_peer
	if p == null:
		return false
	return p.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


## Открыть синхронизатор узла конкретному пиру. Возвращает false, если
## синхронизатора нет.
func _open_sync_for(node: Node, peer_id: int) -> bool:
	var sync := node.get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync == null:
		return false
	sync.set_visibility_for(peer_id, true)
	return true
#endregion

####### СПАВН ИГРОКА
#region spawn player
# ИДЕМПОТЕНТНАЯ СХЕМА.
# Раньше состав игроков собирался из ОТДЕЛЬНЫХ событий: create_player,
# _remove_player, sync_ready_peers. Итог = начальное состояние + сумма событий,
# поэтому любая потеря пакета ломала результат навсегда, порядок доставки был
# важен, а новому пиру требовался отдельный "догоняющий" путь.
#
# Теперь по сети едет ПОЛНОЕ СОСТОЯНИЕ, а приёмник приводит своё дерево к нему.
# Свойства меняются на противоположные: потеря пакета лечится следующим
# снапшотом, порядок не важен, а новый пир получает то же самое сообщение,
# что и все остальные.

## Начало новой эпохи. Зовёт LevelManager ДО смены сцены.
func begin_epoch(new_epoch: int) -> void:
	epoch = new_epoch
	_pending_state.clear()
	clear_spawned()
	_dbg("новая эпоха %d, локальные реестры очищены" % new_epoch)

## ЕДИНСТВЕННАЯ точка синхронизации состава игроков
@rpc("authority", "call_local", "reliable")
func apply_players_state(state_epoch: int, ids: Array) -> void:
	# Пакет из прошлого уровня
	if state_epoch != epoch:
		_dbg("снапшот ОТБРОШЕН: epoch %d != текущей %d, ids=%s"
			% [state_epoch, epoch, str(ids)])
		return

	var cont := _players_cont()
	if cont == null:
		_pending_state = {"epoch": state_epoch, "ids": ids.duplicate()}
		_dbg("снапшот ОТЛОЖЕН (PlayersCont ещё нет): ids=%s" % str(ids))
		return

	_reconcile_players(cont, ids)

## Применить снапшот, отложенный на время загрузки сцены.
func apply_pending_state() -> void:
	if _pending_state.is_empty():
		return
	var st := _pending_state.duplicate()
	_pending_state.clear()
	_dbg("применяем отложенный снапшот ids=%s" % str(st["ids"]))
	apply_players_state(int(st["epoch"]), st["ids"])

## Приведение дерева к состоянию
func _reconcile_players(cont: Node, ids: Array) -> void:
	var want: Dictionary = {}
	for id in ids:
		want[int(id)] = true

	var created: Array[int] = []
	var removed: Array[int] = []

	for child in cont.get_children():
		# Уже помеченные на удаление пропускаем
		if str(child.name).begins_with("_dead"):
			continue
		var cid := str(child.name).to_int()
		if not want.has(cid):
			removed.append(cid)
			child.name = "_dead_%d" % cid
			child.queue_free()

	for id in want.keys():
		if not cont.has_node(str(id)):
			_make_player(cont, int(id))
			created.append(int(id))

	# Локальный реестр = снапшот
	spawned_ids.clear()
	for id in ids:
		spawned_ids.append(int(id))

	_apply_sync_visibility()

	if not created.is_empty() or not removed.is_empty():
		_dbg("reconcile: создано %s, удалено %s -> итог %s"
			% [str(created), str(removed), str(spawned_ids)])

func _make_player(cont: Node, id: int) -> void:
	var p := PLAYER.instantiate()
	p.name = str(id)
	p.add_to_group("player")
	# Авторитет ставим ДО add_child: MultiplayerSynchronizer читает его
	# в момент входа в дерево.
	p.set_multiplayer_authority(id)
	cont.add_child(p)

## Свой синхронизатор открываем только тем, кто ТОЧНО уже в сцене, иначе сыпется
## "Node not found: .../MultiplayerSynchronizer" у пира, который ещё грузится.
## Важно: видимостью управляет АВТОРИТЕТ узла, то есть каждый пир настраивает СВОЙ.
func _apply_sync_visibility() -> void:
	var me := get_player_node(_me())
	if me == null: return
	var sync := me.get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync == null: return

	sync.public_visibility = false
	sync.set_visibility_for(1, true)		# сервер видит всегда
	for pid in spawned_ids:
		sync.set_visibility_for(int(pid), true)
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
	var cont := _players_cont()
	if cont == null: return
	var p := cont.get_node_or_null(str(peer_id))
	if p == null: return
	_server_spawn_item(ITEMS.resource_path, p.global_position + Vector3.UP * 0.6)

@rpc("authority", "call_local", "reliable")
func _create_item(scene_path: String, item_name: String, pos: Vector3, yaw: float) -> void:
	var node := _instantiate_item(scene_path, item_name, pos, yaw)
	if node == null:
		return		# сцена не готова, предмет досошлётся из send_items_to
	if not multiplayer.is_server():
		# Подтверждаем серверу: узел создан, синхронизировать теперь безопасно.
		_ack_item.rpc_id(1, item_name)


## КЛИЕНТ -> СЕРВЕР
@rpc("any_peer", "reliable")
func _ack_item(item_name: String) -> void:
	if not multiplayer.is_server(): return
	var sender := multiplayer.get_remote_sender_id()
	if not spawned_items.has(item_name): return
	var d = spawned_items[item_name]
	if not is_instance_valid(d.node): return
	if _open_sync_for(d.node, sender):
		_dbg("предмет '%s' открыт для пира %d" % [item_name, sender])

# Локальное создание узла (одинаково на сервере и клиенте)
func _instantiate_item(scene_path: String, item_name: String, pos: Vector3, yaw: float) -> Node:
	var scene_root := get_tree().current_scene
	var cont: Node = scene_root.get_node_or_null("Items") if scene_root else null
	if cont == null:
		# Предметы на идемпотентную схему пока не переведены, в отладке видно что пакет пропал.
		_dbg("ПОТЕРЯН предмет '%s': контейнер Items не найден" % item_name)
		return null
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
	_gate_sync(i, item_name)
	return i

# Догоняем новый пир, предохранитель от херни со спавном игрока
func send_items_to(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	# Себе досылать нечего: предметы уже созданы локально в _server_spawn_item.
	if peer_id == 1: return
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
	var scene_root := get_tree().current_scene
	var cont: Node = scene_root.get_node_or_null("Items") if scene_root else null
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
	var node := _instantiate_enemy(scene_path, enemy_name, pos, yaw)
	if node == null:
		return		# сцена не готова, враг досошлётся из send_enemies_to
	# call_local тут нет, так что сюда попадают только клиенты, но проверку
	# оставляем явной - её отсутствие уже стреляло на send_enemies_to(1).
	if not multiplayer.is_server():
		_ack_enemy.rpc_id(1, enemy_name)


## КЛИЕНТ -> СЕРВЕР
@rpc("any_peer", "reliable")
func _ack_enemy(enemy_name: String) -> void:
	if not multiplayer.is_server(): return
	var sender := multiplayer.get_remote_sender_id()
	if not spawned_enemy.has(enemy_name): return
	var d = spawned_enemy[enemy_name]
	if not is_instance_valid(d.node): return
	if _open_sync_for(d.node, sender):
		_dbg("враг '%s' открыт для пира %d" % [enemy_name, sender])

## Инстанцируем врагов
func _instantiate_enemy(scene_path: String, enemy_name: String, pos: Vector3, yaw: float) -> Node:
	var scene_root := get_tree().current_scene
	var cont: Node = scene_root.get_node_or_null("EnemiesCont") if scene_root else null
	if cont == null:
		_dbg("ПОТЕРЯН враг '%s': контейнер EnemiesCont не найден" % enemy_name)
		return null

	if cont.has_node(enemy_name):
		return cont.get_node(enemy_name)
	
	var scene: PackedScene = load(scene_path)
	if scene == null: return null
	
	var e := scene.instantiate()
	e.add_to_group("enemy")
	e.name = enemy_name
	e.set_multiplayer_authority(1)
	e.position = pos
	e.rotation.y = yaw
	cont.add_child(e)
	_gate_sync(e, enemy_name)
	return e

## Предохранитель от гонки
func send_enemies_to(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	if peer_id == 1: return

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
	var scene_root := get_tree().current_scene
	var cont: Node = scene_root.get_node_or_null("EnemiesCont") if scene_root else null
	if cont and cont.has_node(enemy_name):
		cont.get_node(enemy_name).queue_free()

#endregion

#region resapwn + clear
# clear_spawned_players_nodes() удалена вместе с _remove_player:
# теперь лишние узлы сносит _reconcile_players по снапшоту.

func clear_spawned() -> void:
	spawned_ids.clear()	# Чистим реестр игроков
	spawned_items.clear()	# и реестр предметов (сами узлы умрут вместе со сценой)
	spawned_enemy.clear()
#endregion

# Массив - ссылочный тип данных в годоте.
# Причина в том, что реестр узлов дублирует то, что и так известно: spawned_ids плюс GameManager.died_players. 
# Вместо фикса дублирования массива и spectate-camera,
# лучше убрать сам массив — это разом закрывает и мутацию по ссылке, 
# и накопление освобождённых узлов при смене сцены.
# По сети теперь ездят id, а не узлы
# — это ВАЖНО: узел валиден только внутри своей сцены, а id переживает любые переходы.

#region alive/died players
func get_alive_peer_ids() -> Array[int]:
	var result: Array[int] = []
	for id in spawned_ids:
		if GameManager.died_players.has(id):
			continue
		result.append(id)
	return result	# возвращаю массив АЙДИ!!

func get_player_node(peer_id: int) -> Node3D:
	var cont := _players_cont()
	if cont == null: return null
	return cont.get_node_or_null(str(peer_id)) as Node3D

@rpc("authority", "call_local", "reliable")
func spectate_retarget(alive_ids: Array) -> void:
	var me := get_player_node(_me())
	if me == null: return
	me.retarget_spectate(alive_ids)
#endregion

#region debug
func _players_cont() -> Node:
	var scene_root := get_tree().current_scene
	if scene_root == null: return null
	return scene_root.get_node_or_null("PlayersCont")

## get_unique_id() ругается, если пир ещё не поднят - отсюда обёртка.
func _me() -> int:
	return multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0

func _dbg(msg: String) -> void:
	if not DEBUG: return
	print("[NET/%d] %s" % [_me(), msg])

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build(): return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F3: dump_state()
		KEY_F4: transport_report()			# см. регион ТЕСТ ENET ниже
		KEY_F5: start_transform_probe()		# см. регион ТЕСТ ENET ниже

## F3 - полный локальный снимок. Жать НА КАЖДОЙ машине и сравнивать вывод.
##
## Как читать результат:
##  - Списки spawned_ids разошлись между машинами -> проблема в СПАВНЕ,
##    смотри строки "ОТБРОШЕН"/"ОТЛОЖЕН" выше по логу.
##  - Списки совпали, узлы у всех есть, но pos чужого игрока НЕ МЕНЯЕТСЯ
##    от дампа к дампу -> спавн исправен, не доезжают ТРАНСФОРМЫ.
##    Это уже вопрос транспорта, а не этого файла (тест на ENet).
##  - "моя видимость для" короче spawned_ids -> гейт видимости закрыл
##    синхронизатор от того, кого в списке нет.
func dump_state() -> void:
	var me := _me()
	print("\n========== [NET DUMP] пир %d ==========" % me)
	print("  роль          : %s" % ("СЕРВЕР" if multiplayer.is_server() else "клиент"))
	print("  LevelManager  : %s" % LevelManager.debug_report())
	print("  epoch (Net)   : %d" % epoch)
	print("  spawned_ids   : %s" % str(spawned_ids))
	print("  pending_state : %s" % ("нет" if _pending_state.is_empty() else str(_pending_state)))
	print("  соединённые   : %s" % str(multiplayer.get_peers()))

	var cont := _players_cont()
	if cont == null:
		print("  PlayersCont   : НЕ НАЙДЕН (сцена не готова?)")
	else:
		print("  узлы в PlayersCont:")
		for child in cont.get_children():
			var auth: int = child.get_multiplayer_authority()
			var pos := Vector3.ZERO
			if child is Node3D:
				pos = (child as Node3D).global_position.snapped(Vector3.ONE * 0.01)
			print("    %-12s авторитет=%-11d свой=%-5s pos=%s"
				% [child.name, auth, str(auth == me), str(pos)])

	var mine := get_player_node(me)
	if mine:
		var sync := mine.get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
		if sync:
			var vis: Array[int] = []
			for pid in spawned_ids:
				if sync.get_visibility_for(int(pid)):
					vis.append(int(pid))
			print("  моя видимость для: %s (public_visibility=%s)"
				% [str(vis), str(sync.public_visibility)])
	# Реестры spawned_items/spawned_enemy заполняются ТОЛЬКО на сервере
	# (_server_spawn_item пишет в них, а _create_item у клиента лишь создаёт узел).
	# Поэтому у клиента реестр всегда нулевой - считаем реальные узлы в сцене,
	# иначе дамп врёт "предметов 0" при живом предмете под ногами.
	print("  предметов в сцене: %s (реестр сервера: %d)"
		% [_count_in("Items"), spawned_items.size()])
	print("  врагов в сцене   : %s (реестр сервера: %d)"
		% [_count_in("EnemiesCont"), spawned_enemy.size()])
	print("=========================================\n")


## Возвращает строку, а не число: отсутствие контейнера и ноль детей - разные
## вещи. В хабе EnemiesCont нет вовсе, и "-1" читалось как ошибка.
func _count_in(container_name: String) -> String:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return "<сцены нет>"
	var c := scene_root.get_node_or_null(container_name)
	if c == null:
		return "<нет контейнера %s>" % container_name
	return str(c.get_child_count())
#endregion


#region ТЕСТ: ENet вместо Steam + проверка доставки трансформов
# =============================================================================
# ЗАЧЕМ ЭТО НУЖНО
#
#   Steam-транспорт у нас звезда: клиенты соединены ТОЛЬКО с хостом, между
#   собой - нет. Чтобы пакет от клиента А дошёл до клиента Б, сервер обязан
#   его ПЕРЕСЛАТЬ (за это отвечает SceneMultiplayer.server_relay).
#
#   Если пересылки нет, симптом маскируется под баг спавна: узлы у всех есть,
#   состав сходится, а чужие игроки стоят на месте. И проявляется это ТОЛЬКО
#   с третьего пира - при двоих пары "клиент-клиент" просто не существует,
#   поэтому вдвоём всё выглядит рабочим.
#
#   ENet пересылку умеет гарантированно. Значит он здесь - КОНТРОЛЬНЫЙ ОБРАЗЕЦ:
#   если на ENet трое видят друг друга, а на Steam нет, то виноват транспорт,
#   и переписывать игровой код бессмысленно.
#
# КАК ПОЛЬЗОВАТЬСЯ
#
#   F1 - поднять ENet-хост и уйти в хаб   (обработка в main/main.gd)
#   F2 - подключиться к 127.0.0.1         (обработка в main/main.gd)
#   F3 - dump_state()          полный снимок состояния, жать НА КАЖДОЙ машине
#   F4 - transport_report()    какой транспорт и включён ли relay
#   F5 - start_transform_probe()  ГЛАВНЫЙ ТЕСТ, замер на 5 секунд
#
# ПОРЯДОК ТЕСТА (три экземпляра)
#
#   1. Запустить трёх: один с --server, двое с --client (см. настройку ниже).
#   2. Дождаться, пока все окажутся в хабе.
#   3. Нажать F3 на каждой машине, сверить списки spawned_ids.
#   4. На КЛИЕНТЕ Б нажать F5 и в эти 5 секунд побегать КЛИЕНТОМ А.
#   5. Прочитать вердикт замера.
#
# ЧТО ЗНАЧИТ РЕЗУЛЬТАТ
#
#   Двигаются все            -> транспорт исправен, трансформы ходят.
#   Хост двигается, клиент нет -> НЕ РАБОТАЕТ ПЕРЕСЫЛКА между клиентами.
#                                 Это и есть искомая причина, дальше F4.
#   Не двигается никто       -> пир не соединён либо сцена другая, смотри F3.
#
# ЧЕГО ЭТИМ НЕ ПРОВЕРИТЬ
#   Устойчивость к потерям пакетов: три экземпляра на одной машине общаются
#   через loopback, где потерь и задержек нет. Замер отвечает только на вопрос
#   "доходит ли в принципе".
#
# ПЕРЕД РЕЛИЗОМ весь регион можно удалить - на игровую логику он не влияет.
# Вместе с ним удаляются ветки F1/F2 в main/main.gd.
# =============================================================================

## Порт для отладочного ENet. Steam использует NetworkSteam.VIRTUAL_PORT и его не трогаем.
const ENET_PORT := 7777

var _probe_active: bool = false
var _probe_left: float = 0.0
var _probe_start: Dictionary = {}	# peer_id -> Vector3 в начале замера
var _probe_max: Dictionary = {}		# peer_id -> максимальное отклонение за замер


## ОТЛАДКА. Поднять хост на ENet вместо Steam.
func host_game_enet(max_clients: int = 4) -> Error:
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(ENET_PORT, max_clients)
	if err != OK:
		push_error("[ENET] Сервер не поднялся: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = p
	transport_report()
	return OK


## ОТЛАДКА. Подключиться к ENet-хосту.
func join_game_enet(host_ip: String = "127.0.0.1") -> Error:
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(host_ip, ENET_PORT)
	if err != OK:
		push_error("[ENET] Клиент не создан: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = p
	transport_report()
	return OK


## F4. Какой транспорт поднят и умеет ли он пересылку между клиентами.
func transport_report() -> void:
	var p := multiplayer.multiplayer_peer
	print("\n===== [TRANSPORT] пир %d =====" % _me())
	print("  класс пира    : %s" % (p.get_class() if p else "<пир не поднят>"))
	print("  роль          : %s" % ("СЕРВЕР" if multiplayer.is_server() else "клиент"))
	print("  соединённые   : %s" % str(multiplayer.get_peers()))

	# server_relay объявлен у SceneMultiplayer, а свойство multiplayer статически
	# типизировано как MultiplayerAPI - отсюда приведение типа.
	var sm := multiplayer as SceneMultiplayer
	if sm == null:
		print("  server_relay  : не проверить, MultiplayerAPI не SceneMultiplayer")
	else:
		print("  server_relay  : %s" % str(sm.server_relay))
		if not sm.server_relay:
			print("  !! ПЕРЕСЫЛКА ВЫКЛЮЧЕНА. В звезде клиенты НЕ увидят друг друга.")
	print("==============================\n")


## F5. Замер: шевелятся ли чужие игроки. Запускать на КЛИЕНТЕ,
## пока ДРУГОЙ клиент бегает - иначе замерять будет нечего.
func start_transform_probe(duration: float = 5.0) -> void:
	_probe_start.clear()
	_probe_max.clear()

	var me := _me()
	for id in spawned_ids:
		if int(id) == me:
			continue			# за собой следить смысла нет, свои координаты локальные
		var n := get_player_node(int(id))
		if n == null:
			continue
		_probe_start[int(id)] = n.global_position
		_probe_max[int(id)] = 0.0

	if _probe_start.is_empty():
		print("[PROBE] Замерять некого: чужих игроков в сцене нет. Сначала F3.")
		return

	_probe_left = duration
	_probe_active = true
	print("[PROBE] Замер %.1f с. ПУСТЬ ДРУГОЙ ИГРОК ПОБЕГАЕТ. Цели: %s"
		% [duration, str(_probe_start.keys())])


## _process принадлежит тестовому региону: вне замера сразу выходит.
func _process(delta: float) -> void:
	if not _probe_active:
		return

	for id in _probe_start.keys():
		var n := get_player_node(int(id))
		if n == null:
			continue
		var from: Vector3 = _probe_start[id]
		var best: float = _probe_max[id]
		var d: float = n.global_position.distance_to(from)
		if d > best:
			_probe_max[id] = d

	_probe_left -= delta
	if _probe_left <= 0.0:
		_probe_active = false
		_report_probe()


func _report_probe() -> void:
	var me := _me()
	print("\n===== [PROBE] Итог замера, пир %d =====" % me)

	var moved: Array[int] = []
	var frozen: Array[int] = []

	for id in _probe_max.keys():
		var pid := int(id)
		var d: float = _probe_max[id]
		# 5 см - порог, ниже которого это дрожание, а не движение.
		var moving := d > 0.05
		print("  игрок %-12d сдвинулся на %5.2f м  ->  %s"
			% [pid, d, "ТРАНСФОРМ ИДЁТ" if moving else "движения нет"])
		if moving:
			moved.append(pid)
		else:
			frozen.append(pid)

	print("  ---")

	# ГЛАВНАЯ ОГОВОРКА, без неё вердикт врёт.
	# Замер доказывает только ПОЛОЖИТЕЛЬНЫЙ результат: увидели движение -
	# значит данные идут. Обратное неверно: неподвижный пир мог просто стоять
	# на месте, и отличить это от "данные не идут" замер не может.
	if frozen.is_empty():
		print("  ВЕРДИКТ: двигались все цели - данные идут от каждого.")
	else:
		print("  Движение НЕ зафиксировано у: %s" % str(frozen))
		print("  Это ещё НЕ поломка: пир мог просто стоять на месте.")
		print("  Замер доказывает только положительный результат.")
		print("  Повтори замер, двигая ИМЕННО ЭТИХ игроков, и сравни.")
		if not moved.is_empty():
			print("  От %s данные точно идут, значит транспорт в принципе живой."
				% str(moved))

	if multiplayer.is_server():
		print("  (Замер на СЕРВЕРЕ. Он получает данные напрямую от всех,")
		print("   пересылку между клиентами так не проверить - нужен клиент.)")
	elif frozen.has(1) and not moved.is_empty():
		print("  (Хост не двигался, а от других данные пришли - для проверки")
		print("   пересылки это нормально, побегай хостом и повтори.)")
	elif moved.has(1) and not frozen.is_empty():
		print("  (!) Хост двигается, а клиенты %s - нет." % str(frozen))
		print("      Если они ТОЧНО бегали - это неработающая пересылка между")
		print("      клиентами. Дальше F4: server_relay=false нужно включить;")
		print("      если true и это Steam - проблема в SteamMultiplayerPeer,")
		print("      сверь с прогоном на ENet.")
	print("=======================================\n")
#endregion
