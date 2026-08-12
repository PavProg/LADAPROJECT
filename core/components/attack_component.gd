extends Node3D
# AttackComponent
# Что делает: ловит момент, когда хитбокс оружия (HitArea) вошёл в хартбокс
# разрушаемого предмета, считает урон и передаёт его в BreakComponent цели.
# Чего тут нет: собственной прочности, кулдауна и разрушения — всё это
# теперь ответственность BreakComponent (принимающей стороны).
# Сеть: урон считает и применяет ТОЛЬКО сервер. У клиентов физика оружия заморожена, linear_velocity ломается,
# поэтому их локальные удары надо игнорировать — иначе снова рассинхрон.

# Множитель перевода скорости удара в урон
@export var speed_damage_scale: float = 0.2
# Верхняя граница урона за удар
@export var max_hit_damage: int = 100
@onready var item: RigidBody3D = get_parent()


# Сигнал area_entered от HitArea (подключён в сцене оружия).
func _on_hit_area_area_entered(area: Area3D) -> void:
	# Только сервер имеет право наносить урон.
	if not multiplayer.is_server():
		return

	# area — это HurtArea цели; её родитель — разрушаемый предмет (RigidBody3D).
	var target := area.get_parent()
	if target == null:
		return

	# Ищем на цели хартбокс
	var break_comp := target.get_node_or_null("BreakComponent")
	if break_comp == null:
		return

	# Базовый урон оружия из его ItemData, усиленный текущей скоростью удара.
	var base: int = item.item_data.damage
	var damage: int = clampi(
		int(base * item.linear_velocity.length() * speed_damage_scale),
		base,
		max_hit_damage
	)
	break_comp.take_damage(damage)
