extends Node
class_name PriorityComponent
# Функция для расчета приоритета цели врага. Возвращает ноду игрока (за кем следует)

@export var fov_area: Area3D
@export var eye: Marker3D
@export var fov_degrees: float = 140.0
@export var scan_interval: float = 0.15 # интервал сканирования
## Порог срабатывания для смены состояний (гистерезис)
@export var lose_multiplier: float = 1.4

## Два поля ниже для расчета приоритета. Враг оценивает у кого value предмета больше и до кого меньше топать
@export var value_weight: float = 1.0
@export var distance_weight: float = 1.0

## Не дает метаться врагам с около одинаковым счетом
@export var bonus: float = 25.0

var current_target: Node3D = null
var last_known_position: Vector3 = Vector3.ZERO
var has_last_known: bool = false

var _enemy : Enemy
var _candidates: Array[Node3D] = []
var _timer: float = 0.0
var _cos_half_fov: float

func _ready() -> void:
	_enemy = get_parent() as Enemy
	if not multiplayer.is_server():
		set_process(false)
		return
	_cos_half_fov = cos(deg_to_rad(fov_degrees * 0.5))	# Расчет половины от угла обзора
	if fov_area:
		fov_area.body_entered.connect(_on_body_entered)
		fov_area.body_exited.connect(_on_body_exited)
		
func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and not _candidates.has(body):
		_candidates.append(body)
		print("[FOV] Игрок вошел в зону видимости врага")

func _on_body_exited(body: Node3D) -> void:
	_candidates.erase(body)
	print("[FOV] Игрок вышел из зоны видимости врага")

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0: return
	_timer = scan_interval
	_rescan()
	
func _rescan() -> void:
	print("[PRIORITY] Поиск игроков")
	var best: Node3D = null
	var best_score := -INF
	var detect: float = _enemy.data.radius_detection
	var lose: float = detect * lose_multiplier
	
	for p in _candidates:
		if not is_instance_valid(p): continue
		
		var to: Vector3 = p.global_position - _enemy.global_position
		var dist_sq: float = to.length_squared()	# вычисляем произведение  векторов (кратчайший путь)
		var limit: float = lose if p == current_target else detect

		if dist_sq > limit * limit: continue
		if not _in_fov(to): continue
		if not _has_los(p): continue
		
		var score: float = _score(p, sqrt(dist_sq))
		if score > best_score:
			best_score = score
			best = p
	
	if best == null and current_target != null and is_instance_valid(current_target):
		print("[PRIORITY/SEARCH-STATE] Игрок ушел из виду, враг запомнил позицию и цель!")
		last_known_position = current_target.global_position
		has_last_known = true
	current_target = best
	if current_target != null:
		print("[PRIORITY] Приоритетный игрок найден: ", current_target)

## Алгоритм вычисления нахождения игрока в поле зрения
func _in_fov(to: Vector3) -> bool:
	var forward : Vector3 = -_enemy.global_transform.basis.z
	var flat: Vector3 = Vector3(to.x, 0.0, to.z).normalized()
	return forward.dot(flat) >= _cos_half_fov

func _has_los(p: Node3D) -> bool:
	#if eye == null:
		#print("[PRIORITY] Нода глаза (маркер) не найден, взята заглушка")
	var from: Vector3 = eye.global_position if eye else _enemy.global_position + Vector3.UP
	var space := _enemy.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, p.global_position + Vector3.UP)
	q.collision_mask = 1
	q.exclude = [_enemy.get_rid()]
	return space.intersect_ray(q).is_empty()

func _score(p: Node3D, dist: float) -> float:
	var peer: int = str(p.name).to_int()
	var s: float = ThreadsRegistry.value_by(peer) * value_weight - dist * distance_weight
	if p == current_target:
		s += bonus
	return s

func clear_target() -> void:
	current_target = null
	has_last_known = false
