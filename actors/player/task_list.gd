extends Node
class_name TaskListManager

## словарь всех заданий с кратким названием задания и его описанием для игрока
# { "task_name": "task_description" }
const main_tasks_pull: Dictionary = {
	"5_vases": 				"Break vases",
	"3_red_vases": 			"Break red vases",
	"3_green_vases": 		"Break green vases",
	"600_damage_vases": 	"Deal damage to vases",
	"500_damage_paintings": "Deal damage to paintings",
	"5_paintins":			"Break paintings",
	"PIG_vase": 			"Break PIG vase",
	"1000_damage_armor": 	"Deal damage to knight armor",
	"break_box": 			"Break box",
	"break_3_idol": 		"Break stone idols",
}
# описания заданий
const TASK_DEFS := {
	"5_vases": {
		"desc": "Break vases",
		"action": "object_destroyed",
		"filter": {"tag": "vase"},
		"mode": "count",
		"target": 5,
	},
	"3_red_vases": {
		"desc": "Break red vases",
		"action": "object_destroyed",
		"filter": {"tag": "vase", "color": "red"},
		"mode": "count",
		"target": 3,
	},
	"3_green_vases": {
		"desc": "Break green vases",
		"action": "object_destroyed",
		"filter": {"tag": "vase", "color": "green"},
		"mode": "count",
		"target": 3,
	},
	"600_damage_vases": {
		"desc": "Deal damage to vases",
		"action": "object_damaged",
		"filter": {"tag": "vase"},
		"mode": "sum",
		"value_key": "amount",
		"target": 600,
	},
	"500_damage_paintings": {
		"desc": "Deal damage to paintings",
		"action": "object_damaged",
		"filter": {"tag": "painting"},
		"mode": "sum",
		"value_key": "amount",
		"target": 500,
	},
	"5_paintins": {
		"desc": "Break paintings",
		"action": "object_destroyed",
		"filter": {"tag": "painting"},
		"mode": "count",
		"target": 5,
	},
	"PIG_vase": {
		"desc": "Break PIG vase",
		"action": "object_destroyed",
		"filter": {"tag": "pig"},
		"mode": "count",
		"target": 1,
	},
	"1000_damage_armor": {
		"desc": "Deal damage to knight armor",
		"action": "object_damaged",
		"filter": {"tag": "armor"},
		"mode": "sum",
		"value_key": "amount",
		"target": 1000,
	},
	"break_box": {
		"desc": "Break box",
		"action": "object_destroyed",
		"filter": {"tag": "box"},
		"mode": "count",
		"target": 1,
	},
	"break_3_idol": {
		"desc": "Break stone idols",
		"action": "object_destroyed",
		"filter": {"tag": "idol"},
		"mode": "count",
		"target": 3,
	},
}

var tasks: Dictionary = {}   # task_name -> task_desc
var progress: Dictionary = {}   # task_name -> текущее значение
var completed: Dictionary = {}  # task_name -> bool

var tasks_container: Container = null
var task_labels : Dictionary = {}

func _ready() -> void:
	if multiplayer.is_server():
		Events.object_destroyed.connect(on_task_event.bind("object_destroyed"))
		Events.object_damaged.connect(on_task_event.bind("object_damaged"))
	
	#call_deferred("_bind_container")
	pass
	
func _process(delta: float) -> void:
	pass
	
func _bind_container() -> void:
	print("Вызов _bind_container")
	var player := get_parent()

	if player == null:
		print("игрок не найден")
		return
	print(UiManager)
	print(UiManager.hud)
	tasks_container = UiManager.hud.find_child("TasksContainer", true, false) as Container
	
	print(tasks_container)
	
	if tasks_container == null:
		print("TaskManageer контейнер не найден")
	else:
		if not tasks.is_empty():
			print("Вызов rebuild_task_labels")
			rebuild_task_labels()
		else:
			print("пустой tasks")
			
## вызывается на старте уровня
# вызывает сервер только у себя
func load_tasks(ammount_of_tasks: int) -> void:
	if not multiplayer.is_server(): return
	tasks.clear()
	progress.clear()
	completed.clear()
	print("TASKS -- load_tasks")
	var main_dict = main_tasks_pull
	var keys = main_dict.keys()
	keys.shuffle()
	
	# столько раз сколько берем заданий на уровень
	for i in range(ammount_of_tasks):
		# из массива ключей достаем (ammount_of_tasks) имен тасок из разных частей массива
		var k = keys[i]
		# закидываем в массив тасок игрока нужные (ammount_of_tasks) рандомные
		tasks[k] = main_tasks_pull[k]
		pass
	print("TASKS -- generated: ", tasks.values())
	rebuild_task_labels()
	pass

# вызывается клиентом на сервере
@rpc("any_peer", "call_remote", "reliable")
func request_tasks() -> void:
	if not multiplayer.is_server(): return
	var request_peer = multiplayer.get_remote_sender_id()
	if request_peer == 0 or request_peer == 1: return
	print("TASKS -- request_tasks")
	
	var host_task_manager: TaskListManager = null
	for player in get_tree().get_nodes_in_group("player"):
		if player.is_multiplayer_authority():
			host_task_manager = player.get_node("TaskListManager")
			break

	if host_task_manager == null:
		push_error("TASKS -- host TaskListManager not found")
		return

	print(
		"TASKS -- server source tasks: ",
		host_task_manager.tasks.values()
	)
	# вызывается только у запросившего клиента
	sync_tasks.rpc_id(
		request_peer,
		host_task_manager.tasks.duplicate(),
		host_task_manager.progress.duplicate(),
		host_task_manager.completed.duplicate()
	)
	pass

# выполнится ТОЛЬКО у запросившего клиента
@rpc("any_peer", "call_remote", "reliable")
func sync_tasks(_tasks: Dictionary, _progress: Dictionary, _completed: Dictionary) -> void:
	if multiplayer.is_server(): return
	if multiplayer.get_remote_sender_id() != 1: return

	tasks = _tasks.duplicate()
	progress = _progress.duplicate()
	completed = _completed.duplicate()

	print("TASKS -- sync_tasks: ", tasks.keys())
	rebuild_task_labels()
	
func show_tasks() -> void:
	print("TASKS -- show_tasks")
	# TODO UI отображение заданий
	print("TASKS -- : ", tasks.values())
	pass
	
func hide_tasks() -> void:
	#print("tasks hided")
	# TODO UI убрать отображение заданий
	pass
	
# вызывается с сервера у сервера + клиентов
@rpc("authority", "call_local", "reliable")
func task_done(task_name: String) -> void:
	print("TASKS -- task_done: ", task_name)
	completed[task_name] = true
	# вычеркивание таски в UI
	# TODO UI вычеркивание в UI
	print("TASKS -- completed tasks: ", completed)
	pass


func on_task_event(payload: Dictionary, action_name: String) -> void:
	print("TASKS -- _on_event")
	# пробегаемся по всем задача на уровень
	for task_name in tasks.keys():
		if completed.get(task_name, false): continue
		var def: Dictionary = TASK_DEFS.get(task_name, {})
		if def.is_empty(): continue
		if def.get("action", "") != action_name: continue
		if not matches(payload, def.get("filter", {})): continue

		var cur: int = progress.get(task_name, 0)
		match def.get("mode", "count"):
			"count": cur += 1
			"sum":   cur += int(payload.get(def.get("value_key", ""), 0))

		_broadcast_progress(task_name, cur)

		if cur >= int(def.get("target", 0)):
			_broadcast_done(task_name)   # раздать всем и себе(серверу) что задание завершилось (нужно для UI)

# проверка что задание реально подходит по параметрам к тому что нужно выолпнить на уровне
func matches(payload: Dictionary, filter: Dictionary) -> bool:
	# перебор всех тэгов и цветов - если хоть что-то не воспало, то задание не подходит
	for k in filter:
		if payload.get(k) != filter[k]: return false
	return true

# сервер вызывает у всех кроме себя
@rpc("authority", "call_local", "reliable")
func task_progress_updated(task_name: String, value) -> void:
	progress[task_name] = value

#region Рассылка прогресса/готовности в собственные менеджеры клиентов

func _broadcast_progress(task_name: String, value: int) -> void:
	# свой (серверный) менеджер обновляем локально
	progress[task_name] = value
	_refresh_label(task_name)

	for player in get_tree().get_nodes_in_group("player"):
		if player.is_multiplayer_authority(): continue     # это серверный игрок, уже обновлён
		var tlm = player.get_node_or_null("TaskListManager")
		if tlm == null: continue
		var peer_id: int = player.get_multiplayer_authority()
		if peer_id <= 1: continue
		tlm._apply_progress.rpc_id(peer_id, task_name, value)

func _broadcast_done(task_name: String) -> void:
	completed[task_name] = true
	_refresh_label(task_name)

	for player in get_tree().get_nodes_in_group("player"):
		if player.is_multiplayer_authority(): continue
		var tlm = player.get_node_or_null("TaskListManager")
		if tlm == null: continue
		var peer_id: int = player.get_multiplayer_authority()
		if peer_id <= 1: continue
		tlm._apply_done.rpc_id(peer_id, task_name)

@rpc("any_peer", "call_remote", "reliable")
func _apply_progress(task_name: String, value: int) -> void:
	if multiplayer.get_remote_sender_id() != 1: return
	progress[task_name] = value
	_refresh_label(task_name)

@rpc("any_peer", "call_remote", "reliable")
func _apply_done(task_name: String) -> void:
	if multiplayer.get_remote_sender_id() != 1: return
	completed[task_name] = true
	_refresh_label(task_name)

#endregion

#region UI

## Собирает лейблы заново. Вызывается при получении/генерации списка заданий.
func rebuild_task_labels() -> void:
	if tasks_container == null:
		print("Пробуем привязать контейнер из ребилда")
		_bind_container()
	if tasks_container == null:
		print("Пошел нахуй")
		return

	print("Пересобираем контейнер тасок")
	# чистим старые
	for child in tasks_container.get_children():
		child.queue_free()
	task_labels.clear()

	print("task.keys() = ", tasks.keys())
	
	for task_name in tasks.keys():
		var lbl := Label.new()
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 35)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 10)
		tasks_container.add_child(lbl)
		task_labels[task_name] = lbl
		print(task_name)
		_refresh_label(task_name)

func _refresh_label(task_name: String) -> void:
	var lbl: Label = task_labels.get(task_name)
	if lbl == null: return

	var def: Dictionary = TASK_DEFS.get(task_name, {})
	var desc: String = tasks.get(task_name, "")
	var cur: int = int(progress.get(task_name, 0))
	var target: int = int(def.get("target", 0))
	var is_done: bool = completed.get(task_name, false)

	var line := desc
	if target > 1:
		line = "%s  (%d/%d)" % [desc, mini(cur, target), target]

	if is_done:
		lbl.text = "✓ " + line
		lbl.modulate = Color(0.55, 0.55, 0.55)
	else:
		lbl.text = line
		lbl.modulate = Color.WHITE

#endregion
