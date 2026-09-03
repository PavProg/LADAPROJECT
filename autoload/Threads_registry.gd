extends Node
# Синглтон который отвечает за реестр взятых предметов. Необходмо для БТ и расстановки приоритетов
# Берет сигнал взятия предмета и помещает в словарь item: by_peer

var _taken: Dictionary = {}

func _ready() -> void:
	Events.item_grabbed.connect(_on_grabbed)
	Events.item_dropped.connect(_on_dropped)
	
func _on_grabbed(item: Node, by_peer: int) -> void:
	if not multiplayer.is_server():
		print("[REGISTRY WARNING] Взятый предмет не добавился в реестр")
		return
	_taken[by_peer] = item
	#print("[REGISTRY TEST] Взят предмет: ", by_peer, " - ", item)
	
func _on_dropped(item: Node) -> void:
	if not multiplayer.is_server():
		print("[REGISTRY WARNING] Упавший предмет не учтен в реестре")
		return
	for peer in _taken.keys():
		if _taken[peer] == item:
			_taken.erase(peer)
			#print("[REGISTRY TEST] Удален предмет: ", peer, " - ", item)
			return

## Функция возвращающая value предмета (Синглтон Threads_registry).
func value_by(peer: int) -> int:
	var item = _taken.get(peer)
	# or, а не and: у освобождённого объекта item == null даёт false,
	# и со связкой and мы проваливались в обращение к мёртвой ссылке.
	if item == null or not is_instance_valid(item):
		return 0
	return item.item_data.value
