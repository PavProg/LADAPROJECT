extends Node
## =====================================================================
## ТЕСТ ENET - ВРЕМЕННЫЙ БЛОК. Не нужен в релизе.
##
## КАК УДАЛИТЬ ЦЕЛИКОМ:
##   1. Удалить этот файл (autoload/enet_test.gd + .uid)
##   2. Project Settings -> Globals -> Autoload: удалить строку EnetTest
##      (или в project.godot строку EnetTest="*res://autoload/enet_test.gd")
##   Больше ничего в проекте от него не зависит.
##
## ЗАЧЕМ: несколько экземпляров игры на одном ПК через ENet вместо Steam
## (Steam не даст два клиента под одним аккаунтом).
##
## КЛАВИШИ (работают только в debug-сборке):
##   F1 - поднять ENet-хост и уйти в хаб
##   F2 - подключиться к 127.0.0.1
##   F6 - (только хост) сразу перейти на процедурный уровень, как через туалет хаба
##   F7 - печать сида и хеша планировки - сравнить в окнах всех пиров
##   F3/F4/F5 - отладка из Net (дамп, транспорт, замер трансформов)
##
## АВТОЗАПУСК ПО АРГУМЕНТАМ:
##   Debug -> Customize Run Instances -> Enable Multiple Instances, число 3.
##   Каждому включить Override Main Run Args:
##     первому  --server        (или --server --run - сразу на процедурный уровень, минуя хаб)
##     остальным --client
##
## Через консоль (двойное -- обязательно, иначе Godot съест аргументы):
##   godot --path <папка проекта> -- --server
##   godot --path <папка проекта> -- --client
## =====================================================================

const ENET_PORT := 7777
const ENET_MAX_CLIENTS := 4
const ENET_HOST_IP := "127.0.0.1"

func _ready() -> void:
	if not OS.is_debug_build():
		return
	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		_start_host.call_deferred()
		if "--run" in args:
			_auto_run()
	elif "--client" in args:
		_start_client.call_deferred()


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1: _start_host()
		KEY_F2: _start_client()
		KEY_F6: _skip_to_run()
		KEY_F7: _print_layout()


## Поднять сервер и увести всех в хаб - аналог кнопок Host + Start Game
func _start_host() -> void:
	if _has_live_peer():
		print("[ENET-TEST] F1 проигнорирован: это окно уже %s (id %d)"
			% ["ХОСТ" if multiplayer.is_server() else "клиент", multiplayer.get_unique_id()])
		return
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(ENET_PORT, ENET_MAX_CLIENTS)
	if err != OK:
		push_error("[ENET-TEST] сервер не поднялся: %s" % error_string(err))
		return
	multiplayer.multiplayer_peer = p
	GameManager.required_quote_next_level = GameManager.base_quote
	Net.is_peer_active = false
	print("[ENET-TEST] хост на порту %d" % ENET_PORT)
	LevelManager.go_to_hub()


## Подключиться к локальному хосту. Сцену пришлёт сервер (_on_connected_peer)
func _start_client() -> void:
	if _has_live_peer():
		print("[ENET-TEST] F2 проигнорирован: это окно уже %s (id %d). Жми F2 в ДРУГОМ экземпляре игры"
			% ["ХОСТ" if multiplayer.is_server() else "клиент", multiplayer.get_unique_id()])
		return
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(ENET_HOST_IP, ENET_PORT)
	if err != OK:
		push_error("[ENET-TEST] клиент не создан: %s" % error_string(err))
		return
	multiplayer.multiplayer_peer = p
	Net.is_peer_active = false
	print("[ENET-TEST] подключаемся к %s:%d" % [ENET_HOST_IP, ENET_PORT])


## Хост: перейти на следующий уровень (из хаба это процедурный RUNS[0])
func _skip_to_run() -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		print("[ENET-TEST] F6 работает только на хосте")
		return
	LevelManager.next_level()


## --run: дождаться загрузки хаба и сразу уйти на уровень.
## Клиенты, подключившиеся позже, получат уровень с тем же сидом - заодно проверка позднего входа
func _auto_run() -> void:
	while get_tree().current_scene == null \
			or get_tree().current_scene.scene_file_path != LevelManager.HUB:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	_skip_to_run()


## Сид и хеш планировки на этом пире - должны совпадать во всех окнах
func _print_layout() -> void:
	var gen := get_tree().get_first_node_in_group("level_generator")
	if gen == null:
		print("[ENET-TEST] генератора в сцене нет (это не процедурный уровень)")
		return
	print("[ENET-TEST] пир %d: seed=%d hash=%d"
		% [multiplayer.get_unique_id(), LevelManager.level_seed, gen._layout_hash()])


## Настоящий сетевой пир уже есть. OfflineMultiplayerPeer по умолчанию не считается
func _has_live_peer() -> bool:
	var p := multiplayer.multiplayer_peer
	return p != null and not (p is OfflineMultiplayerPeer) \
		and p.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED
