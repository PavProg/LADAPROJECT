extends Node

const HUB := "res://levels/hub/hub.tscn"
const RUNS := [
	"res://levels/run_XX/run_level_1.tscn",
	"res://levels/hub/hub_old.tscn"
]

## Отладочные принты
const DEBUG := true

## Как часто сервер ПОВТОРЯЕТ снапшот состава (секунды)
const STATE_HEARTBEAT := 3.0

var current_scene_path: String = ""
var _run_index: int = -1
var _content_spawned: bool = false

## Номер загрузки уровня, растёт на каждый _load
var epoch: int = 0

## ЕДИНСТВЕННЫЙ источник истины: кто сейчас в уровне. ВКЛЮЧАЯ сервер (1)
var _peers: Array[int] = []

## Кому уже выдали стартовый инвентарь на этом уровне
var _equipped: Array[int] = []

## Последний разосланный состав. Нужен только чтобы не спамить в лог на каждый heartbeat
var _last_sent: Array[int] = []

var _heartbeat_t: float = 0.0

#region PEERS
func _ready() -> void:
	multiplayer.peer_connected.connect(_on_connected_peer)
	multiplayer.peer_disconnected.connect(_on_disconnected_peer)

func _process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer(): return
	# Периодический повтор снапшота. Только сервер и только когда есть кому слать.
	if not multiplayer.is_server(): return
	if _peers.is_empty(): return
	_heartbeat_t -= delta
	if _heartbeat_t <= 0.0:
		_heartbeat_t = STATE_HEARTBEAT
		_broadcast_state()

func _on_connected_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if current_scene_path != "":
		# Эпоху отдаём вместе со сценой: пир должен знать, какие снапшоты для него свежие.
		change_scene.rpc_id(peer_id, current_scene_path, epoch)

func _on_disconnected_peer(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	_peers.erase(peer_id)
	_equipped.erase(peer_id)
	_dbg("пир %d отвалился, состав: %s" % [peer_id, str(_peers)])
	# Отдельная RPC на удаление узла больше не нужна:
	# reconcile на приёмнике сам снесёт всех, кого нет в снапшоте.
	_broadcast_state()
#endregion

# СМЕНА УРОВНЕЙ И ХАБ
# СЕРВАК
#region функции хелперы
func go_to_hub() -> void:
	if not multiplayer.is_server():
		return
	_run_index = -1
	_load(HUB)

func start_first_run() -> void:
	if not multiplayer.is_server():
		return
	_run_index = 0
	_load(RUNS[0])

func next_level() -> void:
	if not multiplayer.is_server():
		return
	GameManager.on_level_end()
	_run_index += 1
	if _run_index >= RUNS.size():
		go_to_hub()
	else:
		_load(RUNS[_run_index])
#endregion

#region change Scenes
# СМЕНА СЦЕНЫ
func _load(path: String) -> void:
	current_scene_path = path
	_content_spawned = false
	epoch += 1					# всё, что было отправлено до этой строки, протухло
	_peers.clear()
	_equipped.clear()
	_last_sent.clear()
	_dbg("загрузка %s, epoch=%d" % [path, epoch])
	change_scene.rpc(path, epoch)

@rpc("authority","call_local", "reliable")
func change_scene(path: String, new_epoch: int) -> void:
	epoch = new_epoch
	Net.begin_epoch(new_epoch)	# локальные реестры обнуляются ДО загрузки сцены

	get_tree().change_scene_to_file(path)

	# Гоняем цикл пока ВСЕ не будет загружено на уровень
	while get_tree().current_scene == null or get_tree().current_scene.scene_file_path != path:
		await get_tree().process_frame
	await get_tree().process_frame

	Net.apply_pending_state()

	_ack_ready.rpc_id(1, multiplayer.get_unique_id())
#endregion

#region rpc spawn
# СПАВНЫ СУЩНОСТЕЙ
@rpc("any_peer", "call_local", "reliable")
func _ack_ready(peer_id: int) -> void:
	if not multiplayer.is_server(): return

	if not _peers.has(peer_id):
		_peers.append(peer_id)
		_dbg("ack от %d, состав: %s" % [peer_id, str(_peers)])

	if _peers.has(1) and not _content_spawned:
		_spawn_level_content()

	if not _peers.has(1):
		_dbg("ack от %d принят, но сервер ещё грузится - рассылка отложена" % peer_id)
		return

	_sync_all_peers()

func _spawn_level_content() -> void:
	_content_spawned = true
	Net.spawn_content()
	if _run_index >= 0:
		Net.spawn_enemies()
	GameManager.on_level_start(GameManager.required_quote_next_level)
	_dbg("контент уровня заспавнен (run_index=%d)" % _run_index)

## Приводит ВСЕХ к текущему состоянию.
## Вызывать можно сколько угодно раз: всё внутри идемпотентно.
func _sync_all_peers() -> void:
	if not multiplayer.is_server(): return

	# Состав игроков - одним снапшотом сразу всем.
	_broadcast_state()

	# Содержимое уровня. Досылается КАЖДОМУ, кто в игре, а не только новичку
	for pid in _peers:
		Net.send_items_to(pid)
		if _run_index >= 0:
			Net.send_enemies_to(pid)
			_give_starting_gear(pid)

## Молоток НЕ идемпотентен - каждый вызов создаёт новый предмет.
## Поэтому выдача защищена отдельным списком.
func _give_starting_gear(peer_id: int) -> void:
	if _equipped.has(peer_id): return
	_equipped.append(peer_id)
	Net.give_hammer_to(peer_id)
	_dbg("выдан стартовый инвентарь пиру %d" % peer_id)

func _broadcast_state() -> void:
	if not multiplayer.is_server(): return
	var ids := _peers.duplicate()
	# Логируем только когда состав РЕАЛЬНО изменился, иначе heartbeat зальёт консоль.
	if _last_sent != ids:
		_last_sent = ids.duplicate()
		_dbg("рассылка состава: epoch=%d ids=%s" % [epoch, str(ids)])
	Net.apply_players_state.rpc(epoch, ids)
#endregion

#region debug
func _me() -> int:
	return multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 0

func _dbg(msg: String) -> void:
	if not DEBUG: return
	print("[LEVEL/%d] %s" % [_me(), msg])

func debug_report() -> String:
	var loaded := "<нет>"
	if get_tree().current_scene:
		loaded = get_tree().current_scene.scene_file_path

	if multiplayer.is_server():
		return "epoch=%d загружено=%s peers=%s equipped=%s" % [
			epoch, loaded, str(_peers), str(_equipped)]
	# У клиента серверные поля не печатаем вовсе, чтобы пустые списки
	# не читались как "состав потерялся".
	return "epoch=%d загружено=%s (peers/equipped - серверные, тут пусто всегда)" % [
		epoch, loaded]
#endregion
