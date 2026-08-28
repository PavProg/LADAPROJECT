extends Node3D
# AttackComponent
# Что делает: ловит момент, когда хитбокс оружия (HitArea) вошёл в хартбокс
# разрушаемого предмета, считает урон и передаёт его в BreakComponent цели.
# Чего тут нет: собственной прочности, кулдауна и разрушения — всё это
# теперь ответственность BreakComponent (принимающей стороны).
# Сеть: урон считает и применяет ТОЛЬКО сервер. У клиентов физика оружия заморожена, linear_velocity ломается,
# поэтому их локальные удары надо игнорировать — иначе снова рассинхрон.

# Множитель перевода скорости удара в урон
@export var speed_damage_scale: float = 0.2 # (20%)
# Верхняя граница урона за удар
@onready var item: RigidBody3D = get_parent()


# Сигнал area_entered от HitArea (подключён в сцене оружия).
func _on_hit_area_area_entered(area: Area3D) -> void:
	# Только сервер имеет право наносить урон.
	if not multiplayer.is_server(): return
	
	# area — это HurtArea цели; её родитель — разрушаемый предмет (RigidBody3D).
	var target := area.get_parent()
	if target == null: return
	
	# Ищем на цели BreakComponent
	var break_comp = target.get_node_or_null("BreakComponent")
	if break_comp == null: break_comp = target.get_node_or_null("") # TODO
	if break_comp == null: return
	
	# Базовый урон оружия из его ItemData, усиленный текущей скоростью удара.
	var base_damage: int = item.item_data.damage
	
	break_comp.take_damage(base_damage)
