extends HoldableBody

@onready var durability_label: Label3D = $DurabilityLabel
@onready var damage_label: Label3D = $DamageLabel
@onready var sound_player: AudioStreamPlayer3D = get_node_or_null("AudioStreamPlayer3D")
@export var filename: String
@export var export_item_data: Resource
var item_data: Resource

# Физика притягивания живёт в предмете и считается только на авторитете (хосте). 
# Предмет знает, кто его держит (held_by), и сам тянется к точке удержания этого игрока.

# Отладка
#func _process(delta: float) -> void:
	#if not is_multiplayer_authority():
		#print("[ITEM/sync] pos=%s auth=%d" % [global_position, get_multiplayer_authority()])

func _ready() -> void:
	add_to_group("item")
	super._ready()
	item_data = export_item_data
	if not item_data.display_name == "hummer":
		update_durability_label_value()

func grab_by(peer_id: int) -> void:
	set_durability_label_visibility(true)
	

func release() -> void:
	set_durability_label_visibility(false)


func set_durability_label_visibility(is_visible: bool) -> void:
	if durability_label:
		durability_label.visible = is_visible
	pass

# включить и анимировать damage label
func toggle_damage_label(damage: int) -> void:
	if item_data.display_name == "hummer":
		print("[LABEL] Ошибка label молотка 0")
	damage_label.text = str(damage)
	damage_label.scale = Vector3.ZERO
	damage_label.modulate = Color.WHITE 
	damage_label.visible = true
	
	# Создаем твин от имени damage_label
	var tween = damage_label.create_tween()
	
	# Устанавливает тип перехода
	tween.set_trans(Tween.TRANS_CUBIC)
	#tween.set_ease(Tween.EASE_OUT)
	
	# Плавный взлет вверх
	#var target_y = damage_label.position.y + 1.5
	#tween.tween_property(damage_label, "position:y", target_y, 1.0)
	
	# Пульсация размера
	tween.parallel().tween_property(damage_label, "scale", Vector3(1.2, 1.2, 1.2), 1.0)
	tween.tween_property(damage_label, "modulate:a", 0.0, 0.3)
	
	tween.tween_callback(func(): damage_label.visible = false)
	pass
	
func update_durability_label_value():
	if item_data.display_name == "hummer":
		print("[LABEL] Ошибка label молотка")
	if durability_label: 
		durability_label.text = str(item_data.durability)
	pass


func play_sound() -> void:
	if sound_player == null:
		return
	if item_data.sound == null:
		return

	sound_player.stream = item_data.sound
	sound_player.volume_db = -30.0
	sound_player.play()
