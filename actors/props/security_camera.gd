class_name SecurityCamera
extends Node3D

enum State { SWEEP, TRACK }

#region export VARS
## Дальность луча
@export var detect_range: float = 8.0
## Полный угол обзра, градусы
@export var fov_degrees: float = 50.0
## Насколько камера овторачивается в сторону от исходного направления
@export var sweep_angle: float = 45.0
## Скорость поворота рад/с (базовое значение 0.5 = 28 градусов в сек)
@export var sweep_speed: float = 0.5
## Скорость доворота за целью
@export var track_speed: float = 5.0
## Дальше этого угла камера не доворачивает
@export var max_track_angle: float = 80.0
## Высота точки прицеливания над ногами игрока
@export var aim_height: float = 0.4
## Интервал проверки игроков
@export var scan_interval: float = 0.1
## Интервал репорта для охранника
@export var report_interval: float = 0.3
## Сколько камера держит цель после потери из виду
@export var lose_grace: float = 1.0
## Шанс что камера останется на уровне. Для генератора rng
@export_range(0.0, 1.0) var spawn_chance: float = 1.0
## Прозрачность конуса обзора (0 = невидим, 1 = непрозрачный)
@export_range(0.0, 1.0) var cone_alpha: float = 0.2

@export var color_idle: Color = Color(1.0, 0.95, 0.8)
@export var color_alert: Color = Color(1.0, 0.15, 0.1)

@onready var pivot: Node3D = $Pivot
@onready var eye: Marker3D = $Pivot/Eye
@onready var light: SpotLight3D = $Pivot/SpotLight3D
@onready var cone: MeshInstance3D = $Pivot/Cone
@onready var sync: MultiplayerSynchronizer = $MultiplayerSynchronizer

#endregion

#region temp vars
var state: int = State.SWEEP:
	set(v):
		state = v
		if is_node_ready():
			_apply_visual()

var _target: Node3D = null
var _base_yaw: float = 0.0
var _base_pitch: float = 0.0
var _sweep_t: float = 0.0
var _scan_left: float = 0.0
var _report_left: float = 0.0
var _lost_for: float = 0.0
var _cos_half_for: float = 0.0
var _cone_mat: StandardMaterial3D

#endregion

#region физика

func _ready() -> void:
	add_to_group("security_camera")
	_base_yaw = pivot.rotation.y
	_base_pitch = pivot.rotation.x
	_cos_half_for = cos(deg_to_rad(fov_degrees * 0.5))
	_fit_light_and_cone()
	_apply_visual()
	if multiplayer.is_server():
		# Комната есть у сервера раньше чем клиенты ее построят
		sync.public_visibility = false
	else:
		set_physics_process(false)	# клиент только отображает
	pass

## Сервер. Открыть синк пиру у которого уровень уже построен
func open_sync_for(peer_id: int) -> void:
	sync.set_visibility_for(peer_id, true)

func _physics_process(delta: float) -> void:
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = scan_interval
		_scan()
	
	if state == State.TRACK and is_instance_valid(_target):
		_track(delta)
		_report_left -= delta
		if _report_left <= 0.0:
			_report_left = report_interval
			_report()
	else:
		_sweep(delta)

#endregion

#region СЛЕЖКА

## Ищет ближайшего видимого игрока
func _scan() -> void:
	var best: Node3D = null
	var best_d := INF
	for p in get_tree().get_nodes_in_group("player"):
		if not _can_see(p):
			continue
		var d := eye.global_position.distance_squared_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
		
	if best != null:
		if best != _target:
			_report_left = 0.0
		_target = best
		_lost_for = 0.0
		state  = State.TRACK
	elif state == State.TRACK:
		_lost_for += scan_interval
		if _lost_for >= lose_grace:
			_target = null
			state = State.SWEEP

func _can_see(p: Node3D) -> bool:
	if not is_instance_valid(p):
		return false
	
	if p.has_method("is_dead") and p.is_dead():
		return false
	var aim := p.global_position + Vector3.UP * aim_height
	var to := aim - eye.global_position
	if to.length_squared() > detect_range * detect_range:
		return false
	
	var forward := -pivot.global_transform.basis.z.normalized()
	if forward.dot(to.normalized()) < _cos_half_for:
		return false
	
	# Рэйкаст по миру, игроки и предметы не перекрывают
	var q := PhysicsRayQueryParameters3D.create(eye.global_position, aim)
	q.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	
## плавный осмотр. синус вокруг исходного направления
func _sweep(delta: float) -> void:
	_sweep_t += delta * sweep_speed
	var want_yaw := _base_yaw + sin(_sweep_t) * deg_to_rad(sweep_angle)
	pivot.rotation.y = lerp_angle(pivot.rotation.y, want_yaw, 3.0 * delta)
	pivot.rotation.x = lerp_angle(pivot.rotation.x, _base_pitch, 3.0 * delta)

#endregion

#region Обнаружение

## Слежение. Доворачиваем пивот на цель в пределах max_track_angle
func _track(delta: float) -> void:
	var aim := _target.global_position + Vector3.UP * aim_height
	var local: Vector3 = (pivot.get_parent() as Node3D).to_local(aim) - pivot.position
	var yaw := atan2(-local.x, -local.z)
	var pitch := atan2(local.y, Vector2(local.x, local.z).length())
	var lim := deg_to_rad(max_track_angle)
	yaw = _base_yaw + clampf(angle_difference(_base_yaw, yaw), -lim, lim)
	pivot.rotation.x = lerp_angle(pivot.rotation.x, pitch, track_speed * delta)
	pivot.rotation.y = lerp_angle(pivot.rotation.y, yaw, track_speed * delta)
	
## ДОложить охранникам. Связь через группу, камера не знает где будка
func _report() -> void:
	var pos := _target.global_position
	for g in get_tree().get_nodes_in_group("security_quard"):
		g.on_camera_sighting(_target, pos)

## Свет и конус должны соответствовать реальному обзору
func _fit_light_and_cone() -> void:
	light.spot_range = detect_range
	light.spot_angle = fov_degrees * 0.5	# Половина угла конуса
	light.transform = Transform3D.IDENTITY
	
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = detect_range * tan(deg_to_rad(fov_degrees * 0.5))
	m.height = detect_range
	cone.mesh = m
	cone.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)
	cone.position = Vector3(0.0, 0.0, -detect_range * 0.5)
	
	var src := cone.get_active_material(0) as StandardMaterial3D
	if src:
		_cone_mat = src.duplicate()
	else:
		_cone_mat = StandardMaterial3D.new()
		_cone_mat.albedo_color = Color(1, 1, 1, cone_alpha)
	_cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone_mat.no_depth_test = false
	cone.material_override = _cone_mat
	cone.transparency = 0.0
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

#endregion

func _apply_visual() -> void:
	var c := color_alert if state == State.TRACK else color_idle
	light.light_color = c
	if _cone_mat:
		_cone_mat.albedo_color = Color(c.r, c.g, c.b, _cone_mat.albedo_color.a)
