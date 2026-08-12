extends Node3D

# BreakComponent — часть РАЗРУШАЕМОГО предмета
# Сеть: вся логика — ТОЛЬКО на сервере. Клиенты ничего не считают: предмет им
# приходит по репликации, а его удаление и осколки — по команде сервера.
# Так у всех пиров одинаковые прочность, квота и момент разрушения.

@onready var item: RigidBody3D = get_parent()        # сам разрушаемый предмет
@onready var timer: Timer = $"../TakeDamageTimer"

@export var take_damage_recovery_time: float = 0.2   # секунд «неуязвимости» между ударами
var can_be_hitted: bool = true                       # можно ли ударить прямо сейчас (только на сервере)


# Вызывается AttackComponent оружия. На всякий продублировал чтобы прям точно
func take_damage(dmg: int) -> void:
	if not multiplayer.is_server():
		return
	if not can_be_hitted:
		return

	# Урон не может превысить остаток прочности
	var final_damage: int = clampi(dmg, 0, item.item_data.durability)
	item.item_data.durability -= final_damage
	print("BREAK_COMPONENT -- %s HP: %d, income DMG: %d"
		% [item.name, item.item_data.durability, final_damage])

	# Начисляем квоту. GameManager на сервере сам разошлёт новое значение всем.
	GameManager.on_quote_earned(final_damage)

	# Прочность кончилась — разрушаемся
	if item.item_data.durability <= 0:
		_destroy()
		return

	# Иначе — "неуязвимость" на take_damage_recovery_time секунд.
	can_be_hitted = false
	timer.stop()
	timer.wait_time = take_damage_recovery_time
	timer.start()


func _on_take_damage_timer_timeout() -> void:
	# Таймер тикает там же, где стартовал — на сервере.
	can_be_hitted = true


# Решение принял сервер осколки должны появиться У ВСЕХ, а сам предмет — исчезнуть у всех.
func _destroy() -> void:
	# Путь к сцене осколков
	var fragments_path := ""
	if item.item_data.distructed_scene != null:
		fragments_path = item.item_data.distructed_scene.resource_path

	# Просим GameManager разослать осколки всем пирам
	GameManager.broadcast_break_fx(fragments_path, item.global_transform)

	# Сервер удаляет сам предмет. тк предмет заспавнен MultiplayerSpawner,
	# удаление на сервере автоматически деспавнит его у всех клиентов.
	item.queue_free()
