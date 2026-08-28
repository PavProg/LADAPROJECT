extends Node3D

# BreakComponent — часть РАЗРУШАЕМОГО предмета
# Сеть: вся логика — ТОЛЬКО на сервере. Клиенты ничего не считают: предмет им
# приходит по репликации, а его удаление и осколки — по команде сервера.
# Так у всех пиров одинаковые прочность, квота и момент разрушения.

@onready var item: RigidBody3D = get_parent()        # сам разрушаемый предмет
@onready var timer: Timer = $"../TakeDamageTimer"

@export var take_damage_recovery_time: float = 0.3   # секунд «неуязвимости» между ударами
@export var speed_damage_scale: float = 0.4          # множитель перевода скорости удара в урон (20%)
@export var max_damage_allowed: int = 100            # ограничение максимального урона
var can_be_hitted: bool = true                       # можно ли ударить прямо сейчас (только на сервере)


# Вызывается AttackComponent оружия. На всякий продублировал чтобы прям точно
func take_damage(dmg: int) -> void:
	#print("BREAK_COMPONENT -- take_damage -- ")
	if not multiplayer.is_server(): return
	if not can_be_hitted: return

	# Урон не может превысить остаток прочности
	var final_damage: int = clampi(dmg, 0, item.item_data.durability)
	
	if final_damage <= 0: return
	item.item_data.durability -= final_damage
	# вклчюаение метки + ее задание урона
	item.toggle_damage_label(final_damage)

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
	if item.item_data.id != null:
		Net.despawn_item(item.name)
	else:
		print("Не вышло найти id предмета")
		

# вызывается когда объект сталкивается с объектом уровня(статичное). Нужен так как _on_hurt_area_area_entered отслеживает только Area3D, но никак не StaticBody3D
func _on_hurt_area_body_entered(body: Node3D) -> void:
	#print("BREAK_COMPONENT -- Damage area entered")
	var other_body := body
	if other_body == null: return
	#print("BREAK_COMPONENT -- other_body NOT null")

	var other_velocity_length: float
	var other_body_damage: float
	var self_damage: float = item.item_data.damage

	if other_body is GridMap or other_body is StaticBody3D:
		#print("StaticBody3D damaging")
		other_velocity_length = 1.0
		other_body_damage = 0.0

	if other_body is CharacterBody3D:
		#print("CharacterBody3D damaging")
		other_velocity_length = other_body.velocity.length()
		other_body_damage = 0.0
	
	if other_body is RigidBody3D and other_body.is_in_group("item"):
		#print("RigidBody3D damaging")
		other_velocity_length = other_body.linear_velocity.length()
		other_body_damage = other_body.item_data.damage
	
	# только велосити нашего объекта тк другой объект статичен
	var self_velocity_length = item.linear_velocity.length()
	var overall_velocity_length: float = self_velocity_length * other_velocity_length
	var velocity_threshold = item.item_data.velocity_length_threshold
	
	if overall_velocity_length <= velocity_threshold: return
	
	# в данном случае это тот урон который базово получает объект при столкновениях с полом(у хрупких больше, у крепких меньше)
	var base_damage: int = self_damage + other_body_damage
	print(base_damage)
	# считаем урон с применением velocity (скорости удара)
	var actual_damage: int = clampi(
		int(base_damage * overall_velocity_length * speed_damage_scale),
		base_damage,
		max_damage_allowed
	)
	#print("BREAK_COMPONENT -- Actual damage: %d" % actual_damage)

	take_damage(actual_damage)
	pass
