extends Node3D
class_name GrabComponent
# Захват предметов. Локально целится рэйкастом, а САМО действие просит у хоста (RPC).
# Физика притягивания живёт в предмете (item_test.gd) и считается на хосте.

@export var camera: Camera3D          # откуда пускаем луч (взгляд игрока)
@export var reach: float = 5.0        # дальность захвата

var _held_item: Node = null           # что держит этот игрок (имеет смысл только на сервере)
var _hover_target: Node = null        # цель прошлого кадра
var _grab_target: Node = null         # то, что взяли

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return                        # ввод читает ТОЛЬКО свой игрок

	var item := _aim_item()

	# шлём только при смене цели, а не каждый кадр
	if item != _hover_target:
		_hover_target = item
		Events.hover_target_changed.emit(item)

	if Input.is_action_just_pressed("grab"):
		if item:
			_request_grab.rpc_id(1, item.get_path())   # просим ХОСТА (id 1)

			_grab_target = item
			Events.local_item_held_changed.emit(item)
	elif Input.is_action_just_released("grab"):
		_request_release.rpc_id(1)
		if _grab_target:
			_grab_target = null
			Events.local_item_held_changed.emit(null)

# Локальный рэйкаст из камеры — только чтобы выбрать предмет (для картинки/выбора)
func _aim_item() -> Node:
	if camera == null:
		return null
	var space := camera.get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * reach   # -Z камеры = вперёд
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 8          # слой item (чтобы не хватать стены/игроков)
	var hit := space.intersect_ray(query)
	if hit and hit.collider is RigidBody3D and hit.collider.is_in_group("item"):
		return hit.collider
	return null

# Выполняется НА ХОСТЕ: хост валидирует и применяет захват
@rpc("any_peer", "call_local", "reliable")
func _request_grab(item_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var item = get_node_or_null(item_path)
	var who := get_multiplayer_authority()   # id владельца этого GrabComponent = кто просит
	if item and item.is_free():
		item.grab_by(who)                    # помечаем предмет занятым (физика внутри предмета)
		_held_item = item
		Events.item_grabbed.emit(item, who)
	

@rpc("any_peer", "call_local", "reliable")
func _request_release() -> void:
	if not multiplayer.is_server():
		return
	if _held_item and is_instance_valid(_held_item):
		_held_item.release()
		Events.item_dropped.emit(_held_item)
		_held_item = null
