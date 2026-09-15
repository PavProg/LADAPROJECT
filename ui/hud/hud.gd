extends Control

var player
@onready var healthValue: Label = $Stats/VBoxContainer/HealthRow/Value
@onready var staminaValue: Label = $Stats/VBoxContainer/StaminaRow/Value
@onready var quota: MarginContainer = $Quota
@onready var quotaValue: Label = $Quota/HBoxContainer/Value
@onready var crosshairTexture: TextureRect = $Crosshair/CrosshairTexture
@onready var healthSuffix: Label = $Stats/VBoxContainer/HealthRow/Suffix
@onready var staminaSuffix: Label = $Stats/VBoxContainer/StaminaRow/Suffix
@onready var quotaSuffix: Label = $Quota/HBoxContainer/Suffix
@onready var crosshair: CenterContainer = $Crosshair

@export_subgroup("Crosshairs")
@export var hoverCrosshairTexture : Texture2D
@export var defaultCrosshairTexture : Texture2D
@export var grabCrosshairTexture : Texture2D
@export_group("")

@export_subgroup("Quota popups")
@export var damageFeed: Control
@export var damagePopupScene: PackedScene
enum PopupMode { GLOBAL, LOCAL_ONLY }
@export var popup_mode: PopupMode = PopupMode.GLOBAL
@export_group("")

var _popup_queue: Array[int] = []
var _active_popup: DamagePopup = null

var is_holding : bool
var is_aiming : bool

var prevStamina : int = -1

func _ready():
	Events.hover_target_changed.connect(_hover_target_changed)
	Events.local_item_held_changed.connect(_local_item_held_changed)
	GameManager.quota_earned.connect(_on_quota_earned)
	
func _process(_delta: float) -> void:
	if not player:
		return
	# пока что никак не обновляется, будет работать от сигнала изменения
	healthValue.text = "%d " % player._health
	healthSuffix.text = "/ %d" % player.data.max_health
	quotaValue.text = "%d " % GameManager.current_quote
	quotaSuffix.text = "/ %d" % GameManager.required_quote
	if prevStamina != int(player.data.endurance):
		staminaValue.text = "%d " % player.data.endurance
		staminaSuffix.text = "/ %d" % player.data.max_endurance
		prevStamina = int(player.data.endurance)
func set_player(new_player):
	player = new_player
	is_holding = false
	is_aiming = false
	_update_crosshair()
	
func _hover_target_changed(item):
	is_aiming = item != null
	_update_crosshair()

func _local_item_held_changed(item):
	is_holding = item != null
	_update_crosshair()

func _update_crosshair():
	if is_holding:
		crosshairTexture.texture = grabCrosshairTexture
	elif is_aiming:
		crosshairTexture.texture = hoverCrosshairTexture
	else:
		crosshairTexture.texture = defaultCrosshairTexture
		
func show_popup_for_everyone(amount: int) -> void:
	_enqueue_popup(amount)
	
func show_popup_local_only(amount: int, earner_peer_id: int) -> void:
	if earner_peer_id == 0 or earner_peer_id == multiplayer.get_unique_id():
		_enqueue_popup(amount)

func _on_quota_earned(amount: int, earner_peer_id: int) -> void:
	#print("resived quota earned, trying to spawn popup")
	match popup_mode:
		PopupMode.GLOBAL:
			show_popup_for_everyone(amount)
		PopupMode.LOCAL_ONLY:
			show_popup_local_only(amount, earner_peer_id)
			
func _enqueue_popup(amount: int) -> void:
	#print("enqueu popup")
	if damageFeed == null or damagePopupScene == null:
		return
	_popup_queue.append(amount)
	_try_spawn_next_popup()

func _try_spawn_next_popup() -> void:
	#print("try spawn popup")
	# Пока активный попап жив — ждём
	if is_instance_valid(_active_popup):
		#print("active popup is invalid instance")
		return
	if _popup_queue.is_empty():
		#print("popup queue is empty")
		return

	var amount: int = _popup_queue.pop_front()
	_spawn_popup(amount)

func _spawn_popup(amount: int) -> void:
	#print("spawn popup")
	var popup: DamagePopup = damagePopupScene.instantiate()
	damageFeed.add_child(popup)
	_active_popup = popup
	popup.halfway_reached.connect(_on_popup_halfway)

	var quota_rect: Rect2 = quotaValue.get_global_rect()
	var damageFeed_rect: Rect2 = damageFeed.get_global_rect()
	
	var end_global: Vector2   = quota_rect.get_center() - damageFeed_rect.get_center()
	var start_global: Vector2 = Vector2(end_global.x, end_global.y + damageFeed_rect.get_center().y)
	
	#print("start_global = " + str(start_global) + ", end_global = " + str(end_global))

	popup.play(amount, start_global, end_global)


func _on_popup_halfway() -> void:
	# Активный долетел до середины — берём следующий из очереди
	_active_popup = null
	_try_spawn_next_popup()
