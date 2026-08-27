extends Node

signal hover_target_changed(target: Node)	# Навел рейкаст на предмет
signal item_grabbed(item: Node, by_peer: int)	# Хоcт подтвердил захват
signal item_dropped(item: Node)
signal local_player_spawned(player: Node)

# Сигнал на будущее если нужна будет подсказка к нажатию на кнопку
signal prompt_changed(text: String)
