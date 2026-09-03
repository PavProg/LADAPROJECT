extends Node
class_name EnemyAttackComponent

#region поля
## Хитбокс врага
@export var hitbox: Area3D
## Насколько блокируется анимация во время атаки
@export var anim_lock: float = 0.0
## Делей атаки
@export var damage_delay: float = 0.6

var _enemy: Enemy
var _cd_left: float = 0.0
## < 0 -> удара в очереди нет
var _pending: float = -1.0

#endregion

#region Функции
func _ready() -> void:
	_enemy = get_parent() as Enemy
	if not multiplayer.is_server():
		set_process(false)
		return

func _process(delta: float) -> void:
	_cd_left = maxf(0.0, _cd_left - delta)

	# Отложенный удар
	if _pending >= 0.0:
		_pending -= delta
		if _pending <= 0.0:
			_pending = -1.0
			_deal_damage()

func _can_attack() -> bool:
	return _cd_left <= 0.0 and not _enemy.is_ragdolled()

func _start_attack() -> void:
	if not multiplayer.is_server(): return
	if not _can_attack(): return

	#print("[ATTACK-COMPONENT] Атака началась!")
	_cd_left = _enemy.data.cooldown_attack
	_pending = damage_delay
	_enemy.play_anim(_enemy.ANIM_ATTACK, false)
	_enemy._lock_anim(anim_lock)

## Наносим урон. Смотрим чужой хартбокс
func _deal_damage() -> void:
	if hitbox == null:
		return

	for area in hitbox.get_overlapping_areas():
		var body := area.get_parent()
		if body and body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(_enemy.data.damage_attack)
			#print("[ATTACK-COMPONENT] Вызвал функцию получения дамага!")


#endregion
