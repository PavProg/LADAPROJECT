extends Node

signal hover_target_changed(target: Node)	# Навел рейкаст на предмет
signal item_grabbed(item: Node, by_peer: int)	# Хоcт подтвердил захват
signal item_dropped(item: Node)
signal local_player_spawned(player: Node) # игрок заспавнился
signal local_item_held_changed(item: Node) # состояние захвата предмета локально

signal player_died(player_id: int, spectate_mode: bool)


# Сигнал на будущее если нужна будет подсказка к нажатию на кнопку
signal prompt_changed(text: String)
