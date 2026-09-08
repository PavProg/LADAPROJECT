extends Node3D
class_name GrabComponent
# Захват предметов. Локально целится рэйкастом, а САМО действие просит у хоста (RPC).
# Физика притягивания живёт в предмете (item_test.gd) и считается на хосте.

@export var camera: Camera3D          # откуда пускаем луч (взгляд игрока)
@export var reach: float = 5.0        # дальность захвата

var _held_object: Node = null           # что держит этот игрок (имеет смысл только на сервере)
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
	query.collision_mask = 4104          # слой item и рэгдол (чтобы не хватать стены/игроков)
	query.exclude = owner.exceptions
	
	var hit := space.intersect_ray(query)
	if hit:
		if hit.collider is RigidBody3D and hit.collider.is_in_group("item"):
			#print("RigidBody3D")
			return hit.collider
			
		elif hit.collider is PhysicalBone3D:
			if !hit.collider.owner.owner.is_ragdoll: return
			return hit.collider

	return null

# Выполняется НА ХОСТЕ: хост валидирует и применяет захват
@rpc("any_peer", "call_local", "reliable")
func _request_grab(item_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var grabbed_object = get_node_or_null(item_path)
	var who := get_multiplayer_authority()   # id владельца этого GrabComponent = кто просит
	# если хватаем объект
	if grabbed_object and grabbed_object.is_in_group("item"):
		grabbed_object.enable_gravity(true)
		owner.try_grab(grabbed_object)
		_held_object = grabbed_object
		grabbed_object.play_sound()
		Events.item_grabbed.emit(grabbed_object, who)
		pass
	# если хватаем рэгдол игрока
	elif grabbed_object and grabbed_object is PhysicalBone3D:
		owner.try_grab(grabbed_object)
		_held_object = grabbed_object
		Events.item_grabbed.emit(grabbed_object, who)
		pass

@rpc("any_peer", "call_local", "reliable")
func _request_release() -> void:
	if not multiplayer.is_server(): return
	if _held_object and is_instance_valid(_held_object):
		owner.release_grab()
		Events.item_dropped.emit(_held_object)
		_held_object = null
