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

@export var hoverCrosshairTexture : Texture2D
@export var defaultCrosshairTexture : Texture2D
@export var grabCrosshairTexture : Texture2D

var is_holding : bool
var is_aiming : bool

var prevStamina : int = -1

func _ready():
	Events.hover_target_changed.connect(_hover_target_changed)
	Events.local_item_held_changed.connect(_local_item_held_changed)
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
