extends Node3D

var item: RigidBody3D

@onready var timer: Timer = $TakeDamageTimer
var take_damage_recovery_time: float = 2.0 # кол-во секунд между ударами
var can_be_hitted: bool = true # может ли быть объект сейчас ударен

func _ready() -> void:
	pass


func _process(delta: float) -> void:
	pass


func _physics_process(_delta: float) -> void:
	pass

func take_damage(dmg: float) -> void:
	if !can_be_hitted: return
	var final_damage = clamp(dmg, 0, get_parent().item_data.durability) # клампим урон от 0 до текущей прочности предмета
	#print("ATTACK_COMPONENT -- Item NAME: %s HP: %d, income_DMG: %d" % [get_parent().name, get_parent().item_data.durability, final_damage])
	get_parent().item_data.durability -= final_damage
	GameManager.on_quote_earned(final_damage) # QUOTE
	can_be_hitted = false
	
	if get_parent().item_data.durability <= 0.0:
		distruction()
		return
		
	timer.stop()
	timer.wait_time = take_damage_recovery_time
	timer.start()
	pass

func distruction() -> void:
	
	item.get_node("Mesh").visible = false
	item.get_node("Collision").disabled = true # одна коллизиия всегда есть, отключаем
	# проверка если заведены еще коллизиии объекта
	for i in range(5):
		var name: String = "Collision" + str(i+1)
		var coll = item.get_node_or_null(name)
		if coll:
			item.get_node_or_null(name).disabled = true
			#print("Collision%d DISABLED" % (i + 1))
		else:
			break
		pass
		
	# спавн сцены с фрагментами меша
	if item.item_data.distructed_scene == null or not item.item_data.distructed_scene is PackedScene:
		push_error("distructed_scene не задан или битый у %s" % item.name)
		return
	var fragments = item.item_data.distructed_scene.instantiate()
	if fragments == null:
		push_error("instantiate() вернул null для %s" % item.name)
		return
	fragments.global_transform = item.global_transform
	item.get_parent().add_child(fragments)
	for child in fragments.get_children():
		child.apply_central_impulse(Vector3(
			randf_range(-3, 3), 
			randf_range(-1, 3),
			randf_range(-3, 3)
			))
	await get_tree().create_timer(2.0).timeout
	item.queue_free()
	pass


func _on_take_damage_timer_timeout() -> void:
	can_be_hitted = true
	pass
