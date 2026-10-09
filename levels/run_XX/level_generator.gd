extends Node3D

#region создаем поля
# Порядок важен: каждый следующий = поворот на +90° вокруг Y в Godot.
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0),   # 0 East  (+X)
	Vector2i(0, -1),  # 1 North (-Z)
	Vector2i(-1, 0),  # 2 West  (-X)
	Vector2i(0, 1),   # 3 South (+Z)
]
## .tres файлы с инфой о комнатах
@export var rooms: Array[RoomData]   
@export var start_room: RoomData
## зашлушка двери 1x2
@export var door_cap: PackedScene
## размер одной клетки в gridMap в метрах
@export var cell_size: float = 2.0
## отвечает за то насколько ветвиста или линейна будет генерация. 0 - ветвисто, 1 - линейно
@export_range(0.0, 1.0) var linearity: float = 0.0
## кол-во попыток для генерации полного уровня
@export var max_restarts: int = 150
## Для отладки. Удобно воспроизводить сломанный уровень
@export var debug_seed: int = -1
## Количество комнат
@export var room_count: int = 50

## Сцена выхода с уровня
@export var exit_scene: PackedScene

## генератор случайных чисел, который сработает и на клиенте и на хосте одинаково
var rng = RandomNumberGenerator.new()
## уже расставленные комнаты {сслыка на RoomData, поворот двери, центр комнаты в клетках, прямоугольник после поворота комнаты, индекс родителя, индекс текущей комнаты}
var placed: Array[Dictionary] = []       # {data, rot, center, rect, parent, depth}
## открытыие двери расставленных комнат {индекс комнаты где дверь, направление двери, точка центра двери на ребре комнаты}
var open_doors: Array[Dictionary] = []   # {room, dir, point}
## соединения между расставленными комнатами {индекс комнаты a, направление двери a, **повтор для b**}
var connections: Array[Dictionary] = []  # {a, a_dir, b, b_dir} — мировые направления

var is_level_ready: bool = false

## Экземпляры комнат по индексу placed - чтобы не искать по имени
var _room_nodes: Array[Node3D] = []
#endregion

signal level_ready()

func _ready() -> void:
	add_to_group("level_generator")
	
	var seed_value: int = debug_seed if debug_seed >= 0 else LevelManager.level_seed
	print_rich("[color=yellow] PCG -- generate level, seed = %d" % seed_value)
	#generate(seed_value, room_count)
	var ok := generate(seed_value, room_count)
	if not ok:
		ok = generate(seed_value, room_count / 2)
	if not ok:
		push_error("PCG -- уровень не собран, seed = %d" % seed_value)
	print_rich("[color=yellow] PCG -- layout hash = %d" % _layout_hash())
	
	if multiplayer.is_server():
		var nav_region := get_parent() as NavigationRegion3D
		nav_region.bake_navigation_mesh(true)
		await nav_region.bake_finished
		# Готовый меш попадает на карту на след синхронизации
		await get_tree().physics_frame
	
	is_level_ready = true
	level_ready.emit()
	
	# Спавн убрал, спавном занимается Level Manager
	print_rich("[color=green] PCG -- end generate.")

func _layout_hash() -> int:
	var parts: Array = []
	for p in placed:
		parts.append([p.data.resource_path, p.rot, p.center])
	return hash(parts)

func generate(seed_value: int, count: int) -> bool:
	for attempt in max_restarts:
		# Производный seed: тот же seed_value всегда даёт ту же цепочку попыток, поэтому гееннрим другой (разность из-за attempt)
		rng.seed = seed_value * 1000003 + attempt
		if try_generate(count):
			spawn()
			return true
	push_error("Не удалось сгенерировать уровень за %d попыток" % max_restarts)
	return false

## одна попытка составления удачной схемы комнат
func try_generate(count: int) -> bool:
	placed.clear()
	open_doors.clear()
	connections.clear()
	place(start_room, 0, Vector2i.ZERO, -1, -1)

	while placed.size() < count:
		if open_doors.is_empty():
			return false  # комнат набралось слишком мало, а дверей открытых уже нет - перезапуск генерациии
		var idx: int
		# linearity - вероятность того что дверь, от которой мы пойдем дальше строить комнаты, будет последняя открытая дверь
		if rng.randf() < linearity:
			idx = open_doors.size() - 1
		else:
			idx = rng.randi_range(0, open_doors.size() - 1)
		# сохраняем параметры открытой двери
		var door: Dictionary = open_doors[idx]
		# дверь более неявляется открытой
		open_doors.remove_at(idx)
		#  пытаемся присобачить к двери комнату
		try_attach(door, count - placed.size())
	return true
 
func clear_items_from_level() -> void:
	print_rich("[color=red] PCG -- clear_items_from_level")
	var item_marks = owner.get_node_or_null("ItemMarks")
	if !item_marks: return
	
	print("PCG -- item_marks is correct")
	print("PCG -- ", item_marks.get_children())
	for child in item_marks.get_children():
		print("PCG -- child: ", child.name, " deleted!")
		item_marks.remove_child(child)
		child.queue_free()
		pass
pass

# Пытается приставить к двери door какую-нибудь комнату из пула
func try_attach(door: Dictionary, remaining: int) -> bool:
	var need_dir: int = (door.dir + 2) % 4  # новая дверь должна смотреть навстречу
	var room_candidates = rooms.duplicate()
	# перемешиваем комнаты каждый раз, чтоб комнаты были наиболее случайно подобраны
	shuffle(room_candidates)
 
	# берем каждую комнату, для нее смотрим направления дверей свободных и пытаемся прикрепить к этим дверям другие комнаты
	for room_data: RoomData in room_candidates:
		var local_dirs = door_dirs(room_data)
		# если нет дверей то увы
		if local_dirs.is_empty():
			continue
		# Пока комнат не хватает, не даём поставить тупик, если других дверей нет.
		if remaining > 1 and open_doors.size() + local_dirs.size() - 1 == 0:
			continue
			
		# размешали двери для рандомности
		shuffle(local_dirs)
		# каждую дверь берем, вычисляем поворот комнаты(насколько нужно повернуть для этой двери), размер комнаты после поворота, центр комнат повсле поворота
		for local_dir: int in local_dirs:
			var rot: int = (need_dir - local_dir + 4) % 4
			var size = rotated_size(room_data.size, rot)
			var center: Vector2i = door.point + DIRS[door.dir] * half_extent(size, door.dir)
			# в случае если выбранная комната пересекает какие-либо комнаты - то пробуем другую дверь комнаты для раастановки
			if overlaps(Rect2i(center - size / 2, size)):
				continue
			# если успешно то ставим комнату на нужное место
			var new_idx = place(room_data, rot, center, door.room, need_dir)
			connections.append({a = door.room, a_dir = door.dir, b = new_idx, b_dir = need_dir})
			return true
	return false
 
 
func place(data: RoomData, rot: int, center: Vector2i, parent: int, used_dir: int) -> int:
	var size = rotated_size(data.size, rot)
	var idx = placed.size()
	placed.append({
		data = data,
		rot = rot,
		center = center,
		rect = Rect2i(center - size / 2, size),
		parent = parent,
		depth = 0 if parent < 0 else placed[parent].depth + 1,
	})
	for local_dir: int in door_dirs(data):
		var d: int = (local_dir + rot) % 4
		if d == used_dir:
			continue
		open_doors.append( 
			{ room = idx, 
			dir = d, 
			point = center + DIRS[d] * half_extent(size, d) })
	return idx
 
 # проверка пересечений прямоугольников комнат между заданной и уже расставленными
func overlaps(r: Rect2i) -> bool:
	# Касание сторонами разрешено, пересечение — нет.
	for p in placed:
		var o: Rect2i = p.rect
		if r.position.x < o.end.x and o.position.x < r.end.x \
				and r.position.y < o.end.y and o.position.y < r.end.y:
			return true
	return false
 
## Ставит выход. Выбор комнаты без rng - одинаковый у всех пиров для сети
func _place_exit() -> void:
	if exit_scene == null:
		push_warning("PCG -- exit scene не задан, выхода с уровня не будет") 
		return
	var idx := _pick_exit_room()
	var room := _room_nodes[idx]
	var mark := room.get_node_or_null("ExitMark") as Marker3D
	
	var exit := exit_scene.instantiate() as Node3D
	exit.name = "LevelExit"	 # Фикс путь - rpc туалета дойдет
	add_child(exit)
	
	if mark:
		exit.global_transform = mark.global_transform	# Позиция и поворот от геядиза. МЕТКУ ПРОСТО ПОСТАВИТЬ И ВСЕ
	else:
		exit.global_position = room.global_position	 # запасной вариант по центру
	
	print_rich("[color=yellow] PCG -- выход в Room_%02d (depth %d, %s)"
		% [idx, placed[idx].depth, "метка" if mark else "центр"])

## Самая глубокая комната с ExitMark. Если нет - просто самая глубокая
func _pick_exit_room() -> int:
	var best_marked := -1
	var best_any := 0
	for i in range(1, placed.size()):
		if placed[i].depth > placed[best_any].depth:
			best_any = i
		if _room_nodes[i].has_node("ExitMark"):
			if best_marked < 0 or placed[i].depth > placed[best_marked].depth:
				best_marked = i
	return best_marked if best_marked >= 0 else best_any

# создание сцены на уже успешно сгенерированном графе
func spawn() -> void:
	
	#clear_items_from_level()
	for child in get_children():
		child.queue_free()
	_room_nodes.clear()
	
	# инитим словрь как "соединение" - "да"
	var connected = {}
	for c in connections:
		connected[Vector2i(c.a, c.a_dir)] = true
		connected[Vector2i(c.b, c.b_dir)] = true

	for i in placed.size():
		
		var placed_room: Dictionary = placed[i]
		var room_instance: Node3D = placed_room.data.scene.instantiate()
		
		room_instance.position = Vector3(placed_room.center.x, 0, placed_room.center.y) * cell_size
		room_instance.rotation.y = placed_room.rot * PI / 2
		room_instance.name = "Room_%02d" % i	# индекс одинаковый у всех
		add_child(room_instance)
		_room_nodes.append(room_instance)
 	
		migrate_marks(room_instance)
	
		### Закрываем проёмы, к которым ничего не подключилось.
		# если проем закрыть нечем то увы скип
		if door_cap == null:
			continue
			
		var size = rotated_size(placed_room.data.size, placed_room.rot)
		for local_dir: int in door_dirs(placed_room.data):
			var door: int = (local_dir + placed_room.rot) % 4
			# если дверь приконнекчена к чему-то то ей заглушка не надо
			if connected.has(Vector2i(i, door)):
				continue
				
			# точка на которую нужно поставить заглушку
			var point: Vector2i = placed_room.center + DIRS[door] * half_extent(size, door)
			
			# Стена толщиной в 1 клетку лежит внутри комнаты: сдвиг на полклетки внутрь.
			var pos := Vector2(point) - Vector2(DIRS[door]) * 0.5
			var cap_instance: Node3D = door_cap.instantiate()
			cap_instance.position = Vector3(pos.x, 0, pos.y) * cell_size
			cap_instance.rotation.y = door * PI / 2
			cap_instance.name = "Cap_%02d_%d" % [i, door]
			add_child(cap_instance)
	_place_exit()
	
	for i in owner.get_node("EnemyMarkCont").get_children():
		if i is EnemyMark and i.patrol_zone == null:
			push_warning("PCG -- у метки %s нет зоны патруля" % i.name)
 
# функции хэлперы
 
func door_dirs(data: RoomData) -> Array[int]:
	var res: Array[int] = []
	for d in 4:
		# смотрим что двери валидны и тогда смотрим каждую сторону на наличие дверей. По итогу записываем 0-3 числа в результат res
		if data.doors & (1 << d):
			res.append(d)
	return res
 
 
func rotated_size(size: Vector2i, rot: int) -> Vector2i:
	if rot % 2 == 0:
		return size
	else:
		return Vector2i(size.y, size.x)
 
 
## Половина размера (уже повёрнутой) комнаты вдоль направления dir.
func half_extent(size: Vector2i, dir: int) -> int:
	if dir % 2 == 0:
		return size.x / 2 
	else:
		return size.y / 2
 
 
## Перемешивание только через свой rng (Array.shuffle() использует глобальный рандом).
func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func shuffle_node_children(parent: Node) -> void:
	var children = parent.get_children()
	shuffle(children)
	for i in children.size():
		parent.move_child(children[i], i)

# перенесение меток со сцены уровня на главный уровень
func migrate_marks(room_instance: Node3D) -> void:
	#print("PCG -- room_instance: ", room_instance.name)
	parse_item_groups(room_instance)
	migrate_item_marks(room_instance)
	migrate_enemies(room_instance)
	pass

func migrate_enemies(room_instance: Node3D) -> void:
	migrate_enemy_zones(room_instance)
	migrate_enemy_marks(room_instance)
	pass


func parse_item_groups(room_instance: Node3D) -> void:
	#print("PCG -- parse_item_groups")
	var groups := room_instance.get_node_or_null("ItemMarksGrouped")
	if groups == null:
		return
	var target := owner.get_node_or_null("ItemMarks")
	
	for group in groups.get_children():
		if not (group is ItemMarksGroup):
			continue
	
		# Копируем содержимое на листок. reparent меняет дерево, но не этот массив
		var marks: Array = group.get_children().filter(func(m): return m is Marker3D)
		if marks.is_empty():
			continue
		
		# Сколько меток берем через rng уровня в пределах реального числа меток
		var lo := clampi(group.marks_in_group_MIN, 0, marks.size())
		var hi := clampi(group.marks_in_group_MAX, lo, marks.size())
		var need := rng.randi_range(lo, hi)
		
		# Перемешать один раз
		shuffle(marks)
		
		# Первые need штук - в общий контейнер
		for i in need:
			marks[i].reparent(target)


func migrate_item_marks(room_instance: Node3D) -> void:
	#print("PCG -- migrate_item_marks")
	
	var item_marks = room_instance.get_node_or_null("ItemMarks") as Node3D
	if !item_marks or item_marks.get_child_count() == 0: return

	#print("PCG -- item_marks found")
	for item in item_marks.get_children():
		if item and item is Marker3D:
			item.reparent(owner.get_node_or_null("ItemMarks"))
	pass
	
func migrate_enemy_zones(room_instance: Node3D) -> void:
	#print("PCG -- migrate_enemy_zones")
	
	var enemy_zones = room_instance.get_node_or_null("RatZones") as Node3D
	if !enemy_zones or enemy_zones.get_child_count() == 0: return
	
	#print("PCG -- enemy_zones found")
	for zone in enemy_zones.get_children():
		if zone and zone is CollisionShape3D:
			zone.reparent(owner.get_node_or_null("RatZones"))
	
	pass
	
func migrate_enemy_marks(room_instance: Node3D) -> void:
	#print("PCG -- migrate_enemy_marks")
	
	var enemy_marks = room_instance.get_node_or_null("EnemyMarkCont") as Node3D
	if !enemy_marks or enemy_marks.get_child_count() == 0: return
	
	#print("PCG -- enemy_marks found")
	for mark in enemy_marks.get_children():
		if mark and mark is Marker3D:
			mark.reparent(owner.get_node_or_null("EnemyMarkCont"))
	pass
