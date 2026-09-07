extends Camera3D
## Класс для наблюдения за живыми игроками. Живет локально.
class_name SpectateMode

## Насколько позади игрока
@export var distance_back: float = 2.0
## Насколько выше игрока
@export var height_offset: float = 1.0
## Скорость доворота 0 = мгновенно
@export var look_smoothing: float = 8.0

var _alive_players: Array[Node3D] = []
var _target_player: Node3D = null
var _target_index: int = -1

var orbit_yaw: float = 0.0
## Радиана. Наклон сверху
var orbit_pitch: float = 0.4

func _ready() -> void:
	current = false

## Начало наблюдения. Просчет направление и вектора камеры.
func start_spectating(alive: Array[Node3D]) -> void:
	_alive_players = alive.filter(func(p): return is_instance_valid(p))
	if _alive_players.is_empty():
		print("[DEBUG SPECTATE] Alive players list is empty! Camera is not active.")
		return

	# print("[SPECTATE-CHECK] print active players: ", _alive_players)

	_target_index = 0
	_target_player = _alive_players[0]
	current = true
	_snap_to_target()

func stop_spectating() -> void:
	current = false
	_target_player = null

func _process(delta: float) -> void:
	if not current or _target_player == null or not is_instance_valid(_target_player):
		push_error("[DEBUG] target player: ", _target_player, ". CURRENT: ", current, ". IS_INSTANCE_VALID: ", is_instance_valid(_target_player))
		return
	_follow_target(delta)
	# print("[Spectate DEBUG] Position spectate camera: ")

func _follow_target(delta: float) -> void:
	# var desired_pos := _calc_desired_position()
	var desired_pos := _calc_desired_mobiled_position()
	global_position = desired_pos

	print("[DEBUG-SPECTATE] Target player: ", _target_player)

	var look_target := _target_player.global_position + Vector3.UP
	if look_smoothing > 0.0:
		var current_basis := global_transform.basis
		var t := Transform3D(current_basis, global_position).looking_at(look_target, Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(t.basis, look_smoothing * delta)
		# print("[DEBUG-SPECTATE] global transform camera: ", global_transform.basis)
	else:
		look_at(look_target, Vector3.UP)
		# print("look_at: ", look_target, Vector3.UP)
	pass

## Просчет подвижной камеры
func _calc_desired_mobiled_position() -> Vector3:
	var offset := Vector3(0, 0, distance_back).rotated(Vector3.RIGHT, orbit_pitch).rotated(Vector3.UP, orbit_yaw)
	return _target_player.global_position + Vector3.UP * height_offset + offset

## Просчет статичной камеры
func _calc_desired_position() -> Vector3:
	var player_forward: Vector3 = -_target_player.global_transform.basis.z.normalized()
	# Vector3(Позиция игрока, - направление взгляда натянутое на оффсет (distance_back), 
	# Растягиваем единичный вектор высоты камеры)
	return _target_player.global_position \
		- player_forward * distance_back \
		+ Vector3.UP * height_offset

func _snap_to_target() -> void:
	# global_position = _calc_desired_position()
	global_position = _calc_desired_mobiled_position()
	look_at(_target_player.global_position + Vector3.UP * 1.0, Vector3.UP)
	# print("[SPECTATEMODE] Просчитали позицию камеры (в отладке не полная, считается через look_at): ", global_position)

func _unhandled_input(event: InputEvent) -> void:
	if not current: return
	if event is InputEventMouseMotion:
		orbit_yaw -= event.relative.x * 0.005
		orbit_pitch = clamp(orbit_pitch - event.relative.y * 0.005, -1.2, 1.2)