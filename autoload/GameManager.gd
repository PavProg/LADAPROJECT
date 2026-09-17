extends Node

var died_players: Array[int] = []

## квота которую нужно набрать за ТЕКУЩИЙ уровень
var required_quote: int = 0
## квота которую нужно набрать за СЛЕДУЮЩИЙ уровень
var required_quote_next_level: int = 20 # на первом уровне
## квота на текущий момент в уровне || сбрасывается в 0 каждый уровень
var current_quote: int = 0
## квота, которую игроки могут тратить в хабе
var earned_quote: int = 0
## текущее состояние квоты
var current_state: quote_states = quote_states.PROCESS
## enum для состояний квоты (в процессе сбора или уже собрали)
enum quote_states {
	FINISHED,
	PROCESS
}
## процент на который увеличивается quote между уровнями
var quote_raising: float = 20.0 # 20%

# ВАЖНО ПРО СЕТЬ.
# GameManager — это autoload, а значит у КАЖДОГО пира (хоста и всех клиентов)
# он свой, отдельный. Раньше квоту менял каждый пир сам у себя из компонентов —
# отсюда и был рассинхрон: у всех получались разные числа.
#
# Теперь правило простое:
#   менять current_quote имеет право ТОЛЬКО сервер (хост);
#   после изменения сервер рассылает готовое число всем через RPC _sync_quote();
#   клиенты ничего не считают сами — только принимают присланное значение.
# Так у всех пиров всегда одна и та же квота.


# Точка входа для начисления квоты. Её вызывает BreakComponent — и только на сервере
func on_quote_earned(quote: int, earner_peer_id: int = 0) -> void:
	if not multiplayer.is_server():
		return
	current_quote += quote
	if current_quote >= required_quote:
		current_state = quote_states.FINISHED
	# Рассылаем актуальную квоту ВСЕМ пирам (call_local => и самому серверу тоже).
	_sync_quote.rpc(current_quote, current_state, required_quote)
	# Отдельная рассылка для UI попапа (всем, с инфо об источнике)
	_notify_quota_earned.rpc(quote, earner_peer_id)

# Выполняется у ВСЕХ пиров. Отправить может только авторитет автолоада (сервер, id 1).
# Клиенты просто присваивают присланные значения.
@rpc("authority", "call_local", "reliable")
func _sync_quote(value: int, state: int, req: int) -> void:
	current_quote = value
	current_state = state as quote_states
	required_quote = req
	# Отладка
	#print("QUOTE sync -> peer %d: current=%d / required=%d"
		#% [multiplayer.get_unique_id(), current_quote, required_quote])

# Вызывается из main.gd на КАЖДОМ пире => старт детерминирован и одинаков у всех — отдельный RPC тут не нужен.
func on_level_start(new_req_quote: int) -> void:
	current_state = quote_states.PROCESS
	current_quote = 0
	#print("required_quote = new_req_quote: ", new_req_quote)
	required_quote = new_req_quote

# Итоги уровня. Считает сервер 
# следующую квоту тоже нцжно рассылать клиентам
func on_level_end() -> void:
	earned_quote += max(current_quote - required_quote, 0) # к остатку с прошлого уровня добавляем разницу текущего уровня
	required_quote_next_level = int(required_quote * (1.0 + quote_raising))


# Осколки. в будующем можно закинуть в FX autoload.
# Суть в том что узел предмета удаляется в BreakComponent значит пакет уйдет в пустоту

func broadcast_break_fx(fragments_scene_path: String, xform: Transform3D) -> void:
	if not multiplayer.is_server():
		return
	# Общий seed => одинаковый начальный разлёт осколков на всех машинах.
	_break_fx.rpc(fragments_scene_path, xform, randi())

@rpc("authority", "call_local", "reliable")
func _break_fx(fragments_scene_path: String, xform: Transform3D, fx_seed: int) -> void:
	if fragments_scene_path.is_empty():
		return
	var packed: PackedScene = load(fragments_scene_path)
	if packed == null:
		return
	var fragments := packed.instantiate()
	fragments.global_transform = xform
	# Осколки кладём в корень текущей сцены — этот узел есть у всех пиров.
	# Осколки чисто визуальные, по сети не реплицируются (их физика может слегка
	# разойтись между машинами со временем, не критично).
	get_tree().current_scene.add_child(fragments)

	var rng := RandomNumberGenerator.new()
	rng.seed = fx_seed
	for child in fragments.get_children():
		if child is RigidBody3D:
			#print("[ГЕЙ МЕНЕДЖЕР] Нода осколка: ", child)
			child.apply_central_impulse(Vector3(
				rng.randf_range(-3, 3),
				rng.randf_range(-1, 3),
				rng.randf_range(-3, 3)))

signal quota_earned(amount: int, earner_peer_id: int)

@rpc("authority", "call_local", "reliable")
func _notify_quota_earned(amount: int, earner_peer_id: int) -> void:
	# print("Notifying quota earned, quota| amount = " + str(amount) + ", earner_peer_id = " + str(earner_peer_id))
	quota_earned.emit(amount, earner_peer_id)
