extends Node

const HUB := "res://levels/hub/TestHub.tscn"
const RUNS := [
	"res://levels/run_XX/run_test.tscn"
]

var current_scene_path: String = ""
var _run_index: int = -1
var _content_spawned: bool = false

# PEERS
func _ready() -> void:
	multiplayer.peer_connected.connect(_on_connected_peer)
	multiplayer.peer_disconnected.connect(_on_disconnected_peer)
	
func _on_connected_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if current_scene_path != "":
		change_scene.rpc_id(peer_id, current_scene_path)

func _on_disconnected_peer(peer_id: int ) -> void:
	if not multiplayer.is_server(): return
	Net.server_dispawn_player(peer_id)

# СМЕНА УРОВНЕЙ И ХАБ
# СЕРВАК

func go_to_hub() -> void:
	if not multiplayer.is_server():
		return
	_run_index = -1
	_load(HUB)

# Функция заглушка, чтобы релоуднуть хаб и клиент двигался
func reload_hub() -> void:
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
	if GameManager.current_state != GameManager.quote_states.FINISHED:
		return
	GameManager.on_level_end()
	_run_index += 1
	if _run_index >= RUNS.size():
		go_to_hub()
	else:
		_load(RUNS[_run_index])

# СМЕНА СЦЕНЫ
func _load(path: String) -> void:
	current_scene_path = path
	_content_spawned = false
	Net.clear_spawned()
	change_scene.rpc(path)
	
@rpc("authority","call_local", "reliable")
func change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
	
	# Гоняем цикл пока ВСЕ не будет загружено на уровень
	while get_tree().current_scene == null or get_tree().current_scene.scene_file_path != path:
		await get_tree().process_frame
		print("ЗАГРУЗКА...")	# Можно вывести как экран загрузки
	await get_tree().process_frame
	
	_ack_ready.rpc_id(1, multiplayer.get_unique_id())
	

# СПАВНЫ СУЩНОСТЕЙ
@rpc("any_peer", "call_local", "reliable")
func _ack_ready(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
		
	print("Сервер получил готовность от peer_id: ", peer_id)
		
	if peer_id == 1 and not _content_spawned:
		_content_spawned = true
		if _run_index >= 0:
			Net.spawn_content()
			print("Предметы заспавнены!!")
		GameManager.on_level_start(GameManager.required_quote_next_level)
	
	Net.server_spawn_player(peer_id) # Спавним вручную, без PlayerSpawner.
	if _run_index >= 0 and peer_id != 1:
		Net.send_items_to(peer_id)   # догнать клиента уже заспавненными предметами уровня
	print("Игрок с пиром ", peer_id, " заспавнен!")
