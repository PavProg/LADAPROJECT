extends Node3D

@onready var actor: CharacterBody3D = get_parent()        # сам юнит получающий урон
@onready var damage_label: Label3D = $"../DamageLabel"
@onready var timer: Timer = $"../TakeDamageTimer"
@export var take_damage_recovery_time: float = 0.3   # секунд «неуязвимости» между ударами
@export var speed_damage_scale: float = 0.2          # множитель перевода скорости удара в урон (20%)
@export var max_damage_allowed: int = 100            # ограничение максимального урона

var can_be_hitted: bool = true                       # можно ли ударить прямо сейчас (только на сервере)


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	pass
	
	
func take_damage(dmg: int) -> void:
	print("DAMAGE_COMPONENT -- take_damage -- ")
	if not multiplayer.is_server(): return
	
	# Урон не может превысить остаток ХП
	var final_damage: int = clampi(dmg, 0, actor.data.health)
	
	if final_damage == 0: return
	actor.data.health -= final_damage
	# вклчюаение метки + ее задание урона
	toggle_damage_label(final_damage)


	# ХП кончилось — разрушаемся
	if actor.data.health <= 0:
		# TODO Смерть
		pass
	pass



# включить и анимировать damage label
func toggle_damage_label(damage: int) -> void:
	damage_label.text = str(damage)
	damage_label.scale = Vector3.ZERO
	damage_label.modulate = Color.WHITE 
	damage_label.visible = true
	
	# Создаем твин от имени damage_label
	var tween = damage_label.create_tween()
	
	# Устанавливает тип перехода
	tween.set_trans(Tween.TRANS_CUBIC)
	#tween.set_ease(Tween.EASE_OUT)
	
	# Плавный взлет вверх
	#var target_y = damage_label.position.y + 1.5
	#tween.tween_property(damage_label, "position:y", target_y, 1.0)
	
	# Пульсация размера
	tween.parallel().tween_property(damage_label, "scale", Vector3(1.2, 1.2, 1.2), 3.0)
	tween.tween_property(damage_label, "modulate:a", 0.0, 1.0)
	
	tween.tween_callback(func(): damage_label.visible = false)
	pass


func _on_hurtbox_body_entered(body: Node3D) -> void:
	#print("DAMAGE_COMPONENT -- Damage area entered")
	var other_body := body
	if other_body == null: return
	if other_body is not RigidBody3D or !other_body.is_in_group("item"): return
	#print("DAMAGE_COMPONENT -- is RigidBody3D")
	

	var other_velocity_length = other_body.linear_velocity.length()
	var other_body_damage = other_body.item_data.damage
	
	var self_velocity_length = 0.9 if actor.velocity.length() == 0 else actor.velocity.length()
	var overall_velocity_length: float = self_velocity_length * other_velocity_length
	var velocity_threshold = actor.data.velocity_length_threshold
	
	#print("actor.velocity            : ", actor.velocity)
	#print("other_body.linear_velocity: ", other_body.linear_velocity)
	#print("DAMAGE_COMPONENT -- CHECK VELOCITY")
	#print("overall_velocity: ", actor.velocity * other_body.linear_velocity)
	if overall_velocity_length <= velocity_threshold: return
	
	# в данном случае это тот урон который базово получает объект при столкновениях с полом(у хрупких больше, у крепких меньше)
	var base_damage: int = other_body_damage
	# считаем урон с применением velocity (скорости удара)
	var actual_damage: int = clampi(
		int(base_damage * overall_velocity_length * speed_damage_scale),
		base_damage,
		max_damage_allowed
	)
	print("BREAK_COMPONENT -- Actual damage: %d" % actual_damage)

	take_damage(actual_damage)
	pass
