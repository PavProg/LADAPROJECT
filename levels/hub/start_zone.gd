extends Area3D

# Список пиров внутри
var _inside: Array[int] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	
	var peer := str(body.name).to_int()
	if not _inside.has(peer):
		_inside.append(peer)
	
	# Эмитим сигнал что кто-то вошел в зону. Для возможной подсказки игроку
	#if body.is_multiplayer_authority():
		#Events.prompt_changed.emit("E - начать забег")

func _on_body_exited(body: Node):
	if not body.is_in_group("player"):
		return
	
	_inside.erase(str(body.name).to_int())
	#if body.is_multiplayer_authority():
		#Events.prompt_changed.emit(" ")
	
func has_peer(peer: int) -> bool:
	return _inside.has(peer)

func count_inside() -> void:
	return _inside.size()
