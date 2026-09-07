extends Node

@export var tutorial_area: Area3D

const TUTORIAL_DIALOGUES = preload("uid://c32shbbuvlgtu")

func _ready() -> void:
	if tutorial_area == null:
		return
	# Подключаем сигналы входа
	tutorial_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	# Проверяем, что вошедший объект — игрок
	if body.is_in_group("player"):
		# Если мы на сервере — отправляем RPC всем клиентам
		if multiplayer.is_server():
			var player = body
			var peer_id := player.get_multiplayer_authority()
			_notify_zone_entered.rpc(peer_id)  # RPC на все клиенты (включая сервер через call_local)



@rpc("any_peer", "call_local", "reliable")
func _notify_zone_entered(peer_id: int) -> void:
	
	# Этот код выполнится у всех клиентов (и на сервере)
	print("Игрок ", peer_id, " вошел в зону")
	# Здесь можно показать UI, запустить обучение и т.д.
	var dialogues : TutorialDialogues = TUTORIAL_DIALOGUES.instantiate()
	#print("DEBUG", get_tree().current_scene)
	get_tree().current_scene.add_child(dialogues)
	dialogues.show_first_dialogue()
